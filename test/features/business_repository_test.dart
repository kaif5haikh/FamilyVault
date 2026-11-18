import 'dart:convert';

import 'package:familyvault/core/database/app_database.dart';
import 'package:familyvault/core/errors/app_failure.dart';
import 'package:familyvault/core/finance/money.dart';
import 'package:familyvault/features/business/data/business_repository.dart';
import 'package:familyvault/features/finance/data/ledger_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import '../support/vault_fixture.dart';

void main() {
  late VaultFixture fixture;
  late BusinessRepository repo;
  late LedgerAccount cash;
  late String businessId, stockId;
  const uuid = Uuid();
  final failure = isA<AppFailure>();

  setUp(() async {
    fixture = await VaultFixture.create();
    repo = BusinessRepository(fixture.ledger);
    cash = await fixture.ledger.createAccount(
      name: 'Synthetic business cash',
      kind: AccountKind.asset,
      subtype: 'cash',
      openingBalance: Money.fromMinor(100000),
      openedOn: '2026-01-01',
    );
    businessId = await repo.create(name: 'Synthetic enterprise', notes: '');
    stockId = await repo.saveItem(
      businessId: businessId,
      name: 'Synthetic tyre',
      sku: 'TEST-01',
    );
  });
  tearDown(() => fixture.dispose());

  StockEntryDraft receipt(int units, int cost, {String date = '2026-01-02'}) =>
      StockEntryDraft(
        kind: StockEntryKind.purchase,
        units: units,
        date: date,
        costMinor: cost,
        cashAccountId: cash.id,
      );
  StockEntryDraft issue(int units, {String date = '2026-01-03'}) =>
      StockEntryDraft(kind: StockEntryKind.stockOut, units: units, date: date);
  SalaryDraft salary(int amount) => SalaryDraft(
    amountMinor: amount,
    period: '2026-01',
    paidOn: '2026-01-10',
    cashAccountId: cash.id,
  );

  Future<BusinessProfit> profit(String id) async => BusinessProfit.forPeriod(
    await repo.business(id),
    await fixture.ledger.snapshot(),
    from: '2026-01-01',
    through: '2026-01-31',
  );
  Future<StockPosition> position() async =>
      (await repo.snapshot()).positions[stockId]!;
  Future<String> worker() => repo.saveWorker(
    businessId: businessId,
    name: 'Synthetic worker',
    notes: '',
    expectedMonthlyMinor: 110,
  );

  test('business profit isolates real journal scope and exact weighted stock cost from cash purchases', () async {
    await repo.moveStock(stockId, 1, receipt(3, 100));
    expect((await profit(businessId)).net, BigInt.zero);
    expect((await position()).costPoolMinor, 100);
    await repo.moveStock(stockId, 2, issue(1));
    await repo.moveStock(stockId, 3, issue(1));
    await repo.cashEntry(
      businessId,
      revenue: true,
      amount: Money.fromMinor(1000),
      accountId: cash.id,
      date: '2026-01-03',
      description: 'Synthetic daily revenue',
    );
    await repo.cashEntry(
      businessId,
      revenue: false,
      amount: Money.fromMinor(70),
      accountId: cash.id,
      date: '2026-01-04',
      description: 'Synthetic operating expense',
    );
    await repo.paySalary(await worker(), 1, salary(100));
    final other = await repo.create(
      name: 'Synthetic second business',
      notes: '',
    );
    await repo.cashEntry(
      other,
      revenue: true,
      amount: Money.fromMinor(1500),
      accountId: cash.id,
      date: '2026-01-05',
      description: 'Synthetic independent revenue',
    );
    await fixture.ledger.recordTransaction(
      kind: EntryKind.expense,
      accountId: cash.id,
      counterAccountId: fixture.ledger.chartId('groceries'),
      amount: Money.fromMinor(250),
      occurredOn: '2026-01-06',
      description: 'Synthetic household expense',
    );
    final result = await profit(businessId),
        business = await repo.business(businessId);
    expect(result.revenue, BigInt.from(1000));
    expect(result.costOfGoods, BigInt.from(67));
    expect(result.salaries, BigInt.from(100));
    expect(result.operatingExpenses, BigInt.from(70));
    expect(result.net, BigInt.from(763));
    expect((await profit(other)).net, BigInt.from(1500));
    expect((await position()).quantity, 1);
    expect((await position()).costPoolMinor, 33);
    expect(
      await fixture.ledger.accountBalance(business.inventoryAccountId),
      BigInt.from(33),
    );
  });

  test('stock correction reverses the latest movement and replaces it in one durable change', () async {
    await repo.moveStock(stockId, 1, receipt(3, 100));
    await repo.moveStock(stockId, 2, issue(1));
    final before = (await repo.snapshot());
    final original = before.activeMovements(stockId).first;
    await expectLater(
      repo.correctStock(
        stockId,
        3,
        before.activeMovements(stockId).last.id,
        'Synthetic stale correction',
      ),
      throwsA(failure),
    );
    await expectLater(
      repo.correctStock(
        stockId,
        3,
        original.id,
        'Synthetic oversell',
        replacement: issue(4),
      ),
      throwsA(failure),
    );
    expect((await position()).quantity, 2);
    expect(
      (await fixture.ledger.detail(original.journalId!)).journal.deletedAtUs,
      isNull,
    );
    final op = uuid.v4();
    await repo.correctStock(
      stockId,
      3,
      original.id,
      'Synthetic corrected issue',
      replacement: issue(2),
      operationId: op,
    );
    expect((await position()).quantity, 1);
    expect((await position()).costPoolMinor, 33);
    expect((await profit(businessId)).costOfGoods, BigInt.from(67));
    final history = (await repo.snapshot()).movements;
    expect(history, hasLength(4));
    expect(history.where((e) => e.reversesId == original.id), hasLength(1));
    expect((await repo.snapshot()).activeMovements(stockId), hasLength(2));
    final row = await (fixture.db.select(
      fixture.db.pendingMutations,
    )..where((t) => t.operationId.equals(op))).getSingle();
    final bundle =
        (jsonDecode(row.payloadJson) as Map<String, dynamic>)['bundle']
            as Map<String, dynamic>;
    expect(bundle['stock_movements'], hasLength(2));
    expect(bundle['journals'], hasLength(3));
    await expectLater(
      fixture.ledger.reverse(
        history.first.journalId!,
        reason: 'Generic bypass',
      ),
      throwsA(failure),
    );
  });

  test(
    'zero-cost stock retains events, duplicate retries and archival history',
    () async {
      final draft = const StockEntryDraft(
        kind: StockEntryKind.opening,
        units: 1,
        date: '2026-01-03',
        costMinor: 0,
      );
      final op = uuid.v4();
      await repo.moveStock(stockId, 1, draft, operationId: op);
      await repo.moveStock(stockId, 1, draft, operationId: op);
      expect((await repo.snapshot()).movements.single.journalId, isNull);
      await expectLater(
        repo.archiveItem(stockId, 2, restore: false),
        throwsA(failure),
      );
      await expectLater(
        repo.moveStock(stockId, 2, issue(1, date: '2026-01-02')),
        throwsA(failure),
      );
      await expectLater(
        repo.saveItem(businessId: businessId, name: 'Same SKU', sku: 'test-01'),
        throwsA(failure),
      );
      await repo.moveStock(stockId, 2, issue(1));
      await repo.archiveItem(stockId, 3, restore: false);
      await repo.archiveItem(stockId, 4, restore: true);
      expect((await repo.snapshot()).movements, hasLength(2));
      expect((await repo.item(stockId)).deletedAtUs, isNull);
      expect((await position()).quantity, 0);
      expect((await position()).costPoolMinor, 0);
    },
  );

  test('actual salary payments can be corrected with both payment histories retained', () async {
    final id = await worker();
    await repo.paySalary(id, 1, salary(50));
    await repo.paySalary(id, 2, salary(60));
    final paid = (await repo.snapshot()).salaries.firstWhere(
      (p) => p.amountMinor == 60,
    );
    final otherWorker = await worker();
    await expectLater(
      repo.correctSalary(
        otherWorker,
        1,
        paid.id,
        'Synthetic cross-worker attempt',
      ),
      throwsA(failure),
    );
    await repo.correctSalary(
      id,
      3,
      paid.id,
      'Synthetic salary correction',
      replacement: salary(62),
    );
    expect((await profit(businessId)).salaries, BigInt.from(112));
    final result = await repo.snapshot();
    expect(result.salaries, hasLength(3));
    expect(
      (await fixture.ledger.detail(paid.journalId)).journal.deletedAtUs,
      isNotNull,
    );
    await repo.archiveWorker(id, 4, restore: false);
    await expectLater(repo.paySalary(id, 5, salary(1)), throwsA(failure));
    expect((await profit(businessId)).salaries, BigInt.from(112));
    await repo.archiveWorker(id, 5, restore: true);
    expect((await repo.worker(id)).monthlySalaryMinor, 110);
  });

  test('outbox failures and concurrent issues keep the stock projection and ledger balanced', () async {
    await fixture.db.customStatement(
      '''CREATE TRIGGER synthetic_stock_failure BEFORE INSERT ON pending_mutations
      WHEN NEW.entity_type = 'stock' BEGIN SELECT RAISE(ABORT, 'Synthetic failure'); END''',
    );
    final before = await fixture.ledger.snapshot();
    await expectLater(
      repo.moveStock(stockId, 1, receipt(2, 100)),
      throwsA(failure),
    );
    expect((await repo.item(stockId)).revision, 1);
    expect((await position()).quantity, 0);
    expect((await repo.snapshot()).movements, isEmpty);
    expect(
      (await fixture.ledger.snapshot()).journals.length,
      before.journals.length,
    );
    await fixture.db.customStatement('DROP TRIGGER synthetic_stock_failure');
    await repo.moveStock(stockId, 1, receipt(2, 100));
    final results = await Future.wait(
      List.generate(2, (_) async {
        try {
          await repo.moveStock(stockId, 2, issue(2));
          return true;
        } on AppFailure {
          return false;
        }
      }),
    );
    expect(results.where((v) => v), hasLength(1));
    expect((await position()).quantity, 0);
    expect((await profit(businessId)).costOfGoods, BigInt.from(100));
    expect(
      await fixture.db.customSelect('PRAGMA foreign_key_check').get(),
      isEmpty,
    );
  });
}
