import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

import '../../app/vault_providers.dart';
import '../../core/errors/app_failure.dart';
import '../../shared/widgets/vault_widgets.dart';
import '../foundation/foundation_pages.dart' show VaultPage;
import 'backup_archive.dart';
import 'backup_file_io.dart';
import 'drive_backup_api.dart';
import 'drive_backups_panel.dart';
import 'vault_backup.dart';

class RestoreBackupPage extends ConsumerStatefulWidget {
  const RestoreBackupPage({super.key});

  @override
  ConsumerState<RestoreBackupPage> createState() => _RestoreBackupPageState();
}

class _RestoreBackupPageState extends ConsumerState<RestoreBackupPage> {
  final _key = TextEditingController();
  BackupInput? _selected;
  DriveBackupSelection? _drive;
  VerifiedVaultBackup? _verified;
  Object? _error;
  bool _working = false, _installing = false;

  Future<void> _pick() async {
    if (_working) return;
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final file = await ref.read(backupFilePickerProvider).pick();
      if (file == null || !mounted) return;
      await _verified?.close();
      _verified = null;
      _selected = file;
      _drive = null;
      _key.clear();
    } catch (error) {
      if (mounted) _error = error;
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _verify() async {
    final selected = _selected, drive = _drive;
    if (_working || selected == null && drive == null) return;
    final lifecycle = ref.read(vaultLifecycleProvider);
    setState(() {
      _working = true;
      _error = null;
    });
    BackupRecoveryKey? key;
    File? copy;
    try {
      key = BackupRecoveryKey.fromCode(_key.text);
      _key.clear();
      final root = Directory(
        p.join((await lifecycle.root()).path, 'backup-staging'),
      );
      copy = drive == null
          ? await stageSelectedBackup(selected!, root, key)
          : await drive.connection.destination.fetch(drive.file, root, key);
      final verified = await VaultBackup(root).verify(copy, key);
      if (drive != null &&
          verified.contents.manifest.id != drive.file.snapshotId) {
        await verified.close();
        throw driveInvalid;
      }
      if (!mounted) {
        await verified.close();
        return;
      }
      _verified = verified;
    } catch (error) {
      if (mounted) _error = error;
    } finally {
      key?.destroy();
      await copy?.parent.delete(recursive: true);
      if (mounted) setState(() => _working = false);
    }
  }

  void _selectDrive(DriveBackupSelection selection) {
    setState(() {
      _selected = null;
      _drive = selection;
      _key.clear();
      _error = null;
    });
  }

  Future<void> _restore() async {
    final verified = _verified;
    if (_working || verified == null) return;
    setState(() {
      _working = _installing = true;
      _error = null;
    });
    try {
      await ref.read(vaultLifecycleProvider).restoreBackup(verified);
    } on AppFailure catch (error) {
      if (mounted) _error = error;
    } finally {
      _installing = false;
      _verified = null;
      await verified.close();
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  void dispose() {
    _key.clear();
    _key.dispose();
    if (!_installing) unawaited(_verified?.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(vaultProvider);
    final verified = _verified;
    return VaultPage(
      title: 'Bring back saved data',
      children: [
        if (state.hasVault && !_installing) ...[
          const Text(
            'This phone already has FamilyVault records. Open those records to keep using them.',
          ),
          TextButton(
            onPressed: () => context.go('/access'),
            child: const Text('Open your records'),
          ),
        ] else ...[
          if (verified == null) ...[
            OutlinedButton.icon(
              onPressed: _working ? null : _pick,
              icon: const Icon(Icons.folder_open_outlined),
              label: Text(
                _selected == null
                    ? 'Choose your safe-copy file'
                    : 'Choose a different file',
              ),
            ),
            const SizedBox(height: 16),
            DriveBackupsPanel(enabled: !_working, onSelect: _selectDrive),
            if (_selected != null || _drive != null) ...[
              const SizedBox(height: 16),
              if (_drive != null)
                Text(
                  'Selected Google Drive copy from ${MaterialLocalizations.of(context).formatMediumDate(_drive!.file.created.toLocal())}',
                ),
              TextField(
                controller: _key,
                enabled: !_working,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                textCapitalization: TextCapitalization.none,
                decoration: const InputDecoration(labelText: 'Recovery key'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _working ? null : _verify,
                child: const Text('Check this copy'),
              ),
            ],
          ] else ...[
            const Text(
              'Your safe copy is ready. Bring the records back to this phone.',
            ),
            const SizedBox(height: 12),
            Text(
              '${verified.documents} documents, ${verified.pending} saved changes',
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _working ? null : _restore,
              child: const Text('Bring back my records'),
            ),
          ],
        ],
        if (_working) const LinearProgressIndicator(),
        if (_error != null) FailureNotice(_error!),
      ],
    );
  }
}
