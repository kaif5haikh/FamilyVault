import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/mutation_writer.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/finance/money.dart';
import '../../../core/sync/database_record.dart';
import '../../finance/data/ledger_repository.dart';
import '../domain/business_records.dart';
import '../domain/inventory_math.dart';

export '../domain/business_records.dart';

final class BusinessSnapshot {
  const BusinessSnapshot({
    required this.businesses,
    required this.items,
    required this.positions,
    required this.movements,
    required this.workers,
    required this.salaries,
  });
  final List<BusinessesData> businesses;
  final List<StockItem> items;
  final Map<String, StockPosition> positions;
  final List<StockMovement> movements;
  final List<Worker> workers;
  final List<SalaryPayment> salaries;

  Iterable<StockMovement> activeMovements(String itemId) {
    final history = movements.where((r) => r.stockItemId == itemId);
    final reversed = history.map((row) => row.reversesId).nonNulls.toSet();
    return history.where(
      (row) => row.reversesId == null && !reversed.contains(row.id),
    );
  }
}

final class BusinessProfit {
  BusinessProfit({
    required this.revenue,
    required this.costOfGoods,
    required this.salaries,
    required this.operatingExpenses,
  });
  final BigInt revenue, costOfGoods, salaries, operatingExpenses;
  BigInt get gross => revenue - costOfGoods;
  BigInt get net => gross - salaries - operatingExpenses;

  factory BusinessProfit.forPeriod(
    BusinessesData business,
    FinanceSnapshot finance, {
    required String from,
    required String through,
  }) {
    LedgerRepository.validateDate(from);
    LedgerRepository.validateDate(through);
    if (from.compareTo(through) > 0) {
      throw BusinessRepository._invalid;
    }
    final journals = finance.journals
        .where(
          (row) =>
              row.businessId == business.id &&
              row.status == 'posted' &&
              row.occurredOn.compareTo(from) >= 0 &&
              row.occurredOn.compareTo(through) <= 0,
        )
        .map((j) => j.id)
        .toSet();
    final kinds = {for (final a in finance.accounts) a.id: a.kind};
    var revenue = BigInt.zero,
        cost = BigInt.zero,
        salaries = BigInt.zero,
        operating = BigInt.zero;
    for (final p in finance.postings.where(
      (p) => journals.contains(p.journalId),
    )) {
      final amount = BigInt.from(p.amountMinor);
      if (kinds[p.accountId] == 'income') {
        revenue -= amount;
      }
      if (kinds[p.accountId] != 'expense') {
        continue;
      }
      if (p.accountId == business.costOfGoodsAccountId) {
        cost += amount;
      } else if (p.accountId == business.salaryAccountId) {
        salaries += amount;
      } else {
        operating += amount;
      }
    }
    return BusinessProfit(
      revenue: revenue,
      costOfGoods: cost,
      salaries: salaries,
      operatingExpenses: operating,
    );
  }
}

final class BusinessRepository {
  const BusinessRepository(this.ledger);
  final LedgerRepository ledger;
  AppDatabase get db => ledger.db;
  String get family => ledger.identity.familyId;
  String get actor => ledger.identity.memberId;
  int get now => ledger.mutations.now;
  static const _invalid = AppFailure(
    FailureCode.validation,
    'Check the business, amount and date.',
  );
  static const _stale = AppFailure(
    FailureCode.conflict,
    'This record changed. Open it again before saving.',
  );

  static String _text(String value, int limit, {bool optional = false}) {
    value = value.trim();
    if ((!optional && value.isEmpty) ||
        value.length > limit ||
        value.contains('\u0000')) {
      throw _invalid;
    }
    return value;
  }

  Future<BusinessesData> business(String id, {bool active = true}) async {
    final row =
        await (db.select(db.businesses)
              ..where((t) => t.familyId.equals(family) & t.id.equals(id)))
            .getSingleOrNull();
    if (row == null || (active && row.deletedAtUs != null)) {
      throw const AppFailure(
        FailureCode.validation,
        'This business is unavailable in this family.',
      );
    }
    return row;
  }

