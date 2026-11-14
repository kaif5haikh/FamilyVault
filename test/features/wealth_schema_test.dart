import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:familyvault/core/database/app_database.dart';
import 'package:familyvault/features/finance/data/ledger_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import '../support/vault_fixture.dart';

void main() {
  late VaultFixture f;
  const uuid = Uuid();
  setUp(() async {
    f = await VaultFixture.create();
  });
  tearDown(() => f.dispose());

  Future<String> asset(String kind, {int share = 10000}) async {
    final account = await f.ledger.createAccount(
      name: 'Synthetic holding account',
      kind: AccountKind.asset,
      subtype: kind,
    );
    final id = uuid.v4(), i = f.identity;
    await f.db
        .into(f.db.wealthAssets)
        .insert(
          WealthAssetsCompanion.insert(
            id: id,
            familyId: i.familyId,
            createdBy: i.memberId,
            updatedBy: i.memberId,
            createdAtUs: 0,
            updatedAtUs: 0,
            name: 'Synthetic holding',
            kind: kind,
            accountId: account.id,
            familyOwnershipBps: share,
            purchaseOwnershipBps: share,
          ),
        );
    return id;
  }

  Future<({String id, String inventory, String cost, String salary})>
  business() async {
    final inventory = await f.ledger.createAccount(
      name: 'Synthetic stock',
      kind: AccountKind.asset,
      subtype: 'inventory',
    );
    final cost = await f.ledger.createAccount(
      name: 'Synthetic cost of goods',
      kind: AccountKind.expense,
      subtype: 'cost_of_goods',
    );
    final salary = await f.ledger.createAccount(
      name: 'Synthetic salaries',
      kind: AccountKind.expense,
      subtype: 'salary',
    );
    final id = uuid.v4(), i = f.identity;
    await f.db
        .into(f.db.businesses)
        .insert(
          BusinessesCompanion.insert(
            id: id,
            familyId: i.familyId,
            createdBy: i.memberId,
            updatedBy: i.memberId,
            createdAtUs: 0,
            updatedAtUs: 0,
            name: 'Synthetic business',
            notes: '',
            inventoryAccountId: inventory.id,
            costOfGoodsAccountId: cost.id,
            salaryAccountId: salary.id,
          ),
        );
    return (id: id, inventory: inventory.id, cost: cost.id, salary: salary.id);
  }

  test('ownership cannot exceed the family share and valuation rounding stays exact', () async {
    final id = await asset('property', share: 5000), i = f.identity;
    Future<void> owner(int share) async => f.db
        .into(f.db.assetOwnerships)
        .insert(
          AssetOwnershipsCompanion.insert(
            id: uuid.v4(),
            familyId: i.familyId,
            createdBy: i.memberId,
            updatedBy: i.memberId,
            createdAtUs: 0,
            updatedAtUs: 0,
            assetId: id,
            ownerLabel: 'Synthetic family owner',
            shareBps: share,
          ),
        );
    await owner(4000);
    await expectLater(owner(2000), throwsA(anything));
    await owner(1000);
    await expectLater(
      (f.db.update(f.db.wealthAssets)..where((t) => t.id.equals(id))).write(
        const WealthAssetsCompanion(
          familyOwnershipBps: Value(3999),
          revision: Value(2),
        ),
      ),
      throwsA(anything),
    );
    final holding = await (f.db.select(
      f.db.wealthAssets,
    )..where((t) => t.id.equals(id))).getSingle();
    expect(holding.familyOwnershipBps, 5000);
    final journal = await f.ledger.postJournal(
      kind: EntryKind.adjustment,
      occurredOn: '2026-11-01',
      description: 'Synthetic valuation',
      relatedEntityId: id,
      postings: [
        PostingInput(holding.accountId, 1),
        PostingInput(f.ledger.chartId('opening'), -1),
      ],
    );
    Future<void> observation(int value, {String? linkedJournal}) async => f.db
        .into(f.db.assetValuations)
        .insert(
          AssetValuationsCompanion.insert(
            id: uuid.v4(),
            familyId: i.familyId,
            createdBy: i.memberId,
            deviceId: i.deviceId,
            createdAtUs: 0,
            assetId: id,
            assetRevision: 1,
            journalId: Value(linkedJournal),
            valuedOn: '2026-11-01',
            totalValueMinor: 1,
            familyValueMinor: value,
            previousFamilyValueMinor: 0,
            ownershipBps: 5000,
            source: 'manual',
            notes: 'Synthetic one-paise observation',
          ),
        );
    await expectLater(
      observation(0, linkedJournal: journal),
      throwsA(anything),
    );
    await expectLater(observation(1), throwsA(anything));
    await observation(1, linkedJournal: journal);
    expect(
      (await f.db.select(f.db.assetValuations).get()).single.familyValueMinor,
      1,
    );
    await expectLater(
      f.db.customStatement(
        'UPDATE asset_valuations SET family_value_minor = 0',
      ),
      throwsA(anything),
    );
    await expectLater(
      f.db.customStatement('DELETE FROM wealth_assets WHERE id = ?', [id]),
      throwsA(anything),
    );
    expect(await f.db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
  });
  test(
    'metal subtype, nominal karat ratio and unknown purity remain distinct',
    () async {
      final gold = await asset('gold'),
          silver = await asset('silver'),
          i = f.identity;
      MetalDetailsCompanion detail(
        String id, {
        String metal = 'gold',
        int? purity,
        int? karat,
        String kind = 'unrecorded',
      }) => MetalDetailsCompanion.insert(
        assetId: id,
        familyId: i.familyId,
        weightMg: 12345,
        metal: metal,
        purityPpm: Value(purity),
        karat: Value(karat),
        purityKind: Value(kind),
      );
      await expectLater(
        f.db
            .into(f.db.metalDetails)
            .insert(detail(gold, purity: 999000, karat: 22, kind: 'nominal')),
        throwsA(anything),
      );
      await f.db
          .into(f.db.metalDetails)
          .insert(detail(gold, purity: 916667, karat: 22, kind: 'nominal'));
      await expectLater(
        f.db
            .into(f.db.metalDetails)
            .insert(detail(silver, purity: 916667, karat: 22, kind: 'nominal')),
        throwsA(anything),
      );
      await f.db
          .into(f.db.metalDetails)
          .insert(detail(silver, metal: 'silver'));
      final rows = await f.db.select(f.db.metalDetails).get();
      expect(rows.singleWhere((m) => m.assetId == silver).purityPpm, isNull);
      expect(rows.singleWhere((m) => m.assetId == gold).purityKind, 'nominal');
    },
  );
  test('stock event and ledger roll back together; projection prevents negative stock and loses no paise', () async {
    final b = await business(), i = f.identity, item = uuid.v4();
    await f.db
        .into(f.db.stockItems)
        .insert(
          StockItemsCompanion.insert(
            id: item,
            familyId: i.familyId,
            createdBy: i.memberId,
            updatedBy: i.memberId,
            createdAtUs: 0,
            updatedAtUs: 0,
            businessId: b.id,
            name: 'Synthetic tyres',
          ),
        );
    Future<void> move(int quantity, int cost) => f.db.transaction(() async {
      final current = await (f.db.select(
        f.db.stockItems,
      )..where((t) => t.id.equals(item))).getSingle();
      final revision = current.revision + 1;
      await (f.db.update(f.db.stockItems)..where((t) => t.id.equals(item)))
          .write(StockItemsCompanion(revision: Value(revision)));
      String? journal;
      if (cost != 0) {
        journal = await f.ledger.postJournal(
          kind: EntryKind.business,
          occurredOn: '2026-11-01',
          description: 'Synthetic stock event',
          businessId: b.id,
          relatedEntityId: item,
          postings: [
            PostingInput(b.inventory, cost),
            PostingInput(
              cost > 0 ? f.ledger.chartId('opening') : b.cost,
              -cost,
            ),
          ],
        );
      }
      await f.db
          .into(f.db.stockMovements)
          .insert(
            StockMovementsCompanion.insert(
              id: uuid.v4(),
              familyId: i.familyId,
              createdBy: i.memberId,
              deviceId: i.deviceId,
              createdAtUs: 0,
              businessId: b.id,
              stockItemId: item,
              itemRevision: revision,
              journalId: Value(journal),
              occurredOn: '2026-11-01',
              kind: quantity > 0 ? 'opening' : 'stock_out',
              quantityDelta: quantity,
              valueDeltaMinor: cost,
              notes: 'Synthetic movement',
            ),
          );
    });
    await move(3, 100);
    final journalCount = (await f.db.select(f.db.ledgerJournals).get()).length;
    final auditCount = (await f.db.select(f.db.localAuditEvents).get()).length;
    await expectLater(move(-4, -100), throwsA(anything));
    expect((await f.db.select(f.db.ledgerJournals).get()).length, journalCount);
    expect((await f.db.select(f.db.localAuditEvents).get()).length, auditCount);
    var position = (await f.db.select(f.db.stockPositions).get()).single;
    expect(position.quantity, 3);
    expect(position.costPoolMinor, 100);
    await expectLater(
      (f.db.update(f.db.stockItems)..where((t) => t.id.equals(item))).write(
        const StockItemsCompanion(deletedAtUs: Value(0), revision: Value(3)),
      ),
      throwsA(anything),
    );
    await move(-1, -33);
    await move(-2, -67);
    // Large alternating costs cannot overflow an aggregate SUM or become REAL.
    for (var n = 0; n < 2; n++) {
      await move(1, 9223372036854775807);
      await move(-1, -9223372036854775807);
    }
    position = (await f.db.select(f.db.stockPositions).get()).single;
    expect(position.quantity, 0);
    expect(position.costPoolMinor, 0);
    await expectLater(
      f.db.customStatement('DELETE FROM stock_movements'),
      throwsA(anything),
    );
    expect((await f.db.select(f.db.stockPositions).get()).single.quantity, 0);
  });
  test(
    'same-family business boundaries and debt direction are checked in SQL',
    () async {
      final first = await business(), second = await business(), i = f.identity;
      final item = uuid.v4();
      await f.db
          .into(f.db.stockItems)
          .insert(
            StockItemsCompanion.insert(
              id: item,
              familyId: i.familyId,
              createdBy: i.memberId,
              updatedBy: i.memberId,
              createdAtUs: 0,
              updatedAtUs: 0,
              businessId: first.id,
              name: 'Synthetic stock item',
            ),
          );
      await expectLater(
        f.db
            .into(f.db.stockMovements)
            .insert(
              StockMovementsCompanion.insert(
                id: uuid.v4(),
                familyId: i.familyId,
                createdBy: i.memberId,
                deviceId: i.deviceId,
                createdAtUs: 0,
                businessId: second.id,
                stockItemId: item,
                itemRevision: 1,
                occurredOn: '2026-11-01',
                kind: 'opening',
                quantityDelta: 1,
                valueDeltaMinor: 0,
                notes: 'Invalid business association',
              ),
            ),
        throwsA(anything),
      );
      final wrong = await f.ledger.createAccount(
        name: 'Synthetic wrong debt account',
        kind: AccountKind.asset,
        subtype: 'receivable',
      );
      await expectLater(
        f.db
            .into(f.db.debtContracts)
            .insert(
              DebtContractsCompanion.insert(
                id: uuid.v4(),
                familyId: i.familyId,
                createdBy: i.memberId,
                updatedBy: i.memberId,
                createdAtUs: 0,
                updatedAtUs: 0,
                name: 'Synthetic loan',
                direction: 'borrowed',
                counterparty: 'Synthetic lender',
                accountId: wrong.id,
                principalMinor: 10000,
                startedOn: '2026-11-01',
                notes: '',
              ),
            ),
        throwsA(anything),
      );
      final valid = await f.ledger.createAccount(
        name: 'Synthetic loan account',
        kind: AccountKind.liability,
        subtype: 'loan',
      );
      await f.db
          .into(f.db.debtContracts)
          .insert(
            DebtContractsCompanion.insert(
              id: uuid.v4(),
              familyId: i.familyId,
              createdBy: i.memberId,
              updatedBy: i.memberId,
              createdAtUs: 0,
              updatedAtUs: 0,
              name: 'Synthetic loan',
              direction: 'borrowed',
              counterparty: 'Synthetic lender',
              accountId: valid.id,
              principalMinor: 10000,
              startedOn: '2026-11-01',
              notes: '',
            ),
          );
      expect(
        (await f.db.select(f.db.debtContracts).get()).single.annualRateBps,
        isNull,
      );
      expect(
        await f.db.customSelect('PRAGMA foreign_key_check').get(),
        isEmpty,
      );
    },
  );
  test('stock corrections reverse only the latest active event and retain both histories', () async {
    final b = await business(), i = f.identity, item = uuid.v4();
    await f.db
        .into(f.db.stockItems)
        .insert(
          StockItemsCompanion.insert(
            id: item,
            familyId: i.familyId,
            createdBy: i.memberId,
            updatedBy: i.memberId,
            createdAtUs: 0,
            updatedAtUs: 0,
            businessId: b.id,
            name: 'Synthetic reversible stock',
          ),
        );
    Future<String> event(int units, int cost) => f.db.transaction(() async {
      final before = await (f.db.select(
        f.db.stockItems,
      )..where((t) => t.id.equals(item))).getSingle();
      final revision = before.revision + 1;
      await (f.db.update(f.db.stockItems)..where((t) => t.id.equals(item)))
          .write(StockItemsCompanion(revision: Value(revision)));
      final journal = await f.ledger.postJournal(
        kind: EntryKind.business,
        occurredOn: '2026-11-01',
        description: 'Synthetic stock correction fixture',
        businessId: b.id,
        relatedEntityId: item,
        postings: [
          PostingInput(b.inventory, cost),
          PostingInput(cost > 0 ? f.ledger.chartId('opening') : b.cost, -cost),
        ],
      );
      final id = uuid.v4();
      await f.db
          .into(f.db.stockMovements)
          .insert(
            StockMovementsCompanion.insert(
              id: id,
              familyId: i.familyId,
              createdBy: i.memberId,
              deviceId: i.deviceId,
              createdAtUs: 0,
              businessId: b.id,
              stockItemId: item,
              itemRevision: revision,
              journalId: Value(journal),
              occurredOn: '2026-11-01',
              kind: units > 0 ? 'opening' : 'stock_out',
              quantityDelta: units,
              valueDeltaMinor: cost,
              notes: 'Synthetic event',
            ),
          );
      return id;
    });
    Future<void> reverse(String id) => f.db.transaction(() async {
      final original = await (f.db.select(
        f.db.stockMovements,
      )..where((t) => t.id.equals(id))).getSingle();
      final before = await (f.db.select(
        f.db.stockItems,
      )..where((t) => t.id.equals(item))).getSingle();
      final revision = before.revision + 1;
      await (f.db.update(f.db.stockItems)..where((t) => t.id.equals(item)))
          .write(StockItemsCompanion(revision: Value(revision)));
      final journal = await f.ledger.reverse(
        original.journalId!,
        reason: 'Synthetic inventory correction',
      );
      await f.db
          .into(f.db.stockMovements)
          .insert(
            StockMovementsCompanion.insert(
              id: uuid.v4(),
              familyId: i.familyId,
              createdBy: i.memberId,
              deviceId: i.deviceId,
              createdAtUs: 0,
              businessId: b.id,
              stockItemId: item,
              itemRevision: revision,
              journalId: Value(journal),
              reversesId: Value(id),
              occurredOn: original.occurredOn,
              kind: 'reversal',
              quantityDelta: -original.quantityDelta,
              valueDeltaMinor: -original.valueDeltaMinor,
              notes: 'Synthetic inverse event',
            ),
          );
    });
    final incoming = await event(3, 100), outgoing = await event(-1, -33);
    await expectLater(reverse(incoming), throwsA(anything));
    expect((await f.db.select(f.db.ledgerJournals).get()).length, 2);
    await reverse(outgoing);
    expect((await f.db.select(f.db.stockPositions).get()).single.quantity, 3);
    await reverse(incoming);
    final position = (await f.db.select(f.db.stockPositions).get()).single;
    expect(position.quantity, 0);
    expect(position.costPoolMinor, 0);
    expect((await f.db.select(f.db.stockMovements).get()).length, 4);
    expect((await f.ledger.snapshot()).balances()[b.inventory], BigInt.zero);
    await expectLater(reverse(outgoing), throwsA(anything));
  });
}
