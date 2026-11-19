import 'dart:io';

import 'package:drift/drift.dart' show BooleanExpressionOperators;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../core/database/encrypted_connection.dart';
import '../../core/database/mutation_writer.dart';
import '../../core/errors/app_failure.dart';
import '../../core/security/sealed_file.dart';
import '../../core/security/vault_keys.dart';
import '../../core/security/vault_lifecycle.dart';
import '../document_vault/document_repository.dart';
import 'backup_archive.dart';

final class BackupArtifact {
  const BackupArtifact(this.id, this.file, this.digest, this.bytes);
  final String id, digest;
  final File file;
  final int bytes;
}

/// The files remain encrypted in a private staging directory during review.
final class VerifiedVaultBackup {
  const VerifiedVaultBackup._(
    this.contents, {
    required this.documents,
    required this.pending,
  });
  final ExtractedBackup contents;
  final int documents, pending;
  Future<void> close() => contents.close();
}

final class VaultBackup {
  const VaultBackup(this.stagingRoot);
  final Directory stagingRoot;
  static const _uuid = Uuid();

  Future<BackupArtifact> capture({
    required VaultSession session,
    required Directory destination,
    required BackupRecoveryKey recovery,
  }) => storageBoundary(() async {
    await _authorize(session);
    final stage = await (await stagingRoot.create(recursive: true))
        .createTemp('capture-');
    final key = SealedFile.randomBytes(32);
    final id = _uuid.v4();
    final target = File(p.join(destination.path, '$id.fvbackup'));
    final partial = File('${target.path}.partial');
    BackupManifest? manifest;
    try {
      final database = File(p.join(stage.path, BackupEntry.database));
      final copyKey = VaultDatabaseKey.fromBytes(key);
      await snapshotEncryptedDatabase(
        source: session.db.file,
        sourceKey: VaultDatabaseKey.fromBytes(session.keys.database),
        destination: database,
        destinationKey: copyKey,
      );
      await _authorize(session);

      final snapshot = AppDatabase.encrypted(file: database, key: copyKey);
      final versions = <({VaultDocumentVersion version, bool confirmed})>[];
      try {
        await snapshot.customStatement('PRAGMA query_only = ON');
        versions.addAll(await session.documents.backupVersions(snapshot));
      } finally {
        await snapshot.close();
      }
      final names = <String>{};
      for (final entry in versions) {
        final file = await session.documents.verifiedBackupFile(
          entry.version,
          confirmed: entry.confirmed,
        );
        final name = 'documents/${entry.version.id}.fvdoc';
        if (!names.add(name)) continue;
        final dest = File(p.join(stage.path, name));
        await dest.parent.create(recursive: true);
        await file.copy(dest.path);
      }
      final ordered = names.toList()..sort();
      manifest = BackupManifest(
        id: id,
        createdAtUs: DateTime.now().toUtc().microsecondsSinceEpoch,
        schemaVersion: session.db.schemaVersion,
        identity: session.identity,
        databaseKey: key,
        documentKey: session.keys.documents,
        entries: [
          await BackupEntry.measure(stage, BackupEntry.database),
          for (final name in ordered) await BackupEntry.measure(stage, name),
        ],
      );
      await destination.create(recursive: true);
      final digest = await BackupArchive.write(
        source: stage,
        destination: partial,
        manifest: manifest,
        recovery: recovery,
      );
      final verified = await verify(partial, recovery);
      try {
        if (verified.contents.digest != digest ||
            verified.contents.manifest.id != id) {
          throw invalidBackup;
        }
      } finally {
        await verified.close();
      }
      await _authorize(session);
      final bytes = await partial.length();
      if (await target.exists()) throw invalidBackup;
      await partial.rename(target.path);
      return BackupArtifact(id, target, digest, bytes);
    } finally {
      manifest?.destroy();
      key.fillRange(0, key.length, 0);
      if (await partial.exists()) await partial.delete();
      await stage.delete(recursive: true);
    }
  });

  Future<VerifiedVaultBackup> verify(
    File archive,
    BackupRecoveryKey recovery,
  ) => storageBoundary(() async {
    final contents = await BackupArchive.extract(
      archive: archive,
      stagingRoot: stagingRoot,
      recovery: recovery,
    );
    var passed = false;
    try {
      final manifest = contents.manifest;
      final file = File(p.join(contents.directory.path, BackupEntry.database));
      final key = VaultDatabaseKey.fromBytes(manifest.databaseKey);
      if (await verifyEncryptedDatabase(file, key) != manifest.schemaVersion) {
        throw invalidBackup;
      }
      final db = AppDatabase.encrypted(file: file, key: key);
      final session = VaultSession(
        db: db,
        identity: manifest.identity,
        keys: VaultKeys.fromRecovery(
          database: manifest.databaseKey,
          documents: manifest.documentKey,
        ),
        directory: contents.directory,
      );
      final VerifiedVaultBackup verified;
      try {
        await db.customStatement('PRAGMA query_only = ON');
        final family = await db.select(db.familySpaces).getSingle();
        if (family.id != manifest.identity.familyId ||
            family.mode != manifest.identity.mode ||
            family.currency != 'INR') {
          throw invalidBackup;
        }
        final entries = await session.documents.backupVersions(db);
        final names = {BackupEntry.database};
        for (final entry in entries) {
          await session.documents.verifiedBackupFile(
            entry.version,
            confirmed: entry.confirmed,
          );
          names.add('documents/${entry.version.id}.fvdoc');
        }
        if (manifest.entries.length != names.length ||
            !manifest.entries.every((entry) => names.contains(entry.name))) {
          throw invalidBackup;
        }
        final docs = await db.select(db.vaultDocuments).get();
        final edits = await (db.select(
          db.pendingMutations,
        )..where((t) => t.state.equals('acknowledged').not())).get();
        final uploads = await (db.select(
          db.vaultDocumentUploads,
        )..where((t) => t.state.equals('acknowledged').not())).get();
        verified = VerifiedVaultBackup._(
          contents,
          documents: docs.length,
          pending: edits.length + uploads.length,
        );
      } finally {
        await session.close();
      }
      passed = true;
      return verified;
    } finally {
      if (!passed) await contents.close();
    }
  });

  Future<void> _authorize(VaultSession session) async {
    const locked = AppFailure(
      FailureCode.locked,
      'Unlock this vault before creating a backup.',
    );
    if (session.closed || session.keys.destroyed) throw locked;
    await session.ledger.mutations.authorize();
    if (session.closed) throw locked;
  }
}