  Future<String> create({
    required String name,
    required String notes,
    String? operationId,
  }) {
    final op = operationId ?? ledger.operationId();
    final id = ledger.aggregateId(op, 'business');
    return ledger.runAggregate(
      operationId: op,
      entityType: 'business',
      entityId: id,
      baseRevision: 0,
      action: 'create',
      command: {'name': name.trim(), 'notes': notes.trim()},
      change: (tx) async {
        final label = _text(name, 96);
        final stock = await tx.createAccount(
          label: 'inventory',
          name: '$label · Inventory',
          kind: AccountKind.asset,
          subtype: 'managed_inventory',
        );
        final goods = await tx.createAccount(
          label: 'goods',
          name: '$label · Stock cost',
          kind: AccountKind.expense,
          subtype: 'managed_stock_cost',
        );
        final salary = await tx.createAccount(
          label: 'salary',
          name: '$label · Wages',
          kind: AccountKind.expense,
          subtype: 'managed_salary',
        );
        await db
            .into(db.businesses)
            .insert(
              BusinessesCompanion.insert(
                id: id,
                familyId: family,
                createdBy: actor,
                updatedBy: actor,
                createdAtUs: now,
                updatedAtUs: now,
                name: label,
                notes: _text(notes, 4000, optional: true),
                inventoryAccountId: stock.id,
                costOfGoodsAccountId: goods.id,
                salaryAccountId: salary.id,
              ),
            );
        return databaseRecord(await business(id));
      },
    );
  }

  Future<String> edit(
    String id,
    int revision, {
    required String name,
    required String notes,
    String? operationId,
  }) => ledger.runAggregate(
    operationId: operationId ?? ledger.operationId(),
    entityType: 'business',
    entityId: id,
    baseRevision: revision,
    command: {'name': name.trim(), 'notes': notes.trim()},
    change: (tx) async {
      final before = await business(id);
      if (before.revision != revision) {
        throw _stale;
      }
      final label = _text(name, 96);
      tx.before = databaseRecord(before);
      await (db.update(
        db.businesses,
      )..where((t) => t.id.equals(id) & t.familyId.equals(family))).write(
        BusinessesCompanion(
          name: Value(label),
          notes: Value(_text(notes, 4000, optional: true)),
          revision: Value(revision + 1),
          updatedBy: Value(actor),
          updatedAtUs: Value(now),
        ),
      );
      if (label != before.name) {
        await tx.renameAccount(before.inventoryAccountId, '$label · Inventory');
        await tx.renameAccount(
          before.costOfGoodsAccountId,
          '$label · Stock cost',
        );
        await tx.renameAccount(before.salaryAccountId, '$label · Wages');
      }
      return databaseRecord(await business(id));
    },
  );

  Future<String> cashEntry(
    String businessId, {
    required bool revenue,
    required Money amount,
    required String accountId,
    required String date,
    required String description,
    String? operationId,
  }) => storageBoundary(
    () => db.transaction(() async {
      await ledger.mutations.authorize();
      await business(businessId);
      final account = await ledger.account(accountId);
      if (account.kind != 'asset' ||
          !['cash', 'bank'].contains(account.subtype) ||
          account.deletedAtUs != null) {
        throw _invalid;
      }
      return ledger.recordTransaction(
        kind: revenue ? EntryKind.income : EntryKind.expense,
        accountId: accountId,
        counterAccountId: ledger.chartId(
          revenue ? 'business_income' : 'business_expense',
        ),
        amount: amount,
        occurredOn: date,
        description: description,
        operationId: operationId,
        businessId: businessId,
      );
    }),
  );

  Future<StockItem> item(String id, {bool active = true}) async {
    final row =
        await (db.select(db.stockItems)
              ..where((t) => t.familyId.equals(family) & t.id.equals(id)))
            .getSingleOrNull();
    if (row == null || (active && row.deletedAtUs != null)) {
      throw const AppFailure(
        FailureCode.validation,
        'This stock item is unavailable in this family.',
      );
    }
    return row;
  }

