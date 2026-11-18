import 'dart:convert';

import 'package:familyvault/core/database/app_database.dart';
import 'package:familyvault/core/errors/app_failure.dart';
import 'package:familyvault/core/finance/money.dart';
import 'package:familyvault/core/security/vault_identity.dart';
import 'package:familyvault/features/assets/data/asset_repository.dart';
import 'package:familyvault/features/assets/domain/metal_calculator.dart';
import 'package:familyvault/features/finance/data/ledger_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import '../support/vault_fixture.dart';

void main() {
  late VaultFixture f;
  late AssetRepository assets;
  late LedgerAccount bank;
  const uuid = Uuid();
  final failure = isA<AppFailure>();
  setUp(() async {
    f = await VaultFixture.create();
    assets = AssetRepository(f.ledger);
    bank = await f.ledger.createAccount(
      name: 'Synthetic funding',
      kind: AccountKind.asset,
      subtype: 'bank',
      openingBalance: Money.fromMinor(1000000),
      openedOn: '2026-01-01',
    );
  });
  tearDown(() => f.dispose());
  Future<BigInt> balance(String id, String date) async {
    final a = await assets.asset(id);
    return (await f.ledger.snapshot()).balances(through: date)[a.accountId] ??
        BigInt.zero;
  }

  AssetDraft property({int? cost = 10000, int? current = 20000}) => AssetDraft(
    name: 'Synthetic property',
    kind: AssetKind.property,
    purchaseTotalMinor: cost,
    purchasedOn: cost == null ? null : '2026-01-01',
    currentTotalMinor: current,
    valuedOn: current == null ? null : '2026-01-10',
    familyOwnershipBps: 5000,
    property: const PropertyDraft(
      city: 'Mumbai',
      location: 'Synthetic location',
      areaMilli: 123456,
      areaUnit: 'square feet',
    ),
    owners: const [OwnerDraft('Synthetic family allocation', 5000)],
  );

  test('acquisition and valuation are one exact idempotent aggregate with audit and child scope', () async {
    final before = (await f.db.select(f.db.pendingMutations).get()).length;
    final op = uuid.v4(), draft = property();
    final id = await assets.create(draft, operationId: op);
    expect(await assets.create(draft, operationId: op), id);
    expect((await f.db.select(f.db.pendingMutations).get()).length, before + 1);
    final a = await assets.asset(id), s = await assets.snapshot();
    expect(a.familyOwnershipBps, 5000);
    expect(s.properties.single.areaMilli, 123456);
    expect(s.owners.single.shareBps, 5000);
    expect(await balance(id, '2026-01-01'), BigInt.from(5000));
    expect(await balance(id, '2026-01-10'), BigInt.from(10000));
    final mutation = await (f.db.select(
      f.db.pendingMutations,
    )..where((t) => t.operationId.equals(op))).getSingle();
    final payload = jsonDecode(mutation.payloadJson) as Map<String, dynamic>;
    expect(payload['record']['created_by'], f.identity.memberId);
    expect(payload['bundle']['journals'], hasLength(2));
    expect(
      payload['bundle']['accounts'],
      hasLength(2),
    ); // holding + valuation reserve
    expect(payload['bundle']['valuations'], hasLength(2));
    expect(payload['bundle']['property']['asset_id'], id);
    expect((await f.ledger.snapshot()).total(AccountKind.income), BigInt.zero);
    expect((await f.ledger.snapshot()).total(AccountKind.expense), BigInt.zero);
    await expectLater(
      assets.create(
        const AssetDraft(name: 'Changed retry', kind: AssetKind.other),
        operationId: op,
      ),
      throwsA(failure),
    );
    expect((await assets.snapshot()).assets, hasLength(1));
  });

  test('funded purchases reduce cash once; unknown value is distinct from recorded zero', () async {
    final id = await assets.create(
      AssetDraft(
        name: 'Synthetic vehicle',
        kind: AssetKind.vehicle,
        purchaseTotalMinor: 150000,
        purchasedOn: '2026-02-01',
        fundingAccountId: bank.id,
      ),
    );
    expect(
      (await f.ledger.snapshot()).balances()[bank.id],
      BigInt.from(850000),
    );
    expect(await balance(id, '2026-02-01'), BigInt.from(150000));
    final unknown = await assets.create(
      const AssetDraft(name: 'Unvalued holding', kind: AssetKind.other),
    );
    final zero = await assets.create(
      const AssetDraft(
        name: 'Known zero',
        kind: AssetKind.other,
        currentTotalMinor: 0,
        valuedOn: '2026-02-01',
      ),
    );
    expect((await assets.asset(unknown)).valuationState, 'unrecorded');
    expect((await assets.asset(zero)).valuationState, 'recorded');
    expect(
      (await assets.snapshot()).valuations
          .where((v) => v.assetId == zero)
          .single
          .familyValueMinor,
      0,
    );
    expect(
      (await assets.snapshot()).valuations.where((v) => v.assetId == unknown),
      isEmpty,
    );
  });

  test('backdated and same-day corrections preserve every later known quote and exact period balances', () async {
    final id = await assets.create(property());
    await assets.value(
      id,
      1,
      total: Money.fromMinor(30000),
      valuedOn: '2026-01-20',
      notes: 'Synthetic later value',
    );
    await assets.value(
      id,
      2,
      total: Money.fromMinor(15000),
      valuedOn: '2026-01-05',
      notes: 'Synthetic backdated quote',
    );
    expect(await balance(id, '2026-01-04'), BigInt.from(5000));
    expect(await balance(id, '2026-01-05'), BigInt.from(7500));
    expect(await balance(id, '2026-01-10'), BigInt.from(10000));
    expect(await balance(id, '2026-01-20'), BigInt.from(15000));
    await assets.value(
      id,
      3,
      total: Money.fromMinor(17000),
      valuedOn: '2026-01-05',
      notes: 'Synthetic correction on same date',
    );
    expect(await balance(id, '2026-01-05'), BigInt.from(8500));
    expect(await balance(id, '2026-01-10'), BigInt.from(10000));
    expect(await balance(id, '2026-01-20'), BigInt.from(15000));
    final s = await assets.snapshot();
    expect(s.latest(id)!.totalValueMinor, 30000);
    expect(
      s.valuations.where((v) => v.source == 'carry_forward'),
      hasLength(2),
    );
    expect(s.valuations, hasLength(7));
    await expectLater(
      assets.value(
        id,
        1,
        total: Money.fromMinor(1),
        valuedOn: '2026-01-06',
        notes: 'Stale edit',
      ),
      throwsA(failure),
    );
  });

  test('closure keeps quote history, backdated quotes keep current balance zero, undo appends reversals', () async {
    final id = await assets.create(property());
    await assets.close(
      id,
      1,
      closedOn: '2026-01-10',
      proceeds: Money.fromMinor(12000),
      accountId: bank.id,
      reason: 'Synthetic sale',
    );
    expect(await balance(id, '2026-01-09'), BigInt.from(5000));
    expect(await balance(id, '2026-01-10'), BigInt.zero);
    expect(
      (await f.ledger.snapshot()).balances()[bank.id],
      BigInt.from(1012000),
    );
    await assets.value(
      id,
      2,
      total: Money.fromMinor(16000),
      valuedOn: '2026-01-05',
      notes: 'Synthetic historical correction after sale',
    );
    expect(await balance(id, '2026-01-05'), BigInt.from(8000));
    expect(
      await balance(id, '2026-01-10'),
      BigInt.zero,
    ); // quote and sale share this date
    await expectLater(
      assets.value(
        id,
        3,
        total: Money.fromMinor(10),
        valuedOn: '2026-01-11',
        notes: 'After sale',
      ),
      throwsA(failure),
    );
    await assets.undoClose(id, 3, reason: 'Synthetic mistaken closure');
    expect((await assets.asset(id)).deletedAtUs, isNull);
    expect(await balance(id, '2026-01-10'), BigInt.from(10000));
    expect(
      (await f.ledger.snapshot()).balances()[bank.id],
      BigInt.from(1000000),
    );
    expect((await assets.snapshot()).valuations, hasLength(4));
    expect(
      (await f.db.select(f.db.ledgerJournals).get()).where(
        (j) => j.kind == 'reversal',
      ),
      hasLength(1),
    );
    expect(await f.db.customSelect('PRAGMA foreign_key_check').get(), isEmpty);
  });

  test(
    'module-owned financial and account mutations reject generic finance paths',
    () async {
      final id = await assets.create(property()), a = await assets.asset(id);
      final journal = (await assets.snapshot()).valuations
          .firstWhere((v) => v.assetId == id)
          .journalId!;
      await expectLater(
        f.ledger.recordTransaction(
          kind: EntryKind.transfer,
          accountId: bank.id,
          counterAccountId: a.accountId,
          amount: Money.fromMinor(1),
          occurredOn: '2026-02-01',
          description: 'Bypass',
        ),
        throwsA(failure),
      );
      await expectLater(
        f.ledger.postJournal(
          kind: EntryKind.adjustment,
          occurredOn: '2026-02-01',
          description: 'Bypass',
          postings: [PostingInput(a.accountId, 1), PostingInput(bank.id, -1)],
        ),
        throwsA(failure),
      );
      await expectLater(
        f.ledger.reverse(journal, reason: 'Bypass'),
        throwsA(failure),
      );
      await expectLater(
        f.ledger.correct(
          journal,
          kind: EntryKind.expense,
          accountId: bank.id,
          counterAccountId: f.ledger.chartId('household'),
          amount: Money.fromMinor(1),
          occurredOn: '2026-02-01',
          description: 'Bypass',
          reason: 'Bypass',
        ),
        throwsA(failure),
      );
      await expectLater(
        f.ledger.renameAccount(a.accountId, 'Bypass', 1),
        throwsA(failure),
      );
      expect(await balance(id, '2026-02-01'), BigInt.from(10000));
    },
  );

  test('outbox failure rolls back all metadata, accounts, postings and immutable audit', () async {
    final before = await f.ledger.snapshot(),
        audit = await f.db.select(f.db.localAuditEvents).get();
    await f.db.customStatement(
      "CREATE TRIGGER synthetic_asset_outbox_failure BEFORE INSERT ON pending_mutations WHEN NEW.entity_type = 'asset' BEGIN SELECT RAISE(ABORT, 'Synthetic failure'); END",
    );
    await expectLater(assets.create(property()), throwsA(failure));
    expect((await assets.snapshot()).assets, isEmpty);
    expect((await assets.snapshot()).properties, isEmpty);
    expect((await assets.snapshot()).valuations, isEmpty);
    expect((await f.ledger.snapshot()).accounts.length, before.accounts.length);
    expect((await f.ledger.snapshot()).postings.length, before.postings.length);
    expect(
      (await f.db.select(f.db.localAuditEvents).get()).length,
      audit.length,
    );
  });

  test('shared member may edit metadata while preserving creator and retaining former ownerships', () async {
    final id = await assets.create(property()),
        member = uuid.v4(),
        device = uuid.v4();
    await f.db
        .into(f.db.familyMembers)
        .insert(
          FamilyMembersCompanion.insert(
            id: member,
            familyId: f.identity.familyId,
            displayName: 'Synthetic second member',
            relationship: 'member',
            role: 'member',
            createdAtUs: 0,
          ),
        );
    await f.db
        .into(f.db.vaultDevices)
        .insert(
          VaultDevicesCompanion.insert(
            id: device,
            familyId: f.identity.familyId,
            memberId: member,
            state: 'enrolled',
            createdAtUs: 0,
          ),
        );
    final other = AssetRepository(
      LedgerRepository(
        f.db,
        VaultIdentity(
          familyId: f.identity.familyId,
          memberId: member,
          deviceId: device,
          mode: 'offline',
        ),
        clock: () => DateTime.utc(2026, 11, 14),
      ),
    );
    await other.edit(
      id,
      1,
      name: 'Synthetic renamed property',
      notes: 'Synthetic details',
      property: const PropertyDraft(
        city: 'Ballia',
        location: 'Synthetic changed location',
      ),
      owners: [
        OwnerDraft('Synthetic shared allocation', 5000, memberId: member),
      ],
    );
    final a = await assets.asset(id), s = await assets.snapshot();
    expect(a.createdBy, f.identity.memberId);
    expect(a.updatedBy, member);
    expect(s.properties.single.city, 'Ballia');
    expect(s.owners, hasLength(2));
    expect(
      s.owners.where((o) => o.deletedAtUs == null).single.memberId,
      member,
    );
    expect((await f.ledger.account(a.accountId)).name, a.name);
    await other.recordRent(
      id,
      2,
      amount: Money.fromMinor(1000),
      accountId: bank.id,
      receivedOn: '2026-03-01',
      description: 'Synthetic rent',
    );
    expect(
      (await f.ledger.snapshot()).total(AccountKind.income),
      BigInt.from(1000),
    );
    expect(await balance(id, '2026-03-01'), BigInt.from(10000));
    await expectLater(
      other.edit(
        id,
        2,
        name: 'Stale name',
        notes: '',
        owners: const [],
        property: const PropertyDraft(city: 'Mumbai', location: ''),
      ),
      throwsA(failure),
    );
  });

  test('metal rate valuations verify exact weight/purity and record their calculation basis', () async {
    final id = await assets.create(
      AssetDraft(
        name: 'Synthetic gold lot',
        kind: AssetKind.gold,
        metal: MetalDraft(
          metal: 'gold',
          weightMg: 12345,
          purityPpm: MetalCalculator.nominalPurity(22),
          purityKind: 'nominal',
          karat: 22,
        ),
      ),
    );
    final rate = Money.fromMinor(700000),
        value = MetalCalculator.estimate(
          weightMg: 12345,
          holdingPurityPpm: MetalCalculator.nominalPurity(22),
          ratePerGram: rate,
          quotePurityPpm: 1000000,
        );
    await expectLater(
      assets.value(
        id,
        1,
        total: value + Money.fromMinor(1),
        valuedOn: '2026-02-01',
        notes: 'Synthetic wrong calculation',
        metalRate: rate,
        quotePurityPpm: 1000000,
      ),
      throwsA(failure),
    );
    await assets.value(
      id,
      1,
      total: value,
      valuedOn: '2026-02-01',
      notes: 'Synthetic nominal estimate',
      metalRate: rate,
      quotePurityPpm: 1000000,
    );
    final v = (await assets.snapshot()).valuations.single;
    expect(v.source, 'metal_rate');
    expect(jsonDecode(v.basisJson)['weight_mg'], 12345);
    expect(await balance(id, '2026-02-01'), BigInt.from(value.minor));
    await expectLater(
      assets.create(
        const AssetDraft(
          name: 'Invalid owners',
          kind: AssetKind.other,
          familyOwnershipBps: 5000,
          owners: [OwnerDraft('Too much', 5001)],
        ),
      ),
      throwsA(failure),
    );
  });

  test('a dated ownership change preserves prior shares and later recorded balances', () async {
    final id = await assets.create(property());
    await assets.changeOwnership(
      id,
      1,
      shareBps: 7500,
      wholeValue: Money.fromMinor(20000),
      effectiveOn: '2026-01-15',
      reason: 'Synthetic transfer of share',
    );
    await assets.value(
      id,
      2,
      total: Money.fromMinor(14000),
      valuedOn: '2026-01-12',
      notes: 'Synthetic earlier appraisal',
    );
    expect(await balance(id, '2026-01-10'), BigInt.from(10000));
    expect(await balance(id, '2026-01-12'), BigInt.from(7000));
    expect(await balance(id, '2026-01-15'), BigInt.from(15000));
    expect((await assets.snapshot()).latest(id)!.ownershipBps, 7500);
    await expectLater(
      assets.changeOwnership(
        id,
        3,
        shareBps: 4999,
        wholeValue: Money.fromMinor(20000),
        effectiveOn: '2026-01-15',
        reason: 'Synthetic overallocated owners',
      ),
      throwsA(failure),
    );
  });

  test('rent correction retains the original fact and reverses income without changing value', () async {
    final id = await assets.create(property());
    await assets.recordRent(
      id,
      1,
      amount: Money.fromMinor(123),
      accountId: bank.id,
      receivedOn: '2026-01-16',
      description: 'Synthetic rent',
    );
    final finance = await f.ledger.snapshot();
    final link = finance.journalLinks.values.singleWhere(
      (l) => l.purpose == 'rent',
    );
    expect(finance.total(AccountKind.income), BigInt.from(123));
    await assets.reverseRent(id, 2, link.journalId, 'Synthetic correction');
    final after = await f.ledger.snapshot();
    expect(after.total(AccountKind.income), BigInt.zero);
    expect(
      after.journals
          .singleWhere((j) => j.reversesId == link.journalId)
          .relatedEntityId,
      id,
    );
    expect(await balance(id, '2026-01-16'), BigInt.from(10000));
  });

  test('simultaneous stale edits admit one complete aggregate without lost updates', () async {
    final id = await assets.create(
      const AssetDraft(
        name: 'Synthetic concurrent holding',
        kind: AssetKind.other,
      ),
    );
    final results = await Future.wait(
      [100, 200].map((n) async {
        try {
          await assets.value(
            id,
            1,
            total: Money.fromMinor(n),
            valuedOn: '2026-02-01',
            notes: 'Synthetic concurrent quote',
          );
          return true;
        } on AppFailure {
          return false;
        }
      }),
    );
    expect(results.where((r) => r), hasLength(1));
    expect((await assets.asset(id)).revision, 2);
    expect((await assets.snapshot()).valuations, hasLength(1));
  });
}
