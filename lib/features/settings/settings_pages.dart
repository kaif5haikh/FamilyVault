import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/appearance.dart';
import '../../app/vault_providers.dart';
import '../../shared/widgets/vault_widgets.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key});
  @override
  Widget build(BuildContext context) => VaultContent(
    children: [
      const SectionHeading('More for your family'),
      for (final entry in <(String, String, IconData, String)>[
        (
          'Assets',
          'Property, metals, investments and valuations',
          Icons.diamond_outlined,
          '/assets',
        ),
        (
          'Loans & lending',
          'Principal, interest and repayment history',
          Icons.request_quote_outlined,
          '/loans',
        ),
        (
          'Business',
          'Revenue, expenses, stock and worker payments',
          Icons.storefront_outlined,
          '/businesses',
        ),
        (
          'Budgets & planning',
          'Plan monthly spending by category',
          Icons.savings_outlined,
          '/planning',
        ),
        (
          'Reports',
          'Monthly and yearly financial perspectives',
          Icons.insights_outlined,
          '/reports',
        ),
        (
          'Settings',
          'Appearance, privacy and your workspace',
          Icons.tune,
          '/settings',
        ),
        (
          'About FamilyVault',
          'Application details and licences',
          Icons.info_outline,
          '/about',
        ),
      ])
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Card.outlined(
            child: ListTile(
              leading: Icon(entry.$3),
              title: Text(entry.$1),
              subtitle: Text(entry.$2),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go(entry.$4),
            ),
          ),
        ),
    ],
  );
}

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appearance = ref.watch(appearanceProvider),
        controller = ref.read(appearanceProvider.notifier);
    final session = ref.watch(vaultProvider).session;
    return VaultContent(
      maxWidth: 800,
      children: [
        const SectionHeading('Make yourself at home'),
        Card.outlined(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Appearance',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final mode in ThemeMode.values)
                      ChoiceChip(
                        label: Text(switch (mode) {
                          ThemeMode.system => 'Device default',
                          ThemeMode.light => 'Light',
                          ThemeMode.dark => 'Dark',
                        }),
                        selected: appearance.theme == mode,
                        onSelected: (_) => controller.change(theme: mode),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                DropdownButtonFormField<String>(
                  initialValue: appearance.locale.languageCode,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Navigation language',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'en',
                      child: Text('English (India)'),
                    ),
                    DropdownMenuItem(value: 'hi', child: Text('हिन्दी (भारत)')),
                  ],
                  onChanged: (v) => controller.change(locale: Locale(v!, 'IN')),
                ),
                if (!appearance.saved)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Text(
                      'Appearance changed for this session. Reopen the vault to retry saving preferences.',
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        const SectionHeading('Privacy & workspace'),
        Card.outlined(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session?.identity.isCloud == true
                      ? 'Connected family workspace'
                      : 'Local workspace',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  session?.identity.isCloud == true
                      ? 'Your individual account is used for family access.'
                      : 'Your records stay in this encrypted vault on this device. Family cloud access requires separate enrollment.',
                ),
                const SizedBox(height: 16),
                const Text(
                  'Device verification on unlock. Automatic lock in the background or after five idle minutes.',
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: ref.read(vaultProvider.notifier).lock,
                  icon: const Icon(Icons.lock_outline),
                  label: const Text('Lock vault'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.info_outline),
          title: const Text('About & open-source licences'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/about'),
        ),
      ],
    );
  }
}