  Future<String> saveItem({
    required String businessId,
    required String name,
    String? sku,
    String? id,
    int revision = 0,
    String? operationId,
  }) {
    final op = operationId ?? ledger.operationId();
    final key = id ?? ledger.aggregateId(op, 'stock');
    return ledger.runAggregate(
      operationId: op,
      entityType: 'stock',
      entityId: key,
      baseRevision: revision,
      action: id == null ? 'create' : 'update',
      command: {
        'business_id': businessId,
        'name': name.trim(),
        'sku': sku?.trim(),
      },
      change: (tx) async {
        await business(businessId);
        final label = _text(name, 120),
            code = sku == null ? null : _text(sku, 80);
        if (id == null) {
          await db
              .into(db.stockItems)
              .insert(
                StockItemsCompanion.insert(
                  id: key,
                  familyId: family,
                  businessId: businessId,
                  name: label,
                  sku: Value(code),
                  createdBy: actor,
                  updatedBy: actor,
                  createdAtUs: now,
                  updatedAtUs: now,
                ),
              );
        } else {
          final before = await item(id);
          if (before.businessId != businessId) {
            throw _invalid;
          }
          tx.before = databaseRecord(before);
          await _updateItem(
            before,
            revision,
            StockItemsCompanion(name: Value(label), sku: Value(code)),
          );
        }
        return databaseRecord(await item(key));
      },
    );
  }

  Future<String> archiveItem(
    String id,
    int revision, {
    required bool restore,
  }) => ledger.runAggregate(
    operationId: ledger.operationId(),
    entityType: 'stock',
    entityId: id,
    baseRevision: revision,
    action: restore ? 'restore' : 'delete',
    command: {'restore': restore},
    change: (tx) async {
      final before = await item(id, active: !restore);
      await business(before.businessId);
      if (restore && before.deletedAtUs == null) {
        throw _stale;
      }
      if (!restore && (await _position(id)).quantity != 0) {
        throw const AppFailure(
          FailureCode.validation,
          'Remove or correct remaining stock before archiving the item.',
        );
      }
      tx.before = databaseRecord(before);
      await _updateItem(
        before,
        revision,
        StockItemsCompanion(deletedAtUs: Value(restore ? null : now)),
      );
      return databaseRecord(await item(id, active: false));
    },
  );

  Future<void> _updateItem(
    StockItem row,
    int revision,
    StockItemsCompanion change,
  ) async {
    if (row.revision != revision) {
      throw _stale;
    }
    final updated =
        await (db.update(db.stockItems)..where(
              (t) =>
                  t.id.equals(row.id) &
                  t.familyId.equals(family) &
                  t.revision.equals(revision),
            ))
            .write(
              change.copyWith(
                revision: Value(revision + 1),
                updatedBy: Value(actor),
                updatedAtUs: Value(now),
              ),
            );
    if (updated != 1) {
      throw _stale;
    }
  }

  Future<StockPosition> _position(String id) =>
      (db.select(
            db.stockPositions,
          )..where((t) => t.stockItemId.equals(id) & t.familyId.equals(family)))
          .getSingle();

  Future<StockMovement?> _latestActive(String id) async {
    final rows =
        await (db.select(db.stockMovements)
              ..where(
                (t) => t.familyId.equals(family) & t.stockItemId.equals(id),
              )
              ..orderBy([
                (t) => OrderingTerm.desc(t.itemRevision),
                (t) => OrderingTerm.desc(t.eventIndex),
              ]))
            .get();
    final reversed = rows.map((r) => r.reversesId).nonNulls.toSet();
    return rows
        .where((row) => row.reversesId == null && !reversed.contains(row.id))
        .firstOrNull;
  }

  Future<String> moveStock(
    String id,
    int revision,
    StockEntryDraft draft, {
    String? operationId,
  }) => _stockChange(id, revision, draft: draft, operationId: operationId);

  Future<String> correctStock(
    String id,
    int revision,
    String originalId,
    String reason, {
    StockEntryDraft? replacement,
    String? operationId,
  }) => _stockChange(
    id,
    revision,
    draft: replacement,
    reverseId: originalId,
    reason: reason,
    operationId: operationId,
  );

  Future<String> _stockChange(
    String id,
    int revision, {
    StockEntryDraft? draft,
    String? reverseId,
    String? reason,
    String? operationId,
  }) => ledger.runAggregate(
    operationId: operationId ?? ledger.operationId(),
    entityType: 'stock',
    entityId: id,
    baseRevision: revision,
    command: {
      'movement': draft?.toJson(),
      'reverse_movement': reverseId,
      'reason': reason?.trim(),
    },
    change: (tx) async {
      final before = await item(id);
      final location = await business(before.businessId);
      tx.before = databaseRecord(before);
      await _updateItem(before, revision, const StockItemsCompanion());
      final row = await item(id);
      final events = <Map<String, Object?>>[];
      if (reverseId != null) {
        final original = await _latestActive(id);
        if (original == null || original.id != reverseId) {
          throw const AppFailure(
            FailureCode.conflict,
            'Only the latest active movement can be corrected.',
          );
        }
        final note = _text(reason!, 400);
        final journal = original.journalId == null
            ? null
            : await tx.reverse(original.journalId!, note);
        events.add(
          await _stockEvent(
            tx,
            row,
            index: 0,
            kind: 'reversal',
            date: original.occurredOn,
            units: -original.quantityDelta,
            cost: -original.valueDeltaMinor,
            notes: note,
            journalId: journal,
            reversesId: original.id,
          ),
        );
      }
      if (draft != null) {
        events.add(await _move(tx, row, location, draft, events.length));
      }
      tx.include('stock_movements', events);
      return databaseRecord(row);
    },
  );

