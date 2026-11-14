import 'package:drift/drift.dart';

import 'finance_tables.dart';

class WealthAssets extends Table with FamilyProvenance {
  TextColumn get name => text()();
  TextColumn get kind => text()();
  TextColumn get accountId => text()();
  IntColumn get familyOwnershipBps => integer()();
  TextColumn get valuationState =>
      text().withDefault(const Constant('unrecorded'))();
  TextColumn get closedOn => text().nullable()();
  IntColumn get purchaseTotalMinor => integer().nullable()();
  IntColumn get purchaseOwnershipBps => integer()();
  TextColumn get purchasedOn => text().nullable()();
  TextColumn get currency => text().withDefault(const Constant('INR'))();
  TextColumn get notes => text().withDefault(const Constant(''))();
  @override
  List<String> get customConstraints => [
    "UNIQUE (family_id, id)",
    "CHECK (revision > 0)",
    "CHECK (updated_at_us >= created_at_us)",
    "CHECK (deleted_at_us IS NULL OR deleted_at_us >= created_at_us)",
    "FOREIGN KEY (family_id, created_by) REFERENCES family_members(family_id, id)",
    "FOREIGN KEY (family_id, updated_by) REFERENCES family_members(family_id, id)",
    "CHECK (kind IN ('property', 'land', 'gold', 'silver', 'jewellery', 'vehicle', 'deposit', 'investment', 'other'))",
    "FOREIGN KEY (family_id, account_id) REFERENCES ledger_accounts(family_id, id)",
    "UNIQUE (account_id)",
    "CHECK (family_ownership_bps BETWEEN 1 AND 10000)",
    "CHECK (valuation_state IN ('unrecorded', 'recorded', 'closed'))",
    "CHECK ((valuation_state = 'closed') = (deleted_at_us IS NOT NULL))",
    "CHECK ((valuation_state = 'closed') = (closed_on IS NOT NULL))",
    "CHECK (closed_on IS NULL OR (date(closed_on) IS NOT NULL AND date(closed_on) = closed_on AND length(closed_on) = 10 AND (purchased_on IS NULL OR closed_on >= purchased_on)))",
    "CHECK (purchase_ownership_bps BETWEEN 1 AND 10000)",
    "CHECK (purchase_total_minor IS NULL OR purchase_total_minor >= 0)",
    "CHECK (purchased_on IS NULL OR (date(purchased_on) IS NOT NULL AND date(purchased_on) = purchased_on AND length(purchased_on) = 10))",
    "CHECK (currency = 'INR')",
  ];
}

class PropertyDetails extends Table {
  TextColumn get assetId => text()();
  TextColumn get familyId => text()();
  TextColumn get city => text()();
  TextColumn get location => text()();
  TextColumn get recordReference => text().nullable()();
  IntColumn get areaMilli => integer().nullable()();
  TextColumn get areaUnit => text().nullable()();
  @override
  bool get isStrict => true;
  @override
  Set<Column<Object>> get primaryKey => {assetId};
  @override
  List<String> get customConstraints => [
    "FOREIGN KEY (family_id, asset_id) REFERENCES wealth_assets(family_id, id)",
    "CHECK ((area_milli IS NULL) = (area_unit IS NULL))",
    "CHECK (area_milli IS NULL OR area_milli > 0)",
    "CHECK (area_unit IS NULL OR length(trim(area_unit)) BETWEEN 1 AND 24)",
  ];
}

class MetalDetails extends Table {
  TextColumn get assetId => text()();
  TextColumn get familyId => text()();
  IntColumn get weightMg => integer()();
  TextColumn get metal => text()();
  IntColumn get purityPpm => integer().nullable()();
  TextColumn get purityKind =>
      text().withDefault(const Constant('unrecorded'))();
  IntColumn get karat => integer().nullable()();
  IntColumn get purchaseRateMinorPerGram => integer().nullable()();
  IntColumn get makingChargesMinor => integer().nullable()();
  @override
  bool get isStrict => true;
  @override
  Set<Column<Object>> get primaryKey => {assetId};
  @override
  List<String> get customConstraints => [
    "FOREIGN KEY (family_id, asset_id) REFERENCES wealth_assets(family_id, id)",
    "CHECK (weight_mg > 0)",
    "CHECK (metal IN ('gold', 'silver'))",
    "CHECK (purity_ppm IS NULL OR purity_ppm BETWEEN 1 AND 1000000)",
    "CHECK (purity_kind IN ('unrecorded', 'nominal', 'assayed'))",
    "CHECK ((purity_kind = 'unrecorded') = (purity_ppm IS NULL))",
    "CHECK (purity_kind <> 'nominal' OR (karat IS NOT NULL AND purity_ppm = (karat * 1000000 + 12) / 24))",
    "CHECK (karat IS NULL OR karat IN (18, 22, 24))",
    "CHECK (purchase_rate_minor_per_gram IS NULL OR purchase_rate_minor_per_gram >= 0)",
    "CHECK (making_charges_minor IS NULL OR making_charges_minor >= 0)",
  ];
}

