import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../app/vault_providers.dart';
import '../../core/errors/app_failure.dart';
import '../../core/security/sealed_file.dart';
import '../../core/security/secure_store.dart';
import '../../core/security/vault_identity.dart';
import '../../core/security/vault_lifecycle.dart';
import 'backup_archive.dart';
import 'vault_backup.dart';

abstract interface class BackupFileDestination {
  Future<({int bytes, String digest})?> copy(BackupArtifact artifact);
}

final backupFileDestinationProvider = Provider<BackupFileDestination>(
  (ref) => const NativeBackupDestination(),
);

final class NativeBackupDestination implements BackupFileDestination {
  const NativeBackupDestination();
  static const _channel = MethodChannel('app.familyvault/backup-files');

  @override
  Future<({int bytes, String digest})?> copy(BackupArtifact artifact) async {
    try {
      final reply = await _channel.invokeMapMethod<String, Object?>('export', {
        'path': artifact.file.path,
        'bytes': artifact.bytes,
      });
      if (reply == null) return null;
      return (
        bytes: reply['bytes']! as int,
        digest: reply['digest']! as String,
      );
    } catch (_) {
      throw const AppFailure(
        FailureCode.storage,
        'Could not verify the selected backup copy.',
      );
    }
  }
}

final localBackupProvider = Provider<LocalBackupDestination>(
  (ref) => LocalBackupDestination(
    root: ref.watch(vaultLifecycleProvider).root,
    store: ref.watch(secureStoreProvider),
    files: ref.watch(backupFileDestinationProvider),
  ),
);

final class LocalBackupStatus {
  const LocalBackupStatus(this.artifact, this.createdAtUs, {this.exportedAtUs});
  final BackupArtifact artifact;
  final int createdAtUs;
  final int? exportedAtUs;
}

final class LocalBackupDestination {
  LocalBackupDestination({
    required this.root,
    required this.store,
    required this.files,
    this.catalogNamespace = 'familyvault.backup.latest',
  });
  final Future<Directory> Function() root;
  final SecureStore store;
  final BackupFileDestination files;
  final String catalogNamespace;
  Future<void> _recording = Future.value();

  String _catalog(VaultIdentity i) =>
      '$catalogNamespace.${i.familyId}.${i.memberId}.${i.deviceId}';

  Future<LocalBackupStatus?> read(VaultIdentity identity) async {
    try {
      final value = await store.read(_catalog(identity));
      if (value == null) return null;
      final data = jsonDecode(value) as Map<String, Object?>;
      final id = data['id']! as String, digest = data['digest']! as String;
      final size = data['bytes']! as int,
          created = data['created_at_us']! as int;
      final exported = data['exported_at_us'] as int?;
      if (data['version'] != 1 ||
          !Uuid.isValidUUID(fromString: id) ||
          !RegExp(r'^[0-9a-f]{64}$').hasMatch(digest) ||
          size < 1 ||
          created < 1 ||
          exported != null && exported < created) {
        throw invalidBackup;
      }
      final file = File(p.join((await root()).path, 'backups', '$id.fvbackup'));
      return LocalBackupStatus(
        BackupArtifact(id, file, digest, size),
        created,
        exportedAtUs: exported,
      );
    } catch (_) {
      throw const AppFailure(
        FailureCode.storage,
        'Backup status could not be verified.',
      );
    }
  }

  Future<LocalBackupStatus> create(
    VaultSession session,
    BackupRecoveryKey key,
  ) async {
    final support = await root();
    final engine = VaultBackup(
      Directory(p.join(support.path, 'backup-staging')),
    );
    final artifact = await engine.capture(
      session: session,
      destination: Directory(p.join(support.path, 'backups')),
      recovery: key,
    );
    final latest = LocalBackupStatus(
      artifact,
      DateTime.now().toUtc().microsecondsSinceEpoch,
    );
    await _save(session.identity, latest);
    return latest;
  }

  Future<LocalBackupStatus?> export(
    VaultIdentity identity,
    LocalBackupStatus status,
  ) async {
    final artifact = status.artifact;
    final current = await read(identity);
    if (current?.artifact.id != artifact.id ||
        current?.artifact.digest != artifact.digest ||
        !await artifact.file.exists() ||
        await artifact.file.length() != artifact.bytes ||
        await SealedFile.digest(artifact.file) != artifact.digest) {
      throw invalidBackup;
    }
    final receipt = await files.copy(artifact);
    if (receipt == null) return null;
    if (receipt.bytes != artifact.bytes || receipt.digest != artifact.digest) {
      throw invalidBackup;
    }
    final now = DateTime.now().toUtc().microsecondsSinceEpoch;
    final latest = LocalBackupStatus(
      artifact,
      status.createdAtUs,
      exportedAtUs: now >= status.createdAtUs ? now : status.createdAtUs,
    );
    await _save(identity, latest, onlyIfCurrent: artifact.id);
    return latest;
  }

  Future<void> _save(
    VaultIdentity identity,
    LocalBackupStatus status, {
    String? onlyIfCurrent,
  }) {
    final operation = _recording.then(
      (_) => _writeReceipt(identity, status, onlyIfCurrent),
    );
    _recording = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {},
    );
    return operation;
  }

  Future<void> _writeReceipt(
    VaultIdentity identity,
    LocalBackupStatus status,
    String? onlyIfCurrent,
  ) async {
    final artifact = status.artifact;
    try {
      if (onlyIfCurrent != null &&
          (await read(identity))?.artifact.id != onlyIfCurrent) {
        return;
      }
      await store.write(
        _catalog(identity),
        jsonEncode({
          'version': 1,
          'id': artifact.id,
          'digest': artifact.digest,
          'bytes': artifact.bytes,
          'created_at_us': status.createdAtUs,
          'exported_at_us': status.exportedAtUs,
        }),
      );
    } catch (_) {
      throw const AppFailure(
        FailureCode.storage,
        'Could not record this backup result.',
      );
    }
  }
}
