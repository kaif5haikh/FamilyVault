import 'dart:convert';

import 'package:familyvault/core/database/app_database.dart';
import 'package:familyvault/core/errors/app_failure.dart';
import 'package:familyvault/core/finance/money.dart';
import 'package:familyvault/features/finance/data/ledger_repository.dart';
import 'package:familyvault/features/liabilities/data/debt_repository.dart';
import 'package:familyvault/features/liabilities/domain/loan_calculator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import '../support/vault_fixture.dart';

void main() {
  late VaultFixture fixture;
  late DebtRepository repo;
  late LedgerAccount cash;
  final failure = isA<AppFailure>();

  setUp(() async {
    fixture = await VaultFixture.create();
    repo = DebtRepository(fixture.ledger);
    cash = await fixture.ledger.createAccount(
      name: 'Synthetic cash',
      kind: AccountKind.asset,
      subtype: 'cash',
      openingBalance: Money.fromMinor(1000000),
      openedOn: '2026-01-01',
    );
  });
  tearDown(() => fixture.dispose());

  Future<String> loan({
    DebtDirection direction = DebtDirection.bankLoan,
    bool funded = true,
  }) => repo.create(
    DebtDraft(
      name: 'Synthetic loan',
      direction: direction,
      counterparty: 'Synthetic counterparty',
      principalMinor: 100000,
      startedOn: '2026-01-02',
      cashAccountId: funded ? cash.id : null,
    ),
  );

  RepaymentDraft payment(
    int principal,
    int interest, {
    String date = '2026-02-01',
  }) => RepaymentDraft(
    principalMinor: principal,
    interestMinor: interest,
    accountId: cash.id,
    paidOn: date,
  );

  Future<BigInt> outstanding(String id, {String? through}) async {
    final contract = await repo.contract(id);
    return DebtRepository.outstanding(
      contract,
      await fixture.ledger.accountBalance(contract.accountId, through: through),
    );
  }

  test('bank borrowing and lent money use opposite balance signs with only paid interest in profit', () async {
    final id = await loan(), lent = await loan(direction: DebtDirection.lent);
    expect(
      (await fixture.ledger.snapshot()).balances()[cash.id],
      BigInt.from(1000000),
    );
    await repo.repay(id, 1, payment(12000, 300));
    await repo.repay(lent, 1, payment(15000, 450));
    expect(await outstanding(id), BigInt.from(88000));
    expect(await outstanding(lent), BigInt.from(85000));
    var snapshot = await fixture.ledger.snapshot();
    expect(snapshot.total(AccountKind.expense), BigInt.from(300));
    expect(snapshot.total(AccountKind.income), BigInt.from(450));
    expect(snapshot.total(AccountKind.liability), BigInt.from(88000));
    expect(snapshot.balances()[cash.id], BigInt.from(1003150));
    await repo.repay(lent, 2, payment(0, 27));
    expect(await outstanding(lent), BigInt.from(85000));
    snapshot = await fixture.ledger.snapshot();
    expect(snapshot.total(AccountKind.income), BigInt.from(477));
    expect((await repo.snapshot()).repayments, hasLength(3));
  });

  test('loan creation and repayment retries record the principal, interest and postings once', () async {
    final op = const Uuid().v4(), repayOp = const Uuid().v4();
    const draft = DebtDraft(
      name: 'Synthetic opening',
      direction: DebtDirection.borrowed,
      counterparty: 'Synthetic lender',
      principalMinor: 5000,
      startedOn: '2026-01-02',
    );
    final id = await repo.create(draft, operationId: op);
    expect(await repo.create(draft, operationId: op), id);
    expect(
      (await fixture.ledger.snapshot()).balances()[cash.id],
      BigInt.from(1000000),
    );
    await repo.repay(id, 1, payment(1, 1), operationId: repayOp);
    expect(await repo.repay(id, 1, payment(1, 1), operationId: repayOp), id);
    await expectLater(
      repo.repay(id, 1, payment(2, 1), operationId: repayOp),
      throwsA(failure),
    );
    final changes = await (fixture.db.select(
      fixture.db.pendingMutations,
    )..where((t) => t.entityId.equals(id))).get();
    expect(changes, hasLength(2));
    final body = jsonDecode(
      changes.singleWhere((r) => r.operationId == repayOp).payloadJson,
    ) as Map<String, dynamic>;
    expect(body['record']['revision'], 2);
    expect(body['bundle']['repayments'], hasLength(1));
    expect(body['bundle']['journals'].single['postings'], hasLength(3));
    expect(await outstanding(id), BigInt.from(4999));
  });

  test('correction reverses and replaces atomically, maintaining date-bounded history', () async {
    final id = await loan(funded: false);
    await repo.repay(id, 1, payment(10000, 500));
    final original = (await repo.snapshot()).repayments.single;
    await expectLater(
      repo.correctRepayment(
        id,
        2,
        original.id,
        'Synthetic invalid correction',
        payment(100001, 0),
      ),
      throwsA(failure),
    );
    expect(
      (await fixture.ledger.detail(original.journalId)).journal.deletedAtUs,
      isNull,
    );
    expect((await repo.contract(id)).revision, 2);
    await repo.correctRepayment(
      id,
      2,
      original.id,
      'Synthetic statement correction',
      payment(9000, 250, date: '2026-02-05'),
    );
    expect(await outstanding(id, through: '2026-02-01'), BigInt.from(100000));
    expect(await outstanding(id, through: '2026-02-05'), BigInt.from(91000));
    expect(
      (await fixture.ledger.detail(original.journalId)).journal.deletedAtUs,
      isNotNull,
    );
    final kept = (await repo.snapshot()).repayments;
    expect(kept, hasLength(2));
    expect(
      (await fixture.ledger.snapshot()).total(AccountKind.expense),
      BigInt.from(250),
    );
    await expectLater(
      fixture.ledger.reverse(kept.first.journalId, reason: 'Generic bypass'),
      throwsA(failure),
    );
    await repo.reverseRepayment(
      id,
      3,
      kept.first.id,
      'Synthetic accidental entry',
    );
    expect(await outstanding(id), BigInt.from(100000));
    expect(
      (await fixture.ledger.snapshot()).total(AccountKind.expense),
      BigInt.zero,
    );
  });

  test('opening correction preserves funding provenance history and rejects invalid repayment ordering', () async {
    final id = await loan();
    await repo.repay(id, 1, payment(10000, 0));
    await expectLater(
      repo.correctPrincipal(
        id,
        2,
        principalMinor: 9999,
        startedOn: '2026-01-05',
        reason: 'Synthetic too small',
      ),
      throwsA(failure),
    );
    await expectLater(
      repo.correctPrincipal(
        id,
        2,
        principalMinor: 120000,
        startedOn: '2026-02-02',
        reason: 'Synthetic too late',
      ),
      throwsA(failure),
    );
    await repo.correctPrincipal(
      id,
      2,
      principalMinor: 110000,
      startedOn: '2026-01-05',
      cashAccountId: cash.id,
      reason: 'Synthetic principal correction',
    );
    expect(await outstanding(id, through: '2026-01-04'), BigInt.zero);
    expect(await outstanding(id, through: '2026-01-05'), BigInt.from(110000));
    expect(await outstanding(id), BigInt.from(100000));
    expect(
      (await fixture.ledger.snapshot()).balances()[cash.id],
      BigInt.from(1100000),
    );
    expect((await repo.contract(id)).principalMinor, 110000);
  });

  test('rejects overpayment, overflow and invalid terms without partial rows, then archives a settled loan', () async {
    final id = await loan();
    await expectLater(repo.repay(id, 1, payment(100001, 0)), throwsA(failure));
    await expectLater(
      repo.repay(id, 1, payment(1, 0x7fffffffffffffff)),
      throwsA(failure),
    );
    await expectLater(
      repo.repay(id, 1, payment(1, 0, date: '2026-01-01')),
      throwsA(failure),
    );
    await expectLater(repo.archive(id, 1, restore: false), throwsA(failure));
    await expectLater(
      repo.edit(
        id,
        1,
        name: 'Synthetic loan',
        counterparty: 'Synthetic lender',
        terms: const DebtTerms(method: InterestMethod.reducingMonthly),
        notes: '',
      ),
      throwsA(failure),
    );
    expect((await repo.snapshot()).repayments, isEmpty);
    expect((await repo.contract(id)).revision, 1);
    await repo.repay(id, 1, payment(100000, 0));
    await repo.archive(id, 2, restore: false);
    expect((await repo.contract(id)).deletedAtUs, isNotNull);
    expect((await repo.snapshot()).repayments, hasLength(1));
    await repo.archive(id, 3, restore: true);
    expect((await repo.contract(id)).deletedAtUs, isNull);
    expect(await outstanding(id), BigInt.zero);
  });

  test('an outbox failure and concurrent repayment attempts preserve all balances and histories', () async {
    final id = await loan();
    await fixture.db.customStatement(
      '''CREATE TRIGGER synthetic_debt_fail BEFORE INSERT ON pending_mutations
      WHEN NEW.entity_type = 'debt' BEGIN SELECT RAISE(ABORT, 'Synthetic failure'); END''',
    );
    final before = await fixture.ledger.snapshot();
    await expectLater(repo.repay(id, 1, payment(1234, 56)), throwsA(failure));
    expect((await repo.snapshot()).repayments, isEmpty);
    expect((await repo.contract(id)).revision, 1);
    expect(
      (await fixture.ledger.snapshot()).journals.length,
      before.journals.length,
    );
    expect(
      (await fixture.ledger.snapshot()).accounts.length,
      before.accounts.length,
    );
    await fixture.db.customStatement('DROP TRIGGER synthetic_debt_fail');
    final results = await Future.wait(
      [70000, 80000].map((amount) async {
        try {
          await repo.repay(id, 1, payment(amount, 0));
          return true;
        } on AppFailure {
          return false;
        }
      }),
    );
    expect(results.where((r) => r), hasLength(1));
    expect((await repo.snapshot()).repayments, hasLength(1));
    expect(
      await outstanding(id),
      anyOf(BigInt.from(20000), BigInt.from(30000)),
    );
  });
}
