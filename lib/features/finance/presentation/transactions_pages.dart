import 'dart:convert';

import 'package:drift/drift.dart' hide Column, Table;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/vault_providers.dart';
import '../../../core/database/app_database.dart';
import '../../../core/finance/formatters.dart';
import '../../../shared/widgets/vault_widgets.dart';
import '../data/ledger_repository.dart';

final _membersProvider = StreamProvider.autoDispose<Map<String, String>>((ref) {
  final session = ref.watch(vaultProvider).session;
  if (session == null) {
    return const Stream.empty();
  }
  return (session.db.select(session.db.familyMembers)
        ..where((t) => t.familyId.equals(session.identity.familyId)))
      .watch()
      .map((rows) => {for (final row in rows) row.id: row.displayName});
});
final auditProvider = StreamProvider.autoDispose
    .family<List<LocalAuditEvent>, String>((ref, id) {
      final session = ref.watch(vaultProvider).session;
      if (session == null) {
        return const Stream.empty();
      }
      return (session.db.select(session.db.localAuditEvents)
            ..where(
              (t) =>
                  t.familyId.equals(session.identity.familyId) &
                  t.entityId.equals(id),
            )
            ..orderBy([(t) => OrderingTerm.desc(t.createdAtUs)]))
          .watch();
    });

class TransactionsPage extends StatefulWidget {
  const TransactionsPage({super.key});
  @override
  State<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends State<TransactionsPage> {
  String _query = '', _kind = 'All';
  bool _history = false;
  @override
  Widget build(BuildContext context) => FinanceView(
    builder: (data) {
      final query = _query.trim().toLowerCase();
      final journals = data.journals
          .where(
            (j) =>
                j.status == 'posted' &&
                (_history || (j.deletedAtUs == null && j.kind != 'reversal')) &&
                (_kind == 'All' || j.kind == _kind.toLowerCase()) &&
                (query.isEmpty ||
                    '${j.description} ${j.occurredOn}'.toLowerCase().contains(
                      query,
                    )),
          )
          .toList();
      return VaultContent(
        children: [
          SectionHeading(
            'Your financial activity',
            action: FilledButton.icon(
              onPressed: () => context.push('/transaction/new'),
              icon: const Icon(Icons.add),
              label: const Text('Add transaction'),
            ),
          ),
          TextField(
            decoration: const InputDecoration(
              labelText: 'Search description or date',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final kind in ['All', 'Income', 'Expense', 'Transfer'])
                ChoiceChip(
                  label: Text(kind),
                  selected: kind == _kind,
                  onSelected: (_) => setState(() => _kind = kind),
                ),
            ],
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Show reversals and corrected originals'),
            value: _history,
            onChanged: (v) => setState(() => _history = v),
          ),
          const SizedBox(height: 12),
          if (journals.isEmpty)
            const EmptyNotice(
              icon: Icons.receipt_long_outlined,
              title: 'No transactions here yet',
              message: 'Add income, an expense or a transfer. Your entries are saved even without an internet connection.',
            ),
          for (final journal in journals)
            JournalTile(journal: journal, snapshot: data),
        ],
      );
    },
  );
}

class JournalTile extends StatelessWidget {
  const JournalTile({required this.journal, required this.snapshot, super.key});
  final LedgerJournal journal;
  final FinanceSnapshot snapshot;
  @override
  Widget build(BuildContext context) {
    final value = snapshot.postings
        .where((p) => p.journalId == journal.id && p.amountMinor > 0)
        .fold(BigInt.zero, (sum, p) => sum + BigInt.from(p.amountMinor));
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card.outlined(
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: colors.surfaceContainerHighest,
            child: Icon(switch (journal.kind) {
              'income' => Icons.south_west,
              'expense' => Icons.north_east,
              'transfer' => Icons.swap_horiz,
              'reversal' => Icons.undo,
              _ => Icons.receipt_outlined,
            }, color: colors.primary),
          ),
          title: Text(journal.description),
          subtitle: Text(
            '${journal.occurredOn} · ${journal.kind}${journal.deletedAtUs != null ? ' · Reversed' : ''}\n${formatInr(value)}',
          ),
          isThreeLine: true,
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/transaction/${journal.id}'),
        ),
      ),
    );
  }
}

class JournalDetailPage extends ConsumerStatefulWidget {
  const JournalDetailPage({required this.id, super.key});
  final String id;
  @override
  ConsumerState<JournalDetailPage> createState() => _JournalDetailPageState();
}

