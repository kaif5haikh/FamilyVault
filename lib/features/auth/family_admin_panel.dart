import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/localization/vault_strings.dart';
import '../../shared/widgets/vault_widgets.dart';
import 'cloud_access_gateway.dart';
import 'cloud_providers.dart';

class FamilyAdminPanel extends ConsumerStatefulWidget {
  const FamilyAdminPanel({
    required this.familyId,
    required this.memberId,
    required this.gateway,
    required this.startsWithInvite,
    super.key,
  });
  final String familyId, memberId;
  final bool startsWithInvite;
  final CloudAccessGateway gateway;
  @override
  ConsumerState<FamilyAdminPanel> createState() => _FamilyAdminPanelState();
}

class _FamilyAdminPanelState extends ConsumerState<FamilyAdminPanel> {
  List<CloudJson> _members = [], _devices = [], _invites = [], _audit = [];
  bool _busy = false, _loaded = false;
  late bool _inviting = widget.startsWithInvite;
  bool _inviteReady = false;
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

  Future<bool> _confirmAdministrator() async {
    if (_loaded) return true;
    final dialog = await showDialog<bool>(
      context: context,
      builder: (_) => _AdministratorVerification(gateway: widget.gateway),
    );
    return dialog == true && mounted;
  }

  Future<void> _verifyAdministrator() async {
    if (await _confirmAdministrator()) {
      await _admin((_) async {});
    }
  }

  Future<void> _saveInvitation(
    String email,
    String name,
    String relationship,
  ) async {
    if (_busy || !await _confirmAdministrator()) return;
    await _admin((proof) async {
      await widget.gateway.invite(proof, email, name, relationship);
      if (mounted) {
        setState(() {
          _inviting = false;
          _inviteReady = true;
        });
      }
    });
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
        scrollable: true,
        title: Text(
          context.tr('Revoke this {kind}?', {'kind': context.tr(kind)}),
        ),
        content: Text(
          context.tr(
            'This removes future family access. Files already saved to a phone can stay there.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.tr('Remove access')),
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
  Widget build(BuildContext context) {
    final strings = VaultStrings.of(context);
    final memberNames = {
      for (final row in _members) row['id']: row['display_name'],
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_busy) const LinearProgressIndicator(),
        if (_error != null) FailureNotice(_error!),
        if (_inviteReady)
          Semantics(
            liveRegion: true,
            child: Text(strings.text('familyInviteReady')),
          ),
        if (_inviting)
          _InviteForm(
            key: const ValueKey('family-invite-form'),
            enabled: !_busy,
            onSave: _saveInvitation,
            onCancel: () => setState(() => _inviting = false),
          )
        else ...[
          if (!_loaded)
            OutlinedButton.icon(
              onPressed: _busy ? null : _verifyAdministrator,
              icon: const Icon(Icons.admin_panel_settings_outlined),
              label: Text(strings.text('verifyFamilyAccess')),
            ),
          FilledButton.icon(
            onPressed: _busy
                ? null
                : () => setState(() {
                    _inviting = true;
                    _inviteReady = false;
                  }),
            icon: const Icon(Icons.person_add_alt_outlined),
            label: Text(strings.text('addFamilyMember')),
          ),
        ],
        if (_loaded && !_inviting) ...[
          const SizedBox(height: 18),
          SectionHeading(context.tr('Pending invitations')),
          if (_invites.isEmpty) Text(strings.text('noFamilyInvites')),
          for (final row in _invites)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(cloudText(row, 'display_name')),
              subtitle: Text(
                [
                  cloudText(row, 'email'),
                  if (DateTime.tryParse(row['expires_at'] as String? ?? '')
                      case final expiry?)
                    strings.message('Open until {date}', {
                      'date': MaterialLocalizations.of(context)
                          .formatMediumDate(expiry.toLocal()),
                    }),
                ].join('\n'),
              ),
              trailing: IconButton(
                tooltip: context.tr('Cancel invitation'),
                icon: const Icon(Icons.cancel_outlined),
                onPressed: _busy ? null : () => _revoke('invitation', row),
              ),
            ),
          SectionHeading(context.tr('Family members')),
          for (final row in _members)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(cloudText(row, 'display_name')),
              subtitle: Text(
                row['active'] != true
                    ? context.tr('Access removed')
                    : row['role'] == 'administrator'
                    ? context.tr('Family administrator')
                    : context.tr('Family member'),
              ),
              trailing: row['active'] == true && row['role'] == 'member'
                  ? IconButton(
                      tooltip: context.tr('Remove family access'),
                      icon: const Icon(Icons.person_remove_outlined),
                      onPressed: _busy ? null : () => _revoke('member', row),
                    )
                  : null,
            ),
          SectionHeading(context.tr('Family phones')),
          for (final row in _devices)
            Card.outlined(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(switch (memberNames[row['member_id']]) {
                      final String name => strings.message(
                        'Phone used by {name}',
                        {'name': name},
                      ),
                      _ => cloudText(row, 'name'),
                    }, style: Theme.of(context).textTheme.titleMedium),
                    Text(switch (row['state']) {
                      'pending' => context.tr('Waiting for approval'),
                      'enrolled' => context.tr('Approved'),
                      'revoked' => context.tr('Access removed'),
                      _ => context.tr('Check phone access'),
                    }),
                    if (row['state'] != 'revoked')
                      Wrap(
                        spacing: 12,
                        runSpacing: 6,
                        children: [
                          if (row['state'] == 'pending')
                            TextButton(
                              onPressed: _busy ? null : () => _approve(row),
                              child: Text(context.tr('Approve phone')),
                            ),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () => _revoke('device', row),
                            child: Text(context.tr('Remove phone access')),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ExpansionTile(
            title: Text(context.tr('Access history')),
            children: [
              for (final row in _audit)
                ListTile(
                  title: Text(
                    context.tr(cloudText(row, 'action').replaceAll('_', ' ')),
                  ),
                  subtitle: Text(cloudText(row, 'occurred_at')),
                ),
            ],
          ),
        ],
      ],
    );
  }
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
    scrollable: true,
    title: Text(context.tr('Confirm family access')),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.tr(
              'Verify a code from your authenticator app before changing family access.',
            ),
          ),
          if (_secret != null) ...[
            const SizedBox(height: 12),
            Text(
              context.tr(
                'Add FamilyVault to your authenticator using this setup key.',
              ),
            ),
            SelectableText(groupedFingerprint(_secret!)),
          ],
          if (_factorId != null)
            TextField(
              controller: _code,
              keyboardType: TextInputType.number,
              maxLength: 6,
              enabled: !_working,
              decoration: InputDecoration(
                labelText: context.tr('Authenticator code'),
              ),
            ),
          if (_error != null) FailureNotice(_error!),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _working ? null : () => Navigator.pop(context),
        child: Text(context.tr('Cancel')),
      ),
      FilledButton(
        onPressed: _working ? null : _verify,
        child: Text(
          _working
              ? context.tr('Checking…')
              : _factorId == null
              ? context.tr('Continue')
              : context.tr('Verify code'),
        ),
      ),
    ],
  );
}

