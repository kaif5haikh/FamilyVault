import 'dart:io';
import 'dart:math';

import 'package:familyvault/core/database/app_database.dart';
import 'package:familyvault/core/database/encrypted_connection.dart';
import 'package:familyvault/core/security/vault_identity.dart';
import 'package:familyvault/features/finance/data/ledger_repository.dart';
import 'package:uuid/uuid.dart';

final class VaultFixture {
  VaultFixture._(this.directory, this.keyBytes, this.identity) {
    db = AppDatabase.encrypted(file: file, key: key);
    ledger = LedgerRepository(
      db,
      identity,
      clock: () => DateTime.utc(2026, 11, 13, 12),
    );
  }
  static const uuid = Uuid();
  final Directory directory;
  final List<int> keyBytes;
  final VaultIdentity identity;
  late AppDatabase db;
  late LedgerRepository ledger;
  File get file => File('${directory.path}/test.sqlite3');
  VaultDatabaseKey get key => VaultDatabaseKey.fromBytes(keyBytes);
  static Future<VaultFixture> create({
    bool bootstrap = true,
    VaultIdentity? identity,
  }) async {
    final parent = await Directory('.cache/test-vaults')
        .create(recursive: true);
    final random = Random.secure();
    final fixture = VaultFixture._(
      await parent.createTemp('ledger-'),
      List.generate(32, (_) => random.nextInt(256)),
      identity ??
          VaultIdentity(
            familyId: uuid.v4(),
            memberId: uuid.v4(),
            deviceId: uuid.v4(),
            mode: 'offline',
          ),
    );
    if (bootstrap) {
      await fixture.ledger.createOfflineWorkspace(
        familyName: 'Synthetic test workspace',
        ownerName: 'Test administrator',
      );
    }
    return fixture;
  }

  Future<void> dispose() async {
    await db.close();
    await directory.delete(recursive: true);
  }
}
