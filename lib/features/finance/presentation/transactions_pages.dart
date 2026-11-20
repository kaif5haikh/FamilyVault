import 'dart:convert';

import 'package:drift/drift.dart' hide Column, Table;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/vault_providers.dart';
import '../../../core/database/app_database.dart';
import '../../../core/finance/formatters.dart';
import '../../../core/localization/vault_strings.dart';
import '../../../shared/widgets/vault_widgets.dart';
import '../../document_vault/linked_documents.dart';

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
  String _query = '', _kind = 'all';
  bool _history = false;

  @override
  Widget build(BuildContext context) => FinanceView(
    builder: (data) {
      final strings = VaultStrings.of(context);
      final localizations = MaterialLocalizations.of(context);
      final query = _query.trim().toLowerCase();
      final accounts = {
        for (final account in data.accounts) account.id: account,
      };
      final postings = <String, List<LedgerPosting>>{};
      for (final posting in data.postings) {
        (postings[posting.journalId] ??= []).add(posting);
      }

      final journals = data.journals.where((entry) {
        if (entry.status != 'posted' ||
            (!_history &&
                (entry.deletedAtUs != null || entry.kind == 'reversal')) ||
            (_kind != 'all' && entry.kind != _kind)) {
          return false;
        }
        if (query.isEmpty) return true;
        final names = (postings[entry.id] ?? [])
            .map((posting) => accounts[posting.accountId]?.name ?? '')
            .join(' ');
        final date = localizations.formatMediumDate(
          DateTime.parse(entry.occurredOn),
        );
        return '${entry.description} ${entry.occurredOn} $date $names'
            .toLowerCase()
            .contains(query);
      }).toList();

      return SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: CustomScrollView(
              key: const PageStorageKey('money-activity-scroll'),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        FilledButton.icon(
                          onPressed: () => context.push('/transaction/new'),
                          icon: const Icon(Icons.add),
                          label: Text(strings.text('addMoneyRecord')),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const ValueKey('money-search'),
                          decoration: InputDecoration(
                            labelText: strings.text('moneySearch'),
                            prefixIcon: const Icon(Icons.search),
                          ),
                          onChanged: (value) => setState(() => _query = value),
                        ),
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          leading: const Icon(Icons.filter_list),
                          title: Text(strings.text('filters')),
                          subtitle: _kind == 'all'
                              ? null
                              : Text(strings.text(_kind)),
                          children: [
                            Wrap(
                              spacing: 8,
                              children: [
                                for (final kind in [
                                  'all',
                                  'income',
                                  'expense',
                                  'transfer',
                                ])
                                  ChoiceChip(
                                    label: Text(strings.text(kind)),
                                    selected: kind == _kind,
                                    onSelected: (_) =>
                                        setState(() => _kind = kind),
                                  ),
                              ],
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(strings.text('showCorrections')),
                              value: _history,
                              onChanged: (value) =>
                                  setState(() => _history = value),
                            ),
                          ],
                        ),
                        if (journals.isEmpty)
                          EmptyNotice(
                            icon: Icons.receipt_long_outlined,
                            title: strings.text('noMatches'),
                            message: strings.text(
                              query.isEmpty ? 'noActivity' : 'tryAnotherSearch',
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  sliver: SliverList.builder(
                    itemCount: journals.length,
                    itemBuilder: (context, index) {
                      final entry = journals[index];
                      return JournalTile(
                        key: ValueKey(entry.id),
                        journal: entry,
                        postings: postings[entry.id] ?? const [],
                        accounts: accounts,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class JournalTile extends StatelessWidget {
  const JournalTile({
    required this.journal,
    required this.postings,
    required this.accounts,
    super.key,
  });

  final LedgerJournal journal;
  final Iterable<LedgerPosting> postings;
  final Map<String, LedgerAccount> accounts;

  @override
  Widget build(BuildContext context) {
    final strings = VaultStrings.of(context);
    final theme = Theme.of(context);
    final value = postings
        .where((posting) => posting.amountMinor > 0)
        .fold(
          BigInt.zero,
          (sum, posting) => sum + BigInt.from(posting.amountMinor),
        );
    final isMove = journal.kind == 'transfer';
    // The ledger records the destination debit first. A move reads from its
    // source account to its destination.
    final ordered = isMove
        ? (postings.toList()
            ..sort((a, b) => a.amountMinor.compareTo(b.amountMinor)))
        : postings;
    final names = {
      for (final posting in ordered)
        if (accounts[posting.accountId] case final account?)
          if (account.kind == 'asset' || account.kind == 'liability')
            account.name,
    };
    final date = MaterialLocalizations.of(context)
        .formatMediumDate(DateTime.parse(journal.occurredOn));
    final kind = recordKindLabel(strings, journal.kind);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card.outlined(
        child: ListTile(
          leading: VaultIcon(
            icon: switch (journal.kind) {
              'income' => Icons.south_west,
              'expense' => Icons.north_east,
              'transfer' => Icons.swap_horiz,
              'reversal' => Icons.undo,
              _ => Icons.receipt_outlined,
            },
          ),
          title: Text(journal.description),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('$date · $kind'),
              if (names.isNotEmpty)
                Text(names.join(isMove && names.length == 2 ? ' → ' : ' · ')),
              if (journal.deletedAtUs != null)
                Text(strings.text('recordUndone')),
              Text(formatInr(value), style: theme.textTheme.titleMedium),
            ],
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/transaction/${journal.id}'),
        ),
      ),
    );
  }
}

String recordKindLabel(VaultStrings strings, String kind) =>
    strings.text(switch (kind) {
      'income' => 'income',
      'expense' => 'expense',
      'transfer' => 'transfer',
      'opening' => 'openingRecord',
      'adjustment' => 'balanceChange',
      'reversal' => 'reversalRecord',
      'repayment' => 'loanPayment',
      'business' => 'business',
      _ => 'moneyRecord',
    });

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
    appBar: AppBar(title: const Text('Money record')),
    body: FinanceView(
      builder: (data) {
        final journal = data.journals
            .where((j) => j.id == widget.id)
            .firstOrNull;
        if (journal == null) {
          return const VaultContent(
            children: [Text('We couldn’t find this money record.')],
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
        final strings = VaultStrings.of(context);
        return VaultContent(
          maxWidth: 800,
          children: [
            MetricCard(
              title: recordKindLabel(strings, journal.kind),
              value: formatInr(value),
              icon: Icons.receipt_long_outlined,
              detail: [
                MaterialLocalizations.of(context)
                    .formatMediumDate(DateTime.parse(journal.occurredOn)),
                if (journal.deletedAtUs != null) strings.text('recordUndone'),
              ].join(' · '),
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
                label: const Text('Open the related item'),
              ),
            if (link?.aggregateType == 'debt')
              TextButton.icon(
                onPressed: () => context.push('/loan/${link!.aggregateId}'),
                icon: const Icon(Icons.request_quote_outlined),
                label: const Text('View related loan'),
              ),
            if (link?.aggregateType == 'stock')
              TextButton.icon(
                onPressed: () => context.push('/stock/${link!.aggregateId}'),
                icon: const Icon(Icons.inventory_2_outlined),
                label: const Text('View stock item'),
              ),
            if (link?.aggregateType == 'salary')
              TextButton.icon(
                onPressed: () => context.push('/worker/${link!.aggregateId}'),
                icon: const Icon(Icons.person_outline),
                label: const Text('View worker'),
              ),
            if (journal.businessId != null)
              TextButton.icon(
                onPressed: () =>
                    context.push('/business/${journal.businessId}'),
                icon: const Icon(Icons.storefront_outlined),
                label: const Text('View business'),
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
                          : () {
                              ScaffoldMessenger.of(context)
                                  .removeCurrentSnackBar();
                              context.push('/transaction/${journal.id}/edit');
                            },
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Correct this record'),
                    ),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => _reverse(journal.id),
                    icon: const Icon(Icons.undo),
                    label: const Text('Undo this record'),
                  ),
                ],
              ),
            if (journal.reversesId != null)
              TextButton.icon(
                onPressed: () =>
                    context.push('/transaction/${journal.reversesId}'),
                icon: const Icon(Icons.history),
                label: const Text('See the original record'),
              ),
            if (reversed != null)
              TextButton.icon(
                onPressed: () => context.push('/transaction/${reversed.id}'),
                icon: const Icon(Icons.undo),
                label: const Text('See the undo record'),
              ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              FailureNotice(_error!),
            ],
            const SizedBox(height: 24),
            Card.outlined(
              child: ExpansionTile(
                title: const Text('Accounts in this record'),
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
            LinkedDocuments(journalId: journal.id),
            const SectionHeading('Change history'),
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
        title: 'Undo this money record?',
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