class InvestmentDetails extends Table {
  TextColumn get assetId => text()();
  TextColumn get familyId => text()();
  TextColumn get instrument => text()();
  TextColumn get symbol => text().nullable()();
  IntColumn get quantityScaled => integer().nullable()();
  IntColumn get quantityScale => integer().nullable()();
  @override
  bool get isStrict => true;
  @override
  Set<Column<Object>> get primaryKey => {assetId};
  @override
  List<String> get customConstraints => [
    "FOREIGN KEY (family_id, asset_id) REFERENCES wealth_assets(family_id, id)",
    "CHECK ((quantity_scaled IS NULL) = (quantity_scale IS NULL))",
    "CHECK (quantity_scaled IS NULL OR quantity_scaled > 0)",
    "CHECK (quantity_scale IS NULL OR quantity_scale BETWEEN 0 AND 9)",
  ];
}

class AssetOwnerships extends Table with FamilyProvenance {
  TextColumn get assetId => text()();
  TextColumn get memberId => text().nullable()();
  TextColumn get ownerLabel => text()();
  IntColumn get shareBps => integer()();
  @override
  List<String> get customConstraints => [
    "UNIQUE (family_id, id)",
    "CHECK (revision > 0)",
    "CHECK (updated_at_us >= created_at_us)",
    "CHECK (deleted_at_us IS NULL OR deleted_at_us >= created_at_us)",
    "FOREIGN KEY (family_id, created_by) REFERENCES family_members(family_id, id)",
    "FOREIGN KEY (family_id, updated_by) REFERENCES family_members(family_id, id)",
    "FOREIGN KEY (family_id, asset_id) REFERENCES wealth_assets(family_id, id)",
    "FOREIGN KEY (family_id, member_id) REFERENCES family_members(family_id, id)",
    "CHECK (share_bps BETWEEN 1 AND 10000)",
  ];
}

class AssetValuations extends Table {
  TextColumn get id => text()();
  TextColumn get familyId => text()();
  TextColumn get createdBy => text()();
  TextColumn get deviceId => text()();
  IntColumn get createdAtUs => integer()();
  TextColumn get assetId => text()();
  IntColumn get assetRevision => integer()();
  IntColumn get eventIndex => integer().withDefault(const Constant(0))();
  TextColumn get journalId => text().nullable()();
  TextColumn get valuedOn => text()();
  IntColumn get totalValueMinor => integer()();
  IntColumn get familyValueMinor => integer()();
  IntColumn get previousFamilyValueMinor => integer()();
  IntColumn get ownershipBps => integer()();
  TextColumn get source => text()();
  TextColumn get notes => text()();
  TextColumn get basisJson => text().withDefault(const Constant('{}'))();
  TextColumn get currency => text().withDefault(const Constant('INR'))();
  @override
  bool get isStrict => true;
  @override
  Set<Column<Object>> get primaryKey => {id};
  @override
  List<String> get customConstraints => [
    "UNIQUE (family_id, id)",
    "FOREIGN KEY (family_id, device_id, created_by) REFERENCES vault_devices(family_id, id, member_id)",
    "FOREIGN KEY (family_id, asset_id) REFERENCES wealth_assets(family_id, id)",
    "UNIQUE (family_id, asset_id, asset_revision, event_index)",
    "CHECK (asset_revision > 0 AND event_index >= 0)",
    "FOREIGN KEY (family_id, journal_id) REFERENCES ledger_journals(family_id, id)",
    "UNIQUE (journal_id)",
    "CHECK (total_value_minor >= 0 AND family_value_minor >= 0)",
    "CHECK (typeof(family_value_minor - previous_family_value_minor) = 'integer')",
    "CHECK ((family_value_minor = previous_family_value_minor) = (journal_id IS NULL))",
    "CHECK (ownership_bps BETWEEN 1 AND 10000)",
    "CHECK (family_value_minor = (total_value_minor / 10000) * ownership_bps + ((total_value_minor % 10000) * ownership_bps + 5000) / 10000)",
    "CHECK (json_valid(basis_json))",
    "CHECK (source IN ('purchase', 'manual', 'metal_rate', 'carry_forward'))",
    "CHECK (date(valued_on) IS NOT NULL AND date(valued_on) = valued_on AND length(valued_on) = 10)",
    "CHECK (currency = 'INR')",
  ];
}

