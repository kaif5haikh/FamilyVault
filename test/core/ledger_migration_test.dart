import 'dart:io';

import 'package:familyvault/core/database/app_database.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import '../support/vault_fixture.dart';

void main() {
  test('encrypted v1 to v3 migration preserves existing operations and checkpoints', () async {
    final f = await VaultFixture.create(bootstrap: false);
    await f.db.close();
    final raw = sqlite3.open(f.file.path);
    final hex = f.keyBytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    try {
      raw.execute("PRAGMA key = '$hex'");
      raw.execute(await File('docs/design/sqlite.sql').readAsString());
      raw.execute(
        "INSERT INTO sync_checkpoints VALUES ('synthetic-family', 7, 2, 0)",
      );
      raw.execute(
        "INSERT INTO pending_mutations(operation_id, family_id, device_id, entity_type, entity_id, mutation_kind, base_revision, payload_json, payload_digest, protocol_version, created_at_us) VALUES ('synthetic-op', 'synthetic-family', 'synthetic-device', 'synthetic', 'synthetic-id', 'upsert', 0, '{}', ?, 1, 0)",
        ['0' * 64],
      );
    } finally {
      raw.close();
    }
    f.db = AppDatabase.encrypted(file: f.file, key: f.key);
    try {
      final checkpoint = (await f.db.select(f.db.syncCheckpoints).get()).single;
      expect(checkpoint.lastSequence, 7);
      expect(checkpoint.authorizationEpoch, 2);
      expect(
        (await f.db.select(f.db.pendingMutations).get()).single.operationId,
        'synthetic-op',
      );
      expect(await f.db.select(f.db.ledgerAccounts).get(), isEmpty);
      expect(
        (await f.db.customSelect('PRAGMA user_version').getSingle()).read<int>(
          'user_version',
        ),
        3,
      );
      expect(
        await f.db.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
      final triggers = await f.db
          .customSelect("SELECT name FROM sqlite_schema WHERE type = 'trigger'")
          .get();
      expect(
        triggers.map((r) => r.read<String>('name')),
        containsAll([
          'ledger_seal',
          'posted_posting_no_update',
          'local_audit_no_delete',
        ]),
      );
    } finally {
      await f.dispose();
    }
  });
}
