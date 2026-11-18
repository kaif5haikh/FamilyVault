import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../app/vault_providers.dart';
import '../../core/security/vault_lifecycle.dart';
import '../auth/cloud_access_panel.dart';
import '../auth/cloud_providers.dart';

class WelcomePage extends ConsumerWidget {
  const WelcomePage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).colorScheme,
        text = Theme.of(context).textTheme;
    final status = ref.watch(vaultProvider);
    return VaultPage(
      title: 'FamilyVault',
      children: [
        const SizedBox(height: 24),
        Align(
          alignment: Alignment.centerLeft,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Icon(
                Icons.shield_outlined,
                size: 44,
                color: colors.primary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Your family.\nYour shared future.',
          style: text.headlineLarge?.copyWith(
            fontWeight: FontWeight.w700,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'A private home for your finances and important documents.',
          style: text.bodyLarge?.copyWith(color: colors.onSurfaceVariant),
        ),
        const SizedBox(height: 32),
        Card.filled(
          child: Padding(
            padding: const EdgeInsets.all(VaultTheme.space),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lock_outline),
                const SizedBox(height: 16),
                Text(
                  status.hasVault
                      ? 'Your vault is ready'
                      : 'A private space, on your terms',
                  style: text.titleLarge,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Start on this device. Your vault is encrypted, and works without an internet connection.',
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () => context.push('/access'),
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Family access'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        const Wrap(
          spacing: 20,
          runSpacing: 12,
          children: [
            _TrustItem(Icons.currency_rupee, 'Made for India'),
            _TrustItem(Icons.wifi_off_outlined, 'Works offline'),
            _TrustItem(Icons.key_outlined, 'Device protected'),
          ],
        ),
        const SizedBox(height: 28),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.info_outline),
          title: const Text('About FamilyVault'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/about'),
        ),
      ],
    );
  }
}

class _TrustItem extends StatelessWidget {
  const _TrustItem(this.icon, this.label);
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 6),
      Flexible(child: Text(label)),
    ],
  );
}

class AccessPage extends ConsumerStatefulWidget {
  const AccessPage({super.key});
  @override
  ConsumerState<AccessPage> createState() => _AccessPageState();
}

class _AccessPageState extends ConsumerState<AccessPage> {
  bool _creating = false;
  bool _cloud = false;
  final _form = GlobalKey<FormState>();
  final _family = TextEditingController();
  final _owner = TextEditingController();
  @override
  void dispose() {
    _family.dispose();
    _owner.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(vaultProvider),
        controller = ref.read(vaultProvider.notifier);
    final busy =
        status.phase == VaultPhase.opening ||
        status.phase == VaultPhase.loading;
    final configured = ref.watch(cloudConfigProvider).cloudConfigured;
    if (_cloud && configured) {
      return VaultPage(
        title: 'Family access',
        children: [
          TextButton.icon(
            onPressed: () => setState(() => _cloud = false),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Local vault'),
          ),
          const SizedBox(height: 16),
          const CloudAccessPanel(),
        ],
      );
    }
    return VaultPage(
      title: 'Family access',
      children: [
        Icon(
          status.hasVault
              ? Icons.lock_person_outlined
              : Icons.add_moderator_outlined,
          size: 52,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 24),
        Text(
          status.hasVault
              ? 'Your vault is locked'
              : 'Create your private vault',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Text(
          status.hasVault
              ? 'Verify with your device passcode or biometrics to continue.'
              : 'Your name identifies your edits. This local vault belongs to this device; family cloud enrollment is a separate step.',
        ),
        const SizedBox(height: 24),
        if (status.failure != null) ...[
          Semantics(
            liveRegion: true,
            child: Text(
              status.failure!.message,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
          const SizedBox(height: 20),
        ],
        if (busy)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          ),
        if (!busy && status.phase == VaultPhase.unavailable)
          OutlinedButton.icon(
            onPressed: controller.retry,
            icon: const Icon(Icons.refresh),
            label: const Text('Try secure storage again'),
          ),
        if (!busy && status.hasVault)
          FilledButton.icon(
            onPressed: controller.unlock,
            icon: const Icon(Icons.fingerprint),
            label: const Text('Unlock vault'),
          ),
        if (!busy &&
            !status.hasVault &&
            status.phase != VaultPhase.unavailable &&
            !_creating)
          FilledButton.icon(
            onPressed: () => setState(() => _creating = true),
            icon: const Icon(Icons.add),
            label: const Text('Create a local vault'),
          ),
        if (!status.hasVault && _creating)
          Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _family,
                  enabled: !busy,
                  maxLength: 80,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Vault name',
                    hintText: 'Choose a name',
                  ),
                  validator: _required,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _owner,
                  enabled: !busy,
                  maxLength: 80,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Your name'),
                  validator: _required,
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: busy
                      ? null
                      : () {
                          if (_form.currentState!.validate()) {
                            controller.createOffline(_family.text, _owner.text);
                          }
                        },
                  icon: const Icon(Icons.lock_outline),
                  label: const Text('Verify device & create'),
                ),
              ],
            ),
          ),
        const SizedBox(height: 28),
        if (configured && !busy) ...[
          OutlinedButton.icon(
            onPressed: () => setState(() => _cloud = true),
            icon: const Icon(Icons.group_outlined),
            label: const Text('Open family access'),
          ),
          const SizedBox(height: 16),
        ],
        Text(
          'Each family member uses an independent account when connected. Keep an encrypted backup and its recovery key separately.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }

  String? _required(String? value) =>
      value == null || value.trim().isEmpty ? 'Enter a name.' : null;
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});
  @override
  Widget build(BuildContext context) => VaultPage(
    title: 'About FamilyVault',
    children: [
      Text('FamilyVault', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 8),
      const Text('Version 0.1.0 · Private family finance'),
      const SizedBox(height: 24),
      const Text(
        'Built to keep your family’s finances and important records together.',
      ),
      const SizedBox(height: 16),
      const Text(
        'Offline vaults stay on this device. Cloud services require a configured family connection. No shared sign-in credentials.',
      ),
      const SizedBox(height: 24),
      const LicensePageButton(),
    ],
  );
}

class LicensePageButton extends StatelessWidget {
  const LicensePageButton({super.key});
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: () => showLicensePage(
      context: context,
      applicationName: 'FamilyVault',
      applicationVersion: '0.1.0',
    ),
    icon: const Icon(Icons.description_outlined),
    label: const Text('Open-source licences'),
  );
}

class VaultPage extends StatelessWidget {
  const VaultPage({
    required this.title,
    required this.children,
    super.key,
    this.actions,
  });
  final String title;
  final List<Widget> children;
  final List<Widget>? actions;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title), actions: actions),
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: VaultTheme.contentWidth),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(VaultTheme.space),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ),
      ),
    ),
  );
}
