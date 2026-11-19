import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../core/errors/app_failure.dart';
import '../../core/security/sealed_file.dart';
import '../../core/security/secure_store.dart';
import '../../core/security/vault_identity.dart';
import 'drive_backup_api.dart';
import 'vault_backup.dart';

final class DriveBackupReceipt {
  const DriveBackupReceipt(this.file, this.digest, this.completedAtUs);
  final DriveBackupFile file;
  final String digest;
  final int completedAtUs;
}

final class _DriveAttempt {
  const _DriveAttempt(this.fileId, this.session, {this.verifiedAtUs});
  final String fileId;
  final Uri? session;
  final int? verifiedAtUs;
  @override
  String toString() => '_DriveAttempt([redacted])';
}

/// One immutable provider file per snapshot. Its pre-generated Drive ID is
/// saved before starting transfer and remains stable across retries.
final class DriveBackupDestination {
  DriveBackupDestination({
    required this.api,
    required this.store,
    required this.accountId,
  });
  final GoogleDriveBackupApi api;
  final SecureStore store;
  final String accountId;
  final _active = <String, Future<DriveBackupReceipt>>{};
  static const _chunk = 8 * 1024 * 1024;

  String _scope(VaultIdentity i) => sha256
      .convert(
        utf8.encode(
          jsonEncode([
            'FamilyVault Drive backup v1',
            accountId,
            i.familyId,
            i.memberId,
            i.deviceId,
          ]),
        ),
      )
      .toString();

  Future<DriveBackupReceipt> upload(
    VaultIdentity identity,
    BackupArtifact artifact,
  ) {
    final key = _attemptKey(identity, artifact);
    return _active[key] ??= _deliver(key, artifact).whenComplete(() {
      _active.remove(key);
    });
  }

  Future<int?> verifiedAt(
    VaultIdentity identity,
    BackupArtifact artifact,
  ) async =>
      (await _load(_attemptKey(identity, artifact), artifact))?.verifiedAtUs;

  String _attemptKey(VaultIdentity identity, BackupArtifact artifact) {
    if (!Uuid.isValidUUID(fromString: artifact.id)) throw driveInvalid;
    return 'familyvault.drive.${_scope(identity)}.${artifact.id}';
  }

  Future<DriveBackupReceipt> _deliver(
    String key,
    BackupArtifact artifact,
  ) async {
    if (!await artifact.file.exists() ||
        await artifact.file.length() != artifact.bytes ||
        await SealedFile.digest(artifact.file) != artifact.digest) {
      throw driveInvalid;
    }
    var attempt = await _load(key, artifact);
    if (attempt == null) {
      attempt = _DriveAttempt(await api.allocateId(), null);
      await _save(key, artifact, attempt);
    }
    final existing = await api.metadata(attempt.fileId);
    if (existing != null) return _confirm(key, artifact, existing);

    var session = attempt.session;
    var offset = 0;
    if (session != null) {
      final state = await api.status(session, artifact.bytes);
      if (state.phase == DriveUploadPhase.completed) {
        return _complete(key, artifact, attempt, state);
      }
      if (state.phase == DriveUploadPhase.expired) {
        session = null;
      } else {
        offset = state.offset;
      }
    }
    if (session == null) {
      session = await api.start(artifact, attempt.fileId);
      if (session == null) {
        final found = await api.metadata(attempt.fileId);
        if (found == null) throw driveUnavailable;
        return _confirm(key, artifact, found);
      }
      attempt = _DriveAttempt(attempt.fileId, session);
      await _save(key, artifact, attempt);
    }
    while (offset < artifact.bytes) {
      final end = min(artifact.bytes, offset + _chunk);
      final DriveUploadProgress state;
      try {
        state = await api.upload(session, artifact, offset, end);
      } on AppFailure catch (error) {
        if (error.code != FailureCode.network) rethrow;
        final observed = await api.status(session, artifact.bytes);
        if (observed.phase != DriveUploadPhase.completed) {
          // The saved session and the next status probe recover a partial copy.
          rethrow;
        }
        return _complete(key, artifact, attempt, observed);
      }
      switch (state.phase) {
        case DriveUploadPhase.completed:
          if (end != artifact.bytes) throw driveInvalid;
          return _complete(key, artifact, attempt, state);
        case DriveUploadPhase.expired:
          await _save(key, artifact, _DriveAttempt(attempt.fileId, null));
          throw driveUnavailable;
        case DriveUploadPhase.transferring:
          if (state.offset > end || state.offset <= offset) throw driveInvalid;
          offset = state.offset;
      }
    }
    throw driveInvalid;
  }

  Future<DriveBackupReceipt> _complete(
    String key,
    BackupArtifact artifact,
    _DriveAttempt attempt,
    DriveUploadProgress state,
  ) async {
    if (state.fileId != attempt.fileId) throw driveInvalid;
    final file = await api.metadata(attempt.fileId);
    if (file == null) throw driveUnavailable;
    return _confirm(key, artifact, file);
  }

  Future<DriveBackupReceipt> _confirm(
    String key,
    BackupArtifact artifact,
    DriveBackupFile file,
  ) async {
    if (file.snapshotId != artifact.id || file.bytes != artifact.bytes) {
      throw driveInvalid;
    }
    final digest = file.digest ?? await api.checksum(file);
    if (digest != artifact.digest) throw driveInvalid;
    final now = DateTime.now().toUtc().microsecondsSinceEpoch;
    await _save(key, artifact, _DriveAttempt(file.id, null, verifiedAtUs: now));
    return DriveBackupReceipt(file, digest, now);
  }

  Future<({List<DriveBackupFile> files, String? nextPage})> history({
    String? page,
  }) => api.list(page: page);

  Future<File> fetch(DriveBackupFile file, Directory staging) async {
    final current = await api.metadata(file.id);
    if (current == null ||
        current.snapshotId != file.snapshotId ||
        current.bytes != file.bytes ||
        file.digest != null && file.digest != current.digest) {
      throw driveInvalid;
    }
    final folder = await (await staging.create(recursive: true))
        .createTemp('drive-');
    final target = File(p.join(folder.path, '${file.snapshotId}.fvbackup'));
    try {
      await api.download(current, target);
      return target;
    } catch (_) {
      await folder.delete(recursive: true);
      rethrow;
    }
  }

  Future<_DriveAttempt?> _load(String key, BackupArtifact artifact) async {
    try {
      final saved = await store.read(key);
      if (saved == null) return null;
      final data = jsonDecode(saved) as Map<String, Object?>;
      if (data['version'] != 1 ||
          data['bytes'] != artifact.bytes ||
          data['digest'] != artifact.digest) {
        throw driveInvalid;
      }
      final id = data['file_id']! as String,
          session = data['session'] as String?;
      final verified = data['verified_at_us'] as int?;
      if (verified != null && (verified < 1 || session != null)) {
        throw driveInvalid;
      }
      return _DriveAttempt(
        id,
        session == null ? null : api.sessionUri(session),
        verifiedAtUs: verified,
      );
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw driveInvalid;
    }
  }

  Future<void> _save(
    String key,
    BackupArtifact artifact,
    _DriveAttempt attempt,
  ) async {
    try {
      await store.write(
        key,
        jsonEncode({
          'version': 1,
          'file_id': attempt.fileId,
          'session': attempt.session?.toString(),
          'bytes': artifact.bytes,
          'digest': artifact.digest,
          'verified_at_us': attempt.verifiedAtUs,
        }),
      );
    } catch (_) {
      throw const AppFailure(
        FailureCode.storage,
        'Could not record the Drive backup status.',
      );
    }
  }
}
