import 'dart:io';

import 'package:drift/drift.dart';

import 'document_tables.dart';
import 'encrypted_connection.dart';
import 'finance_tables.dart';
import 'ledger_guards.dart';
import 'wealth_tables.dart';
import 'wealth_guards.dart';

export 'finance_tables.dart';
export 'document_tables.dart';
export 'wealth_tables.dart';

part 'app_database.g.dart';

@TableIndex(
  name: 'pending_mutations_retry',
  columns: {#state, #nextAttemptAtUs},
)
@TableIndex.sql('''CREATE UNIQUE INDEX pending_document_change ON pending_mutations(family_id, entity_id)
  WHERE entity_type = 'document_change' AND state = 'pending' ''')
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
    WealthAssets,
    PropertyDetails,
    MetalDetails,
    InvestmentDetails,
    AssetOwnerships,
    AssetValuations,
    DebtContracts,
    DebtRepayments,
    Businesses,
    StockItems,
    StockPositions,
    StockMovements,
    Workers,
    SalaryPayments,
    AggregateJournalLinks,
    VaultDocuments,
    VaultDocumentVersions,
    VaultDocumentLinks,
    VaultDocumentUploads,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase._(this.file, super.executor);

  factory AppDatabase.encrypted({
    required File file,
    required VaultDatabaseKey key,
  }) => AppDatabase._(file, openEncryptedConnection(file: file, key: key));

  final File file;

  @override
  int get schemaVersion => 6;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) => transaction(() async {
      await migrator.createAll();
      await _installLedgerGuards();
      await _installWealthGuards();
      await _installDocumentGuards();
      await customStatement('PRAGMA user_version = $schemaVersion');
    }),
    onUpgrade: (migrator, from, to) async {
      if (from < 1 || from >= schemaVersion || to != schemaVersion) {
        throw StateError('An explicit database migration is required');
      }
      await transaction(() async {
        if (from == 1) {
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
        }
        if (from < 3) {
          for (final table in <TableInfo<Table, dynamic>>[
            wealthAssets,
            propertyDetails,
            metalDetails,
            investmentDetails,
            assetOwnerships,
            assetValuations,
            debtContracts,
            debtRepayments,
            businesses,
            stockItems,
            stockPositions,
            stockMovements,
            workers,
            salaryPayments,
            aggregateJournalLinks,
          ]) {
            await migrator.createTable(table);
          }
        }
        if (from < 4) {
          await migrator.createTable(vaultDocuments);
          await migrator.createTable(vaultDocumentVersions);
          await migrator.createTable(vaultDocumentLinks);
        }
        if (from < 5) {
          await migrator.createTable(vaultDocumentUploads);
          await migrator.createIndex(vaultDocumentUploadRetry);
        }
        await migrator.createIndex(pendingDocumentChange);
        // The connected projection can receive several accepted revisions at
        // once. Replace the two local guards inside this additive migration.
        await customStatement('DROP TRIGGER IF EXISTS vault_document_identity');
        await customStatement(
          'DROP TRIGGER IF EXISTS vault_document_version_sequence',
        );
        await _installLedgerGuards();
        await _installWealthGuards();
        await _installDocumentGuards();
        // Keep the version stamp in the same transaction as its DDL. Drift's
        // subsequent version write is idempotent if the process stops after this.
        await customStatement('PRAGMA user_version = $schemaVersion');
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

  Future<void> _installWealthGuards() async {
    for (final statement in wealthGuards()) {
      await customStatement(statement);
    }
  }

  Future<void> _installDocumentGuards() async {
    for (final statement in documentGuards) {
      await customStatement(statement);
    }
  }
}
