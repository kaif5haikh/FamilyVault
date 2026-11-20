import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/localization/vault_strings.dart';
import 'vault_providers.dart';

enum WorkspaceArea {
  home('/home', 'dashboard', Icons.home_outlined, Icons.home_rounded),
  money(
    '/money',
    'money',
    Icons.account_balance_wallet_outlined,
    Icons.account_balance_wallet,
  ),
  documents('/documents', 'documents', Icons.folder_outlined, Icons.folder),
  family('/family', 'family', Icons.group_outlined, Icons.group),
  more('/more', 'more', Icons.grid_view_outlined, Icons.grid_view_rounded);

  const WorkspaceArea(this.path, this.label, this.icon, this.selectedIcon);

  final String path, label;
  final IconData icon, selectedIcon;
}

class VaultShell extends ConsumerWidget {
  const VaultShell({required this.navigation, super.key});

  final StatefulNavigationShell navigation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = VaultStrings.of(context);
    final area = WorkspaceArea.values[navigation.currentIndex];
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 920;
    final largeText = MediaQuery.textScalerOf(context).scale(12) >= 19;

    void select(int index) => navigation.goBranch(
      index,
      initialLocation: index == navigation.currentIndex,
    );

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: largeText ? 76 : null,
        title: Text(strings.text(area.label)),
        actions: [
          if (width >= 390 && !largeText)
            TextButton.icon(
              onPressed: () => context.push('/help'),
              icon: const Icon(Icons.help_outline_rounded, size: 19),
              label: Text(strings.text('shortHelp')),
            )
          else
            IconButton(
              tooltip: strings.text('help'),
              onPressed: () => context.push('/help'),
              icon: const Icon(Icons.help_outline_rounded),
            ),
          IconButton(
            tooltip: strings.text('lock'),
            onPressed: ref.read(vaultProvider.notifier).lock,
            icon: const Icon(Icons.lock_outline_rounded),
          ),
        ],
      ),
      body: Row(
        children: [
          if (wide)
            SizedBox(
              width: 214,
              child: Material(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 12,
                  ),
                  children: [
                    for (final (index, section) in WorkspaceArea.values.indexed)
                      ListTile(
                        leading: Icon(
                          section == area ? section.selectedIcon : section.icon,
                        ),
                        title: Text(strings.text(section.label)),
                        selected: section == area,
                        onTap: () => select(index),
                      ),
                  ],
                ),
              ),
            ),
          Expanded(child: navigation),
        ],
      ),
      bottomNavigationBar: wide
          ? null
          : largeText
          ? _ReadableNavigation(area: area, select: select)
          : NavigationBar(
              selectedIndex: navigation.currentIndex,
              onDestinationSelected: select,
              destinations: [
                for (final section in WorkspaceArea.values)
                  NavigationDestination(
                    key: ValueKey('area-${section.name}'),
                    icon: Icon(section.icon),
                    selectedIcon: Icon(section.selectedIcon),
                    label: strings.text(section.label),
                  ),
              ],
            ),
    );
  }
}

class _ReadableNavigation extends StatelessWidget {
  const _ReadableNavigation({required this.area, required this.select});

  final WorkspaceArea area;
  final ValueChanged<int> select;

  @override
  Widget build(BuildContext context) {
    final strings = VaultStrings.of(context);
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLowest,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _destinations(context, strings, const [
              (WorkspaceArea.home, 1),
              (WorkspaceArea.money, 1),
            ]),
            _destinations(context, strings, const [
              (WorkspaceArea.documents, 5),
              (WorkspaceArea.family, 3),
              (WorkspaceArea.more, 3),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _destinations(
    BuildContext context,
    VaultStrings strings,
    List<(WorkspaceArea, int)> row,
  ) => Row(
    children: [
      for (final (section, width) in row)
        Expanded(
          flex: width,
          child: Semantics(
            selected: section == area,
            child: TextButton(
              key: ValueKey('area-${section.name}'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 8),
                textStyle: Theme.of(context).textTheme.labelLarge
                    ?.copyWith(fontSize: 14),
              ),
              onPressed: () => select(section.index),
              child: Text(
                strings.text(section.label),
                textAlign: TextAlign.center,
                style: section == area
                    ? const TextStyle(
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.underline,
                      )
                    : null,
              ),
            ),
          ),
        ),
    ],
  );
}
