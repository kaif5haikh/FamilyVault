import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../auth/auth_boundary.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return VaultPage(
      title: 'FamilyVault',
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Icon(
                Icons.shield_outlined,
                size: 40,
                color: colors.primary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 32),
        Text('Your family.\nYour shared future.', style: text.headlineLarge),
        const SizedBox(height: 16),
        Text(
          'A private home for your family’s finances and important documents.',
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
                Text('Vault setup pending', style: text.titleLarge),
                const SizedBox(height: 8),
                const Text(
                  'Family access will be available after your vault is set up.',
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => context.push('/access'),
                  child: const Text('Family access'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
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

class AccessPage extends ConsumerWidget {
  const AccessPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(authBoundaryProvider);
    return VaultPage(
      title: 'Family access',
      children: [
        const Icon(Icons.lock_person_outlined, size: 48),
        const SizedBox(height: 24),
        Text(
          'Your vault is locked',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Text(switch (state) {
          AuthBoundary.unconfigured =>
            'Your family’s secure connection has not been set up yet.',
          AuthBoundary.signedOut =>
            'Sign in will be available after vault setup.',
          AuthBoundary.signedInLocked => 'Your account is signed in. Vault access still requires verification.',
        }),
        const SizedBox(height: 12),
        const Text('No family records are available in this initial version.'),
      ],
    );
  }
}

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return VaultPage(
      title: 'About FamilyVault',
      children: [
        Text('FamilyVault', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        const Text('Version 0.1.0 · Initial foundation'),
        const SizedBox(height: 24),
        const Text(
          'Built for a family to keep its finances and important records together.',
        ),
        const SizedBox(height: 16),
        const Text(
          'Family finance and document features will be added after the design review.',
        ),
        const SizedBox(height: 24),
        const LicensePageButton(),
      ],
    );
  }
}

class LicensePageButton extends StatelessWidget {
  const LicensePageButton({super.key});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: () => showLicensePage(
        context: context,
        applicationName: 'FamilyVault',
        applicationVersion: '0.1.0',
      ),
      icon: const Icon(Icons.description_outlined),
      label: const Text('Open-source licences'),
    );
  }
}

class VaultPage extends StatelessWidget {
  const VaultPage({required this.title, required this.children, super.key});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: VaultTheme.contentWidth,
            ),
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
}
