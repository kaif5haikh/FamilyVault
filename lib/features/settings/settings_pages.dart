import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/appearance.dart';
import '../../app/vault_providers.dart';
import '../../core/errors/app_failure.dart';
import '../../core/localization/vault_strings.dart';
import '../../core/security/vault_lifecycle.dart';
import '../../core/sync/live_sync.dart';
import '../../shared/widgets/vault_widgets.dart';
import '../auth/cloud_device_registration.dart';
import '../auth/cloud_cache_access.dart';
import '../auth/cloud_providers.dart';
import '../document_vault/expiry_reminders.dart';
import '../document_vault/reminder_settings.dart';

class MorePage extends StatelessWidget {
  const MorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = VaultStrings.of(context);
    return VaultContent(
      maxWidth: 680,
      children: [
        for (final (label, path, icon) in const [
          ('business', '/businesses', Icons.storefront_outlined),
          ('backup', '/backups', Icons.cloud_upload_outlined),
          ('settings', '/settings', Icons.tune),
          ('help', '/help', Icons.help_outline),
          ('showTourAgain', '/welcome-tour', Icons.signpost_outlined),
          ('about', '/about', Icons.info_outline),
        ])
          VaultLink(
            icon: icon,
            title: strings.text(label),
            onTap: () => context.push(path),
          ),
      ],
    );
  }
}

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = VaultStrings.of(context);
    final appearance = ref.watch(appearanceProvider),
        controller = ref.read(appearanceProvider.notifier);
    final session = ref.watch(vaultProvider).session;
    return VaultContent(
      maxWidth: 800,
      children: [
        const SectionHeading('Look and language'),
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
                  decoration: const InputDecoration(labelText: 'Language'),
                  items: [
                    for (final (locale, name) in languageChoices)
                      DropdownMenuItem(
                        value: locale.languageCode,
                        child: Text(name),
                      ),
                  ],
                  onChanged: (v) => controller.change(locale: Locale(v!, 'IN')),
                ),
                if (!appearance.saved)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Text(
                      'This change is showing now. To keep it, open your records again and try saving.',
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        const SectionHeading('Privacy'),
        Card.outlined(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session?.identity.isCloud == true
                      ? strings.text('sharedFamily')
                      : strings.text('localOnly'),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  session?.identity.isCloud == true
                      ? strings.text('sharedFamilyHelp')
                      : strings.text('localFamilyHelp'),
                ),
                const SizedBox(height: 16),
                const Text(
                  'FamilyVault locks when you leave the app or after five idle minutes. Use your phone’s screen lock to open it again.',
                ),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  onPressed: ref.read(vaultProvider.notifier).lock,
                  icon: const Icon(Icons.lock_outline),
                  label: Text(strings.text('lock')),
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
        if (session != null) DocumentReminderSettings(session.identity),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.backup_outlined),
          title: Text(strings.text('backup')),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/backups'),
        ),
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
    final reminders = ref.read(documentReminderServiceProvider);
    final closed = controller.lock();
    await reminders.clear().catchError((Object _) {});
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
          'We couldn’t finish signing out. Please try again.',
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
                'Family updates',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 10),
              if (value.checking) const LinearProgressIndicator(),
              if (value.pending case final pending?)
                Text(
                  pending == 0
                      ? 'Your changes are up to date.'
                      : '$pending ${pending == 1 ? 'change is' : 'changes are'} waiting to update the family.',
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
                    label: const Text('Check for updates'),
                  ),
                  TextButton.icon(
                    onPressed: () => context.push('/family-recovery'),
                    icon: const Icon(Icons.history),
                    label: const Text('Changes saved on this phone'),
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
