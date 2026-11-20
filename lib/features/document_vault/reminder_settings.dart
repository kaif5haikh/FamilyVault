import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/localization/vault_strings.dart';
import '../../core/security/vault_identity.dart';
import '../../shared/widgets/vault_widgets.dart';
import 'expiry_reminders.dart';

class DocumentReminderSettings extends ConsumerStatefulWidget {
  const DocumentReminderSettings(this.identity, {super.key});
  final VaultIdentity identity;

  @override
  ConsumerState<DocumentReminderSettings> createState() =>
      _DocumentReminderSettingsState();
}

class _DocumentReminderSettingsState
    extends ConsumerState<DocumentReminderSettings> {
  bool _working = false;
  Object? _failure;

  Future<void> _toggle(bool enable) async {
    if (_working) return;
    final identity = widget.identity;
    final service = ref.read(documentReminderServiceProvider);
    setState(() {
      _working = true;
      _failure = null;
    });
    try {
      await service.setEnabled(identity, enable);
      if (mounted) {
        ref.invalidate(documentReminderEnabledProvider(identity));
        ref.invalidate(documentReminderPermissionProvider);
      }
    } catch (error) {
      if (mounted) _failure = error;
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(documentReminderServiceProvider).platform.supported) {
      return const SizedBox.shrink();
    }
    final preference = ref.watch(
      documentReminderEnabledProvider(widget.identity),
    );
    final on = preference.asData?.value == true;
    final permitted = ref.watch(documentReminderPermissionProvider);
    final message = on && permitted.asData?.value == false
        ? 'Allow notifications in your device settings.'
        : 'Get a private reminder before a document expires.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(context.tr('Document expiry notifications')),
          subtitle: Text(context.tr(message)),
          value: on,
          onChanged: !_working && preference.hasValue ? _toggle : null,
        ),
        if (_failure case final failure?) FailureNotice(failure),
        if (preference.error case final error?) FailureNotice(error),
      ],
    );
  }
}
