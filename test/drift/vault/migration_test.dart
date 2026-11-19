import 'package:drift/drift.dart';
import 'package:drift_dev/api/migrations_native.dart';
import 'package:familyvault/core/database/app_database.dart';
import 'package:familyvault/core/database/encrypted_connection.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/vault_fixture.dart';
import 'generated/schema.dart';
import 'generated/schema_v1.dart' as v1;
import 'generated/schema_v2.dart' as v2;
import 'generated/schema_v3.dart' as v3;
import 'generated/schema_v4.dart' as v4;
import 'generated/schema_v5.dart' as v5;

import 'package:familyvault/core/database/ledger_guards.dart';

// Adapted from drift_dev's generated template: retain the encrypted production
// constructor, and put real synthetic rows into the immutable v1 snapshot.
void main() {
  final verifier = SchemaVerifier(GeneratedHelper());
  test('fresh encrypted database matches the versioned schema', () async {
    final f = await VaultFixture.create(bootstrap: false);
    try {
      await verifier.migrateAndValidate(f.db, 6);
    } finally {
      await f.dispose();
    }
  });
  test('generated v1 snapshot migrates to v6 with operations, conflicts and checkpoints intact', () async {
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
      await verifier.migrateAndValidate(f.db, 6);
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
  test('populated encrypted v2 ledger migrates to v6 with posted facts and audit intact', () async {
    final f = await VaultFixture.create(bootstrap: false);
    await f.db.close();
    final old = v2.DatabaseAtV2(
      openEncryptedConnection(file: f.file, key: f.key),
    );
    final i = f.identity;
    const cash = '00000000-0000-4000-8000-000000000011',
        equity = '00000000-0000-4000-8000-000000000012';
    const journal = '00000000-0000-4000-8000-000000000013';
    try {
      await old.customSelect('SELECT 1').get();
      for (final guard in ledgerGuards) {
        await old.customStatement(guard);
      }
      await old.customStatement(
        'INSERT INTO family_spaces(id, name, mode, created_at_us) VALUES (?, ?, ?, ?)',
        [i.familyId, 'Synthetic v2 workspace', 'offline', 0],
      );
      await old.customStatement(
        'INSERT INTO family_members(id, family_id, display_name, relationship, role, created_at_us) VALUES (?, ?, ?, ?, ?, ?)',
        [
          i.memberId,
          i.familyId,
          'Synthetic prior owner',
          'administrator',
          'administrator',
          0,
        ],
      );
      await old.customStatement(
        'INSERT INTO vault_devices(id, family_id, member_id, state, created_at_us) VALUES (?, ?, ?, ?, ?)',
        [i.deviceId, i.familyId, i.memberId, 'enrolled', 0],
      );
      for (final entry in [
        (cash, 'asset', 'cash'),
        (equity, 'equity', 'opening'),
      ]) {
        await old.customStatement(
          'INSERT INTO ledger_accounts(id, family_id, created_by, updated_by, created_at_us, updated_at_us, name, kind, subtype) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
          [
            entry.$1,
            i.familyId,
            i.memberId,
            i.memberId,
            0,
            0,
            'Synthetic v2 account',
            entry.$2,
            entry.$3,
          ],
        );
      }
      await old.customStatement(
        'INSERT INTO ledger_journals(id, family_id, created_by, updated_by, created_at_us, updated_at_us, kind, occurred_on, description) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          journal,
          i.familyId,
          i.memberId,
          i.memberId,
          0,
          0,
          'opening',
          '2026-11-01',
          'Synthetic v2 opening',
        ],
      );
      for (final p in [
        ('synthetic-posting-one', cash, 0, 12345),
        ('synthetic-posting-two', equity, 1, -12345),
      ]) {
        await old.customStatement(
          'INSERT INTO ledger_postings(id, family_id, journal_id, account_id, position, amount_minor) VALUES (?, ?, ?, ?, ?, ?)',
          [p.$1, i.familyId, journal, p.$2, p.$3, p.$4],
        );
      }
      await old.customStatement(
        "UPDATE ledger_journals SET status = 'posted' WHERE id = ?",
        [journal],
      );
      await old.customStatement(
        'INSERT INTO local_audit_events(id, family_id, actor_id, device_id, operation_id, entity_type, entity_id, action, created_at_us) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
        [
          'synthetic-audit',
          i.familyId,
          i.memberId,
          i.deviceId,
          'synthetic-op',
          'journal',
          journal,
          'post',
          0,
        ],
      );
      await old
          .into(old.pendingMutations)
          .insert(
            v2.PendingMutationsCompanion.insert(
              operationId: 'synthetic-op',
              familyId: i.familyId,
              deviceId: i.deviceId,
              entityType: 'journal',
              entityId: journal,
              mutationKind: 'upsert',
              baseRevision: 0,
              payloadJson: '{"synthetic":true}',
              payloadDigest: '0' * 64,
              protocolVersion: 1,
              createdAtUs: 0,
            ),
          );
    } finally {
      await old.close();
    }
    f.db = AppDatabase.encrypted(file: f.file, key: f.key);
    try {
      await verifier.migrateAndValidate(f.db, 6);
      expect(
        (await f.db.select(f.db.ledgerJournals).get()).single.status,
        'posted',
      );
      expect(
        (await f.db.select(f.db.ledgerPostings).get()).map(
          (p) => p.amountMinor,
        ),
        [12345, -12345],
      );
      expect(
        (await f.db.select(f.db.localAuditEvents).get()).single.actorId,
        i.memberId,
      );
      expect(
        (await f.db.select(f.db.pendingMutations).get()).single.payloadJson,
        '{"synthetic":true}',
      );
      expect(await f.db.select(f.db.wealthAssets).get(), isEmpty);
      expect(await f.db.select(f.db.stockPositions).get(), isEmpty);
      expect(
        await f.db.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
      await expectLater(
        f.db.customStatement(
          'UPDATE ledger_postings SET amount_minor = 1 WHERE journal_id = ?',
          [journal],
        ),
        throwsA(anything),
      );
    } finally {
      await f.dispose();
    }
  });
  test(
    'encrypted v3 wealth records are kept during the v6 document migration',
    () async {
      final f = await VaultFixture.create(bootstrap: false);
      await f.db.close();
      final old = v3.DatabaseAtV3(
        openEncryptedConnection(file: f.file, key: f.key),
      );
      final identity = f.identity;
      try {
        await old.customStatement(
          "INSERT INTO family_spaces(id,name,mode,created_at_us) VALUES (?, 'Synthetic v3 vault', 'offline', 1)",
          [identity.familyId],
        );
        await old.customStatement(
          "INSERT INTO family_members(id,family_id,display_name,relationship,role,created_at_us) VALUES (?, ?, 'Synthetic owner', 'administrator', 'administrator', 1)",
          [identity.memberId, identity.familyId],
        );
        await old.customStatement(
          "INSERT INTO ledger_accounts(id,family_id,created_by,updated_by,created_at_us,updated_at_us,name,kind,subtype) VALUES ('asset-account', ?, ?, ?, 1, 1, 'Synthetic asset', 'asset', 'managed_asset')",
          [identity.familyId, identity.memberId, identity.memberId],
        );
        await old.customStatement(
          "INSERT INTO wealth_assets(id,family_id,created_by,updated_by,created_at_us,updated_at_us,name,kind,account_id,family_ownership_bps,purchase_total_minor,purchase_ownership_bps) VALUES ('prior-asset', ?, ?, ?, 1, 1, 'Synthetic holding', 'other', 'asset-account', 10000, 9007199254740993, 10000)",
          [identity.familyId, identity.memberId, identity.memberId],
        );
      } finally {
        await old.close();
      }
      f.db = AppDatabase.encrypted(file: f.file, key: f.key);
      try {
        await verifier.migrateAndValidate(f.db, 6);
        expect(
          (await f.db.select(f.db.wealthAssets).getSingle()).purchaseTotalMinor,
          9007199254740993,
        );
        expect(await f.db.select(f.db.vaultDocuments).get(), isEmpty);
        expect(
          await f.db.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
      } finally {
        await f.dispose();
      }
    },
  );

  for (final previous in [4, 5]) {
    test(
      'v$previous document provenance and version data survive the v6 document migration',
      () async {
        final f = await VaultFixture.create(bootstrap: false);
        await f.db.close();
        final executor = openEncryptedConnection(file: f.file, key: f.key);
        final GeneratedDatabase old = previous == 4
            ? v4.DatabaseAtV4(executor)
            : v5.DatabaseAtV5(executor);
        final identity = f.identity;
        try {
          await old.customStatement(
            "INSERT INTO family_spaces(id,name,mode,created_at_us) VALUES (?, 'Synthetic prior vault', ?, 1)",
            [identity.familyId, previous == 4 ? 'offline' : 'cloud'],
          );
          await old.customStatement(
            "INSERT INTO family_members(id,family_id,display_name,relationship,role,created_at_us) VALUES (?, ?, 'Synthetic owner', 'administrator', 'administrator', 1)",
            [identity.memberId, identity.familyId],
          );
          await old.customStatement(
            "INSERT INTO vault_devices(id,family_id,member_id,state,created_at_us) VALUES (?, ?, ?, 'enrolled', 1)",
            [identity.deviceId, identity.familyId, identity.memberId],
          );
          await old.customStatement(
            "INSERT INTO vault_documents(id,family_id,owner_id,created_by,updated_by,created_at_us,updated_at_us,title,category) VALUES ('synthetic-doc', ?, ?, ?, ?, 1, 1, 'Synthetic prior document', 'general')",
            [
              identity.familyId,
              identity.memberId,
              identity.memberId,
              identity.memberId,
            ],
          );
          await old.customStatement(
            "INSERT INTO vault_document_versions(id,family_id,document_id,version,mime_type,plaintext_bytes,ciphertext_digest,wrapped_key,created_by,device_id,created_at_us) VALUES ('synthetic-version', ?, 'synthetic-doc', 1, 'application/pdf', 20, ?, zeroblob(72), ?, ?, 1)",
            [identity.familyId, '4' * 64, identity.memberId, identity.deviceId],
          );
          if (previous == 5) {
            await old.customStatement(
              "INSERT INTO vault_document_uploads(id,operation_id,family_id,document_id,owner_id,member_id,device_id,base_revision,version,title,metadata_box,mime_type,plaintext_bytes,ciphertext_digest,wrapped_key,created_at_us) VALUES ('staged-version','staged-operation',?,'synthetic-doc',?,?,?,1,2,'Synthetic pending file',?,'application/pdf',40,?,zeroblob(72),2)",
              [
                identity.familyId,
                identity.memberId,
                identity.memberId,
                identity.deviceId,
                'A' * 60,
                '6' * 64,
              ],
            );
            await old.customStatement(
              '''CREATE TRIGGER vault_document_identity BEFORE UPDATE ON vault_documents
            WHEN NEW.revision <> OLD.revision + 1 BEGIN SELECT RAISE(ABORT, 'Prior document revision guard'); END''',
            );
            await expectLater(
              old.customStatement('UPDATE vault_documents SET revision = 3'),
              throwsA(anything),
            );
          }
        } finally {
          await old.close();
        }
        f.db = AppDatabase.encrypted(file: f.file, key: f.key);
        try {
          await verifier.migrateAndValidate(f.db, 6);
          expect(
            (await f.db.select(f.db.vaultDocuments).getSingle()).ownerId,
            identity.memberId,
          );
          final version = await f.db
              .select(f.db.vaultDocumentVersions)
              .getSingle();
          expect(version.id, 'synthetic-version');
          expect(version.ciphertextDigest, '4' * 64);
          final uploads = await f.db.select(f.db.vaultDocumentUploads).get();
          if (previous == 5) {
            expect(uploads.single.operationId, 'staged-operation');
            await f.db.customStatement(
              'UPDATE vault_documents SET revision = 3',
            );
            expect(
              (await f.db.select(f.db.vaultDocuments).getSingle()).revision,
              3,
            );
          } else {
            expect(uploads, isEmpty);
            await expectLater(
              f.db.customStatement('UPDATE vault_documents SET revision = 3'),
              throwsA(anything),
            );
          }
          expect(
            await f.db.customSelect('PRAGMA foreign_key_check').get(),
            isEmpty,
          );
          await expectLater(
            f.db.delete(f.db.vaultDocumentVersions).go(),
            throwsA(anything),
          );
        } finally {
          await f.dispose();
        }
      },
    );
  }

  test('failed v3 DDL rolls back all additions and retains the v2 version and user table', () async {
    final f = await VaultFixture.create(bootstrap: false);
    await f.db.close();
    final old = v2.DatabaseAtV2(
      openEncryptedConnection(file: f.file, key: f.key),
    );
    try {
      await old
          .into(old.syncCheckpoints)
          .insert(
            v2.SyncCheckpointsCompanion.insert(
              familyId: 'synthetic-preserved',
              lastSequence: const Value(42),
              updatedAtUs: 0,
            ),
          );
      // An unexpected existing table causes failure midway through the additions.
      // The application must preserve it rather than reset/overwrite the database.
      await old.customStatement(
        'CREATE TABLE asset_ownerships(sentinel TEXT NOT NULL)',
      );
      await old.customStatement('INSERT INTO asset_ownerships VALUES (?)', [
        'synthetic-user-table-preserved',
      ]);
    } finally {
      await old.close();
    }
    f.db = AppDatabase.encrypted(file: f.file, key: f.key);
    await expectLater(f.db.select(f.db.wealthAssets).get(), throwsA(anything));
    await f.db.close();
    final retained = v2.DatabaseAtV2(
      openEncryptedConnection(file: f.file, key: f.key),
    );
    try {
      expect(
        (await retained.select(retained.syncCheckpoints).get())
            .single
            .lastSequence,
        42,
      );
      expect(
        (await retained.customSelect('PRAGMA user_version').getSingle())
            .read<int>('user_version'),
        2,
      );
      expect(
        (await retained
                .customSelect('SELECT sentinel FROM asset_ownerships')
                .getSingle())
            .read<String>('sentinel'),
        'synthetic-user-table-preserved',
      );
      expect(
        await retained
            .customSelect(
              "SELECT name FROM sqlite_schema WHERE name IN ('wealth_assets', 'property_details', 'metal_details')",
            )
            .get(),
        isEmpty,
      );
    } finally {
      await retained.close();
      await f.dispose();
    }
  });
}
