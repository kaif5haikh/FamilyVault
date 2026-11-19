import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:familyvault/core/database/app_database.dart';
import 'package:familyvault/core/errors/app_failure.dart';
import 'package:familyvault/core/finance/money.dart';
import 'package:familyvault/core/security/vault_identity.dart';
import 'package:familyvault/core/sync/canonical_json.dart';
import 'package:familyvault/core/sync/database_record.dart';
import 'package:familyvault/core/sync/sync_coordinator.dart';
import 'package:familyvault/core/sync/sync_protocol.dart';
import 'package:familyvault/features/assets/data/asset_repository.dart';
import 'package:familyvault/features/auth/cloud_access_gateway.dart';
import 'package:familyvault/features/auth/cloud_cache.dart';
import 'package:familyvault/features/business/data/business_repository.dart';
import 'package:familyvault/features/finance/data/ledger_replay.dart';
import 'package:familyvault/features/finance/data/ledger_repository.dart';
import 'package:familyvault/features/liabilities/data/debt_repository.dart';
import 'package:familyvault/features/liabilities/domain/loan_calculator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../support/vault_fixture.dart';

typedef _Client = ({VaultFixture vault, SyncCoordinator sync});

void main() {
  final fixturePath = Platform.environment['FAMILYVAULT_TEST_SUPABASE_FIXTURE'];
  test(
    'two Dart clients exchange exact paise through the local Data API',
    () async {
      final fixture =
          jsonDecode(await File(fixturePath!).readAsString()) as CloudJson;
      final url = Uri.parse(cloudText(fixture, 'url'));
      expect(url.scheme, 'http');
      expect(url.host, '127.0.0.1');
      final family = cloudText(fixture, 'family');
      final originalWarning =
          driftRuntimeOptions.dontWarnAboutMultipleDatabases;
      driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
      addTearDown(
        () => driftRuntimeOptions.dontWarnAboutMultipleDatabases =
            originalWarning,
      );
      final clients = <_Client>[];
      for (final user in cloudRows(fixture['users'])) {
        final client = SupabaseClient(
          url.toString(),
          'synthetic-local-client',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
        );
        addTearDown(client.dispose);
        final gateway = SupabaseAccessGateway(client);
        await gateway.signIn(
          cloudText(user, 'email'),
          cloudText(user, 'password'),
        );
        expect(gateway.sessionId, isA<String>());
        final device = DeviceProof(
          cloudText(user, 'p_device'),
          cloudText(user, 'p_proof'),
        );
        await gateway.bind(device);
        final workspace = await gateway.workspace(device);
        final identity = VaultIdentity(
          familyId: family,
          memberId: cloudText(workspace, 'member_id'),
          deviceId: device.deviceId,
          mode: 'cloud',
        );
        final vault = await VaultFixture.create(
          bootstrap: false,
          identity: identity,
        );
        addTearDown(vault.dispose);
        final metadata = CloudDirectory.verify(workspace, identity);
        final chart = await gateway.chart(device);
        await vault.db.transaction(() async {
          await metadata.apply(vault.db);
          await vault.db.batch(
            (batch) => batch.insertAll(vault.db.ledgerAccounts, [
              for (final row in chart)
                readDatabaseRecord(row, LedgerAccount.fromJson),
            ]),
          );
        });
        final sync = SyncCoordinator(
          db: vault.db,
          identity: identity,
          transport: gateway.syncTransport(device),
          apply: LedgerReplay(vault.db, family).apply,
        );
        addTearDown(sync.stop);
        await sync.run();
        clients.add((vault: vault, sync: sync));
      }
      final first = clients.first, second = clients.last;
      expect(
        first.vault.identity.memberId == second.vault.identity.memberId,
        isFalse,
      );
      const amount = 9007199254740993;
      final account = await first.vault.ledger.createAccount(
        name: 'Synthetic mobile bank',
        kind: AccountKind.asset,
        subtype: 'bank',
        openingBalance: Money.fromMinor(amount),
      );
      await first.sync.run();
      await second.sync.run();
      final posted = (await second.vault.ledger.snapshot())
          .balances()[account.id];
      expect(posted, BigInt.from(amount));
      final received = await second.vault.ledger.account(account.id);
      expect(received.createdBy, first.vault.identity.memberId);
      await second.vault.ledger.renameAccount(
        account.id,
        'Synthetic member edit',
        received.revision,
      );
      await second.sync.run();
      await first.sync.run();
      final renamed = await first.vault.ledger.account(account.id);
      expect(renamed.name, 'Synthetic member edit');
      expect(renamed.createdBy, first.vault.identity.memberId);
      expect(renamed.updatedBy, second.vault.identity.memberId);
      for (final client in clients) {
        final outbox = await client.vault.db
            .select(client.vault.db.pendingMutations)
            .get();
        expect(outbox.single.state, 'acknowledged');
        expect(outbox.single.acceptedRevision, greaterThan(0));
      }

      final local = AssetRepository(first.vault.ledger);
      final remote = AssetRepository(second.vault.ledger);
      const property = PropertyDraft(
        city: 'Mumbai',
        location: 'Synthetic site',
      );
      final holding = await local.create(
        AssetDraft(
          name: 'Synthetic property',
          kind: AssetKind.property,
          property: const PropertyDraft(
            city: 'Mumbai',
            location: 'Synthetic site',
            areaMilli: 7500,
            areaUnit: 'm²',
          ),
          familyOwnershipBps: 5000,
          purchaseTotalMinor: 3001,
          purchasedOn: '2026-01-01',
          fundingAccountId: account.id,
          currentTotalMinor: amount,
          valuedOn: '2026-04-01',
          owners: [
            OwnerDraft(
              'Synthetic creator',
              2500,
              memberId: first.vault.identity.memberId,
            ),
          ],
        ),
      );
      final pending = await (first.vault.db.select(
        first.vault.db.pendingMutations,
      )..where((t) => t.entityId.equals(holding))).getSingle();
      final envelope = SyncEnvelope.verify(
        pending.payloadJson,
        pending.payloadDigest,
      );
      final quotes = envelope.bundle['valuations']! as List<Object?>;
      final invalid = canonicalJson({
        ...envelope.fields,
        'bundle': {
          ...envelope.bundle,
          'valuations': [
            syncObject(quotes.first),
            {...syncObject(quotes.last), 'family_value_minor': 1},
          ],
        },
      });
      await expectLater(
        first.sync.transport.push(
          SyncEnvelope.verify(invalid, payloadDigest(invalid)),
        ),
        throwsA(
          isA<AppFailure>().having(
            (error) => error.code,
            'code',
            FailureCode.validation,
          ),
        ),
      );
      await first.sync.run();
      final receipt = await first.sync.transport.push(envelope);
      expect(receipt.operationId, pending.operationId);
      await second.sync.run();
      final shared = await remote.snapshot();
      expect(shared.latest(holding)!.familyValueMinor, 4503599627370497);
      final sharedAsset = await remote.asset(holding);
      expect(sharedAsset.createdBy, first.vault.identity.memberId);
      expect(shared.properties.single.city, 'Mumbai');

      await remote.edit(
        holding,
        sharedAsset.revision,
        name: 'Synthetic corrected property',
        notes: 'Synthetic test metadata',
        property: property,
        owners: [
          OwnerDraft(
            'Synthetic editor',
            3000,
            memberId: second.vault.identity.memberId,
          ),
        ],
      );
      await remote.value(
        holding,
        (await remote.asset(holding)).revision,
        total: Money.fromMinor(6001),
        valuedOn: '2026-02-01',
        notes: 'Synthetic backdated quote',
      );
      await remote.changeOwnership(
        holding,
        (await remote.asset(holding)).revision,
        shareBps: 6000,
        wholeValue: Money.fromMinor(100001),
        effectiveOn: '2026-05-01',
        reason: 'Synthetic ownership change',
      );
      await remote.recordRent(
        holding,
        (await remote.asset(holding)).revision,
        amount: Money.fromMinor(5100),
        accountId: account.id,
        receivedOn: '2026-06-01',
        description: 'Synthetic rent',
      );
      final rent =
          await (second.vault.db.select(second.vault.db.aggregateJournalLinks)
                ..where(
                  (t) =>
                      t.aggregateId.equals(holding) & t.purpose.equals('rent'),
                ))
              .getSingle();
      await second.sync.run();
      final rentRevision = (await remote.asset(holding)).revision;
      await remote.reverseRent(
        holding,
        rentRevision,
        rent.journalId,
        'Synthetic rent correction',
      );
      final rentCorrection =
          await (second.vault.db.select(second.vault.db.pendingMutations)
                ..where(
                  (t) =>
                      t.entityId.equals(holding) &
                      t.baseRevision.equals(rentRevision),
                ))
              .getSingle();
      final stagedCorrection = SyncEnvelope.verify(
        rentCorrection.payloadJson,
        rentCorrection.payloadDigest,
      );
      final journalRows = stagedCorrection.bundle['journals']! as List<Object?>;
      final original = syncObject(journalRows.first),
          reversal = syncObject(journalRows.last);
      final wrongScope = canonicalJson({
        ...stagedCorrection.fields,
        'entity_id': reversal['id'],
        'entity_type': 'journal_reversal',
        'base_revision': 1,
        'record': reversal,
        'bundle': {'original': original},
      });
      await expectLater(
        second.sync.transport.push(
          SyncEnvelope.verify(wrongScope, payloadDigest(wrongScope)),
        ),
        throwsA(
          isA<AppFailure>().having(
            (error) => error.code,
            'code',
            FailureCode.unauthorized,
          ),
        ),
      );
      await remote.close(
        holding,
        (await remote.asset(holding)).revision,
        closedOn: '2026-07-01',
        proceeds: Money.fromMinor(50875),
        accountId: account.id,
        reason: 'Synthetic disposal',
      );
      await second.sync.run();
      await first.sync.run();
      final closed = await local.asset(holding);
      expect(closed.createdBy, first.vault.identity.memberId);
      expect(closed.updatedBy, second.vault.identity.memberId);
      expect(closed.closedOn, '2026-07-01');
      expect(
        await first.vault.ledger.accountBalance(closed.accountId),
        BigInt.zero,
      );
      final recorded = await local.snapshot();
      expect(recorded.properties.single.areaMilli, isNull);
      expect(
        recorded.owners.where((owner) => owner.deletedAtUs != null),
        hasLength(1),
      );
      expect(recorded.latest(holding)!.familyValueMinor, 60001);
      expect(
        recorded.valuations.where((quote) => quote.source == 'carry_forward'),
        hasLength(1),
      );

      await local.value(
        holding,
        closed.revision,
        total: Money.fromMinor(120001),
        valuedOn: '2026-07-01',
        notes: 'Synthetic final-day quote',
      );
      await local.undoClose(
        holding,
        (await local.asset(holding)).revision,
        reason: 'Synthetic disposal correction',
      );
      final gold = await local.create(
        const AssetDraft(
          name: 'Synthetic gold',
          kind: AssetKind.gold,
          metal: MetalDraft(
            metal: 'gold',
            weightMg: 2000,
            purityPpm: 1000000,
            purityKind: 'nominal',
            karat: 24,
          ),
        ),
      );
      await local.value(
        gold,
        (await local.asset(gold)).revision,
        total: Money.fromMinor(401),
        valuedOn: '2026-07-01',
        notes: 'Synthetic metal quote',
        metalRate: Money.fromMinor(200),
        quotePurityPpm: 997500,
      );
      await first.sync.run();
      await second.sync.run();
      final restored = await remote.asset(holding);
      expect(restored.closedOn, isNull);
      expect(
        await second.vault.ledger.accountBalance(restored.accountId),
        BigInt.from(72001),
      );
      expect((await remote.snapshot()).latest(gold)!.familyValueMinor, 401);
      await _sharedLoans(first, second, account.id);
      await _sharedBusiness(first, second, account.id);
      final beforeRace = restored.revision;
      await local.edit(
        holding,
        beforeRace,
        name: 'Synthetic accepted edit',
        notes: '',
        owners: [],
        property: property,
      );
      await remote.edit(
        holding,
        beforeRace,
        name: 'Synthetic outdated edit',
        notes: '',
        owners: [],
        property: property,
      );
      await first.sync.run();
      await expectLater(
        second.sync.run(),
        throwsA(
          isA<AppFailure>().having(
            (error) => error.code,
            'code',
            FailureCode.conflict,
          ),
        ),
      );
      expect((await local.asset(holding)).name, 'Synthetic accepted edit');
      final conflicts = await second.vault.db
          .select(second.vault.db.syncConflicts)
          .get();
      expect(conflicts, isNotEmpty);
    },
    skip: fixturePath == null
        ? 'Start the isolated provider check with --mobile'
        : false,
  );
}