  Future<Map<String, Object?>> _move(
    LedgerAggregate tx,
    StockItem row,
    BusinessesData location,
    StockEntryDraft draft,
    int index,
  ) async {
    LedgerRepository.validateDate(draft.date);
    final latest = await _latestActive(row.id),
        isReceipt = draft.kind.isReceipt;
    if (draft.units <= 0 ||
        (latest != null && draft.date.compareTo(latest.occurredOn) < 0)) {
      throw const AppFailure(
        FailureCode.validation,
        'Use a positive stock quantity and a date on or after the last active movement.',
      );
    }
    if (draft.kind == StockEntryKind.opening && latest != null) {
      throw const AppFailure(
        FailureCode.validation,
        'Opening stock is recorded before other movements.',
      );
    }
    if (isReceipt != (draft.costMinor != null) ||
        (draft.kind == StockEntryKind.purchase) !=
            (draft.cashAccountId != null)) {
      throw _invalid;
    }
    final cache = await _position(row.id);
    final position = InventoryPosition(
      quantity: cache.quantity,
      costPoolMinor: cache.costPoolMinor,
    );
    final int delta;
    final String contra;
    if (isReceipt) {
      final cost = draft.costMinor!;
      position.receive(units: draft.units, totalCost: Money.fromMinor(cost));
      delta = cost;
      contra = draft.kind == StockEntryKind.opening
          ? ledger.chartId('opening')
          : (await tx.liquidAccount(draft.cashAccountId!)).id;
    } else {
      delta = -position.issue(draft.units).costMinor;
      contra = location.costOfGoodsAccountId;
    }
    final notes = _text(draft.notes, 4000, optional: true);
    final journal = delta == 0
        ? null
        : await tx.post(
            kind: EntryKind.business,
            occurredOn: draft.date,
            description: switch (draft.kind) {
              StockEntryKind.opening => 'Opening stock',
              StockEntryKind.purchase => 'Stock purchase',
              StockEntryKind.stockOut => 'Cost of stock issued',
              StockEntryKind.adjustment => 'Stock count reduction',
            },
            postings: [
              PostingInput(location.inventoryAccountId, delta),
              PostingInput(contra, -delta),
            ],
            purpose: 'stock',
            businessId: location.id,
          );
    return _stockEvent(
      tx,
      row,
      index: index,
      kind: draft.kind.code,
      date: draft.date,
      units: isReceipt ? draft.units : -draft.units,
      cost: delta,
      notes: notes,
      journalId: journal,
    );
  }

  Future<Map<String, Object?>> _stockEvent(
    LedgerAggregate tx,
    StockItem row, {
    required int index,
    required String kind,
    required String date,
    required int units,
    required int cost,
    required String notes,
    String? journalId,
    String? reversesId,
  }) async {
    final id = tx.id('movement/$index');
    await db
        .into(db.stockMovements)
        .insert(
          StockMovementsCompanion.insert(
            id: id,
            familyId: family,
            createdBy: actor,
            deviceId: ledger.identity.deviceId,
            createdAtUs: now,
            businessId: row.businessId,
            stockItemId: row.id,
            itemRevision: row.revision,
            eventIndex: Value(index),
            reversesId: Value(reversesId),
            journalId: Value(journalId),
            occurredOn: date,
            kind: kind,
            quantityDelta: units,
            valueDeltaMinor: cost,
            notes: notes,
          ),
        );
    return databaseRecord(
      await (db.select(
        db.stockMovements,
      )..where((t) => t.id.equals(id))).getSingle(),
    );
  }

