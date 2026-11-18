import 'package:drift/drift.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/mutation_writer.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/finance/fixed_decimal.dart';
import '../../../core/sync/database_record.dart';
import '../../finance/data/ledger_repository.dart';
import '../domain/debt_draft.dart';
import '../domain/loan_calculator.dart';

export '../domain/debt_draft.dart';

final class DebtSnapshot {
  const DebtSnapshot(this.contracts, this.repayments);
  final List<DebtContract> contracts;
  final List<DebtRepayment> repayments;
}

final class DebtRepository {
  const DebtRepository(this.ledger);
  final LedgerRepository ledger;
  AppDatabase get db => ledger.db;
  String get family => ledger.identity.familyId;
  String get actor => ledger.identity.memberId;
  int get now => ledger.mutations.now;
  static const _invalid = AppFailure(
    FailureCode.validation,
    'Check the loan terms, amount and date.',
  );
  static const _stale = AppFailure(
    FailureCode.conflict,
    'This loan changed. Open it again before saving.',
  );

  Future<DebtContract> contract(String id) async {
    final found =
        await (db.select(db.debtContracts)
              ..where((t) => t.familyId.equals(family) & t.id.equals(id)))
            .getSingleOrNull();
    if (found == null) {
      throw const AppFailure(
        FailureCode.validation,
        'This loan is unavailable in this family.',
      );
    }
    return found;
  }

  Future<DebtContract> _current(
    String id,
    int revision, {
    bool archived = false,
  }) async {
    final row = await contract(id);
    if (row.revision != revision || (row.deletedAtUs != null) != archived) {
      throw _stale;
    }
    return row;
  }

  static BigInt outstanding(DebtContract row, BigInt ledgerBalance) =>
      row.direction == 'lent' ? ledgerBalance : -ledgerBalance;

  Future<BigInt> _outstanding(DebtContract row) async =>
      outstanding(row, await ledger.accountBalance(row.accountId));

  static String _text(String value, int limit, {bool optional = false}) {
    value = value.trim();
    if ((!optional && value.isEmpty) ||
        value.length > limit ||
        value.contains('\u0000')) {
      throw _invalid;
    }
    return value;
  }

  static void _validateTerms(DebtTerms terms, String startedOn) {
    LedgerRepository.validateDate(startedOn);
    final rate = terms.annualRateBps,
        months = terms.termMonths,
        emi = terms.emiMinor;
    if ((terms.method == InterestMethod.unrecorded) != (rate == null) ||
        (rate != null && (rate < 0 || rate > 1000000)) ||
        (months != null && (months < 1 || months > 600)) ||
        (emi != null && emi < 0)) {
      throw _invalid;
    }
    for (final date in [terms.firstDueOn, terms.dueOn].nonNulls) {
      LedgerRepository.validateDate(date);
      if (date.compareTo(startedOn) < 0) {
        throw _invalid;
      }
    }
    final firstDue = terms.firstDueOn, due = terms.dueOn;
    if (firstDue != null && due != null && firstDue.compareTo(due) > 0) {
      throw _invalid;
    }
  }

  Future<String> create(DebtDraft draft, {String? operationId}) {
    final op = operationId ?? ledger.operationId();
    final rootId = ledger.aggregateId(op, 'debt');
    return ledger.runAggregate(
      operationId: op,
      entityType: 'debt',
      entityId: rootId,
      baseRevision: 0,
      action: 'create',
      command: draft.toJson(),
      change: (tx) async {
        if (draft.principalMinor <= 0) {
          throw _invalid;
        }
        _validateTerms(draft.terms, draft.startedOn);
        final name = _text(draft.name, 120),
            lent = draft.direction == DebtDirection.lent;
        final account = await tx.createAccount(
          label: 'principal',
          name: name,
          kind: lent ? AccountKind.asset : AccountKind.liability,
          subtype: 'managed_${draft.direction.code}',
        );
        await db
            .into(db.debtContracts)
            .insert(
              DebtContractsCompanion.insert(
                id: rootId,
                familyId: family,
                createdBy: actor,
                updatedBy: actor,
                createdAtUs: now,
                updatedAtUs: now,
                name: name,
                direction: draft.direction.code,
                counterparty: _text(draft.counterparty, 120),
                accountId: account.id,
                principalMinor: draft.principalMinor,
                annualRateBps: Value(draft.terms.annualRateBps),
                interestMethod: Value(draft.terms.method.name),
                termMonths: Value(draft.terms.termMonths),
                emiMinor: Value(draft.terms.emiMinor),
                startedOn: draft.startedOn,
                firstDueOn: Value(draft.terms.firstDueOn),
                dueOn: Value(draft.terms.dueOn),
                notes: _text(draft.notes, 4000, optional: true),
              ),
            );
        final row = await contract(rootId);
        await _postPrincipal(tx, row, draft.cashAccountId);
        return databaseRecord(row);
      },
    );
  }

