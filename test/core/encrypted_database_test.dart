import 'dart:io';
import 'dart:math';

import 'package:drift/drift.dart';
// Only tests inspect the worker wrapper to check the original SQLite error code.
// ignore: experimental_member_use
import 'package:drift/remote.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:familyvault/core/database/app_database.dart';
import 'package:familyvault/core/database/encrypted_connection.dart';
import 'package:familyvault/core/errors/app_failure.dart';

const _family = '00000000-0000-4000-8000-000000000001';
const _operation = '00000000-0000-4000-8000-000000000002';
const _device = '00000000-0000-4000-8000-000000000003';
const _entity = '00000000-0000-4000-8000-000000000004';

VaultDatabaseKey _newKey() {
  final random = Random.secure();
  return VaultDatabaseKey.fromBytes(
    List.generate(32, (_) => random.nextInt(256)),
  );
}

Object _originalCause(Object error) {
  while (error is DriftRemoteException) {
    error = error.remoteCause;
  }
  return error;
}

Matcher _sqliteFailure(int extendedCode) => isA<DriftRemoteException>().having(
  _originalCause,
  'original SQLite failure',
  isA<SqliteException>().having(
    (error) => error.extendedResultCode,
    'extended result code',
    extendedCode,
  ),
);

PendingMutationsCompanion _mutation() => PendingMutationsCompanion.insert(
  operationId: _operation,
  familyId: _family,
  deviceId: _device,
  entityType: 'synthetic_metadata_probe',
  entityId: _entity,
  mutationKind: 'upsert',
  baseRevision: 0,
  payloadJson: '{}',
  payloadDigest: '0' * 64,
  protocolVersion: 1,
  createdAtUs: 0,
);

