import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../app/vault_providers.dart';
import '../../core/security/vault_lifecycle.dart';
import '../../core/localization/vault_strings.dart';
import '../../shared/widgets/language_picker.dart';
import '../../shared/widgets/vault_widgets.dart';
import '../guidance/welcome_tour.dart';
import '../auth/cloud_access_panel.dart';
import '../auth/cloud_providers.dart';

class WelcomePage extends ConsumerStatefulWidget {
  const WelcomePage({super.key});

  @override
  ConsumerState<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends ConsumerState<WelcomePage> {
  bool _starting = false;

  Future<void> _start({bool join = false}) async {
    if (_starting) return;
    setState(() => _starting = true);
    await finishIntro(ref);
    if (!mounted) return;
    ref.invalidate(introSeenProvider);
    setState(() => _starting = false);
    unawaited(context.push<void>(join ? '/access?join=1' : '/access'));
  }

  @override
  Widget build(BuildContext context) {
    final strings = VaultStrings.of(context);
    final text = Theme.of(context).textTheme;
    final seen = ref.watch(introSeenProvider).asData?.value ?? false;
    final configured = ref.watch(cloudConfigProvider).cloudConfigured;
    return VaultPage(
      title: 'FamilyVault',
      children: [
        const SizedBox(height: 20),
        const Align(
          alignment: AlignmentDirectional.centerStart,
          child: VaultIcon(icon: Icons.shield_outlined, size: 36),
        ),
        const SizedBox(height: 18),
        Text(strings.text('welcomeTitle'), style: text.headlineMedium),
        const SizedBox(height: 10),
        Text(strings.text('welcomeBody'), style: text.bodyLarge),
        const SizedBox(height: 16),
        const LanguagePicker(),
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _starting ? null : _start,
            child: Text(strings.text('start')),
          ),
        ),
        if (configured)
          OutlinedButton.icon(
            onPressed: _starting ? null : () => _start(join: true),
            icon: const Icon(Icons.mail_outline),
            label: Text(strings.text('hasFamilyInvitation')),
          ),
        if (!seen)
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => context.push('/welcome-tour'),
              child: Text(strings.text('seeGuide')),
            ),
          ),
        const SizedBox(height: 18),
        VaultLink(
          icon: Icons.help_outline,
          title: strings.text('help'),
          onTap: () => context.push('/help'),
        ),
      ],
    );
  }
}

class AccessPage extends ConsumerStatefulWidget {
  const AccessPage({this.join = false, super.key});
  final bool join;
  @override
  ConsumerState<AccessPage> createState() => _AccessPageState();
}

class _AccessPageState extends ConsumerState<AccessPage> {
  bool _creating = false;
  late bool _cloud = widget.join;
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
    final strings = VaultStrings.of(context);
    final status = ref.watch(vaultProvider),
        controller = ref.read(vaultProvider.notifier);
    final busy =
        status.phase == VaultPhase.opening ||
        status.phase == VaultPhase.loading;
    final configured = ref.watch(cloudConfigProvider).cloudConfigured;
    if (_cloud && configured) {
      return VaultPage(
        title: strings.text('joinFamily'),
        children: [
          TextButton.icon(
            onPressed: () => setState(() => _cloud = false),
            icon: const Icon(Icons.arrow_back),
            label: Text(strings.text('localOnly')),
          ),
          const SizedBox(height: 16),
          const CloudAccessPanel(),
        ],
      );
    }
    return VaultPage(
      title: strings.text('family'),
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
          strings.text(status.hasVault ? 'unlockTitle' : 'createTitle'),
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 12),
        Text(strings.text(status.hasVault ? 'unlockHelp' : 'setupHelp')),
        const SizedBox(height: 24),
        if (status.failure != null) ...[
          Semantics(
            liveRegion: true,
            child: Text(
              strings.failure(status.failure!),
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
            label: Text(context.tr('Try again')),
          ),
        if (!busy && status.hasVault)
          FilledButton.icon(
            onPressed: controller.unlock,
            icon: const Icon(Icons.fingerprint),
            label: Text(strings.text('unlock')),
          ),
        if (!busy &&
            !status.hasVault &&
            status.phase != VaultPhase.unavailable &&
            !_creating)
          FilledButton.icon(
            onPressed: () => setState(() => _creating = true),
            icon: const Icon(Icons.add),
            label: Text(strings.text('create')),
          ),
        if (status.phase == VaultPhase.setup && !_creating)
          TextButton.icon(
            onPressed: () => context.push('/restore'),
            icon: const Icon(Icons.restore),
            label: Text(strings.text('restore')),
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
                  decoration: InputDecoration(
                    labelText: strings.text('familyName'),
                  ),
                  validator: context.localizedValidator(_required),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _owner,
                  enabled: !busy,
                  maxLength: 80,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: strings.text('yourName'),
                  ),
                  validator: context.localizedValidator(_required),
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
                  label: Text(strings.text('verifyCreate')),
                ),
              ],
            ),
          ),
        const SizedBox(height: 28),
        if (configured && !busy) ...[
          OutlinedButton.icon(
            onPressed: () => setState(() => _cloud = true),
            icon: const Icon(Icons.group_outlined),
            label: Text(strings.text('joinFamily')),
          ),
          const SizedBox(height: 16),
        ],
        Text(
          strings.text('privacyHelp'),
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
    title: context.tr('About FamilyVault'),
    children: [
      Text('FamilyVault', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 8),
      Text(context.tr('Version 0.1.0 · Private family finance')),
      const SizedBox(height: 24),
      Text(
        context.tr(
          'Built to keep your family’s finances and important records together.',
        ),
      ),
      const SizedBox(height: 16),
      Text(
        context.tr(
          'Records you start on this phone stay here. Shared families use an invitation and a separate sign-in for each person.',
        ),
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
    label: Text(context.tr('Open-source licences')),
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
