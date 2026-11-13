import 'package:drift/drift.dart';

class FamilySpaces extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  TextColumn get mode => text()();
  TextColumn get currency => text().withDefault(const Constant('INR'))();
  IntColumn get createdAtUs => integer()();
  @override
  Set<Column<Object>> get primaryKey => {id};
  @override
  bool get isStrict => true;
  @override
  List<String> get customConstraints => [
    "CHECK (mode IN ('offline', 'cloud'))",
    "CHECK (currency = 'INR')",
  ];
}

class FamilyMembers extends Table {
  TextColumn get id => text()();
  TextColumn get familyId => text().references(FamilySpaces, #id)();
  TextColumn get authUserId => text().nullable()();
  TextColumn get displayName => text()();
  TextColumn get relationship => text()();
  TextColumn get role => text()();
  BoolColumn get active => boolean().withDefault(const Constant(true))();
  IntColumn get revision => integer().withDefault(const Constant(1))();
  IntColumn get createdAtUs => integer()();
  @override
  Set<Column<Object>> get primaryKey => {id};
  @override
  bool get isStrict => true;
  @override
  List<String> get customConstraints => [
    'UNIQUE (family_id, id)',
    "CHECK (role IN ('administrator', 'member'))",
    'CHECK (revision > 0)',
  ];
}

class VaultDevices extends Table {
  TextColumn get id => text()();
  TextColumn get familyId => text()();
  TextColumn get memberId => text()();
  TextColumn get state => text()();
  IntColumn get createdAtUs => integer()();
  @override
  Set<Column<Object>> get primaryKey => {id};
  @override
  bool get isStrict => true;
  @override
  List<String> get customConstraints => [
    'UNIQUE (family_id, id, member_id)',
    'FOREIGN KEY (family_id, member_id) REFERENCES family_members(family_id, id)',
    "CHECK (state IN ('enrolled', 'revoked', 'pending'))",
  ];
}

mixin FamilyProvenance on Table {
  TextColumn get id => text()();
  TextColumn get familyId => text().references(FamilySpaces, #id)();
  IntColumn get revision => integer().withDefault(const Constant(1))();
  TextColumn get createdBy => text()();
  TextColumn get updatedBy => text()();
  IntColumn get createdAtUs => integer()();
  IntColumn get updatedAtUs => integer()();
  IntColumn get deletedAtUs => integer().nullable()();
  @override
  Set<Column<Object>> get primaryKey => {id};
  @override
  bool get isStrict => true;
}

@DataClassName('LedgerAccount')
class LedgerAccounts extends Table with FamilyProvenance {
  TextColumn get name => text()();
  TextColumn get kind => text()();
  TextColumn get subtype => text()();
  TextColumn get currency => text().withDefault(const Constant('INR'))();
  BoolColumn get systemAccount =>
      boolean().withDefault(const Constant(false))();
  @override
  List<String> get customConstraints => [
    'UNIQUE (family_id, id)',
    'CHECK (revision > 0)',
    'CHECK (updated_at_us >= created_at_us)',
    'CHECK (deleted_at_us IS NULL OR deleted_at_us >= created_at_us)',
    'FOREIGN KEY (family_id, created_by) REFERENCES family_members(family_id, id)',
    'FOREIGN KEY (family_id, updated_by) REFERENCES family_members(family_id, id)',
    "CHECK (kind IN ('asset', 'liability', 'equity', 'income', 'expense'))",
    "CHECK (currency = 'INR')",
  ];
}

@DataClassName('LedgerJournal')
class LedgerJournals extends Table with FamilyProvenance {
  TextColumn get kind => text()();
  TextColumn get occurredOn => text()();
  TextColumn get description => text()();
  TextColumn get currency => text().withDefault(const Constant('INR'))();
  TextColumn get status => text().withDefault(const Constant('draft'))();
  TextColumn get reversesId => text().nullable()();
  TextColumn get businessId => text().nullable()();
  TextColumn get relatedEntityId => text().nullable()();
  @override
  List<String> get customConstraints => [
    'UNIQUE (family_id, id)',
    'CHECK (revision > 0)',
    'CHECK (updated_at_us >= created_at_us)',
    'CHECK (deleted_at_us IS NULL OR deleted_at_us >= created_at_us)',
    'FOREIGN KEY (family_id, created_by) REFERENCES family_members(family_id, id)',
    'FOREIGN KEY (family_id, updated_by) REFERENCES family_members(family_id, id)',
    "CHECK (kind IN ('income', 'expense', 'transfer', 'opening', 'adjustment', 'reversal', 'repayment', 'business'))",
    "CHECK (currency = 'INR')",
    "CHECK (status IN ('draft', 'posted'))",
    "CHECK (date(occurred_on) IS NOT NULL AND date(occurred_on) = occurred_on AND length(occurred_on) = 10)",
    'FOREIGN KEY (family_id, reverses_id) REFERENCES ledger_journals(family_id, id)',
    'UNIQUE (reverses_id)',
  ];
}

@DataClassName('LedgerPosting')
class LedgerPostings extends Table {
  TextColumn get id => text()();
  TextColumn get familyId => text()();
  TextColumn get journalId => text()();
  TextColumn get accountId => text()();
  IntColumn get position => integer()();
  IntColumn get amountMinor => integer()();
  @override
  Set<Column<Object>> get primaryKey => {id};
  @override
  bool get isStrict => true;
  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (family_id, journal_id) REFERENCES ledger_journals(family_id, id)',
    'FOREIGN KEY (family_id, account_id) REFERENCES ledger_accounts(family_id, id)',
    'UNIQUE (journal_id, position)',
    'CHECK (amount_minor <> 0)',
    'CHECK (position >= 0)',
  ];
}

class LocalAuditEvents extends Table {
  TextColumn get id => text()();
  TextColumn get familyId => text()();
  TextColumn get actorId => text()();
  TextColumn get deviceId => text()();
  TextColumn get operationId => text()();
  TextColumn get entityType => text()();
  TextColumn get entityId => text()();
  TextColumn get action => text()();
  TextColumn get beforeJson => text().nullable()();
  TextColumn get afterJson => text().nullable()();
  IntColumn get createdAtUs => integer()();
  @override
  Set<Column<Object>> get primaryKey => {id};
  @override
  bool get isStrict => true;
  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (family_id, device_id, actor_id) REFERENCES vault_devices(family_id, id, member_id)',
    'UNIQUE (family_id, operation_id, entity_type, entity_id)',
    'CHECK (before_json IS NULL OR json_valid(before_json))',
    'CHECK (after_json IS NULL OR json_valid(after_json))',
  ];
}