  Future<void> _postPrincipal(
    LedgerAggregate tx,
    DebtContract row,
    String? cashAccountId,
  ) async {
    final contra = cashAccountId == null
        ? ledger.chartId('opening')
        : (await tx.liquidAccount(cashAccountId)).id;
    final signed = row.direction == 'lent'
        ? row.principalMinor
        : -row.principalMinor;
    await tx.post(
      kind: cashAccountId == null ? EntryKind.opening : EntryKind.adjustment,
      occurredOn: row.startedOn,
      description: cashAccountId == null
          ? 'Loan opening balance'
          : 'Loan funds',
      postings: [
        PostingInput(row.accountId, signed),
        PostingInput(contra, -signed),
      ],
      purpose: 'opening',
    );
  }

  Future<String> edit(
    String id,
    int revision, {
    required String name,
    required String counterparty,
    required DebtTerms terms,
    required String notes,
    String? operationId,
  }) => ledger.runAggregate(
    operationId: operationId ?? ledger.operationId(),
    entityType: 'debt',
    entityId: id,
    baseRevision: revision,
    command: {
      'name': name.trim(),
      'counterparty': counterparty.trim(),
      ...terms.toJson(),
      'notes': notes.trim(),
    },
    change: (tx) async {
      final row = await _current(id, revision);
      _validateTerms(terms, row.startedOn);
      tx.before = databaseRecord(row);
      final updatedName = _text(name, 120);
      await _update(
        row,
        DebtContractsCompanion(
          name: Value(updatedName),
          counterparty: Value(_text(counterparty, 120)),
          notes: Value(_text(notes, 4000, optional: true)),
          interestMethod: Value(terms.method.name),
          annualRateBps: Value(terms.annualRateBps),
          termMonths: Value(terms.termMonths),
          emiMinor: Value(terms.emiMinor),
          firstDueOn: Value(terms.firstDueOn),
          dueOn: Value(terms.dueOn),
        ),
      );
      if (updatedName != row.name) {
        await tx.renameAccount(row.accountId, updatedName);
      }
      return databaseRecord(await contract(id));
    },
  );

