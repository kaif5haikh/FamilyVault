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
import 'vault_backup.dart';

class RestoreBackupPage extends ConsumerStatefulWidget {
  const RestoreBackupPage({super.key});

  @override
  ConsumerState<RestoreBackupPage> createState() => _RestoreBackupPageState();
}

class _RestoreBackupPageState extends ConsumerState<RestoreBackupPage> {
  final _key = TextEditingController();
  BackupInput? _selected;
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
    } catch (error) {
      if (mounted) _error = error;
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _verify() async {
    final selected = _selected;
    if (_working || selected == null) return;
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
      copy = await stageSelectedBackup(selected, root, key);
      final verified = await VaultBackup(root).verify(copy, key);
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
      title: 'Restore backup',
      children: [
        if (state.hasVault && !_installing) ...[
          const Text('A vault is already saved on this device.'),
          TextButton(
            onPressed: () => context.go('/access'),
            child: const Text('Open your vault'),
          ),
        ] else ...[
          if (verified == null) ...[
            OutlinedButton.icon(
              onPressed: _working ? null : _pick,
              icon: const Icon(Icons.folder_open_outlined),
              label: Text(
                _selected == null
                    ? 'Choose a backup file'
                    : 'Choose a different backup',
              ),
            ),
            if (_selected != null) ...[
              const SizedBox(height: 16),
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
                child: const Text('Verify backup'),
              ),
            ],
          ] else ...[
            const Text(
              'Backup verified. Restore a local copy of the records on this device.',
            ),
            const SizedBox(height: 12),
            Text(
              '${verified.documents} documents, ${verified.pending} saved changes',
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _working ? null : _restore,
              child: const Text('Restore vault'),
            ),
          ],
        ],
        if (_working) const LinearProgressIndicator(),
        if (_error != null) FailureNotice(_error!),
      ],
    );
  }
}
