import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:familyvault/core/database/app_database.dart';
import 'package:familyvault/core/database/encrypted_connection.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/vault_fixture.dart';
import 'generated/schema.dart';
import 'generated/schema_v1.dart' as v1;

// Adapted from drift_dev's generated template: retain the encrypted production
// constructor, and put real synthetic rows into the immutable v1 snapshot.
void main() {
  final verifier = SchemaVerifier(GeneratedHelper());
  test('fresh encrypted database matches the versioned schema', () async {
    final f = await VaultFixture.create(bootstrap: false);
    try {
      await verifier.migrateAndValidate(f.db, 2);
    } finally {
      await f.dispose();
    }
  });
  test('generated v1 snapshot migrates to v2 with operations, conflicts and checkpoints intact', () async {
    final f = await VaultFixture.create(bootstrap: false);
    await f.db.close();
    final old = v1.DatabaseAtV1(
      openEncryptedConnection(file: f.file, key: f.key),
    );
    try {
      await old
          .into(old.pendingMutations)
          .insert(
            v1.PendingMutationsCompanion.insert(
              operationId: 'synthetic-operation',
              familyId: 'synthetic-family',
              deviceId: 'synthetic-device',
              entityType: 'synthetic',
              entityId: 'synthetic-entity',
              mutationKind: 'upsert',
              baseRevision: 3,
              payloadJson: '{"synthetic":true}',
              payloadDigest: '0' * 64,
              protocolVersion: 1,
              state: const Value('conflicted'),
              createdAtUs: 123,
            ),
          );
      await old
          .into(old.syncConflicts)
          .insert(
            v1.SyncConflictsCompanion.insert(
              id: 'synthetic-conflict',
              operationId: 'synthetic-operation',
              serverRevision: 4,
              serverSnapshotJson: '{}',
              detectedAtUs: 124,
            ),
          );
      await old
          .into(old.syncCheckpoints)
          .insert(
            v1.SyncCheckpointsCompanion.insert(
              familyId: 'synthetic-family',
              lastSequence: const Value(77),
              updatedAtUs: 125,
            ),
          );
    } finally {
      await old.close();
    }
    f.db = AppDatabase.encrypted(file: f.file, key: f.key);
    try {
      await verifier.migrateAndValidate(f.db, 2);
      final pending = (await f.db.select(f.db.pendingMutations).get()).single;
      expect(pending.state, 'conflicted');
      expect(pending.baseRevision, 3);
      expect(pending.payloadJson, '{"synthetic":true}');
      expect(
        (await f.db.select(f.db.syncConflicts).get()).single.serverRevision,
        4,
      );
      expect(
        (await f.db.select(f.db.syncCheckpoints).get()).single.lastSequence,
        77,
      );
    } finally {
      await f.dispose();
    }
  });
}
