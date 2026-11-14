import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/localization/vault_strings.dart';
import 'vault_providers.dart';

class VaultShell extends ConsumerWidget {
  const VaultShell({required this.child, required this.path, super.key});
  final Widget child;
  final String path;
  static const sections = <(String, String, IconData)>[
    ('/home', 'dashboard', Icons.dashboard_outlined),
    ('/transactions', 'transactions', Icons.swap_vert),
    ('/accounts', 'accounts', Icons.account_balance_outlined),
    ('/planning', 'budgets', Icons.savings_outlined),
    ('/reports', 'reports', Icons.insights_outlined),
    ('/settings', 'settings', Icons.tune),
  ];
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final strings = VaultStrings(Localizations.localeOf(context));
    final index = sections.indexWhere((item) => item.$1 == path);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          index < 0 ? strings.text('more') : strings.text(sections[index].$2),
        ),
        actions: [
          IconButton(
            tooltip: strings.text('lock'),
            onPressed: ref.read(vaultProvider.notifier).lock,
            icon: const Icon(Icons.lock_outline),
          ),
        ],
      ),
      body: Row(
        children: [
          if (wide)
            SizedBox(
              width: 240,
              child: Material(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(12, 12, 12, 28),
                      child: Text(
                        'FamilyVault',
                        style: TextStyle(
                          fontSize: 23,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    for (final section in sections)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          selected: section.$1 == path,
                          selectedTileColor: Theme.of(context)
                              .colorScheme
                              .primaryContainer,
                          leading: Icon(section.$3),
                          title: Text(strings.text(section.$2)),
                          onTap: () => context.go(section.$1),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          Expanded(key: const ValueKey('workspace-content'), child: child),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : NavigationBar(
              selectedIndex: index < 0 || index > 2 ? 3 : index,
              onDestinationSelected: (value) =>
                  context.go(value == 3 ? '/more' : sections[value].$1),
              destinations: [
                for (final section in sections.take(3))
                  NavigationDestination(
                    icon: Icon(section.$3),
                    label: strings.text(section.$2),
                  ),
                NavigationDestination(
                  icon: const Icon(Icons.grid_view_outlined),
                  label: strings.text('more'),
                ),
              ],
            ),
    );
  }
}