  Future<Worker> worker(String id, {bool active = true}) async {
    final row =
        await (db.select(db.workers)
              ..where((t) => t.familyId.equals(family) & t.id.equals(id)))
            .getSingleOrNull();
    if (row == null || (active && row.deletedAtUs != null)) {
      throw const AppFailure(
        FailureCode.validation,
        'This worker is unavailable in this family.',
      );
    }
    return row;
  }

  Future<String> saveWorker({
    required String businessId,
    required String name,
    required String notes,
    int? expectedMonthlyMinor,
    String? id,
    int revision = 0,
    String? operationId,
  }) {
    final op = operationId ?? ledger.operationId();
    final key = id ?? ledger.aggregateId(op, 'worker');
    return ledger.runAggregate(
      operationId: op,
      entityType: 'worker',
      entityId: key,
      baseRevision: revision,
      action: id == null ? 'create' : 'update',
      command: {
        'business_id': businessId,
        'name': name.trim(),
        'notes': notes.trim(),
        'monthly_salary_minor': expectedMonthlyMinor,
      },
      change: (tx) async {
        await business(businessId);
        if (expectedMonthlyMinor != null && expectedMonthlyMinor < 0) {
          throw _invalid;
        }
        final label = _text(name, 120),
            note = _text(notes, 4000, optional: true);
        if (id == null) {
          await db
              .into(db.workers)
              .insert(
                WorkersCompanion.insert(
                  id: key,
                  familyId: family,
                  createdBy: actor,
                  updatedBy: actor,
                  createdAtUs: now,
                  updatedAtUs: now,
                  businessId: businessId,
                  name: label,
                  monthlySalaryMinor: Value(expectedMonthlyMinor),
                  notes: note,
                ),
              );
        } else {
          final before = await worker(id);
          if (before.businessId != businessId) {
            throw _invalid;
          }
          tx.before = databaseRecord(before);
          await _updateWorker(
            before,
            revision,
            WorkersCompanion(
              name: Value(label),
              monthlySalaryMinor: Value(expectedMonthlyMinor),
              notes: Value(note),
            ),
          );
        }
        return databaseRecord(await worker(key));
      },
    );
  }

  Future<String> archiveWorker(
    String id,
    int revision, {
    required bool restore,
  }) => ledger.runAggregate(
    operationId: ledger.operationId(),
    entityType: 'worker',
    entityId: id,
    baseRevision: revision,
    action: restore ? 'restore' : 'delete',
    command: {'restore': restore},
    change: (tx) async {
      final before = await worker(id, active: !restore);
      await business(before.businessId);
      if (restore && before.deletedAtUs == null) {
        throw _stale;
      }
      tx.before = databaseRecord(before);
      await _updateWorker(
        before,
        revision,
        WorkersCompanion(deletedAtUs: Value(restore ? null : now)),
      );
      return databaseRecord(await worker(id, active: false));
    },
  );

  Future<void> _updateWorker(
    Worker row,
    int revision,
    WorkersCompanion change,
  ) async {
    if (row.revision != revision) {
      throw _stale;
    }
    final updated =
        await (db.update(db.workers)..where(
              (t) =>
                  t.id.equals(row.id) &
                  t.familyId.equals(family) &
                  t.revision.equals(revision),
            ))
            .write(
              change.copyWith(
                revision: Value(revision + 1),
                updatedBy: Value(actor),
                updatedAtUs: Value(now),
              ),
            );
    if (updated != 1) {
      throw _stale;
    }
  }

  Future<String> paySalary(
    String id,
    int revision,
    SalaryDraft draft, {
    String? operationId,
  }) => _salaryChange(id, revision, draft: draft, operationId: operationId);

  Future<String> correctSalary(
    String id,
    int revision,
    String paymentId,
    String reason, {
    SalaryDraft? replacement,
    String? operationId,
  }) => _salaryChange(
    id,
    revision,
    draft: replacement,
    reverseId: paymentId,
    reason: reason,
    operationId: operationId,
  );

