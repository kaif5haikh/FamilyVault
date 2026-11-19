import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../core/database/encrypted_connection.dart';
import '../../core/security/sealed_file.dart';
import '../../core/security/vault_identity.dart';
import '../../core/security/vault_keys.dart';
import '../../core/security/vault_lifecycle.dart';
import '../document_vault/document_repository.dart';
import 'backup_archive.dart';
import 'vault_backup.dart';

final class PreparedVaultRestore {
  const PreparedVaultRestore(this.identity, this.keys, this.directory);
  final VaultIdentity identity;
  final VaultKeys keys;
  final Directory directory;

  static Directory stage(Directory support, VaultIdentity identity) =>
      Directory(p.join(support.path, 'restore-stage', identity.deviceId));

  static Future<PreparedVaultRestore> prepare(
    VerifiedVaultBackup verified,
    Directory support,
  ) async {
    final manifest = verified.contents.manifest;
    final identity = VaultIdentity(
      familyId: manifest.identity.familyId,
      memberId: manifest.identity.memberId,
      deviceId: const Uuid().v4(),
      mode: 'offline',
      sharedChart: manifest.identity.usesSharedChart,
    );
    final directory = stage(support, identity);
    if (await directory.exists()) throw invalidBackup;
    await directory.create(recursive: true);
    final keys = VaultKeys.generate();
    keys.documents.setAll(0, manifest.documentKey);
    var complete = false;
    try {
      final source = verified.contents.directory;
      final database = File(p.join(directory.path, BackupEntry.database));
      final databaseKey = VaultDatabaseKey.fromBytes(keys.database);
      await snapshotEncryptedDatabase(
        source: File(p.join(source.path, BackupEntry.database)),
        sourceKey: VaultDatabaseKey.fromBytes(manifest.databaseKey),
        destination: database,
        destinationKey: databaseKey,
      );
      for (final entry in manifest.entries.skip(1)) {
        final file = File(p.join(directory.path, entry.name));
        await file.parent.create(recursive: true);
        await File(p.join(source.path, entry.name)).copy(file.path);
        if (await file.length() != entry.bytes ||
            await SealedFile.digest(file) != entry.digest) {
          throw invalidBackup;
        }
      }
      final db = AppDatabase.encrypted(file: database, key: databaseKey);
      final session = VaultSession(
        db: db,
        identity: identity,
        keys: keys.copy(),
        directory: directory,
      );
      try {
        await db.transaction(() async {
          final family = await db.select(db.familySpaces).getSingle();
          if (family.id != identity.familyId ||
              family.mode != manifest.identity.mode) {
            throw invalidBackup;
          }
          if (family.mode != identity.mode) {
            await (db.update(db.familySpaces)
                  ..where((t) => t.id.equals(family.id)))
                .write(FamilySpacesCompanion(mode: Value(identity.mode)));
          }
          await db
              .into(db.vaultDevices)
              .insert(
                VaultDevicesCompanion.insert(
                  id: identity.deviceId,
                  familyId: identity.familyId,
                  memberId: identity.memberId,
                  state: 'enrolled',
                  createdAtUs: session.ledger.mutations.now,
                ),
              );
          await session.ledger.mutations.authorize();
          await session.ledger.mutations.audit(
            operationId: const Uuid().v4(),
            entityType: 'backup',
            entityId: manifest.id,
            action: 'restore',
            after: {'pending_records': verified.pending},
          );
        });
        for (final entry in await session.documents.backupVersions(db)) {
          await session.documents.verifiedBackupFile(
            entry.version,
            confirmed: entry.confirmed,
          );
        }
      } finally {
        await session.close();
      }
      await verifyEncryptedDatabase(database, databaseKey);
      complete = true;
      return PreparedVaultRestore(identity, keys, directory);
    } finally {
      if (!complete) {
        keys.destroy();
        await directory.delete(recursive: true);
      }
    }
  }
}
