import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/security/vault_lifecycle.dart';
import '../../shared/widgets/vault_widgets.dart';
import 'backup_archive.dart';
import 'backup_scheduler.dart';
import 'drive_sign_in.dart';

class ScheduledBackupsPanel extends ConsumerStatefulWidget {
  const ScheduledBackupsPanel({required this.session, super.key});
  final VaultSession session;

  @override
  ConsumerState<ScheduledBackupsPanel> createState() =>
      _ScheduledBackupsPanelState();
}

class _ScheduledBackupsPanelState extends ConsumerState<ScheduledBackupsPanel> {
  final _key = TextEditingController();
  BackupCadence _cadence = BackupCadence.daily;
  bool _editing = false, _savedElsewhere = false, _working = false;
  DriveBackupConnection? _useDrive;
  Object? _error;

  Future<void> _run(Future<void> Function(BackupScheduler) work) async {
    if (_working) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await work(ref.read(backupSchedulerProvider));
      if (!mounted) return;
      ref.invalidate(backupScheduleStatusProvider(widget.session.identity));
      _clearForm();
    } catch (error) {
      if (mounted) _error = error;
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  void _clearForm() {
    _editing = false;
    _key.clear();
    _savedElsewhere = false;
    _useDrive = null;
  }

  Future<void> _enable(BackupScheduler scheduler) async {
    if (!_savedElsewhere) return;
    final key = BackupRecoveryKey.fromCode(_key.text);
    try {
      final drive = ref.read(driveConnectionProvider);
      await scheduler.enable(
        widget.session,
        _cadence,
        key,
        drive: identical(drive, _useDrive) ? drive : null,
      );
    } finally {
      key.destroy();
    }
  }

  @override
  void dispose() {
    _key.clear();
    _key.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final identity = widget.session.identity;
    final state = ref.watch(backupScheduleStatusProvider(identity));
    final status = state.asData?.value,
        drive = ref.watch(driveConnectionProvider);
    String date(int us) => MaterialLocalizations.of(context)
        .formatMediumDate(DateTime.fromMicrosecondsSinceEpoch(us).toLocal());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeading('Automatic safe copies'),
        const Text('Backups can run while your vault is open.'),
        if (state.isLoading || _working) const LinearProgressIndicator(),
        if (state.hasError) FailureNotice(state.error!),
        if (status != null) ...[
          Text(
            '${status.cadence == BackupCadence.daily ? 'Daily' : 'Weekly'} schedule. Next backup ${date(status.dueAtUs)}.',
          ),
          if (status.local case final local?)
            Text(
              'Local backup verified ${date(local.createdAtUs)}.'
              '${local.exportedAtUs == null ? '' : ' File copy verified ${date(local.exportedAtUs!)}.'}',
            ),
          if (status.captureFailed)
            const Text(
              'The scheduled backup failed. It will retry while the vault is open.',
            ),
          if (status.driveEnabled)
            Text(
              status.driveFailed
                  ? 'The Drive copy failed. Check your connection and Google account.'
                  : status.driveVerifiedAtUs == null
                  ? 'Drive copy pending. Connect the Google account selected for this schedule.'
                  : 'Drive copy verified ${date(status.driveVerifiedAtUs!)}.',
            ),
          Wrap(
            spacing: 8,
            children: [
              if (status.local != null)
                OutlinedButton.icon(
                  onPressed: _working
                      ? null
                      : () => _run(
                          (scheduler) => scheduler.exportLatest(identity),
                        ),
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Save scheduled backup to Files'),
                ),
              TextButton(
                onPressed: _working
                    ? null
                    : () => _run((scheduler) => scheduler.disable(identity)),
                child: const Text('Turn off schedule'),
              ),
            ],
          ),
        ] else if (_editing) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final option in BackupCadence.values)
                ChoiceChip(
                  label: Text(
                    option == BackupCadence.daily ? 'Daily' : 'Weekly',
                  ),
                  selected: _cadence == option,
                  onSelected: _working
                      ? null
                      : (_) => setState(() => _cadence = option),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _key,
            enabled: !_working,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              labelText: 'Schedule recovery key',
            ),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('I saved the recovery key separately'),
            value: _savedElsewhere,
            onChanged: _working
                ? null
                : (value) => setState(() => _savedElsewhere = value ?? false),
          ),
          if (drive != null)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Also copy scheduled backups to Drive'),
              subtitle: Text(drive.email),
              value: identical(_useDrive, drive),
              onChanged: _working
                  ? null
                  : (value) => setState(
                      () => _useDrive = value == true ? drive : null,
                    ),
            ),
          Wrap(
            spacing: 8,
            children: [
              FilledButton(
                onPressed: _working || !_savedElsewhere
                    ? null
                    : () => _run(_enable),
                child: const Text('Save schedule'),
              ),
              TextButton(
                onPressed: _working ? null : () => setState(_clearForm),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ] else if (state.hasValue)
          OutlinedButton(
            onPressed: _working ? null : () => setState(() => _editing = true),
            child: const Text('Set a backup schedule'),
          ),
        if (_error != null) FailureNotice(_error!),
      ],
    );
  }
}