  Future<String> _salaryChange(
    String id,
    int revision, {
    SalaryDraft? draft,
    String? reverseId,
    String? reason,
    String? operationId,
  }) => ledger.runAggregate(
    operationId: operationId ?? ledger.operationId(),
    entityType: 'worker',
    entityId: id,
    baseRevision: revision,
    command: {
      'salary': draft?.toJson(),
      'reverse_salary': reverseId,
      'reason': reason?.trim(),
    },
    change: (tx) async {
      final workerRow = await worker(id, active: draft != null);
      final location = await business(workerRow.businessId);
      tx.before = databaseRecord(workerRow);
      await _updateWorker(workerRow, revision, const WorkersCompanion());
      if (reverseId != null) {
        final old =
            await (db.select(db.salaryPayments)..where(
                  (t) =>
                      t.id.equals(reverseId) &
                      t.workerId.equals(id) &
                      t.familyId.equals(family),
                ))
                .getSingleOrNull();
        if (old == null) {
          throw _invalid;
        }
        await tx.reverse(
          old.journalId,
          _text(reason!, 400),
          aggregateType: 'salary',
        );
      }
      if (draft != null) {
        await _postSalary(tx, workerRow, location, draft);
      }
      return databaseRecord(await worker(id, active: false));
    },
  );

  Future<void> _postSalary(
    LedgerAggregate tx,
    Worker workerRow,
    BusinessesData location,
    SalaryDraft draft,
  ) async {
    LedgerRepository.validateDate(draft.paidOn);
    LedgerRepository.validateDate('${draft.period}-01');
    if (draft.amountMinor <= 0) {
      throw _invalid;
    }
    final cash = await tx.liquidAccount(draft.cashAccountId);
    final journal = await tx.post(
      kind: EntryKind.business,
      occurredOn: draft.paidOn,
      description: 'Salary payment',
      postings: [
        PostingInput(location.salaryAccountId, draft.amountMinor),
        PostingInput(cash.id, -draft.amountMinor),
      ],
      aggregateType: 'salary',
      purpose: 'salary',
      businessId: location.id,
    );
    final key = tx.id('salary_payment');
    await db
        .into(db.salaryPayments)
        .insert(
          SalaryPaymentsCompanion.insert(
            id: key,
            familyId: family,
            createdBy: actor,
            deviceId: ledger.identity.deviceId,
            createdAtUs: now,
            businessId: location.id,
            workerId: workerRow.id,
            journalId: journal,
            period: draft.period,
            paidOn: draft.paidOn,
            amountMinor: draft.amountMinor,
            notes: _text(draft.notes, 4000, optional: true),
          ),
        );
    tx.include('salary_payments', [
      databaseRecord(
        await (db.select(
          db.salaryPayments,
        )..where((t) => t.id.equals(key))).getSingle(),
      ),
    ]);
  }

  Future<BusinessSnapshot> snapshot() => storageBoundary(
    () => db.transaction(() async {
      await ledger.mutations.authorize();
      return BusinessSnapshot(
        businesses:
            await (db.select(db.businesses)
                  ..where((t) => t.familyId.equals(family))
                  ..orderBy([(t) => OrderingTerm.asc(t.name)]))
                .get(),
        items:
            await (db.select(db.stockItems)
                  ..where((t) => t.familyId.equals(family))
                  ..orderBy([(t) => OrderingTerm.asc(t.name)]))
                .get(),
        positions: {
          for (final p in await (db.select(
            db.stockPositions,
          )..where((t) => t.familyId.equals(family))).get())
            p.stockItemId: p,
        },
        movements:
            await (db.select(db.stockMovements)
                  ..where((t) => t.familyId.equals(family))
                  ..orderBy([
                    (t) => OrderingTerm.desc(t.itemRevision),
                    (t) => OrderingTerm.desc(t.eventIndex),
                  ]))
                .get(),
        workers:
            await (db.select(db.workers)
                  ..where((t) => t.familyId.equals(family))
                  ..orderBy([(t) => OrderingTerm.asc(t.name)]))
                .get(),
        salaries:
            await (db.select(db.salaryPayments)
                  ..where((t) => t.familyId.equals(family))
                  ..orderBy([
                    (t) => OrderingTerm.desc(t.paidOn),
                    (t) => OrderingTerm.desc(t.createdAtUs),
                  ]))
                .get(),
      );
    }),
  );

  Stream<BusinessSnapshot> watch() => db
      .customSelect(
        'SELECT 1 /* business projection */',
        readsFrom: {
          db.businesses,
          db.stockItems,
          db.stockPositions,
          db.stockMovements,
          db.workers,
          db.salaryPayments,
          db.familyMembers,
          db.vaultDevices,
        },
      )
      .watch()
      .asyncMap((_) => snapshot());
}