class MonthlyBudgets extends Table with FamilyProvenance {
  TextColumn get accountId => text()();
  TextColumn get month => text()();
  IntColumn get amountMinor => integer()();
  @override
  List<String> get customConstraints => [
    'UNIQUE (family_id, id)',
    'CHECK (revision > 0)',
    'CHECK (updated_at_us >= created_at_us)',
    'CHECK (deleted_at_us IS NULL OR deleted_at_us >= created_at_us)',
    'FOREIGN KEY (family_id, created_by) REFERENCES family_members(family_id, id)',
    'FOREIGN KEY (family_id, updated_by) REFERENCES family_members(family_id, id)',
    'FOREIGN KEY (family_id, account_id) REFERENCES ledger_accounts(family_id, id)',
    'CHECK (amount_minor >= 0)',
    "CHECK (length(month) = 7 AND date(month || '-01') IS NOT NULL)",
  ];
}

class ReconciliationChecks extends Table with FamilyProvenance {
  TextColumn get accountId => text()();
  TextColumn get statementDate => text()();
  IntColumn get statementMinor => integer()();
  IntColumn get ledgerMinor => integer()();
  TextColumn get notes => text()();
  @override
  List<String> get customConstraints => [
    'UNIQUE (family_id, id)',
    'CHECK (revision > 0)',
    'CHECK (updated_at_us >= created_at_us)',
    'CHECK (deleted_at_us IS NULL OR deleted_at_us >= created_at_us)',
    'FOREIGN KEY (family_id, created_by) REFERENCES family_members(family_id, id)',
    'FOREIGN KEY (family_id, updated_by) REFERENCES family_members(family_id, id)',
    'FOREIGN KEY (family_id, account_id) REFERENCES ledger_accounts(family_id, id)',
    "CHECK (date(statement_date) IS NOT NULL AND date(statement_date) = statement_date)",
  ];
}

class VaultPreferences extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  @override
  Set<Column<Object>> get primaryKey => {key};
  @override
  bool get isStrict => true;
}
