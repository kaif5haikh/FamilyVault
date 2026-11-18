import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/vault_providers.dart';
import '../../core/security/vault_identity.dart';
import '../../shared/widgets/vault_widgets.dart';
import 'cloud_access_gateway.dart';
import 'cloud_cache.dart';
import 'cloud_connection.dart';
import 'cloud_device_registration.dart';
import 'cloud_providers.dart';
import 'family_admin_panel.dart';

class CloudAccessPanel extends ConsumerWidget {
  const CloudAccessPanel({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(cloudGatewayProvider)
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            FailureNotice(error),
            OutlinedButton(
              onPressed: () => ref.invalidate(cloudGatewayProvider),
              child: const Text('Try family sign-in again'),
            ),
          ],
        ),
        data: (gateway) => _ConnectedAccess(gateway: gateway),
      );
}

class _ConnectedAccess extends ConsumerStatefulWidget {
  const _ConnectedAccess({required this.gateway});
  final CloudAccessGateway gateway;
  @override
  ConsumerState<_ConnectedAccess> createState() => _ConnectedAccessState();
}

class _ConnectedAccessState extends ConsumerState<_ConnectedAccess> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController(), _password = TextEditingController();
  List<CloudJson> _families = [], _invitations = [];
  CloudJson? _selected;
  VaultIdentity? _recent;
  EnrollmentResult? _enrollment;
  Object? _error;
  bool _busy = false;
  late final StreamSubscription<String?> _identitySubscription;
  String? _knownUser;

  CloudAccessGateway get _gateway => widget.gateway;

  @override
  void initState() {
    super.initState();
    _knownUser = _gateway.userId;
    _identitySubscription = _gateway.identityChanges.listen((user) {
      if (!mounted || user == _knownUser) {
        return;
      }
      setState(() {
        _knownUser = user;
        _families = [];
        _invitations = [];
        _enrollment = null;
        _selected = null;
        _recent = null;
      });
    }, onError: (Object _) {});
    if (_gateway.userId != null) {
      unawaited(Future<void>.microtask(() => _run(_refresh)));
    }
  }

  @override
  void dispose() {
    unawaited(_identitySubscription.cancel());
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (!mounted || _busy) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) {
        setState(() => _error = error);
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _refresh() async {
    final user = _gateway.userId;
    if (user != null) {
      final recent = await (await _cache()).access.last(user);
      if (mounted && user == _gateway.userId) setState(() => _recent = recent);
    }
    final data = await _gateway.listAccess();
    if (!mounted || user == null || user != _gateway.userId) {
      return;
    }
    final families = cloudRows(data['families']),
        invitations = cloudRows(data['invitations']);
    setState(() {
      _families = families;
      _invitations = invitations;
    });
  }

  Future<void> _signIn() async {
    if (!_form.currentState!.validate()) {
      return;
    }
    await _run(() async {
      try {
        await _gateway.signIn(_email.text, _password.text);
        if (mounted) {
          await _refresh();
        }
      } finally {
        if (mounted) {
          _password.clear();
        }
      }
    });
  }

  Future<void> _register(CloudJson family) => _run(() async {
    final registration = await ref.read(cloudRegistrationProvider.future);
    final result = await registration.enroll(
      familyId: cloudText(family, 'family_id'),
      memberId: cloudText(family, 'member_id'),
      name: 'FamilyVault phone',
    );
    if (mounted) {
      setState(() {
        _selected = family;
        _enrollment = result;
      });
    }
  });

  Future<CloudWorkspaceCache> _cache() async {
    final root = ref.read(vaultLifecycleProvider).root;
    return CloudWorkspaceCache(
      await ref.read(cloudRegistrationProvider.future),
      root: root,
    );
  }

  Future<void> _openFamily(
    String familyId,
    String memberId, {
    String? deviceId,
  }) => _run(() async {
    final controller = ref.read(vaultProvider.notifier);
    final cache = await _cache();
    await controller.openConnected(
      () => connectFamily(
        cache: cache,
        familyId: familyId,
        memberId: memberId,
        expectedDevice: deviceId,
        onRevoked: (failure) => controller.lock(reason: failure),
      ),
    );
  });

  Future<void> _signOut() => _run(() async {
    try {
      try {
        final user = _gateway.userId;
        if (user != null && _recent != null) {
          await (await _cache()).access.revoke(user, _recent!);
        }
      } finally {
        await _gateway.signOut(null);
      }
    } finally {
      if (mounted) {
        _email.clear();
        _password.clear();
        setState(() {
          _families = [];
          _invitations = [];
          _selected = null;
          _enrollment = null;
          _recent = null;
        });
      }
    }
  });

  @override
  Widget build(BuildContext context) {
    if (_gateway.userId == null) {
      return _signInForm();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_busy) const LinearProgressIndicator(),
        if (_error != null) FailureNotice(_error!),
        if (_families.isEmpty &&
            _invitations.isEmpty &&
            !_busy &&
            _error == null)
          const Text(
            'No family invitation was found for this account. Ask your administrator to add this email address.',
          ),
        for (final invite in _invitations)
          Card.outlined(
            child: ListTile(
              leading: const Icon(Icons.mail_outline),
              title: Text(cloudText(invite, 'family_name')),
              subtitle: const Text('Family invitation'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _busy
                  ? null
                  : () => _run(() async {
                      await _gateway.accept(cloudText(invite, 'invite_id'));
                      await _refresh();
                    }),
            ),
          ),
        for (final family in _families)
          Card.outlined(
            child: ListTile(
              leading: const Icon(Icons.group_outlined),
              title: Text(cloudText(family, 'family_name')),
              subtitle: Text(
                cloudText(family, 'role') == 'administrator'
                    ? 'Administrator'
                    : 'Family member',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _busy ? null : () => _register(family),
            ),
          ),
        if (_enrollment case final enrollment?) ...[
          const SizedBox(height: 16),
          if (enrollment.state == 'pending') ...[
            const SectionHeading('Waiting for device approval'),
            const Text(
              'Compare this fingerprint with your administrator before they approve the phone.',
            ),
            const SizedBox(height: 10),
            SelectableText(groupedFingerprint(enrollment.fingerprint)),
            const SizedBox(height: 8),
            SelectableText('Device ID ${enrollment.deviceId}'),
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _register(_selected!),
              icon: const Icon(Icons.refresh),
              label: const Text('Check approval'),
            ),
          ] else if (enrollment.state == 'revoked')
            const Text(
              'This device was revoked. Contact the family administrator about access.',
            )
          else ...[
            const SectionHeading('Device approved'),
            if (_selected case final selection?)
              FilledButton.icon(
                onPressed: _busy
                    ? null
                    : () => _openFamily(
                        cloudText(selection, 'family_id'),
                        cloudText(selection, 'member_id'),
                      ),
                icon: const Icon(Icons.folder_open_outlined),
                label: const Text('Open family vault'),
              ),
            if (_selected != null &&
                enrollment.workspace?['role'] == 'administrator')
              FamilyAdminPanel(
                key: ValueKey(enrollment.deviceId),
                familyId: cloudText(_selected!, 'family_id'),
                memberId: cloudText(_selected!, 'member_id'),
                gateway: _gateway,
              ),
          ],
        ],
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          children: [
            if (_recent case final recent?)
              TextButton.icon(
                onPressed: _busy
                    ? null
                    : () => _openFamily(
                        recent.familyId,
                        recent.memberId,
                        deviceId: recent.deviceId,
                      ),
                icon: const Icon(Icons.history),
                label: const Text('Open last family vault'),
              ),
            TextButton.icon(
              onPressed: _busy ? null : () => _run(_refresh),
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh family access'),
            ),
            TextButton.icon(
              onPressed: _busy ? null : _signOut,
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _signInForm() => Form(
    key: _form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeading('Sign in to your family account'),
        TextFormField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          autofillHints: const [AutofillHints.username],
          decoration: const InputDecoration(labelText: 'Email address'),
          enabled: !_busy,
          maxLength: 254,
          validator: requiredText,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _password,
          obscureText: true,
          autocorrect: false,
          enableSuggestions: false,
          autofillHints: const [AutofillHints.password],
          decoration: const InputDecoration(labelText: 'Password'),
          enabled: !_busy,
          validator: requiredText,
        ),
        const SizedBox(height: 20),
        if (_error != null) FailureNotice(_error!),
        FilledButton.icon(
          onPressed: _busy ? null : _signIn,
          icon: const Icon(Icons.login),
          label: Text(_busy ? 'Signing in…' : 'Sign in'),
        ),
      ],
    ),
  );
}
