import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme.dart';
import '../../../app/vault_providers.dart';
import '../../../core/finance/formatters.dart';
import '../../../core/localization/vault_strings.dart';
import '../../../shared/widgets/vault_widgets.dart';
import '../../document_vault/document_inputs.dart';
import '../../document_vault/document_pages.dart';
import '../data/ledger_repository.dart';
import 'money_page.dart';
import 'transactions_pages.dart';

class FinanceHomePage extends ConsumerStatefulWidget {
  const FinanceHomePage({super.key});

  @override
  ConsumerState<FinanceHomePage> createState() => _FinanceHomePageState();
}

class _FinanceHomePageState extends ConsumerState<FinanceHomePage> {
  bool _hideAmounts = false;

  @override
  Widget build(BuildContext context) {
    final strings = VaultStrings.of(context);
    final theme = Theme.of(context);
    final shared = ref.watch(vaultProvider).session?.identity.isCloud == true;
    final documents = ref.watch(documentRepositoryProvider);
    return FinanceView(
      builder: (snapshot) {
        final now = DateTime.now();
        final today = LedgerRepository.dateOnly(now);
        final from = LedgerRepository.dateOnly(DateTime(now.year, now.month));
        final balances = snapshot.balances(through: today);
        final monthly = snapshot.balances(from: from, through: today);
        var cash = BigInt.zero, owned = BigInt.zero, owed = BigInt.zero;
        var received = BigInt.zero, spent = BigInt.zero;
        var hasAccount = false, hasFamilyValue = false;
        for (final account in snapshot.accounts) {
          final balance = balances[account.id] ?? BigInt.zero;
          switch (account.kind) {
            case 'asset':
              owned += balance;
              if (account.subtype == 'cash' || account.subtype == 'bank') {
                cash += balance;
              } else if (!account.systemAccount &&
                  account.deletedAtUs == null) {
                hasFamilyValue = true;
              }
              if (!account.systemAccount &&
                  account.deletedAtUs == null &&
                  !snapshot.managedAccountIds.contains(account.id)) {
                hasAccount = true;
              }
            case 'liability':
              owed -= balance;
              hasFamilyValue |= account.deletedAtUs == null;
            case 'income':
              received -= monthly[account.id] ?? BigInt.zero;
            case 'expense':
              spent += monthly[account.id] ?? BigInt.zero;
          }
        }
        final accounts = {
          for (final account in snapshot.accounts) account.id: account,
        };
        final recent = snapshot.journals
            .where(
              (entry) =>
                  entry.deletedAtUs == null &&
                  entry.kind != 'reversal' &&
                  entry.status == 'posted',
            )
            .take(3);
        return VaultContent(
          maxWidth: 760,
          scrollKey: const PageStorageKey('home-scroll'),
          children: [
            Text(
              strings.text('hello'),
              style: MediaQuery.textScalerOf(context).scale(14) > 18
                  ? theme.textTheme.titleMedium
                  : theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 4),
            Text(
              strings.text(shared ? 'sharedFamily' : 'localOnly'),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: VaultTheme.gap),
            _MoneySummary(
              available: cash,
              received: received,
              spent: spent,
              hidden: _hideAmounts,
              onVisibilityChanged: () =>
                  setState(() => _hideAmounts = !_hideAmounts),
            ),
            const SizedBox(height: VaultTheme.gap),
            MoneyActions(
              onDocument: () {
                if (documents != null &&
                    (!shared || documents.sharingAvailable)) {
                  chooseDocument(context, ref, documents);
                } else {
                  context.go('/documents');
                }
              },
            ),
            const SizedBox(height: VaultTheme.space),
            if (!hasAccount)
              EmptyNotice(
                icon: Icons.account_balance_wallet_outlined,
                title: strings.text('noAccountsYet'),
                message: strings.text('firstAccountHelp'),
                action: FilledButton(
                  onPressed: () => context.push('/account/new'),
                  child: Text(strings.text('firstAccount')),
                ),
              ),
            if (!_hideAmounts && hasFamilyValue) ...[
              Card.outlined(
                child: ExpansionTile(
                  leading: const Icon(Icons.home_work_outlined),
                  title: Text(strings.text('familyValue')),
                  subtitle: Text(formatInr(owned - owed, compact: true)),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  children: [
                    Text(strings.text('familyValueHelp')),
                    const SizedBox(height: 8),
                    VaultLink(
                      icon: Icons.inventory_2_outlined,
                      title: strings.text('owns'),
                      subtitle: formatInr(owned),
                      onTap: () => context.push('/assets'),
                    ),
                    VaultLink(
                      icon: Icons.payments_outlined,
                      title: strings.text('owes'),
                      subtitle: formatInr(owed),
                      onTap: () => context.push('/loans'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: VaultTheme.space),
            ],
            if (!_hideAmounts) ...[
              SectionHeading(
                strings.text('recent'),
                action: TextButton(
                  onPressed: () => context.push('/transactions'),
                  child: Text(strings.text('allActivity')),
                ),
              ),
              if (recent.isEmpty) Text(strings.text('noActivity')),
              for (final journal in recent)
                JournalTile(
                  journal: journal,
                  postings: snapshot.postings.where(
                    (posting) => posting.journalId == journal.id,
                  ),
                  accounts: accounts,
                ),
            ],
            const SizedBox(height: VaultTheme.gap),
            VaultLink(
              icon: Icons.folder_open_outlined,
              title: strings.text('findDocument'),
              onTap: () => context.go('/documents'),
            ),
          ],
        );
      },
    );
  }
}

class _MoneySummary extends StatelessWidget {
  const _MoneySummary({
    required this.available,
    required this.received,
    required this.spent,
    required this.hidden,
    required this.onVisibilityChanged,
  });

  final BigInt available, received, spent;
  final bool hidden;
  final VoidCallback onVisibilityChanged;

  @override
  Widget build(BuildContext context) {
    final strings = VaultStrings.of(context);
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final textColor = colors.onPrimaryContainer;
    return Card.filled(
      color: colors.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    strings.text('available'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: textColor,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: strings.text(hidden ? 'showAmounts' : 'hideAmounts'),
                  onPressed: onVisibilityChanged,
                  color: textColor,
                  icon: Icon(
                    hidden
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ],
            ),
            if (hidden)
              Text(
                strings.text('amountsHidden'),
                style: TextStyle(color: textColor),
              )
            else ...[
              Text(
                formatInr(available, compact: true),
                style: theme.textTheme.displaySmall?.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                strings.text('cashBankOnly'),
                style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
              ),
              const SizedBox(height: 8),
              Divider(color: textColor.withValues(alpha: .2)),
              Text(
                strings.text('monthSoFar'),
                style: theme.textTheme.labelMedium?.copyWith(color: textColor),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 24,
                runSpacing: 8,
                children: [
                  _SummaryLine(strings.text('income'), received, textColor),
                  _SummaryLine(strings.text('expense'), spent, textColor),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryLine extends StatelessWidget {
  const _SummaryLine(this.title, this.amount, this.color);

  final String title;
  final BigInt amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.bodyMedium?.copyWith(color: color)),
        Text(
          formatInr(amount, compact: true),
          style: theme.textTheme.titleMedium?.copyWith(color: color),
        ),
      ],
    );
  }
}