class DebtContracts extends Table with FamilyProvenance {
  TextColumn get name => text()();
  TextColumn get direction => text()();
  TextColumn get counterparty => text()();
  TextColumn get accountId => text()();
  IntColumn get principalMinor => integer()();
  IntColumn get annualRateBps => integer().nullable()();
  TextColumn get interestMethod =>
      text().withDefault(const Constant('unrecorded'))();
  IntColumn get termMonths => integer().nullable()();
  IntColumn get emiMinor => integer().nullable()();
  TextColumn get startedOn => text()();
  TextColumn get firstDueOn => text().nullable()();
  TextColumn get dueOn => text().nullable()();
  TextColumn get currency => text().withDefault(const Constant('INR'))();
  TextColumn get notes => text()();
  @override
  List<String> get customConstraints => [
    "UNIQUE (family_id, id)",
    "CHECK (revision > 0)",
    "CHECK (updated_at_us >= created_at_us)",
    "CHECK (deleted_at_us IS NULL OR deleted_at_us >= created_at_us)",
    "FOREIGN KEY (family_id, created_by) REFERENCES family_members(family_id, id)",
    "FOREIGN KEY (family_id, updated_by) REFERENCES family_members(family_id, id)",
    "CHECK (direction IN ('borrowed', 'lent', 'bank_loan'))",
    "FOREIGN KEY (family_id, account_id) REFERENCES ledger_accounts(family_id, id)",
    "UNIQUE (account_id)",
    "CHECK (principal_minor > 0)",
    "CHECK (annual_rate_bps IS NULL OR annual_rate_bps BETWEEN 0 AND 1000000)",
    "CHECK (interest_method IN ('unrecorded', 'simpleActual365', 'flatMonthly', 'reducingMonthly'))",
    "CHECK ((interest_method = 'unrecorded') = (annual_rate_bps IS NULL))",
    "CHECK (term_months IS NULL OR term_months BETWEEN 1 AND 600)",
    "CHECK (emi_minor IS NULL OR emi_minor >= 0)",
    "CHECK (date(started_on) IS NOT NULL AND date(started_on) = started_on AND length(started_on) = 10)",
    "CHECK (first_due_on IS NULL OR (date(first_due_on) IS NOT NULL AND date(first_due_on) = first_due_on AND length(first_due_on) = 10 AND first_due_on >= started_on))",
    "CHECK (due_on IS NULL OR (date(due_on) IS NOT NULL AND date(due_on) = due_on AND length(due_on) = 10 AND due_on >= started_on))",
    "CHECK (currency = 'INR')",
  ];
}

class DebtRepayments extends Table {
  TextColumn get id => text()();
  TextColumn get familyId => text()();
  TextColumn get createdBy => text()();
  TextColumn get deviceId => text()();
  IntColumn get createdAtUs => integer()();
  TextColumn get contractId => text()();
  TextColumn get journalId => text()();
  TextColumn get paidOn => text()();
  IntColumn get principalMinor => integer()();
  IntColumn get interestMinor => integer()();
  TextColumn get notes => text()();
  @override
  bool get isStrict => true;
  @override
  Set<Column<Object>> get primaryKey => {id};
  @override
  List<String> get customConstraints => [
    "UNIQUE (family_id, id)",
    "FOREIGN KEY (family_id, device_id, created_by) REFERENCES vault_devices(family_id, id, member_id)",
    "FOREIGN KEY (family_id, contract_id) REFERENCES debt_contracts(family_id, id)",
    "FOREIGN KEY (family_id, journal_id) REFERENCES ledger_journals(family_id, id)",
    "UNIQUE (journal_id)",
    "CHECK (principal_minor >= 0 AND interest_minor >= 0)",
    "CHECK (principal_minor > 0 OR interest_minor > 0)",
    "CHECK (typeof(principal_minor + interest_minor) = 'integer')",
    "CHECK (date(paid_on) IS NOT NULL AND date(paid_on) = paid_on AND length(paid_on) = 10)",
  ];
}

