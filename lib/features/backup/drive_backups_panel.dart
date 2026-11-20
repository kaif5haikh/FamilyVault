import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/security/vault_identity.dart';
import '../../shared/widgets/vault_widgets.dart';
import 'drive_backup_api.dart';
import 'drive_sign_in.dart';
import 'vault_backup.dart';

typedef DriveBackupSelection = ({
  DriveBackupConnection connection,
  DriveBackupFile file,
});

typedef _DriveReceiptQuery = ({
  DriveBackupConnection connection,
  VaultIdentity identity,
  BackupArtifact backup,
});

final _driveReceiptProvider = FutureProvider.autoDispose
    .family<int?, _DriveReceiptQuery>(
      (ref, query) =>
          query.connection.destination.verifiedAt(query.identity, query.backup),
    );

class DriveBackupsPanel extends ConsumerStatefulWidget {
  const DriveBackupsPanel({
    this.identity,
    this.backup,
    this.onSelect,
    this.enabled = true,
    super.key,
  });

  final VaultIdentity? identity;
  final BackupArtifact? backup;
  final ValueChanged<DriveBackupSelection>? onSelect;
  final bool enabled;

  @override
  ConsumerState<DriveBackupsPanel> createState() => _DriveBackupsPanelState();
}

class _DriveBackupsPanelState extends ConsumerState<DriveBackupsPanel> {
  DriveBackupConnection? _listedAccount;
  List<DriveBackupFile> _files = [];
  String? _nextPage;
  Object? _error;
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy || !widget.enabled) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } catch (error) {
      if (mounted) _error = error;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _history(DriveBackupConnection account, {String? page}) async {
    final result = await account.destination.history(page: page);
    if (!mounted || ref.read(driveConnectionProvider) != account) return;
    _listedAccount = account;
    _files = page == null ? result.files : [..._files, ...result.files];
    _nextPage = result.nextPage;
  }

  Future<void> _upload(_DriveReceiptQuery query) async {
    await query.connection.destination.upload(query.identity, query.backup);
    if (mounted) ref.invalidate(_driveReceiptProvider(query));
  }

  void _select(DriveBackupConnection account, DriveBackupFile file) {
    setState(() {
      _listedAccount = null;
      _files = [];
      _nextPage = null;
    });
    widget.onSelect!((connection: account, file: file));
  }

  @override
  Widget build(BuildContext context) {
    final configured = ref.watch(driveConfiguredProvider);
    final account = ref.watch(driveConnectionProvider);
    final enabled = widget.enabled && !_busy;
    final identity = widget.identity, backup = widget.backup;
    final formats = MaterialLocalizations.of(context);
    final query = account != null && identity != null && backup != null
        ? (connection: account, identity: identity, backup: backup)
        : null;
    final receipt = query == null
        ? null
        : ref.watch(_driveReceiptProvider(query));
    final verifiedAt = receipt?.asData?.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeading('Google Drive'),
        if (configured.isLoading)
          const LinearProgressIndicator()
        else if (configured.asData?.value != true)
          const Text('Google Drive copies aren’t set up for this app.')
        else if (account == null)
          OutlinedButton.icon(
            onPressed: enabled
                ? () => _run(ref.read(driveConnectionProvider.notifier).connect)
                : null,
            icon: const Icon(Icons.cloud_outlined),
            label: const Text('Connect Google Drive'),
          )
        else ...[
          Text(account.email),
          if (verifiedAt != null)
            Text(
              'Drive copy verified ${formats.formatMediumDate(DateTime.fromMicrosecondsSinceEpoch(verifiedAt).toLocal())}.',
            ),
          if (receipt?.hasError == true) FailureNotice(receipt!.error!),
          if (query != null)
            OutlinedButton.icon(
              onPressed: enabled ? () => _run(() => _upload(query)) : null,
              icon: const Icon(Icons.cloud_upload_outlined),
              label: Text(
                verifiedAt == null
                    ? 'Save backup to Drive'
                    : 'Check Drive copy',
              ),
            ),
          Wrap(
            spacing: 8,
            children: [
              TextButton(
                onPressed: enabled ? () => _run(() => _history(account)) : null,
                child: Text(
                  _listedAccount == account
                      ? 'Refresh backup history'
                      : 'Show backup history',
                ),
              ),
              TextButton(
                onPressed: enabled
                    ? () => _run(
                        ref.read(driveConnectionProvider.notifier).disconnect,
                      )
                    : null,
                child: const Text('Disconnect'),
              ),
            ],
          ),
          if (_listedAccount == account) ...[
            if (_files.isEmpty)
              const Text('No Safe copies in Google Drive found.'),
            for (final file in _files)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.lock_outline),
                title: Text(formats.formatMediumDate(file.created.toLocal())),
                subtitle: Text(
                  '${formats.formatTimeOfDay(TimeOfDay.fromDateTime(file.created.toLocal()))} · ${formats.formatDecimal(file.bytes)} bytes',
                ),
                trailing: widget.onSelect == null
                    ? null
                    : const Icon(Icons.chevron_right),
                onTap: enabled && widget.onSelect != null
                    ? () => _select(account, file)
                    : null,
              ),
            if (_nextPage != null)
              TextButton(
                onPressed: enabled
                    ? () => _run(() => _history(account, page: _nextPage))
                    : null,
                child: const Text('Load older backups'),
              ),
          ],
        ],
        if (_busy) const LinearProgressIndicator(),
        if (_error != null) FailureNotice(_error!),
      ],
    );
  }
}