  Future<String> correctPrincipal(
    String id,
    int revision, {
    required int principalMinor,
    required String startedOn,
    String? cashAccountId,
    required String reason,
    String? operationId,
  }) => ledger.runAggregate(
    operationId: operationId ?? ledger.operationId(),
    entityType: 'debt',
    entityId: id,
    baseRevision: revision,
    command: {
      'principal_minor': principalMinor,
      'started_on': startedOn,
      'cash_account_id': cashAccountId,
      'reason': reason.trim(),
    },
    change: (tx) async {
      final row = await _current(id, revision);
      final terms = DebtTerms(
        method: InterestMethod.values.byName(row.interestMethod),
        annualRateBps: row.annualRateBps,
        termMonths: row.termMonths,
        emiMinor: row.emiMinor,
        firstDueOn: row.firstDueOn,
        dueOn: row.dueOn,
      );
      _validateTerms(terms, startedOn);
      final linked =
          await (db.select(db.aggregateJournalLinks)..where(
                (t) =>
                    t.familyId.equals(family) &
                    t.aggregateType.equals('debt') &
                    t.aggregateId.equals(id) &
                    t.purpose.equals('opening'),
              ))
              .get();
      final active = <String>[];
      for (final link in linked) {
        if ((await ledger.detail(link.journalId)).journal.deletedAtUs == null) {
          active.add(link.journalId);
        }
      }
      final paid = BigInt.from(row.principalMinor) - await _outstanding(row);
      final beforeFirstDate = await db
          .customSelect(
            '''SELECT 1 FROM debt_repayments r
          JOIN ledger_journals j ON j.family_id = r.family_id AND j.id = r.journal_id
          WHERE r.family_id = ? AND r.contract_id = ? AND j.deleted_at_us IS NULL AND r.paid_on < ? LIMIT 1''',
            variables: [Variable(family), Variable(id), Variable(startedOn)],
          )
          .get();
      if (principalMinor <= 0 ||
          BigInt.from(principalMinor) < paid ||
          beforeFirstDate.isNotEmpty ||
          active.length != 1) {
        throw const AppFailure(
          FailureCode.validation,
          'Principal must cover existing repayments and the start date must precede them.',
        );
      }
      tx.before = databaseRecord(row);
      await tx.reverse(active.single, reason);
      await _update(
        row,
        DebtContractsCompanion(
          principalMinor: Value(principalMinor),
          startedOn: Value(startedOn),
        ),
      );
      final updated = await contract(id);
      await _postPrincipal(tx, updated, cashAccountId);
      return databaseRecord(updated);
    },
  );

  Future<String> repay(
    String id,
    int revision,
    RepaymentDraft draft, {
    String? operationId,
  }) => _repaymentChange(id, revision, draft: draft, operationId: operationId);

  Future<String> reverseRepayment(
    String id,
    int revision,
    String repaymentId,
    String reason, {
    String? operationId,
  }) => _repaymentChange(
    id,
    revision,
    reverseId: repaymentId,
    reason: reason,
    operationId: operationId,
  );

  Future<String> correctRepayment(
    String id,
    int revision,
    String repaymentId,
    String reason,
    RepaymentDraft replacement, {
    String? operationId,
  }) => _repaymentChange(
    id,
    revision,
    reverseId: repaymentId,
    reason: reason,
    draft: replacement,
    operationId: operationId,
  );

  Future<String> _repaymentChange(
    String id,
    int revision, {
    RepaymentDraft? draft,
    String? reverseId,
    String? reason,
    String? operationId,
  }) => ledger.runAggregate(
    operationId: operationId ?? ledger.operationId(),
    entityType: 'debt',
    entityId: id,
    baseRevision: revision,
    command: {
      'repayment': draft?.toJson(),
      'reverse_repayment': reverseId,
      'reason': reason?.trim(),
    },
    change: (tx) async {
      final row = await _current(id, revision);
      tx.before = databaseRecord(row);
      if (reverseId != null) {
        final old =
            await (db.select(db.debtRepayments)..where(
                  (t) =>
                      t.id.equals(reverseId) &
                      t.familyId.equals(family) &
                      t.contractId.equals(id),
                ))
                .getSingleOrNull();
        if (old == null ||
            (await ledger.detail(old.journalId)).journal.deletedAtUs != null) {
          throw _invalid;
        }
        await tx.reverse(old.journalId, reason!);
      }
      await _update(row, const DebtContractsCompanion());
      if (draft != null) {
        await _postRepayment(tx, row, draft);
      }
      return databaseRecord(await contract(id));
    },
  );