Future<void> _sharedLoans(_Client first, _Client second, String cash) async {
  final local = DebtRepository(first.vault.ledger);
  final remote = DebtRepository(second.vault.ledger);
  final loan = await local.create(
    DebtDraft(
      name: 'Synthetic bank loan',
      direction: DebtDirection.bankLoan,
      counterparty: 'Synthetic bank',
      principalMinor: 50001,
      startedOn: '2026-02-01',
      cashAccountId: cash,
      terms: const DebtTerms(
        method: InterestMethod.reducingMonthly,
        annualRateBps: 1200,
        termMonths: 12,
        emiMinor: 4400,
        firstDueOn: '2026-03-01',
      ),
    ),
  );
  await first.sync.run();
  await second.sync.run();
  final original = await remote.contract(loan);
  expect(original.createdBy, first.vault.identity.memberId);
  expect(original.principalMinor, 50001);
  await remote.edit(
    loan,
    original.revision,
    name: 'Synthetic revised loan',
    counterparty: 'Synthetic bank',
    terms: const DebtTerms(),
    notes: 'Synthetic terms change',
  );
  await second.sync.run();
  final revised = await remote.contract(loan);
  await remote.repay(
    loan,
    revised.revision,
    RepaymentDraft(
      principalMinor: 12001,
      interestMinor: 750,
      accountId: cash,
      paidOn: '2026-04-01',
    ),
  );
  final attempted =
      await (second.vault.db.select(second.vault.db.pendingMutations)..where(
            (t) =>
                t.entityId.equals(loan) &
                t.baseRevision.equals(revised.revision),
          ))
          .getSingle();
  final envelope = SyncEnvelope.verify(
    attempted.payloadJson,
    attempted.payloadDigest,
  );
  final payment = syncObject(
    (envelope.bundle['repayments']! as List<Object?>).single,
  );
  final invalid = canonicalJson({
    ...envelope.fields,
    'bundle': {
      ...envelope.bundle,
      'repayments': [
        {...payment, 'principal_minor': 60001},
      ],
    },
  });
  await expectLater(
    second.sync.transport.push(
      SyncEnvelope.verify(invalid, payloadDigest(invalid)),
    ),
    throwsA(
      isA<AppFailure>().having(
        (error) => error.code,
        'code',
        FailureCode.validation,
      ),
    ),
  );
  final firstPayment = (await remote.snapshot()).repayments.single;
  await remote.correctRepayment(
    loan,
    (await remote.contract(loan)).revision,
    firstPayment.id,
    'Synthetic payment correction',
    RepaymentDraft(
      principalMinor: 15001,
      interestMinor: 701,
      accountId: cash,
      paidOn: '2026-04-01',
    ),
  );
  await second.sync.run();
  await first.sync.run();
  final corrected = await local.contract(loan);
  expect(corrected.updatedBy, second.vault.identity.memberId);
  expect(corrected.annualRateBps, isNull);
  expect(corrected.firstDueOn, isNull);
  expect(
    await first.vault.ledger.accountBalance(corrected.accountId),
    BigInt.from(-35000),
  );
  expect(
    (await first.vault.ledger.detail(firstPayment.journalId))
        .journal
        .deletedAtUs,
    isNotNull,
  );

  await local.correctPrincipal(
    loan,
    corrected.revision,
    principalMinor: 55001,
    startedOn: '2026-01-15',
    cashAccountId: cash,
    reason: 'Synthetic principal correction',
  );
  await first.sync.run();
  await second.sync.run();
  final opening = await remote.contract(loan);
  expect(
    await second.vault.ledger.accountBalance(opening.accountId),
    BigInt.from(-40000),
  );
  await remote.repay(
    loan,
    opening.revision,
    RepaymentDraft(
      principalMinor: 40000,
      interestMinor: 100,
      accountId: cash,
      paidOn: '2026-05-01',
    ),
  );
  await remote.archive(
    loan,
    (await remote.contract(loan)).revision,
    restore: false,
  );
  await second.sync.run();
  await first.sync.run();
  expect((await local.contract(loan)).deletedAtUs, isNotNull);
  await remote.archive(
    loan,
    (await remote.contract(loan)).revision,
    restore: true,
  );
  await second.sync.run();
  await first.sync.run();
  final settled = await local.contract(loan);
  expect(settled.deletedAtUs, isNull);
  expect(
    await first.vault.ledger.accountBalance(settled.accountId),
    BigInt.zero,
  );
  expect(
    (await local.snapshot()).repayments.where((row) => row.contractId == loan),
    hasLength(3),
  );

  final lent = await local.create(
    const DebtDraft(
      name: 'Synthetic lent balance',
      direction: DebtDirection.lent,
      counterparty: 'Synthetic borrower',
      principalMinor: 901,
      startedOn: '2026-01-02',
    ),
  );
  await local.repay(
    lent,
    (await local.contract(lent)).revision,
    RepaymentDraft(
      principalMinor: 301,
      interestMinor: 5,
      accountId: cash,
      paidOn: '2026-05-02',
    ),
  );
  await first.sync.run();
  await second.sync.run();
  final receivable = await remote.contract(lent);
  expect(
    await second.vault.ledger.accountBalance(receivable.accountId),
    BigInt.from(600),
  );
}