class Businesses extends Table with FamilyProvenance {
  TextColumn get name => text()();
  TextColumn get notes => text()();
  TextColumn get inventoryAccountId => text()();
  TextColumn get costOfGoodsAccountId => text()();
  TextColumn get salaryAccountId => text()();
  TextColumn get currency => text().withDefault(const Constant('INR'))();
  @override
  List<String> get customConstraints => [
    "UNIQUE (family_id, id)",
    "CHECK (revision > 0)",
    "CHECK (updated_at_us >= created_at_us)",
    "CHECK (deleted_at_us IS NULL OR deleted_at_us >= created_at_us)",
    "FOREIGN KEY (family_id, created_by) REFERENCES family_members(family_id, id)",
    "FOREIGN KEY (family_id, updated_by) REFERENCES family_members(family_id, id)",
    "FOREIGN KEY (family_id, inventory_account_id) REFERENCES ledger_accounts(family_id, id)",
    "FOREIGN KEY (family_id, cost_of_goods_account_id) REFERENCES ledger_accounts(family_id, id)",
    "FOREIGN KEY (family_id, salary_account_id) REFERENCES ledger_accounts(family_id, id)",
    "CHECK (currency = 'INR')",
  ];
}

class StockItems extends Table with FamilyProvenance {
  TextColumn get businessId => text()();
  TextColumn get name => text()();
  TextColumn get sku => text().nullable()();
  TextColumn get unit => text().withDefault(const Constant('piece'))();
  @override
  List<String> get customConstraints => [
    "UNIQUE (family_id, id)",
    "CHECK (revision > 0)",
    "CHECK (updated_at_us >= created_at_us)",
    "CHECK (deleted_at_us IS NULL OR deleted_at_us >= created_at_us)",
    "FOREIGN KEY (family_id, created_by) REFERENCES family_members(family_id, id)",
    "FOREIGN KEY (family_id, updated_by) REFERENCES family_members(family_id, id)",
    "FOREIGN KEY (family_id, business_id) REFERENCES businesses(family_id, id)",
    "UNIQUE (family_id, id, business_id)",
    "CHECK (unit = 'piece')",
  ];
}

class StockMovements extends Table {
  TextColumn get id => text()();
  TextColumn get familyId => text()();
  TextColumn get createdBy => text()();
  TextColumn get deviceId => text()();
  IntColumn get createdAtUs => integer()();
  TextColumn get businessId => text()();
  TextColumn get stockItemId => text()();
  IntColumn get itemRevision => integer()();
  IntColumn get eventIndex => integer().withDefault(const Constant(0))();
  TextColumn get reversesId => text().nullable()();
  TextColumn get journalId => text().nullable()();
  TextColumn get occurredOn => text()();
  TextColumn get kind => text()();
  IntColumn get quantityDelta => integer()();
  IntColumn get valueDeltaMinor => integer()();
  TextColumn get notes => text()();
  @override
  bool get isStrict => true;
  @override
  Set<Column<Object>> get primaryKey => {id};
  @override
  List<String> get customConstraints => [
    "UNIQUE (family_id, id)",
    "FOREIGN KEY (family_id, device_id, created_by) REFERENCES vault_devices(family_id, id, member_id)",
    "FOREIGN KEY (family_id, business_id) REFERENCES businesses(family_id, id)",
    "FOREIGN KEY (family_id, stock_item_id) REFERENCES stock_items(family_id, id)",
    "FOREIGN KEY (family_id, stock_item_id, business_id) REFERENCES stock_items(family_id, id, business_id)",
    "FOREIGN KEY (family_id, reverses_id) REFERENCES stock_movements(family_id, id)",
    "UNIQUE (family_id, stock_item_id, item_revision, event_index)",
    "UNIQUE (reverses_id)",
    "CHECK (item_revision > 0 AND event_index >= 0)",
    "FOREIGN KEY (family_id, journal_id) REFERENCES ledger_journals(family_id, id)",
    "UNIQUE (journal_id)",
    "CHECK (quantity_delta <> 0)",
    "CHECK (value_delta_minor = 0 OR journal_id IS NOT NULL)",
    "CHECK ((quantity_delta > 0 AND value_delta_minor >= 0) OR (quantity_delta < 0 AND value_delta_minor <= 0))",
    "CHECK (kind IN ('purchase', 'opening', 'stock_out', 'return', 'adjustment', 'reversal'))",
    "CHECK ((kind = 'reversal') = (reverses_id IS NOT NULL))",
    "CHECK (date(occurred_on) IS NOT NULL AND date(occurred_on) = occurred_on AND length(occurred_on) = 10)",
  ];
}

