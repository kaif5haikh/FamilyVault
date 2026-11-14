import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/vault_providers.dart';
import '../../../core/finance/formatters.dart';
import '../../../shared/widgets/vault_widgets.dart';
import '../data/ledger_repository.dart';
import '../domain/finance_report.dart';
import 'finance_charts.dart';
import 'transactions_pages.dart';

class FinanceHomePage extends ConsumerWidget {
  const FinanceHomePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => FinanceView(
    builder: (snapshot) {
      final now = DateTime.now(),
          today = LedgerRepository.dateOnly(DateTime.now());
      final first = LedgerRepository.dateOnly(DateTime(now.year, now.month));
      final assets = snapshot.total(AccountKind.asset, through: today),
          liabilities = snapshot.total(AccountKind.liability, through: today);
      final income = snapshot.total(
            AccountKind.income,
            from: first,
            through: today,
          ),
          expenses = snapshot.total(
            AccountKind.expense,
            from: first,
            through: today,
          );
      final balances = snapshot.balances(through: today);
      final cash = snapshot.accounts
          .where(
            (a) => a.kind == 'asset' && ['cash', 'bank'].contains(a.subtype),
          )
          .fold(BigInt.zero, (sum, a) => sum + (balances[a.id] ?? BigInt.zero));
      final recent = snapshot.journals
          .where(
            (j) =>
                j.deletedAtUs == null &&
                j.kind != 'reversal' &&
                j.status == 'posted',
          )
          .take(5)
          .toList();
      final trend =
          [for (var i = 5; i >= 0; i--) DateTime(now.year, now.month - i)]
              .map(
                (d) => FinanceReport(
                  snapshot,
                  ReportPeriod.month(d.year, d.month),
                ),
              )
              .toList();
      return VaultContent(
        children: [
          SectionHeading(
            'A clearer picture of your family',
            action: FilledButton.icon(
              onPressed: () => context.push('/transaction/new'),
              icon: const Icon(Icons.add),
              label: const Text('Add transaction'),
            ),
          ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(
                ref.watch(vaultProvider).session?.identity.isCloud == true
                    ? Icons.cloud_outlined
                    : Icons.phone_iphone_outlined,
                size: 18,
              ),
              Text(
                ref.watch(vaultProvider).session?.identity.isCloud == true
                    ? 'Family workspace'
                    : 'On this device',
              ),
              const Text('·'),
              Text('As of ${DateFormat('d MMM y', 'en_IN').format(now)}'),
            ],
          ),
          const SizedBox(height: 24),
          ResponsiveCards(
            minimumWidth: 320,
            children: [
              MetricCard(
                title: 'Net worth',
                value: formatInr(assets - liabilities, compact: true),
                icon: Icons.account_balance_outlined,
                detail:
                    'Assets ${formatInr(assets)}\nLiabilities ${formatInr(liabilities)}',
                emphasis: true,
              ),
              MetricCard(
                title: 'Cash & bank',
                value: formatInr(cash, compact: true),
                icon: Icons.account_balance_wallet_outlined,
                detail: 'Available across your recorded cash and bank accounts',
              ),
            ],
          ),
          const SizedBox(height: 28),
          SectionHeading('${DateFormat.MMMM('en_IN').format(now)} so far'),
          ResponsiveCards(
            children: [
              MetricCard(
                title: 'Income',
                value: formatInr(income, compact: true),
                icon: Icons.south_west,
              ),
              MetricCard(
                title: 'Expenses',
                value: formatInr(expenses, compact: true),
                icon: Icons.north_east,
              ),
              MetricCard(
                title: 'Savings',
                value: formatInr(income - expenses, compact: true),
                icon: Icons.savings_outlined,
                detail:
                    'Savings rate ${formatPercentage(income - expenses, income)}',
              ),
            ],
          ),
          const SizedBox(height: 28),
          if (snapshot.accounts.every((a) => a.systemAccount)) ...[
            EmptyNotice(
              icon: Icons.account_balance_wallet_outlined,
              title: 'Start with your accounts',
              message: 'Add a cash or bank account, then record income and everyday spending. Your overview will grow with you.',
              action: FilledButton.icon(
                onPressed: () => context.push('/account/new'),
                icon: const Icon(Icons.add),
                label: const Text('Add your first account'),
              ),
            ),
            const SizedBox(height: 28),
          ],
          SectionHeading(
            'Your financial rhythm',
            action: TextButton(
              onPressed: () => context.go('/reports'),
              child: const Text('View reports'),
            ),
          ),
          Card.outlined(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: IncomeExpenseChart(reports: trend),
            ),
          ),
          const SizedBox(height: 28),
          SectionHeading(
            'Recent activity',
            action: TextButton(
              onPressed: () => context.go('/transactions'),
              child: const Text('View all'),
            ),
          ),
          if (recent.isEmpty)
            const Text(
              'No transactions yet. Everything starts with the first entry.',
            ),
          for (final journal in recent)
            JournalTile(journal: journal, snapshot: snapshot),
        ],
      );
    },
  );
}