  Future<void> _postRepayment(
    LedgerAggregate tx,
    DebtContract row,
    RepaymentDraft draft,
  ) async {
    LedgerRepository.validateDate(draft.paidOn);
    final total = checkedInt64(
      BigInt.from(draft.principalMinor) + BigInt.from(draft.interestMinor),
    );
    if (total <= 0 ||
        draft.principalMinor < 0 ||
        draft.interestMinor < 0 ||
        draft.paidOn.compareTo(row.startedOn) < 0) {
      throw _invalid;
    }
    if (BigInt.from(draft.principalMinor) > await _outstanding(row)) {
      throw const AppFailure(
        FailureCode.validation,
        'Principal cannot exceed the outstanding balance. Record interest separately.',
      );
    }
    final cash = await tx.liquidAccount(draft.accountId),
        lent = row.direction == 'lent';
    final notes = _text(draft.notes, 4000, optional: true);
    final postings = <PostingInput>[
      PostingInput(cash.id, lent ? total : -total),
    ];
    if (draft.principalMinor != 0) {
      postings.add(
        PostingInput(
          row.accountId,
          lent ? -draft.principalMinor : draft.principalMinor,
        ),
      );
    }
    if (draft.interestMinor != 0) {
      final interest = await tx.systemAccount(
        lent ? 'interest_received' : 'interest_paid',
        lent ? 'Interest received' : 'Interest paid',
        lent ? AccountKind.income : AccountKind.expense,
      );
      postings.add(
        PostingInput(
          interest.id,
          lent ? -draft.interestMinor : draft.interestMinor,
        ),
      );
    }
    final journal = await tx.post(
      kind: EntryKind.repayment,
      occurredOn: draft.paidOn,
      description: lent ? 'Loan repayment received' : 'Loan repayment paid',
      postings: postings,
      purpose: 'repayment',
    );
    final key = tx.id('repayment');
    await db
        .into(db.debtRepayments)
        .insert(
          DebtRepaymentsCompanion.insert(
            id: key,
            familyId: family,
            createdBy: actor,
            deviceId: ledger.identity.deviceId,
            createdAtUs: now,
            contractId: row.id,
            journalId: journal,
            paidOn: draft.paidOn,
            principalMinor: draft.principalMinor,
            interestMinor: draft.interestMinor,
            notes: notes,
          ),
        );
    tx.include('repayments', [
      databaseRecord(
        await (db.select(
          db.debtRepayments,
        )..where((t) => t.id.equals(key))).getSingle(),
      ),
    ]);
  }

  Future<String> archive(
    String id,
    int revision, {
    required bool restore,
    String? operationId,
  }) => ledger.runAggregate(
    operationId: operationId ?? ledger.operationId(),
    entityType: 'debt',
    entityId: id,
    baseRevision: revision,
    action: restore ? 'restore' : 'delete',
    command: {'restore': restore},
    change: (tx) async {
      final row = await _current(id, revision, archived: restore);
      if (!restore && await _outstanding(row) != BigInt.zero) {
        throw const AppFailure(
          FailureCode.validation,
          'Settle the remaining principal before archiving this loan.',
        );
      }
      tx.before = databaseRecord(row);
      await _update(
        row,
        DebtContractsCompanion(deletedAtUs: Value(restore ? null : now)),
      );
      return databaseRecord(await contract(id));
    },
  );

  Future<void> _update(DebtContract row, DebtContractsCompanion changes) async {
    final updated =
        await (db.update(db.debtContracts)..where(
              (t) =>
                  t.id.equals(row.id) &
                  t.familyId.equals(family) &
                  t.revision.equals(row.revision),
            ))
            .write(
              changes.copyWith(
                revision: Value(row.revision + 1),
                updatedBy: Value(actor),
                updatedAtUs: Value(now),
              ),
            );
    if (updated != 1) {
      throw _stale;
    }
  }

  Future<DebtSnapshot> snapshot() => storageBoundary(
    () => db.transaction(() async {
      await ledger.mutations.authorize();
      final rows =
          await (db.select(db.debtContracts)
                ..where((t) => t.familyId.equals(family))
                ..orderBy([(t) => OrderingTerm.asc(t.name)]))
              .get();
      final repayments =
          await (db.select(db.debtRepayments)
                ..where((t) => t.familyId.equals(family))
                ..orderBy([
                  (t) => OrderingTerm.desc(t.paidOn),
                  (t) => OrderingTerm.desc(t.createdAtUs),
                ]))
              .get();
      return DebtSnapshot(rows, repayments);
    }),
  );

  Stream<DebtSnapshot> watch() => db
      .customSelect(
        'SELECT 1 /* debt projection */',
        readsFrom: {
          db.debtContracts,
          db.debtRepayments,
          db.familyMembers,
          db.vaultDevices,
        },
      )
      .watch()
      .asyncMap((_) => snapshot());
}