class _JournalDetailPageState extends ConsumerState<JournalDetailPage> {
  bool _busy = false;
  Object? _error;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Transaction details')),
    body: FinanceView(
      builder: (data) {
        final journal = data.journals
            .where((j) => j.id == widget.id)
            .firstOrNull;
        if (journal == null) {
          return const VaultContent(
            children: [Text('Transaction unavailable in this family.')],
          );
        }
        final postings =
            data.postings.where((p) => p.journalId == journal.id).toList()
              ..sort((a, b) => a.position.compareTo(b.position));
        final value = postings
            .where((p) => p.amountMinor > 0)
            .fold(BigInt.zero, (sum, p) => sum + BigInt.from(p.amountMinor));
        final members =
            ref.watch(_membersProvider).value ?? const <String, String>{};
        final reversed = data.journals
            .where((j) => j.reversesId == journal.id)
            .firstOrNull;
        final link = data.journalLinks[journal.id];
        return VaultContent(
          maxWidth: 800,
          children: [
            MetricCard(
              title: journal.deletedAtUs != null
                  ? 'Reversed ${journal.kind}'
                  : journal.kind[0].toUpperCase() + journal.kind.substring(1),
              value: formatInr(value),
              icon: Icons.receipt_long_outlined,
              detail: journal.occurredOn,
              emphasis: true,
            ),
            const SizedBox(height: 24),
            Text(
              journal.description,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text('Created by ${members[journal.createdBy] ?? 'family member'}'),
            if (journal.updatedBy != journal.createdBy)
              Text(
                'Last modified by ${members[journal.updatedBy] ?? 'family member'}',
              ),
            const SizedBox(height: 20),
            if (link?.aggregateType == 'asset' ||
                link?.aggregateType == 'asset_rent')
              TextButton.icon(
                onPressed: () => context.push('/asset/${link!.aggregateId}'),
                icon: const Icon(Icons.diamond_outlined),
                label: const Text('View related holding'),
              ),
            if (link?.aggregateType == 'debt')
              TextButton.icon(
                onPressed: () => context.push('/loan/${link!.aggregateId}'),
                icon: const Icon(Icons.request_quote_outlined),
                label: const Text('View related loan'),
              ),
            if (link == null &&
                journal.deletedAtUs == null &&
                journal.kind != 'reversal')
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  if (['income', 'expense', 'transfer'].contains(journal.kind))
                    OutlinedButton.icon(
                      onPressed: _busy
                          ? null
                          : () =>
                                context.push('/transaction/${journal.id}/edit'),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Correct entry'),
                    ),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _reverse(journal.id),
                    icon: const Icon(Icons.undo),
                    label: const Text('Reverse entry'),
                  ),
                ],
              ),
            if (journal.reversesId != null)
              TextButton.icon(
                onPressed: () =>
                    context.push('/transaction/${journal.reversesId}'),
                icon: const Icon(Icons.history),
                label: const Text('View original entry'),
              ),
            if (reversed != null)
              TextButton.icon(
                onPressed: () => context.push('/transaction/${reversed.id}'),
                icon: const Icon(Icons.undo),
                label: const Text('View reversal'),
              ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              FailureNotice(_error!),
            ],
            const SizedBox(height: 24),
            Card.outlined(
              child: ExpansionTile(
                title: const Text('Balanced accounting entries'),
                children: [
                  for (final posting in postings)
                    ListTile(
                      title: Text(
                        data.accounts
                                .where((a) => a.id == posting.accountId)
                                .firstOrNull
                                ?.name ??
                            'Account',
                      ),
                      subtitle: Text(
                        '${posting.amountMinor > 0 ? 'Debit' : 'Credit'} · ${formatInr(BigInt.from(posting.amountMinor).abs())}',
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const SectionHeading('Audit history'),
            AuditHistory(entityId: journal.id),
          ],
        );
      },
    ),
  );
  Future<void> _reverse(String id) async {
    final text = await showDialog<String>(
      context: context,
      builder: (_) => const ReasonDialog(
        title: 'Reverse this entry?',
        message: 'This adds equal and opposite entries. The original and its audit trail stay intact.',
        confirmLabel: 'Reverse',
      ),
    );
    if (text == null || !mounted) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = ref.read(vaultProvider).session!;
      await session.ledger.reverse(id, reason: text);
      if (mounted) {
        savedNotice(context, cloud: session.identity.isCloud);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = error);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }
}

class AuditHistory extends ConsumerWidget {
  const AuditHistory({required this.entityId, super.key});
  final String entityId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members =
        ref.watch(_membersProvider).value ?? const <String, String>{};
    return ref
        .watch(auditProvider(entityId))
        .when(
          loading: () => const LinearProgressIndicator(),
          error: (e, _) => FailureNotice(e),
          data: (events) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final event in events)
                Card.outlined(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${event.action} · ${members[event.actorId] ?? 'Family member'}',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          DateTime.fromMicrosecondsSinceEpoch(
                            event.createdAtUs,
                            isUtc: true,
                          ).toLocal().toString().split('.').first,
                        ),
                        if (event.action == 'correct' &&
                            event.afterJson != null)
                          Builder(
                            builder: (context) {
                              final record = jsonDecode(
                                event.afterJson!,
                              ) as Map<String, Object?>;
                              final bundle =
                                  record['_bundle'] as Map<String, Object?>?;
                              final original =
                                  bundle?['original'] as Map<String, Object?>?;
                              return original == null
                                  ? const SizedBox.shrink()
                                  : TextButton.icon(
                                      onPressed: () => context.push(
                                        '/transaction/${original['id']}',
                                      ),
                                      icon: const Icon(Icons.history),
                                      label: const Text(
                                        'View corrected original',
                                      ),
                                    );
                            },
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
  }
}