class _InviteForm extends StatefulWidget {
  const _InviteForm({
    required this.enabled,
    required this.onSave,
    required this.onCancel,
    super.key,
  });

  final bool enabled;
  final void Function(String, String, String) onSave;
  final VoidCallback onCancel;

  @override
  State<_InviteForm> createState() => _InviteFormState();
}

class _InviteFormState extends State<_InviteForm> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController(),
      _name = TextEditingController(),
      _relationship = TextEditingController();
  static final _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

  @override
  void dispose() {
    _email.dispose();
    _name.dispose();
    _relationship.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    widget.onSave(
      _email.text.trim(),
      _name.text.trim(),
      _relationship.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = VaultStrings.of(context);
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(strings.text('familyInviteAccountHelp')),
          const SizedBox(height: 16),
          TextFormField(
            key: const ValueKey('invite-name'),
            controller: _name,
            enabled: widget.enabled,
            maxLength: 80,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: strings.text('familyInviteName'),
            ),
            validator: context.localizedValidator(requiredText),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const ValueKey('invite-email'),
            controller: _email,
            enabled: widget.enabled,
            maxLength: 254,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autocorrect: false,
            decoration: InputDecoration(
              labelText: strings.text('familyInviteEmail'),
            ),
            validator: (value) => _emailPattern.hasMatch(value?.trim() ?? '')
                ? null
                : strings.text('familyInviteEmailError'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const ValueKey('invite-relationship'),
            controller: _relationship,
            enabled: widget.enabled,
            maxLength: 40,
            textCapitalization: TextCapitalization.sentences,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              labelText: context.tr('Relationship'),
              hintText: strings.text('familyRelationshipExample'),
            ),
            validator: context.localizedValidator(requiredText),
          ),
          const SizedBox(height: 12),
          Text(strings.text('familyInviteNext')),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: widget.enabled ? _submit : null,
            child: Text(strings.text('saveFamilyInvitation')),
          ),
          TextButton(
            onPressed: widget.enabled ? widget.onCancel : null,
            child: Text(strings.text('cancel')),
          ),
        ],
      ),
    );
  }
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
    title: Text(context.tr("Approve {phone}", {'phone': widget.label})),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.tr(
                'Enter the fingerprint shown on the phone you are approving.',
              ),
            ),
            TextFormField(
              controller: _fingerprint,
              maxLines: 3,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: context.tr('Device fingerprint'),
              ),
              validator: (v) =>
                  v?.replaceAll(RegExp(r'\s+'), '').toLowerCase() ==
                      widget.expectedFingerprint
                  ? null
                  : context.tr('The fingerprints do not match.'),
            ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: Text(context.tr('Cancel')),
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
        child: Text(context.tr('Approve device')),
      ),
    ],
  );
}