class Workers extends Table with FamilyProvenance {
  TextColumn get businessId => text()();
  TextColumn get name => text()();
  IntColumn get monthlySalaryMinor => integer().nullable()();
  TextColumn get notes => text()();
  @override
  List<String> get customConstraints => [
    "UNIQUE (family_id, id)",
    "CHECK (revision > 0)",
    "CHECK (updated_at_us >= created_at_us)",
    "CHECK (deleted_at_us IS NULL OR deleted_at_us >= created_at_us)",
    "FOREIGN KEY (family_id, created_by) REFERENCES family_members(family_id, id)",
    "FOREIGN KEY (family_id, updated_by) REFERENCES family_members(family_id, id)",
    "FOREIGN KEY (family_id, business_id) REFERENCES businesses(family_id, id)",
    "UNIQUE (family_id, id, business_id)",
    "CHECK (monthly_salary_minor IS NULL OR monthly_salary_minor >= 0)",
  ];
}

class SalaryPayments extends Table {
  TextColumn get id => text()();
  TextColumn get familyId => text()();
  TextColumn get createdBy => text()();
  TextColumn get deviceId => text()();
  IntColumn get createdAtUs => integer()();
  TextColumn get businessId => text()();
  TextColumn get workerId => text()();
  TextColumn get journalId => text()();
  TextColumn get period => text()();
  TextColumn get paidOn => text()();
  IntColumn get amountMinor => integer()();
  TextColumn get notes => text()();
  @override
  bool get isStrict => true;
  @override
  Set<Column<Object>> get primaryKey => {id};
  @override
  List<String> get customConstraints => [
    "UNIQUE (family_id, id)",
    "FOREIGN KEY (family_id, device_id, created_by) REFERENCES vault_devices(family_id, id, member_id)",
    "FOREIGN KEY (family_id, business_id) REFERENCES businesses(family_id, id)",
    "FOREIGN KEY (family_id, worker_id) REFERENCES workers(family_id, id)",
    "FOREIGN KEY (family_id, worker_id, business_id) REFERENCES workers(family_id, id, business_id)",
    "FOREIGN KEY (family_id, journal_id) REFERENCES ledger_journals(family_id, id)",
    "UNIQUE (journal_id)",
    "CHECK (amount_minor > 0)",
    "CHECK (length(period) = 7 AND date(period || '-01') IS NOT NULL)",
    "CHECK (date(paid_on) IS NOT NULL AND date(paid_on) = paid_on AND length(paid_on) = 10)",
  ];
}

/// Derived cache maintained only by stock event triggers; events remain the facts.
class StockPositions extends Table {
  TextColumn get stockItemId => text()();
  TextColumn get familyId => text()();
  IntColumn get quantity => integer().withDefault(const Constant(0))();
  IntColumn get costPoolMinor => integer().withDefault(const Constant(0))();
  @override
  Set<Column<Object>> get primaryKey => {stockItemId};
  @override
  bool get isStrict => true;
  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (family_id, stock_item_id) REFERENCES stock_items(family_id, id)',
    'CHECK (quantity >= 0 AND cost_pool_minor >= 0)',
    'CHECK (quantity <> 0 OR cost_pool_minor = 0)',
  ];
}

/// Explicit domain linkage survives outbox pruning and directs corrections to
/// the owning module, keeping stock/valuation/repayment facts consistent.
class AggregateJournalLinks extends Table {
  TextColumn get journalId => text()();
  TextColumn get familyId => text()();
  TextColumn get aggregateType => text()();
  TextColumn get aggregateId => text()();
  TextColumn get operationId => text()();
  TextColumn get purpose => text().withDefault(const Constant('other'))();
  @override
  Set<Column<Object>> get primaryKey => {journalId};
  @override
  bool get isStrict => true;
  @override
  List<String> get customConstraints => [
    'FOREIGN KEY (family_id, journal_id) REFERENCES ledger_journals(family_id, id)',
    "CHECK (aggregate_type IN ('asset', 'debt', 'stock', 'salary', 'asset_rent'))",
    "CHECK (purpose IN ('opening', 'acquisition', 'valuation', 'valuation_bridge', 'disposal', 'disposal_bridge', 'repayment', 'salary', 'stock', 'rent', 'reversal', 'other'))",
  ];
}
