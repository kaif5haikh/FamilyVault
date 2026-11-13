import 'dart:convert';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:familyvault/core/database/app_database.dart';
import 'package:familyvault/core/errors/app_failure.dart';
import 'package:familyvault/core/finance/money.dart';
import 'package:familyvault/core/security/vault_identity.dart';
import 'package:familyvault/core/sync/canonical_json.dart';
import 'package:familyvault/features/finance/data/ledger_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import '../support/vault_fixture.dart';

void main() {
  late VaultFixture f;
  late LedgerRepository ledger;
  late LedgerAccount cash, bank;
  const uuid = Uuid();
  final validation = isA<AppFailure>().having(
    (e) => e.code,
    'code',
    FailureCode.validation,
  );
  setUp(() async {
    f = await VaultFixture.create();
    ledger = f.ledger;
    cash = await ledger.createAccount(
      name: 'Synthetic cash',
      kind: AccountKind.asset,
      subtype: 'cash',
    );
    bank = await ledger.createAccount(
      name: 'Synthetic bank',
      kind: AccountKind.asset,
      subtype: 'bank',
    );
  });
  tearDown(() async => f.dispose());
  Future<String> income({int amount = 100000, String? operation}) =>
      ledger.recordTransaction(
        kind: EntryKind.income,
        accountId: bank.id,
        counterAccountId: ledger.chartId('salary'),
        amount: Money.fromMinor(amount),
        occurredOn: '2026-11-01',
        description: 'Synthetic income',
        operationId: operation,
      );

  test('metadata starts empty; income, expense, transfer and reports balance exactly', () async {
    expect((await ledger.snapshot()).journals, isEmpty);
    await income();
    await ledger.recordTransaction(
      kind: EntryKind.expense,
      accountId: bank.id,
      counterAccountId: ledger.chartId('groceries'),
      amount: Money.fromMinor(12345),
      occurredOn: '2026-11-02',
      description: 'Synthetic expense',
    );
    await ledger.recordTransaction(
      kind: EntryKind.transfer,
      accountId: bank.id,
      counterAccountId: cash.id,
      amount: Money.fromMinor(20000),
      occurredOn: '2026-11-03',
      description: 'Synthetic transfer',
    );
    final snap = await ledger.snapshot(), balances = snap.balances();
    expect(balances[bank.id], BigInt.from(67655));
    expect(balances[cash.id], BigInt.from(20000));
    expect(snap.total(AccountKind.income), BigInt.from(100000));
    expect(snap.total(AccountKind.expense), BigInt.from(12345));
    expect(balances.values.fold(BigInt.zero, (a, b) => a + b), BigInt.zero);
    final pending = await f.db.select(f.db.pendingMutations).get();
    expect(pending.where((p) => p.entityType == 'journal').length, 3);
    expect(
      pending.every(
        (p) =>
            p.state == 'pending' &&
            payloadDigest(p.payloadJson) == p.payloadDigest,
      ),
      isTrue,
    );
    expect(
      (await f.db.select(f.db.localAuditEvents).get()).length,
      pending.length,
    );
  });

  test('stable operation IDs prevent duplicate postings and reject altered retries', () async {
    final op = uuid.v4();
    final id = await income(operation: op);
    expect(await income(operation: op), id);
    await expectLater(
      income(amount: 100001, operation: op),
      throwsA(
        isA<AppFailure>().having((e) => e.code, 'code', FailureCode.conflict),
      ),
    );
    expect((await ledger.snapshot()).journals.length, 1);
  });

  test('a cancelled entry keeps facts, negates reports, and cannot be reversed twice', () async {
    final id = await income();
    final original = await ledger.detail(id), op = uuid.v4();
    final reverseId = await ledger.reverse(
      id,
      reason: 'Synthetic correction',
      operationId: op,
    );
    expect(
      await ledger.reverse(id, reason: 'Synthetic correction', operationId: op),
      reverseId,
    );
    final snap = await ledger.snapshot();
    expect(snap.journals.length, 2);
    expect(snap.total(AccountKind.income), BigInt.zero);
    expect(
      (await ledger.detail(id)).postings.map((p) => p.amountMinor),
      original.postings.map((p) => p.amountMinor),
    );
    expect((await ledger.detail(id)).journal.deletedAtUs, isNotNull);
    expect((await ledger.detail(reverseId)).journal.reversesId, id);
    await expectLater(
      ledger.reverse(id, reason: 'Duplicate cancellation'),
      throwsA(validation),
    );
    await expectLater(
      ledger.reverse(reverseId, reason: 'Reverse a reversal'),
      throwsA(validation),
    );
  });

  test('correction is one durable aggregate and invalid replacement rolls back reversal', () async {
    final id = await income(), op = uuid.v4();
    await expectLater(
      ledger.correct(
        id,
        kind: EntryKind.income,
        accountId: bank.id,
        counterAccountId: ledger.chartId('salary'),
        amount: Money.fromMinor(40000),
        occurredOn: '2026-02-31',
        description: 'Invalid date',
        reason: 'Fix amount',
      ),
      throwsA(validation),
    );
    expect((await ledger.snapshot()).journals.length, 1);
    expect((await ledger.detail(id)).journal.deletedAtUs, isNull);
    Future<String> correct() => ledger.correct(
      id,
      kind: EntryKind.income,
      accountId: bank.id,
      counterAccountId: ledger.chartId('salary'),
      amount: Money.fromMinor(40000),
      occurredOn: '2026-11-01',
      description: 'Synthetic corrected income',
      reason: 'Fix amount',
      operationId: op,
    );
    expect(await correct(), await correct());
    final snap = await ledger.snapshot();
    expect(snap.journals.length, 3);
    expect(snap.total(AccountKind.income), BigInt.from(40000));
    final mutation = await (f.db.select(
      f.db.pendingMutations,
    )..where((t) => t.operationId.equals(op))).getSingle();
    expect(mutation.entityType, 'journal_correction');
    final bundle = (jsonDecode(mutation.payloadJson) as Map)['bundle'] as Map;
    expect(bundle.keys, containsAll(['original', 'reversal']));
  });

  test('database guards reject direct edits/deletes, imbalance and malformed reversals', () async {
    final id = await income();
    await expectLater(
      f.db.customStatement(
        'UPDATE ledger_journals SET description = ? WHERE id = ?',
        ['tamper', id],
      ),
      throwsA(anything),
    );
    await expectLater(
      f.db.customStatement('DELETE FROM ledger_journals WHERE id = ?', [id]),
      throwsA(anything),
    );
    await expectLater(
      f.db.customStatement(
        'UPDATE ledger_postings SET amount_minor = 1 WHERE journal_id = ?',
        [id],
      ),
      throwsA(anything),
    );
    await expectLater(
      f.db.customStatement('UPDATE ledger_accounts SET kind = ? WHERE id = ?', [
        'expense',
        bank.id,
      ]),
      throwsA(anything),
    );
    final audit = (await f.db.select(f.db.localAuditEvents).get()).first;
    await expectLater(
      f.db.customStatement('DELETE FROM local_audit_events WHERE id = ?', [
        audit.id,
      ]),
      throwsA(anything),
    );
    await expectLater(
      f.db.customStatement(
        'UPDATE local_audit_events SET action = ? WHERE id = ?',
        ['tamper', audit.id],
      ),
      throwsA(anything),
    );
    final draft = uuid.v4();
    await f.db
        .into(f.db.ledgerJournals)
        .insert(
          LedgerJournalsCompanion.insert(
            id: draft,
            familyId: f.identity.familyId,
            createdBy: f.identity.memberId,
            updatedBy: f.identity.memberId,
            createdAtUs: 0,
            updatedAtUs: 0,
            kind: 'expense',
            occurredOn: '2026-11-01',
            description: 'Raw invalid draft',
          ),
        );
    await f.db
        .into(f.db.ledgerPostings)
        .insert(
          LedgerPostingsCompanion.insert(
            id: uuid.v4(),
            familyId: f.identity.familyId,
            journalId: draft,
            accountId: cash.id,
            position: 0,
            amountMinor: 1,
          ),
        );
    await expectLater(
      f.db.customStatement(
        "UPDATE ledger_journals SET status = 'posted' WHERE id = ?",
        [draft],
      ),
      throwsA(anything),
    );
    await f.db
        .into(f.db.ledgerPostings)
        .insert(
          LedgerPostingsCompanion.insert(
            id: uuid.v4(),
            familyId: f.identity.familyId,
            journalId: draft,
            accountId: bank.id,
            position: 1,
            amountMinor: -1,
          ),
        );
    await f.db.customStatement(
      'UPDATE ledger_journals SET kind = ?, reverses_id = ? WHERE id = ?',
      ['reversal', id, draft],
    );
    await expectLater(
      f.db.customStatement(
        "UPDATE ledger_journals SET status = 'posted' WHERE id = ?",
        [draft],
      ),
      throwsA(anything),
    );
  });

  test('outbox failure rolls back postings, journal, and audit together without raw errors', () async {
    final before = (await f.db.select(f.db.localAuditEvents).get()).length;
    await f.db.customStatement(
      "CREATE TRIGGER synthetic_outbox_failure BEFORE INSERT ON pending_mutations WHEN NEW.entity_type = 'journal' BEGIN SELECT RAISE(ABORT, 'sensitive synthetic content'); END",
    );
    await expectLater(
      income(),
      throwsA(
        isA<AppFailure>().having(
          (e) => e.toString(),
          'redacted',
          'AppFailure(storage)',
        ),
      ),
    );
    expect((await ledger.snapshot()).journals, isEmpty);
    expect(await f.db.select(f.db.ledgerPostings).get(), isEmpty);
    expect((await f.db.select(f.db.localAuditEvents).get()).length, before);
  });

  test('independent family member edits preserve creator and audit modifier, revoked device is denied', () async {
    final member = uuid.v4(), device = uuid.v4();
    await f.db
        .into(f.db.familyMembers)
        .insert(
          FamilyMembersCompanion.insert(
            id: member,
            familyId: f.identity.familyId,
            displayName: 'Synthetic member',
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
    final other = LedgerRepository(
      f.db,
      VaultIdentity(
        familyId: f.identity.familyId,
        memberId: member,
        deviceId: device,
        mode: 'offline',
      ),
    );
    final renamed = await other.renameAccount(
      cash.id,
      'Shared edit',
      cash.revision,
    );
    expect(renamed.createdBy, f.identity.memberId);
    expect(renamed.updatedBy, member);
    await expectLater(
      other.renameAccount(cash.id, 'Stale edit', cash.revision),
      throwsA(
        isA<AppFailure>().having((e) => e.code, 'code', FailureCode.conflict),
      ),
    );
    final id = await income();
    await other.reverse(id, reason: 'Shared correction');
    expect((await ledger.detail(id)).journal.updatedBy, member);
    await (f.db.update(f.db.vaultDevices)..where((t) => t.id.equals(device)))
        .write(const VaultDevicesCompanion(state: Value('revoked')));
    await expectLater(
      other.snapshot(),
      throwsA(
        isA<AppFailure>().having(
          (e) => e.code,
          'code',
          FailureCode.unauthorized,
        ),
      ),
    );
  });

  test('cross-family postings fail and no partial journal survives', () async {
    final second = VaultIdentity(
      familyId: uuid.v4(),
      memberId: uuid.v4(),
      deviceId: uuid.v4(),
      mode: 'offline',
    );
    final other = LedgerRepository(f.db, second);
    await other.createOfflineWorkspace(
      familyName: 'Other synthetic workspace',
      ownerName: 'Other test',
    );
    final foreign = await other.createAccount(
      name: 'Other cash',
      kind: AccountKind.asset,
      subtype: 'cash',
    );
    await expectLater(
      ledger.recordTransaction(
        kind: EntryKind.transfer,
        accountId: cash.id,
        counterAccountId: foreign.id,
        amount: Money.fromMinor(1),
        occurredOn: '2026-11-01',
        description: 'Invalid',
      ),
      throwsA(validation),
    );
    expect((await ledger.snapshot()).journals, isEmpty);
  });

  test('large totals use BigInt across journals and reject overflow inside a posting aggregate', () async {
    const max = 9223372036854775807;
    await income(amount: max);
    await income(amount: max);
    expect(
      (await ledger.snapshot()).total(AccountKind.income),
      BigInt.from(max) * BigInt.two,
    );
    await expectLater(
      ledger.postJournal(
        kind: EntryKind.adjustment,
        occurredOn: '2026-11-01',
        description: 'Overflow',
        postings: [
          PostingInput(cash.id, max),
          PostingInput(bank.id, max),
          PostingInput(ledger.chartId('opening'), -max),
          PostingInput(ledger.chartId('opening'), -max),
        ],
      ),
      throwsA(validation),
    );
    expect((await ledger.snapshot()).journals.length, 2);
  });

  test('budgets and reconciliation compare exact ledger balances and require explicit adjustment', () async {
    await income(amount: 100000);
    await ledger.setBudget(
      accountId: ledger.chartId('groceries'),
      month: '2026-11',
      amount: Money.fromMinor(50000),
    );
    await ledger.setBudget(
      accountId: ledger.chartId('groceries'),
      month: '2026-11',
      amount: Money.fromMinor(60000),
    );
    await ledger.reconcile(
      accountId: bank.id,
      statementDate: '2026-11-02',
      statementBalance: Money.fromMinor(99900),
      notes: 'Statement comparison',
    );
    var snap = await ledger.snapshot();
    expect(snap.budgets.single.amountMinor, 60000);
    expect(snap.budgets.single.revision, 2);
    expect(snap.reconciliations.single.ledgerMinor, 100000);
    expect(snap.balances()[bank.id], BigInt.from(100000));
    await ledger.reconcile(
      accountId: bank.id,
      statementDate: '2026-11-02',
      statementBalance: Money.fromMinor(99900),
      notes: 'Explicit adjustment',
      postAdjustment: true,
    );
    snap = await ledger.snapshot();
    expect(snap.balances()[bank.id], BigInt.from(99900));
    expect(snap.total(AccountKind.income), BigInt.from(100000));
    await expectLater(
      ledger.setBudget(
        accountId: cash.id,
        month: '2026-11',
        amount: Money.fromMinor(1),
      ),
      throwsA(validation),
    );
  });
}
