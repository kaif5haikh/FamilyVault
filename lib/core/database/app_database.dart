import 'dart:io';

import 'package:drift/drift.dart';

import 'encrypted_connection.dart';
import 'finance_tables.dart';
import 'ledger_guards.dart';

export 'finance_tables.dart';

part 'app_database.g.dart';

@TableIndex(
  name: 'pending_mutations_retry',
  columns: {#state, #nextAttemptAtUs},
)
class PendingMutations extends Table {
  TextColumn get operationId => text()();
  TextColumn get familyId => text()();
  TextColumn get deviceId => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get mutationKind => text()();
  IntColumn get baseRevision => integer()();
  TextColumn get payloadJson => text()();
  TextColumn get payloadDigest => text()();
  IntColumn get protocolVersion => integer()();
  TextColumn get state => text().withDefault(const Constant('pending'))();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  IntColumn get createdAtUs => integer()();
  IntColumn get nextAttemptAtUs => integer().nullable()();
  IntColumn get leaseExpiresAtUs => integer().nullable()();
  IntColumn get acceptedRevision => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {operationId};

  @override
  List<String> get customConstraints => [
    "CHECK (mutation_kind IN ('upsert', 'delete'))",
    'CHECK (base_revision >= 0)',
    'CHECK (json_valid(payload_json))',
    'CHECK (length(payload_digest) = 64)',
    'CHECK (protocol_version > 0)',
    "CHECK (state IN ('pending', 'in_flight', 'conflicted', 'rejected', 'acknowledged'))",
    'CHECK (attempts >= 0)',
    'CHECK (accepted_revision IS NULL OR accepted_revision > 0)',
    "CHECK (state <> 'acknowledged' OR accepted_revision IS NOT NULL)",
  ];
}

class SyncCheckpoints extends Table {
  TextColumn get familyId => text()();
  IntColumn get lastSequence => integer().withDefault(const Constant(0))();
  IntColumn get authorizationEpoch =>
      integer().withDefault(const Constant(0))();
  IntColumn get updatedAtUs => integer()();

  @override
  Set<Column<Object>> get primaryKey => {familyId};

  @override
  List<String> get customConstraints => [
    'CHECK (last_sequence >= 0)',
    'CHECK (authorization_epoch >= 0)',
  ];
}

class SyncConflicts extends Table {
  TextColumn get id => text()();
  TextColumn get operationId =>
      text().unique().references(PendingMutations, #operationId)();
  IntColumn get serverRevision => integer()();
  TextColumn get serverSnapshotJson => text()();
  IntColumn get detectedAtUs => integer()();
  IntColumn get resolvedAtUs => integer().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<String> get customConstraints => [
    'CHECK (server_revision > 0)',
    'CHECK (json_valid(server_snapshot_json))',
  ];
}

@DriftDatabase(
  tables: [
    PendingMutations,
    SyncCheckpoints,
    SyncConflicts,
    FamilySpaces,
    FamilyMembers,
    VaultDevices,
    LedgerAccounts,
    LedgerJournals,
    LedgerPostings,
    LocalAuditEvents,
    MonthlyBudgets,
    ReconciliationChecks,
    VaultPreferences,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase._(super.executor);

  factory AppDatabase.encrypted({
    required File file,
    required VaultDatabaseKey key,
  }) => AppDatabase._(openEncryptedConnection(file: file, key: key));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
      await _installLedgerGuards();
    },
    onUpgrade: (migrator, from, to) async {
      if (from != 1 || to != 2) {
        throw StateError('An explicit database migration is required');
      }
      await transaction(() async {
        for (final table in <TableInfo<Table, dynamic>>[
          familySpaces,
          familyMembers,
          vaultDevices,
          ledgerAccounts,
          ledgerJournals,
          ledgerPostings,
          localAuditEvents,
          monthlyBudgets,
          reconciliationChecks,
          vaultPreferences,
        ]) {
          await migrator.createTable(table);
        }
        await _installLedgerGuards();
      });
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON;');
    },
  );

  Future<void> _installLedgerGuards() async {
    for (final statement in ledgerGuards) {
      await customStatement(statement);
    }
  }
}
