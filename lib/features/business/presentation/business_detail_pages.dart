import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/localization/vault_strings.dart';
import '../../../app/vault_providers.dart';
import '../../../core/finance/formatters.dart';
import '../../../shared/widgets/record_audit.dart';
import '../../../shared/widgets/vault_widgets.dart';
import '../data/business_repository.dart';
import 'business_pages.dart';

String stockLabel(String kind) => switch (kind) {
  'opening' => 'Opening stock',
  'purchase' => 'Stock purchase',
  'stock_out' => 'Stock issued',
  'return' => 'Stock returned',
  'adjustment' => 'Stock count reduction',
  'reversal' => 'Reversal',
  _ => 'Stock movement',
};

class WorkRecordPage extends ConsumerStatefulWidget {
  const WorkRecordPage({required this.id, required this.isStock, super.key});
  final String id;
  final bool isStock;
  @override
  ConsumerState<WorkRecordPage> createState() => _WorkRecordPageState();
}

class _WorkRecordPageState extends ConsumerState<WorkRecordPage> {
  bool _busy = false;
  Object? _error;

  Future<void> _save(Future<void> Function(BusinessRepository) action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = ref.read(vaultProvider).session!;
      await action(BusinessRepository(session.ledger));
      if (mounted) {
        savedNotice(context, cloud: session.identity.isCloud);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _reverse({
    required String noun,
    required Future<void> Function(BusinessRepository, String) action,
  }) async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => ReasonDialog(
        title: context.tr("Reverse this {kind}?", {'kind': context.tr(noun)}),
        message: context.tr(
          'The original record and its reversal will stay in the history.',
        ),
        confirmLabel: context.tr('Reverse'),
      ),
    );
    if (reason == null || !mounted) {
      return;
    }
    await _save((repo) => action(repo, reason));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.isStock
            ? context.tr('Stock details')
            : context.tr('Worker details'),
      ),
    ),
    body: BusinessView(
      builder: (data, finance) {
        if (widget.isStock) {
          return _stock(data);
        }
        final reversed = finance.journals
            .where((j) => j.deletedAtUs != null)
            .map((j) => j.id)
            .toSet();
        return _worker(data, reversed);
      },
    ),
  );

  Widget _stock(BusinessSnapshot data) {
    final row = data.items.where((r) => r.id == widget.id).firstOrNull;
    if (row == null) {
      return VaultContent(
        children: [Text(context.tr('Stock item unavailable.'))],
      );
    }
    final position = data.positions[row.id], archived = row.deletedAtUs != null;
    final history = data.movements.where((r) => r.stockItemId == row.id);
    final latest = data.activeMovements(row.id).firstOrNull;
    final reversed = history.map((r) => r.reversesId).nonNulls.toSet();
    return VaultContent(
      maxWidth: 800,
      children: [
        MetricCard(
          title: row.name,
          value: '${position?.quantity ?? 0} pieces',
          icon: Icons.inventory_2_outlined,
          emphasis: true,
          detail: context.tr("{cost} recorded cost{sku}{status}", {
            'cost': formatInr(BigInt.from(position?.costPoolMinor ?? 0)),
            'sku': row.sku == null
                ? ''
                : '\n${context.tr('SKU {code}', {'code': row.sku})}',
            'status': archived ? '\nArchived' : '',
          }),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            if (!archived) ...[
              FilledButton.icon(
                onPressed: () => context.push('/stock/${row.id}/move'),
                icon: const Icon(Icons.add),
                label: Text(context.tr('Record stock movement')),
              ),
              OutlinedButton.icon(
                onPressed: () => context.push('/stock/${row.id}/edit'),
                icon: const Icon(Icons.edit_outlined),
                label: Text(context.tr('Edit stock item')),
              ),
            ],
            if (archived || position?.quantity == 0)
              OutlinedButton.icon(
                onPressed: _busy
                    ? null
                    : () => _save(
                        (repo) => repo.archiveItem(
                          row.id,
                          row.revision,
                          restore: archived,
                        ),
                      ),
                icon: Icon(
                  archived ? Icons.unarchive_outlined : Icons.archive_outlined,
                ),
                label: Text(
                  archived
                      ? context.tr('Restore item')
                      : context.tr('Archive item'),
                ),
              ),
          ],
        ),
        if (_error != null) FailureNotice(_error!),
        const SizedBox(height: 24),
        SectionHeading(context.tr('Stock movement history')),
        if (history.isEmpty) Text(context.tr('No stock movements recorded.')),
        for (final move in history)
          Card.outlined(
            child: Column(
              children: [
                ListTile(
                  title: Text(
                    '${context.tr(stockLabel(move.kind))}${reversed.contains(move.id) ? context.tr(' · Reversed') : ''}',
                  ),
                  subtitle: Text(
                    context.tr(
                      "{date} · {sign}{quantity} pieces\n{value}{note}",
                      {
                        'date': move.occurredOn,
                        'sign': move.quantityDelta > 0 ? '+' : '',
                        'quantity': move.quantityDelta,
                        'value': formatInr(BigInt.from(move.valueDeltaMinor)),
                        'note': move.notes.isEmpty ? '' : '\n${move.notes}',
                      },
                    ),
                  ),
                  trailing: move.journalId == null
                      ? null
                      : const Icon(Icons.chevron_right),
                  onTap: move.journalId == null
                      ? null
                      : () => context.push('/transaction/${move.journalId}'),
                ),
                if (!archived && latest?.id == move.id)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => context.push(
                                  '/stock/${row.id}/move/${move.id}',
                                ),
                          child: Text(context.tr('Correct movement')),
                        ),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => _reverse(
                                  noun: 'stock movement',
                                  action: (repo, reason) => repo.correctStock(
                                    row.id,
                                    row.revision,
                                    move.id,
                                    reason,
                                  ),
                                ),
                          child: Text(context.tr('Undo stock change')),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        RecordAudit(entityId: row.id),
      ],
    );
  }

  Widget _worker(BusinessSnapshot data, Set<String> reversed) {
    final row = data.workers.where((r) => r.id == widget.id).firstOrNull;
    if (row == null) {
      return VaultContent(children: [Text(context.tr('Worker unavailable.'))]);
    }
    final archived = row.deletedAtUs != null;
    final payments = data.salaries.where((r) => r.workerId == row.id);
    final paid = payments
        .where((r) => !reversed.contains(r.journalId))
        .fold(BigInt.zero, (sum, r) => sum + BigInt.from(r.amountMinor));
    return VaultContent(
      maxWidth: 800,
      children: [
        MetricCard(
          title: row.name,
          value: formatInr(paid),
          icon: Icons.person_outline,
          emphasis: true,
          detail: context.tr("Total wages recorded{status}\n{monthly}", {
            'status': archived ? context.tr(' · Archived') : '',
            'monthly': row.monthlySalaryMinor == null
                ? context.tr('Monthly pay unrecorded')
                : '${formatInr(BigInt.from(row.monthlySalaryMinor!))} agreed monthly pay',
          }),
        ),
        if (row.notes.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(row.notes),
          ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            if (!archived) ...[
              FilledButton.icon(
                onPressed: () => context.push('/worker/${row.id}/pay'),
                icon: const Icon(Icons.payments_outlined),
                label: Text(context.tr('Record salary payment')),
              ),
              OutlinedButton.icon(
                onPressed: () => context.push('/worker/${row.id}/edit'),
                icon: const Icon(Icons.edit_outlined),
                label: Text(context.tr('Edit worker')),
              ),
            ],
            OutlinedButton.icon(
              onPressed: _busy
                  ? null
                  : () => _save(
                      (repo) => repo.archiveWorker(
                        row.id,
                        row.revision,
                        restore: archived,
                      ),
                    ),
              icon: Icon(
                archived ? Icons.unarchive_outlined : Icons.archive_outlined,
              ),
              label: Text(
                archived
                    ? context.tr('Restore worker')
                    : context.tr('Archive worker'),
              ),
            ),
          ],
        ),
        if (_error != null) FailureNotice(_error!),
        const SizedBox(height: 24),
        SectionHeading(context.tr('Salary payment history')),
        if (payments.isEmpty)
          Text(context.tr('No salaries recorded for this worker.')),
        for (final payment in payments)
          Card.outlined(
            child: Column(
              children: [
                ListTile(
                  title: Text(
                    '${payment.period} · ${formatInr(BigInt.from(payment.amountMinor))}',
                  ),
                  subtitle: Text(
                    context.tr("Paid {date}{status}{note}", {
                      'date': payment.paidOn,
                      'status': reversed.contains(payment.journalId)
                          ? context.tr(' · Reversed')
                          : '',
                      'note': payment.notes.isEmpty ? '' : '\n${payment.notes}',
                    }),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      context.push('/transaction/${payment.journalId}'),
                ),
                if (!archived && !reversed.contains(payment.journalId))
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Wrap(
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => context.push(
                                  '/worker/${row.id}/pay/${payment.id}',
                                ),
                          child: Text(context.tr('Correct payment')),
                        ),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => _reverse(
                                  noun: 'salary payment',
                                  action: (repo, reason) => repo.correctSalary(
                                    row.id,
                                    row.revision,
                                    payment.id,
                                    reason,
                                  ),
                                ),
                          child: Text(context.tr('Reverse payment')),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        RecordAudit(entityId: row.id),
      ],
    );
  }
}
