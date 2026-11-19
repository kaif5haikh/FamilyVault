import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/vault_providers.dart';
import '../../core/errors/app_failure.dart';
import '../../core/security/vault_lifecycle.dart';
import '../../shared/widgets/vault_widgets.dart';
import '../foundation/foundation_pages.dart' show VaultPage;
import 'backup_archive.dart';
import 'drive_backups_panel.dart';
import 'local_backup_destination.dart';
import 'scheduled_backups_panel.dart';

class BackupsPage extends ConsumerStatefulWidget {
  const BackupsPage({super.key});
  @override
  ConsumerState<BackupsPage> createState() => _BackupsPageState();
}

class _BackupsPageState extends ConsumerState<BackupsPage> {
  final _code = TextEditingController();
  BackupRecoveryKey? _generated;
  Future<LocalBackupStatus?>? _last;
  bool _busy = false, _savedKey = false;
  Object? _error;

  Future<void> _create(
    VaultSession session,
    LocalBackupDestination destination,
  ) async {
    if (_busy || (_generated != null && !_savedKey)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    BackupRecoveryKey? recovery;
    try {
      recovery = _generated == null
          ? BackupRecoveryKey.fromCode(_code.text)
          : BackupRecoveryKey.fromCode(_generated!.code);
      final status = await destination.create(session, recovery);
      if (!mounted) return;
      _generated?.destroy();
      _generated = null;
      _code.clear();
      _savedKey = false;
      _last = Future.value(status);
    } on AppFailure catch (error) {
      if (mounted) _error = error;
    } finally {
      recovery?.destroy();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy(
    VaultSession session,
    LocalBackupDestination destination,
    LocalBackupStatus status,
  ) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final copied = await destination.export(session.identity, status);
      if (copied != null && mounted) _last = Future.value(copied);
    } on AppFailure catch (error) {
      if (mounted) _error = error;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _generated?.destroy();
    _code.clear();
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(vaultProvider).session;
    if (session == null || session.closed) return const SizedBox.shrink();
    final destination = ref.watch(localBackupProvider);
    final generated = _generated;
    return VaultPage(
      title: 'Encrypted backups',
      children: [
        FutureBuilder<LocalBackupStatus?>(
          future: _last ??= destination.read(session.identity),
          builder: (context, snapshot) {
            if (snapshot.hasError) return FailureNotice(snapshot.error!);
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const LinearProgressIndicator();
            }
            final status = snapshot.data;
            if (status == null) {
              return const Text(
                'Create a backup to keep a copy of this vault.',
              );
            }
            final date = DateTime.fromMicrosecondsSinceEpoch(
              status.createdAtUs,
              isUtc: true,
            ).toLocal();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeading('Latest backup'),
                Text(MaterialLocalizations.of(context).formatMediumDate(date)),
                const SizedBox(height: 8),
                Text(
                  status.exportedAtUs == null
                      ? 'Verified on this device.'
                      : 'Your last file copy was read back and verified.',
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () => _copy(session, destination, status),
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Save a verified copy'),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        const SectionHeading('Create backup'),
        if (session.identity.isCloud)
          const Text(
            'This backup includes the records and changes on this device.',
          ),
        const Text(
          'Keep the recovery key somewhere separate. You need it to open the backup.',
        ),
        const SizedBox(height: 12),
        if (generated == null) ...[
          TextField(
            controller: _code,
            enabled: !_busy,
            obscureText: true,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(labelText: 'Recovery key'),
          ),
          TextButton(
            onPressed: _busy
                ? null
                : () => setState(() {
                    _code.clear();
                    _generated = BackupRecoveryKey.generate();
                    _savedKey = false;
                  }),
            child: const Text('Create a new recovery key'),
          ),
        ] else ...[
          SelectableText(generated.code),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _savedKey,
            title: const Text('I saved the recovery key separately'),
            onChanged: _busy
                ? null
                : (value) => setState(() => _savedKey = value ?? false),
          ),
        ],
        FilledButton.icon(
          onPressed: _busy || generated != null && !_savedKey
              ? null
              : () => _create(session, destination),
          icon: const Icon(Icons.backup_outlined),
          label: const Text('Create encrypted backup'),
        ),
        if (_busy) const LinearProgressIndicator(),
        if (_error != null) FailureNotice(_error!),
        const SizedBox(height: 24),
        FutureBuilder<LocalBackupStatus?>(
          future: _last,
          builder: (_, snapshot) => DriveBackupsPanel(
            identity: session.identity,
            backup: snapshot.data?.artifact,
            enabled: !_busy,
          ),
        ),
        const SizedBox(height: 24),
        ScheduledBackupsPanel(session: session),
      ],
    );
  }
}
