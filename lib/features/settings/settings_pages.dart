import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/appearance.dart';
import '../../app/vault_providers.dart';
import '../../core/errors/app_failure.dart';
import '../../core/security/vault_lifecycle.dart';
import '../../core/sync/live_sync.dart';
import '../../shared/widgets/vault_widgets.dart';
import '../auth/cloud_device_registration.dart';
import '../auth/cloud_cache_access.dart';
import '../auth/cloud_providers.dart';

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
        if (session?.sync case final sync?) ...[
          _SyncSection(sync: sync, session: session!),
          const SizedBox(height: 24),
        ],
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

class _SyncSection extends ConsumerWidget {
  const _SyncSection({required this.sync, required this.session});
  final LiveSync sync;
  final VaultSession session;

  Future<void> _signOut(WidgetRef ref) async {
    final registration = await ref.read(cloudRegistrationProvider.future);
    final gateway = registration.gateway;
    if (session.closed) return;
    final proof = CloudDevice(session.identity, session.keys).proof;
    final controller = ref.read(vaultProvider.notifier);
    final closed = controller.lock();
    try {
      try {
        final user = gateway.userId;
        if (user != null) {
          await CloudCacheAccess(registration).revoke(user, session.identity);
        }
      } finally {
        await gateway.signOut(proof);
      }
    } on AppFailure catch (error) {
      await controller.lock(reason: error);
    } catch (_) {
      await controller.lock(
        reason: const AppFailure(
          FailureCode.storage,
          'Secure sign-out needs another check.',
        ),
      );
    } finally {
      await closed;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Card.outlined(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: StreamBuilder<SyncFeedback>(
        stream: sync.changes,
        initialData: sync.status,
        builder: (context, snapshot) {
          final value = snapshot.data ?? sync.status;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Family sync',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              if (value.checking) const LinearProgressIndicator(),
              if (value.pending case final pending?)
                Text(
                  pending == 0
                      ? 'No local changes are waiting for a receipt.'
                      : '$pending local ${pending == 1 ? 'change is' : 'changes are'} waiting for a receipt.',
                ),
              if (value.failure case final failure?) FailureNotice(failure),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: value.checking ? null : sync.check,
                    icon: const Icon(Icons.sync),
                    label: const Text('Check sync'),
                  ),
                  TextButton.icon(
                    onPressed: () => context.push('/family-recovery'),
                    icon: const Icon(Icons.history),
                    label: const Text('Saved device changes'),
                  ),
                  TextButton.icon(
                    onPressed: () => _signOut(ref),
                    icon: const Icon(Icons.logout),
                    label: const Text('Sign out on this device'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    ),
  );
}
