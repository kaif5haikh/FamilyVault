import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

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
        title: 'Reverse this $noun?',
        message:
            'The original record and its reversal will stay in the history.',
        confirmLabel: 'Reverse',
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
      title: Text(widget.isStock ? 'Stock details' : 'Worker details'),
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
      return const VaultContent(children: [Text('Stock item unavailable.')]);
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
          detail:
              '${formatInr(BigInt.from(position?.costPoolMinor ?? 0))} recorded cost${row.sku == null ? '' : '\nSKU ${row.sku}'}${archived ? '\nArchived' : ''}',
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
                label: const Text('Record stock movement'),
              ),
              OutlinedButton.icon(
                onPressed: () => context.push('/stock/${row.id}/edit'),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit stock item'),
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
                label: Text(archived ? 'Restore item' : 'Archive item'),
              ),
          ],
        ),
        if (_error != null) FailureNotice(_error!),
        const SizedBox(height: 24),
        const SectionHeading('Stock movement history'),
        if (history.isEmpty) const Text('No stock movements recorded.'),
        for (final move in history)
          Card.outlined(
            child: Column(
              children: [
                ListTile(
                  title: Text(
                    '${stockLabel(move.kind)}${reversed.contains(move.id) ? ' · Reversed' : ''}',
                  ),
                  subtitle: Text(
                    '${move.occurredOn} · ${move.quantityDelta > 0 ? '+' : ''}${move.quantityDelta} pieces\n${formatInr(BigInt.from(move.valueDeltaMinor))}${move.notes.isEmpty ? '' : '\n${move.notes}'}',
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
                          child: const Text('Correct movement'),
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
                          child: const Text('Undo stock change'),
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
      return const VaultContent(children: [Text('Worker unavailable.')]);
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
          detail:
              'Total wages recorded${archived ? ' · Archived' : ''}\n${row.monthlySalaryMinor == null ? 'Monthly pay unrecorded' : '${formatInr(BigInt.from(row.monthlySalaryMinor!))} agreed monthly pay'}',
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
                label: const Text('Record salary payment'),
              ),
              OutlinedButton.icon(
                onPressed: () => context.push('/worker/${row.id}/edit'),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit worker'),
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
              label: Text(archived ? 'Restore worker' : 'Archive worker'),
            ),
          ],
        ),
        if (_error != null) FailureNotice(_error!),
        const SizedBox(height: 24),
        const SectionHeading('Salary payment history'),
        if (payments.isEmpty)
          const Text('No salaries recorded for this worker.'),
        for (final payment in payments)
          Card.outlined(
            child: Column(
              children: [
                ListTile(
                  title: Text(
                    '${payment.period} · ${formatInr(BigInt.from(payment.amountMinor))}',
                  ),
                  subtitle: Text(
                    'Paid ${payment.paidOn}${reversed.contains(payment.journalId) ? ' · Reversed' : ''}${payment.notes.isEmpty ? '' : '\n${payment.notes}'}',
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
                          child: const Text('Correct payment'),
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
                          child: const Text('Reverse payment'),
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
