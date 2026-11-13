import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/vault_providers.dart';
import '../../../core/finance/formatters.dart';
import '../../foundation/foundation_pages.dart';
import '../data/ledger_repository.dart';

class FinanceHomePage extends ConsumerWidget {
  const FinanceHomePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final finance = ref.watch(financeProvider);
    return VaultPage(
      title: 'Overview',
      actions: [
        IconButton(
          tooltip: 'Lock vault',
          onPressed: ref.read(vaultProvider.notifier).lock,
          icon: const Icon(Icons.lock_outline),
        ),
      ],
      children: [
        const Row(
          children: [
            Icon(Icons.phone_iphone_outlined, size: 18),
            SizedBox(width: 8),
            Text('On this device'),
          ],
        ),
        const SizedBox(height: 24),
        finance.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, _) => const Text(
            'The overview is unavailable. Lock and reopen your vault to try again.',
          ),
          data: (snapshot) {
            final now = DateTime.now(),
                first = LedgerRepository.dateOnly(
                  DateTime(DateTime.now().year, DateTime.now().month),
                );
            final end = LedgerRepository.dateOnly(
              DateTime(now.year, now.month + 1, 0),
            );
            final assets = snapshot.total(AccountKind.asset),
                liabilities = snapshot.total(AccountKind.liability);
            final income = snapshot.total(
              AccountKind.income,
              from: first,
              through: end,
            );
            final expense = snapshot.total(
              AccountKind.expense,
              from: first,
              through: end,
            );
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card.filled(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Net worth'),
                        const SizedBox(height: 8),
                        Text(
                          formatInr(assets - liabilities, compact: true),
                          style: Theme.of(context).textTheme.headlineLarge,
                        ),
                        const SizedBox(height: 16),
                        Text('Assets ${formatInr(assets)}'),
                        Text('Liabilities ${formatInr(liabilities)}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'This month',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.south_west),
                  title: const Text('Income'),
                  subtitle: Text(formatInr(income)),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.north_east),
                  title: const Text('Expenses'),
                  subtitle: Text(formatInr(expense)),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.savings_outlined),
                  title: const Text('Savings rate'),
                  subtitle: Text(formatPercentage(income - expense, income)),
                ),
                if (snapshot.accounts.every((a) => a.systemAccount)) ...[
                  const SizedBox(height: 24),
                  const Text(
                    'Your vault is ready. No financial records have been added.',
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }
}
