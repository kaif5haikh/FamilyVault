import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../shared/widgets/vault_widgets.dart';
import 'cloud_access_gateway.dart';
import 'cloud_providers.dart';

class FamilyAdminPanel extends ConsumerStatefulWidget {
  const FamilyAdminPanel({
    required this.familyId,
    required this.memberId,
    required this.gateway,
    super.key,
  });
  final String familyId, memberId;
  final CloudAccessGateway gateway;
  @override
  ConsumerState<FamilyAdminPanel> createState() => _FamilyAdminPanelState();
}

class _FamilyAdminPanelState extends ConsumerState<FamilyAdminPanel> {
  List<CloudJson> _members = [], _devices = [], _invites = [], _audit = [];
  bool _busy = false, _loaded = false;
  Object? _error;

  Future<void> _admin(Future<void> Function(DeviceProof) action) async {
    if (!mounted || _busy) {
      return;
    }
    setState(() {
      _error = null;
      _busy = true;
    });
    try {
      final registration = await ref.read(cloudRegistrationProvider.future);
      await registration.withVerifiedDevice(
        widget.familyId,
        widget.memberId,
        action: (device) async {
          await action(device.proof);
          final workspace = await widget.gateway.workspace(device.proof);
          final admin = await widget.gateway.administratorView(device.proof);
          if (mounted) {
            setState(() {
              _loaded = true;
              _members = cloudRows(workspace['members']);
              _devices = cloudRows(workspace['devices']);
              _invites = cloudRows(admin['invitations']);
              _audit = cloudRows(admin['audit']);
            });
          }
        },
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _loaded = false;
          _members = [];
          _devices = [];
          _invites = [];
          _audit = [];
          _error = e;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _verifyAdministrator() async {
    final dialog = await showDialog<bool>(
      context: context,
      builder: (_) => _AdministratorVerification(gateway: widget.gateway),
    );
    if (dialog == true && mounted) {
      await _admin((_) async {});
    }
  }

  Future<void> _newInvite() async {
    final invite = await showDialog<(String, String, String)>(
      context: context,
      builder: (_) => const _InviteDialog(),
    );
    if (invite != null && mounted) {
      await _admin(
        (proof) =>
            widget.gateway.invite(proof, invite.$1, invite.$2, invite.$3),
      );
    }
  }

  Future<void> _approve(CloudJson candidate) async {
    final fingerprint = await showDialog<String>(
      context: context,
      builder: (_) => _FingerprintDialog(
        label: cloudText(candidate, 'name'),
        expectedFingerprint: cloudText(candidate, 'fingerprint'),
      ),
    );
    if (fingerprint != null && mounted) {
      await _admin(
        (proof) => widget.gateway.approve(
          proof,
          cloudText(candidate, 'id'),
          fingerprint,
        ),
      );
    }
  }

  Future<void> _revoke(String kind, CloudJson row) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Revoke this $kind?'),
        content: const Text(
          'This blocks future access through the selected record. Copies already downloaded may still be on that device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Revoke access'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await _admin(
        (proof) => widget.gateway.revoke(proof, kind, cloudText(row, 'id')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      OutlinedButton.icon(
        onPressed: _busy ? null : _verifyAdministrator,
        icon: const Icon(Icons.admin_panel_settings_outlined),
        label: const Text('Verify administrator access'),
      ),
      if (_busy) const LinearProgressIndicator(),
      if (_error != null) FailureNotice(_error!),
      if (_loaded) ...[
        const SizedBox(height: 18),
        SectionHeading(
          'Family members',
          action: FilledButton.icon(
            onPressed: _busy ? null : _newInvite,
            icon: const Icon(Icons.person_add_alt_outlined),
            label: const Text('Add invitation'),
          ),
        ),
        for (final row in _members)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(cloudText(row, 'display_name')),
            subtitle: Text(
              row['active'] == true ? cloudText(row, 'role') : 'Revoked',
            ),
            trailing: row['active'] == true && row['role'] == 'member'
                ? IconButton(
                    tooltip: 'Revoke membership',
                    icon: const Icon(Icons.person_remove_outlined),
                    onPressed: _busy ? null : () => _revoke('member', row),
                  )
                : null,
          ),
        if (_invites.isNotEmpty) const SectionHeading('Pending invitations'),
        for (final row in _invites)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(cloudText(row, 'display_name')),
            subtitle: Text(cloudText(row, 'email')),
            trailing: IconButton(
              tooltip: 'Revoke invitation',
              icon: const Icon(Icons.cancel_outlined),
              onPressed: _busy ? null : () => _revoke('invitation', row),
            ),
          ),
        const SectionHeading('Family devices'),
        for (final row in _devices)
          Card.outlined(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    cloudText(row, 'name'),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(cloudText(row, 'state')),
                  if (row['state'] != 'revoked')
                    Wrap(
                      spacing: 12,
                      runSpacing: 6,
                      children: [
                        if (row['state'] == 'pending')
                          TextButton(
                            onPressed: _busy ? null : () => _approve(row),
                            child: const Text('Approve device'),
                          ),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => _revoke('device', row),
                          child: const Text('Revoke device'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ExpansionTile(
          title: const Text('Access history'),
          children: [
            for (final row in _audit)
              ListTile(
                title: Text(cloudText(row, 'action').replaceAll('_', ' ')),
                subtitle: Text(cloudText(row, 'occurred_at')),
              ),
          ],
        ),
      ],
    ],
  );
}

class _AdministratorVerification extends StatefulWidget {
  const _AdministratorVerification({required this.gateway});
  final CloudAccessGateway gateway;
  @override
  State<_AdministratorVerification> createState() =>
      _AdministratorVerificationState();
}

class _AdministratorVerificationState
    extends State<_AdministratorVerification> {
  final _code = TextEditingController();
  String? _factorId, _secret;
  bool _working = false;
  Object? _error;
  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    setState(() {
      _error = null;
      _working = true;
    });
    try {
      final id = _factorId;
      if (id != null) {
        await widget.gateway.verifyTotp(id, _code.text.trim());
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        final existing = (await widget.gateway.factors()).firstOrNull;
        if (!mounted) {
          return;
        }
        if (existing != null) {
          setState(() => _factorId = existing.id);
        } else {
          final enrollment = await widget.gateway.enrollTotp();
          if (mounted) {
            setState(() {
              _factorId = enrollment.factorId;
              _secret = enrollment.secret;
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e);
      }
    } finally {
      if (mounted) {
        setState(() => _working = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Administrator verification'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Verify a code from your authenticator app before changing family access.',
          ),
          if (_secret != null) ...[
            const SizedBox(height: 12),
            const Text(
              'Add FamilyVault to your authenticator using this setup key.',
            ),
            SelectableText(groupedFingerprint(_secret!)),
          ],
          if (_factorId != null)
            TextField(
              controller: _code,
              keyboardType: TextInputType.number,
              maxLength: 6,
              enabled: !_working,
              decoration: const InputDecoration(
                labelText: 'Authenticator code',
              ),
            ),
          if (_error != null) FailureNotice(_error!),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _working ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _working ? null : _verify,
        child: Text(
          _working
              ? 'Checking…'
              : _factorId == null
              ? 'Continue'
              : 'Verify code',
        ),
      ),
    ],
  );
}

class _InviteDialog extends StatefulWidget {
  const _InviteDialog();
  @override
  State<_InviteDialog> createState() => _InviteDialogState();
}

class _InviteDialogState extends State<_InviteDialog> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController(),
      _name = TextEditingController(),
      _relationship = TextEditingController();
  @override
  void dispose() {
    _email.dispose();
    _name.dispose();
    _relationship.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Invite a family member'),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Use the email address on their own family account.'),
            TextFormField(
              controller: _email,
              maxLength: 254,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Account email'),
              validator: requiredText,
            ),
            TextFormField(
              controller: _name,
              maxLength: 80,
              decoration: const InputDecoration(labelText: 'Name'),
              validator: requiredText,
            ),
            TextFormField(
              controller: _relationship,
              maxLength: 40,
              decoration: const InputDecoration(labelText: 'Relationship'),
              validator: requiredText,
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(context, (
              _email.text,
              _name.text,
              _relationship.text,
            ));
          }
        },
        child: const Text('Add invitation'),
      ),
    ],
  );
}

class _FingerprintDialog extends StatefulWidget {
  const _FingerprintDialog({
    required this.label,
    required this.expectedFingerprint,
  });
  final String label, expectedFingerprint;
  @override
  State<_FingerprintDialog> createState() => _FingerprintDialogState();
}

class _FingerprintDialogState extends State<_FingerprintDialog> {
  final _fingerprint = TextEditingController();
  final _form = GlobalKey<FormState>();
  @override
  void dispose() {
    _fingerprint.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Approve ${widget.label}'),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Enter the fingerprint shown on the phone you are approving.',
            ),
            TextFormField(
              controller: _fingerprint,
              maxLines: 3,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                labelText: 'Device fingerprint',
              ),
              validator: (v) =>
                  v?.replaceAll(RegExp(r'\s+'), '').toLowerCase() ==
                      widget.expectedFingerprint
                  ? null
                  : 'The fingerprints do not match.',
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(
              context,
              _fingerprint.text.replaceAll(RegExp(r'\s+'), '').toLowerCase(),
            );
          }
        },
        child: const Text('Approve device'),
      ),
    ],
  );
}