void main() {
  late Directory scratch;
  late File file;
  late VaultDatabaseKey key;
  late AppDatabase db;

  setUp(() async {
    final base = await Directory('.cache/test-vaults').create(recursive: true);
    scratch = await base.createTemp('encrypted-');
    file = File('${scratch.path}/synthetic.sqlite3');
    key = _newKey();
    db = AppDatabase.encrypted(file: file, key: key);
  });

  tearDown(() async {
    await db.close();
    await scratch.delete(recursive: true);
  });

  test(
    'ciphered file persists, rejects a wrong key, and remains recoverable',
    () async {
      await db
          .into(db.syncCheckpoints)
          .insert(
            SyncCheckpointsCompanion.insert(familyId: _family, updatedAtUs: 0),
          );
      await db.close();
      final header = await file.openRead(0, 16).first;
      expect(String.fromCharCodes(header), isNot('SQLite format 3\u0000'));

      final wrong = AppDatabase.encrypted(file: file, key: _newKey());
      try {
        await expectLater(
          wrong.select(wrong.syncCheckpoints).get(),
          throwsA(
            isA<DriftRemoteException>().having(
              _originalCause,
              'sanitized vault-open failure',
              isA<VaultOpenFailure>().having(
                (error) => error.sqliteResultCode,
                'wrong-key result code',
                26,
              ),
            ),
          ),
        );
      } finally {
        await wrong.close();
      }

      db = AppDatabase.encrypted(file: file, key: key);
      expect(
        (await db.select(db.syncCheckpoints).get()).single.familyId,
        _family,
      );
      expect(
        (await db.customSelect('PRAGMA foreign_keys').getSingle()).read<int>(
          'foreign_keys',
        ),
        1,
      );
    },
  );

  test(
    'snapshot a live WAL vault into a database using a different key',
    () async {
      await db.customStatement('PRAGMA journal_mode = WAL');
      await db.into(db.pendingMutations).insert(_mutation());
      final snapshot = File('${scratch.path}/snapshot.sqlite3');
      final snapshotKey = _newKey();
      await snapshotEncryptedDatabase(
        source: db.file,
        sourceKey: key,
        destination: snapshot,
        destinationKey: snapshotKey,
      );
      final saved = AppDatabase.encrypted(file: snapshot, key: snapshotKey);
      try {
        expect(
          (await saved.select(saved.pendingMutations).getSingle()).operationId,
          _operation,
        );
        expect(
          await saved.customSelect('PRAGMA foreign_key_check').get(),
          isEmpty,
        );
      } finally {
        await saved.close();
      }
      expect(
        (await db.select(db.pendingMutations).getSingle()).operationId,
        _operation,
      );
      final wrong = AppDatabase.encrypted(file: snapshot, key: key);
      try {
        await expectLater(
          wrong.select(wrong.pendingMutations).get(),
          throwsA(
            isA<DriftRemoteException>().having(
              _originalCause,
              'ciphered snapshot',
              isA<VaultOpenFailure>(),
            ),
          ),
        );
      } finally {
        await wrong.close();
      }
      final header = await snapshot.openRead(0, 16).first;
      expect(String.fromCharCodes(header), isNot('SQLite format 3\u0000'));
    },
  );

  test('snapshot failure preserves an existing destination and cleans its own partial', () async {
    await db.into(db.pendingMutations).insert(_mutation());
    final existing = File('${scratch.path}/prior-copy.sqlite3');
    await existing.writeAsString('Synthetic existing file');
    await expectLater(
      snapshotEncryptedDatabase(
        source: db.file,
        sourceKey: key,
        destination: existing,
        destinationKey: _newKey(),
      ),
      throwsA(isA<AppFailure>()),
    );
    expect(await existing.readAsString(), 'Synthetic existing file');
    final partial = File('${scratch.path}/partial.sqlite3');
    await expectLater(
      snapshotEncryptedDatabase(
        source: db.file,
        sourceKey: _newKey(),
        destination: partial,
        destinationKey: _newKey(),
      ),
      throwsA(isA<AppFailure>()),
    );
    expect(await partial.exists(), isFalse);
    expect((await db.select(db.pendingMutations).getSingle()).state, 'pending');
  });

  test(
    'duplicate operations and unconfirmed acknowledgements are rejected',
    () async {
      await db.into(db.pendingMutations).insert(_mutation());
      await expectLater(
        db.into(db.pendingMutations).insert(_mutation()),
        throwsA(_sqliteFailure(1555)),
      );
      await expectLater(
        db
            .update(db.pendingMutations)
            .write(
              const PendingMutationsCompanion(state: Value('acknowledged')),
            ),
        throwsA(_sqliteFailure(275)),
      );
      expect(
        (await db.select(db.pendingMutations).get()).single.state,
        'pending',
      );
    },
  );

  test(
    'outbox transaction rollback and conflict foreign keys preserve integrity',
    () async {
      await expectLater(
        db.transaction(() async {
          await db.into(db.pendingMutations).insert(_mutation());
          throw StateError('Synthetic interrupted transaction');
        }),
        throwsStateError,
      );
      expect(await db.select(db.pendingMutations).get(), isEmpty);
      await expectLater(
        db
            .into(db.syncConflicts)
            .insert(
              SyncConflictsCompanion.insert(
                id: _entity,
                operationId: _operation,
                serverRevision: 1,
                serverSnapshotJson: '{}',
                detectedAtUs: 0,
              ),
            ),
        throwsA(_sqliteFailure(787)),
      );
    },
  );

  test('unknown future schema fails without destructive fallback', () async {
    await db
        .into(db.syncCheckpoints)
        .insert(
          SyncCheckpointsCompanion.insert(familyId: _family, updatedAtUs: 0),
        );
    await db.customStatement('PRAGMA user_version = 99');
    await db.close();
    final before = await file.readAsBytes();
    final future = AppDatabase.encrypted(file: file, key: key);
    try {
      await expectLater(
        future.select(future.syncCheckpoints).get(),
        throwsA(
          isA<DriftRemoteException>().having(
            _originalCause,
            'original migration failure',
            isA<StateError>(),
          ),
        ),
      );
    } finally {
      await future.close();
    }
    expect(await file.readAsBytes(), before);
  });

  test('key validation rejects invalid input and redacts string rendering', () {
    expect(() => VaultDatabaseKey.fromBytes([1, 2]), throwsArgumentError);
    expect(
      () => VaultDatabaseKey.fromBytes(List.filled(32, 256)),
      throwsArgumentError,
    );
    expect(key.toString(), 'VaultDatabaseKey([redacted])');
  });
}