Future<void> _sharedBusiness(_Client first, _Client second, String cash) async {
  final local = BusinessRepository(first.vault.ledger);
  final remote = BusinessRepository(second.vault.ledger);
  final shop = await local.create(
    name: 'Synthetic tyre shop',
    notes: 'Synthetic business profile',
  );
  final revenue = await local.cashEntry(
    shop,
    revenue: true,
    amount: Money.fromMinor(100001),
    accountId: cash,
    date: '2026-07-10',
    description: 'Synthetic cash revenue',
  );
  final expense = await local.cashEntry(
    shop,
    revenue: false,
    amount: Money.fromMinor(1001),
    accountId: cash,
    date: '2026-07-10',
    description: 'Synthetic operating expense',
  );
  await first.sync.run();
  await second.sync.run();
  final shared = await remote.business(shop);
  expect(shared.createdBy, first.vault.identity.memberId);
  expect((await second.vault.ledger.detail(revenue)).journal.businessId, shop);
  await remote.edit(
    shop,
    shared.revision,
    name: 'Synthetic renamed shop',
    notes: '',
  );
  final corrected = await second.vault.ledger.correct(
    expense,
    kind: EntryKind.expense,
    accountId: cash,
    counterAccountId: second.vault.ledger.chartId('business_expense'),
    amount: Money.fromMinor(2502),
    occurredOn: '2026-07-10',
    description: 'Synthetic corrected expense',
    reason: 'Synthetic cash correction',
  );
  await second.sync.run();
  await first.sync.run();
  final updated = await local.business(shop);
  expect(updated.name, 'Synthetic renamed shop');
  expect(updated.updatedBy, second.vault.identity.memberId);
  expect(
    (await first.vault.ledger.account(updated.inventoryAccountId)).name,
    'Synthetic renamed shop · Inventory',
  );
  expect(
    (await first.vault.ledger.detail(expense)).journal.deletedAtUs,
    isNotNull,
  );
  expect((await first.vault.ledger.detail(corrected)).journal.businessId, shop);
  final profit = BusinessProfit.forPeriod(
    updated,
    await first.vault.ledger.snapshot(),
    from: '2026-07-01',
    through: '2026-07-31',
  );
  expect(profit.revenue, BigInt.from(100001));
  expect(profit.operatingExpenses, BigInt.from(2502));
  expect(profit.net, BigInt.from(97499));
}
