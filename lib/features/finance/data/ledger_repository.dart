import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/mutation_writer.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/finance/money.dart';
import '../../../core/security/vault_identity.dart';
import '../../../core/sync/canonical_json.dart';

part 'ledger_aggregate.dart';

enum AccountKind { asset, liability, equity, income, expense }

enum EntryKind {
  income,
  expense,
  transfer,
  opening,
  adjustment,
  reversal,
  repayment,
  business,
}

final class PostingInput {
  const PostingInput(this.accountId, this.amountMinor);
  final String accountId;
  final int amountMinor;
  Map<String, Object?> toJson() => {
    'account_id': accountId,
    'amount_minor': amountMinor,
  };
  @override
  String toString() => 'PostingInput([redacted])';
}

final class JournalDetail {
  const JournalDetail(this.journal, this.postings);
  final LedgerJournal journal;
  final List<LedgerPosting> postings;
}

/// A coherent local read model. Financial totals never use binary floating point.
final class FinanceSnapshot {
  FinanceSnapshot({
    required this.accounts,
    required this.journals,
    required this.postings,
    required this.budgets,
    required this.reconciliations,
    required this.managedAccountIds,
    required this.journalLinks,
  });
  final List<LedgerAccount> accounts;
  final List<LedgerJournal> journals;
  final List<LedgerPosting> postings;
  final List<MonthlyBudget> budgets;
  final List<ReconciliationCheck> reconciliations;
  final Set<String> managedAccountIds;
  final Map<String, AggregateJournalLink> journalLinks;

  Map<String, BigInt> balances({String? through, String? from}) {
    final allowed = {
      for (final j in journals)
        if (j.status == 'posted' &&
            (through == null || j.occurredOn.compareTo(through) <= 0) &&
            (from == null || j.occurredOn.compareTo(from) >= 0))
          j.id,
    };
    final result = <String, BigInt>{};
    for (final p in postings) {
      if (allowed.contains(p.journalId)) {
        result.update(
          p.accountId,
          (v) => v + BigInt.from(p.amountMinor),
          ifAbsent: () => BigInt.from(p.amountMinor),
        );
      }
    }
    return result;
  }

  BigInt total(AccountKind kind, {String? from, String? through}) {
    final values = balances(from: from, through: through);
    var result = BigInt.zero;
    for (final a in accounts.where((a) => a.kind == kind.name)) {
      result += values[a.id] ?? BigInt.zero;
    }
    return kind == AccountKind.income ||
            kind == AccountKind.liability ||
            kind == AccountKind.equity
        ? -result
        : result;
  }
}

final class LedgerRepository {
  LedgerRepository(this.db, this.identity, {DateTime Function()? clock})
    : mutations = MutationWriter(db, identity, clock: clock);
  final AppDatabase db;
  final VaultIdentity identity;
  final MutationWriter mutations;
  static const uuid = Uuid();
  static final _nameSpace = Namespace.url.value;
  static const _invalid = AppFailure(
    FailureCode.validation,
    'Check the accounts, amount and date.',
  );
  static const _missing = AppFailure(
    FailureCode.validation,
    'This record is unavailable in this family.',
  );

  /// Creates metadata only: no sample people, balances or financial transactions.
  Future<void> createOfflineWorkspace({
    required String familyName,
    required String ownerName,
  }) => storageBoundary(
    () => db.transaction(() async {
      if (identity.mode != 'offline') {
        throw const AppFailure(
          FailureCode.unauthorized,
          'Cloud enrollment requires server confirmation.',
        );
      }
      final existing = await (db.select(
        db.familySpaces,
      )..where((t) => t.id.equals(identity.familyId))).getSingleOrNull();
      if (existing != null) {
        await mutations.authorize();
        return;
      }
      final now = mutations.now;
      await db
          .into(db.familySpaces)
          .insert(
            FamilySpacesCompanion.insert(
              id: identity.familyId,
              name: _text(familyName, 80),
              mode: 'offline',
              createdAtUs: now,
            ),
          );
      await db
          .into(db.familyMembers)
          .insert(
            FamilyMembersCompanion.insert(
              id: identity.memberId,
              familyId: identity.familyId,
              displayName: _text(ownerName, 80),
              relationship: 'administrator',
              role: 'administrator',
              createdAtUs: now,
            ),
          );
      await db
          .into(db.vaultDevices)
          .insert(
            VaultDevicesCompanion.insert(
              id: identity.deviceId,
              familyId: identity.familyId,
              memberId: identity.memberId,
              state: 'enrolled',
              createdAtUs: now,
            ),
          );
      for (final def in <(String, AccountKind, String)>[
        ('Opening balances', AccountKind.equity, 'opening'),
        ('Reconciliation adjustments', AccountKind.equity, 'reconciliation'),
        ('Salary', AccountKind.income, 'salary'),
        ('Business income', AccountKind.income, 'business_income'),
        ('Rental income', AccountKind.income, 'rental'),
        ('Other income', AccountKind.income, 'other_income'),
        ('Household', AccountKind.expense, 'household'),
        ('Groceries', AccountKind.expense, 'groceries'),
        ('Utilities', AccountKind.expense, 'utilities'),
        ('Transport', AccountKind.expense, 'transport'),
        ('Shopping', AccountKind.expense, 'shopping'),
        ('Medical', AccountKind.expense, 'medical'),
        ('Education', AccountKind.expense, 'education'),
        ('Business expenses', AccountKind.expense, 'business_expense'),
        ('Other expenses', AccountKind.expense, 'other_expense'),
      ]) {
        await _insertAccount(
          id: chartId(def.$3),
          name: def.$1,
          kind: def.$2,
          subtype: def.$3,
          system: true,
        );
      }
    }),
  );

  String chartId(String code) {
    final path = '${identity.familyId}/chart/$code';
    if (!identity.usesSharedChart) return uuid.v5(_nameSpace, path);
    final hash = payloadDigest(path);
    return '${hash.substring(0, 8)}-${hash.substring(8, 12)}'
        '-8${hash.substring(13, 16)}-8${hash.substring(17, 20)}'
        '-${hash.substring(20, 32)}';
  }

  String operationId() => uuid.v4();
  static String _text(String text, int max) {
    text = text.trim();
    if (text.isEmpty || text.length > max || text.contains('\u0000')) {
      throw _invalid;
    }
    return text;
  }

  static String dateOnly(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  static void validateDate(String value) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null ||
        value.length != 10 ||
        dateOnly(parsed) != value ||
        parsed.year < 1900 ||
        parsed.year > 2200) {
      throw _invalid;
    }
  }

  static int checkedMinor(BigInt value) {
    if (value < -(BigInt.one << 63) ||
        value > (BigInt.one << 63) - BigInt.one) {
      throw _invalid;
    }
    return value.toInt();
  }

  Future<LedgerAccount> createAccount({
    required String name,
    required AccountKind kind,
    required String subtype,
    Money? openingBalance,
    String? openedOn,
    String? operationId,
  }) => storageBoundary(
    () => db.transaction(() async {
      await mutations.authorize();
      if (kind == AccountKind.equity ||
          subtype.trim().startsWith('managed_') ||
          (openingBalance != null && openingBalance.currency != Currency.inr) ||
          (openingBalance != null &&
              kind != AccountKind.asset &&
              kind != AccountKind.liability)) {
        throw _invalid;
      }
      final operation = operationId ?? uuid.v4();
      final digest = payloadDigest(
        canonicalJson({
          'create_account': name.trim(),
          'kind': kind.name,
          'subtype': subtype.trim(),
          'opening_minor': openingBalance?.minor,
          'opened_on': openedOn,
        }),
      );
      final prior = await mutations.existing(operation, digest);
      if (prior != null) {
        return account(prior.entityId);
      }
      final a = await _insertAccount(
        id: aggregateId(operation, 'account'),
        name: name,
        kind: kind,
        subtype: _text(subtype, 40),
        emitMutation: false,
      );
      Map<String, Object?>? bundle;
      if (openingBalance != null && openingBalance.minor != 0) {
        final signed = kind == AccountKind.liability
            ? openingBalance.negate().minor
            : openingBalance.minor;
        final journal = await _post(
          kind: EntryKind.opening,
          occurredOn: openedOn ?? dateOnly(mutations.clock()),
          description: 'Opening balance',
          operationId: aggregateId(operation, 'opening'),
          emitMutation: false,
          postings: [
            PostingInput(a.id, signed),
            PostingInput(
              chartId('opening'),
              Money.fromMinor(signed).negate().minor,
            ),
          ],
        );
        final snapshot = await journalJson(journal);
        bundle = {
          'journals': [snapshot],
        };
        await mutations.audit(
          operationId: operation,
          entityType: 'journal',
          entityId: journal,
          action: 'post',
          after: snapshot,
        );
      }
      await mutations.record(
        operationId: operation,
        entityType: 'account',
        entityId: a.id,
        action: 'create',
        baseRevision: 0,
        after: accountJson(a),
        commandDigest: digest,
        bundle: bundle,
      );
      return a;
    }),
  );

  Future<LedgerAccount> _insertAccount({
    required String id,
    required String name,
    required AccountKind kind,
    required String subtype,
    bool system = false,
    bool emitMutation = true,
  }) async {
    final now = mutations.now;
    await db
        .into(db.ledgerAccounts)
        .insert(
          LedgerAccountsCompanion.insert(
            id: id,
            familyId: identity.familyId,
            createdBy: identity.memberId,
            updatedBy: identity.memberId,
            createdAtUs: now,
            updatedAtUs: now,
            name: _text(name, 120),
            kind: kind.name,
            subtype: subtype,
            systemAccount: Value(system),
          ),
        );
    final a = await account(id);
    if (emitMutation) {
      await mutations.record(
        operationId: uuid.v4(),
        entityType: 'account',
        entityId: id,
        action: 'create',
        baseRevision: 0,
        after: accountJson(a),
      );
    }
    return a;
  }

  Future<LedgerAccount> account(String id) async {
    final a =
        await (db.select(db.ledgerAccounts)..where(
              (t) => t.familyId.equals(identity.familyId) & t.id.equals(id),
            ))
            .getSingleOrNull();
    if (a == null) {
      throw _missing;
    }
    return a;
  }

  Future<LedgerAccount> renameAccount(
    String id,
    String name,
    int expectedRevision,
  ) => storageBoundary(
    () => db.transaction(() async {
      await mutations.authorize();
      final before = await account(id);
      await ensureUnmanagedAccount(id);
      if (before.revision != expectedRevision ||
          before.deletedAtUs != null ||
          before.systemAccount) {
        throw const AppFailure(
          FailureCode.conflict,
          'This account changed. Refresh before editing.',
        );
      }
      await (db.update(db.ledgerAccounts)..where((t) => t.id.equals(id))).write(
        LedgerAccountsCompanion(
          name: Value(_text(name, 120)),
          revision: Value(before.revision + 1),
          updatedBy: Value(identity.memberId),
          updatedAtUs: Value(mutations.now),
        ),
      );
      final after = await account(id);
      await mutations.record(
        operationId: uuid.v4(),
        entityType: 'account',
        entityId: id,
        action: 'update',
        baseRevision: before.revision,
        before: accountJson(before),
        after: accountJson(after),
      );
      return after;
    }),
  );

  Future<void> archiveAccount(String id, int expectedRevision) =>
      storageBoundary(
        () => db.transaction(() async {
          await mutations.authorize();
          final before = await account(id);
          await ensureUnmanagedAccount(id);
          if (before.revision != expectedRevision ||
              before.deletedAtUs != null ||
              before.systemAccount) {
            throw const AppFailure(
              FailureCode.conflict,
              'This account changed. Refresh before archiving.',
            );
          }
          if (['asset', 'liability'].contains(before.kind)) {
            final balance = (await snapshot()).balances()[id] ?? BigInt.zero;
            if (balance != BigInt.zero) {
              throw const AppFailure(
                FailureCode.validation,
                'An account with a balance cannot be archived. Reconcile or transfer its balance first.',
              );
            }
          }
          await (db.update(
            db.ledgerAccounts,
          )..where((t) => t.id.equals(id))).write(
            LedgerAccountsCompanion(
              deletedAtUs: Value(mutations.now),
              revision: Value(before.revision + 1),
              updatedBy: Value(identity.memberId),
              updatedAtUs: Value(mutations.now),
            ),
          );
          await mutations.record(
            operationId: uuid.v4(),
            entityType: 'account',
            entityId: id,
            action: 'delete',
            baseRevision: before.revision,
            before: accountJson(before),
            after: accountJson(await account(id)),
          );
        }),
      );

  Future<void> restoreAccount(String id, int expectedRevision) =>
      storageBoundary(
        () => db.transaction(() async {
          await mutations.authorize();
          final before = await account(id);
          await ensureUnmanagedAccount(id);
          if (before.revision != expectedRevision ||
              before.deletedAtUs == null ||
              before.systemAccount) {
            throw const AppFailure(
              FailureCode.conflict,
              'This account changed. Refresh before restoring.',
            );
          }
          await (db.update(
            db.ledgerAccounts,
          )..where((t) => t.id.equals(id))).write(
            LedgerAccountsCompanion(
              deletedAtUs: const Value(null),
              revision: Value(before.revision + 1),
              updatedBy: Value(identity.memberId),
              updatedAtUs: Value(mutations.now),
            ),
          );
          await mutations.record(
            operationId: uuid.v4(),
            entityType: 'account',
            entityId: id,
            action: 'restore',
            baseRevision: before.revision,
            before: accountJson(before),
            after: accountJson(await account(id)),
          );
        }),
      );

  Future<void> deleteBudget(String id, int expectedRevision) => storageBoundary(
    () => db.transaction(() async {
      await mutations.authorize();
      final before =
          await (db.select(db.monthlyBudgets)..where(
                (t) => t.familyId.equals(identity.familyId) & t.id.equals(id),
              ))
              .getSingleOrNull();
      if (before == null ||
          before.revision != expectedRevision ||
          before.deletedAtUs != null) {
        throw const AppFailure(
          FailureCode.conflict,
          'This budget changed. Refresh before deleting.',
        );
      }
      await (db.update(db.monthlyBudgets)..where((t) => t.id.equals(id))).write(
        MonthlyBudgetsCompanion(
          deletedAtUs: Value(mutations.now),
          revision: Value(before.revision + 1),
          updatedBy: Value(identity.memberId),
          updatedAtUs: Value(mutations.now),
        ),
      );
      final after = await (db.select(
        db.monthlyBudgets,
      )..where((t) => t.id.equals(id))).getSingle();
      await mutations.record(
        operationId: uuid.v4(),
        entityType: 'budget',
        entityId: id,
        action: 'delete',
        baseRevision: before.revision,
        before: budgetJson(before),
        after: budgetJson(after),
      );
    }),
  );

  Future<String> recordTransaction({
    required EntryKind kind,
    required String accountId,
    required String counterAccountId,
    required Money amount,
    required String occurredOn,
    required String description,
    String? operationId,
    String? businessId,
    String? relatedEntityId,
  }) => storageBoundary(
    () => db.transaction(() async {
      await mutations.authorize();
      final postings = await _transactionPostings(
        kind,
        accountId,
        counterAccountId,
        amount,
      );
      return _post(
        kind: kind,
        occurredOn: occurredOn,
        description: description,
        postings: postings,
        operationId: operationId,
        businessId: businessId,
        relatedEntityId: relatedEntityId,
      );
    }),
  );

  Future<List<PostingInput>> _transactionPostings(
    EntryKind kind,
    String accountId,
    String counterAccountId,
    Money amount,
  ) async {
    final a = await account(accountId),
        counter = await account(counterAccountId);
    await ensureUnmanagedAccount(a.id);
    await ensureUnmanagedAccount(counter.id);
    if (amount.minor <= 0 ||
        amount.currency != Currency.inr ||
        a.kind != 'asset' ||
        a.id == counter.id) {
      throw _invalid;
    }
    final List<PostingInput> postings;
    switch (kind) {
      case EntryKind.income:
        if (counter.kind != 'income') {
          throw _invalid;
        }
        postings = [
          PostingInput(a.id, amount.minor),
          PostingInput(counter.id, amount.negate().minor),
        ];
      case EntryKind.expense:
        if (counter.kind != 'expense') {
          throw _invalid;
        }
        postings = [
          PostingInput(counter.id, amount.minor),
          PostingInput(a.id, amount.negate().minor),
        ];
      case EntryKind.transfer:
        if (counter.kind != 'asset') {
          throw _invalid;
        }
        postings = [
          PostingInput(counter.id, amount.minor),
          PostingInput(a.id, amount.negate().minor),
        ];
      default:
        throw _invalid;
    }
    return postings;
  }

  Future<String> postJournal({
    required EntryKind kind,
    required String occurredOn,
    required String description,
    required List<PostingInput> postings,
    String? operationId,
    String? businessId,
    String? relatedEntityId,
  }) => storageBoundary(
    () => db.transaction(() async {
      await mutations.authorize();
      if (kind == EntryKind.reversal) {
        throw _invalid;
      }
      for (final p in postings) {
        await ensureUnmanagedAccount(p.accountId);
      }
      return _post(
        kind: kind,
        occurredOn: occurredOn,
        description: description,
        postings: postings,
        operationId: operationId,
        businessId: businessId,
        relatedEntityId: relatedEntityId,
      );
    }),
  );

  Future<String> _post({
    required EntryKind kind,
    required String occurredOn,
    required String description,
    required List<PostingInput> postings,
    String? operationId,
    String? reversesId,
    String? businessId,
    String? relatedEntityId,
    bool emitMutation = true,
  }) async {
    validateDate(occurredOn);
    description = _text(description, 500);
    if (postings.length < 2 || postings.length > 100) {
      throw _invalid;
    }
    var sum = BigInt.zero, debit = BigInt.zero, credit = BigInt.zero;
    for (final p in postings) {
      final a = await account(p.accountId);
      if (a.deletedAtUs != null || a.currency != 'INR' || p.amountMinor == 0) {
        throw _invalid;
      }
      Money.fromMinor(p.amountMinor);
      final amount = BigInt.from(p.amountMinor);
      sum += amount;
      if (amount.isNegative) {
        credit -= amount;
      } else {
        debit += amount;
      }
    }
    checkedMinor(debit);
    checkedMinor(credit);
    if (sum != BigInt.zero) {
      throw const AppFailure(
        FailureCode.validation,
        'Debits and credits must balance.',
      );
    }
    final op = operationId ?? uuid.v4();
    final command = payloadDigest(
      canonicalJson({
        'kind': kind.name,
        'occurred_on': occurredOn,
        'description': description,
        'postings': postings.map((p) => p.toJson()).toList(),
        'business_id': businessId,
        'related_entity_id': relatedEntityId,
        'reverses_id': reversesId,
      }),
    );
    final prior = await mutations.existing(op, command);
    if (prior != null) {
      return prior.entityId;
    }
    final id = uuid.v5(_nameSpace, '${identity.familyId}/journal/$op');
    final now = mutations.now;
    await db
        .into(db.ledgerJournals)
        .insert(
          LedgerJournalsCompanion.insert(
            id: id,
            familyId: identity.familyId,
            createdBy: identity.memberId,
            updatedBy: identity.memberId,
            createdAtUs: now,
            updatedAtUs: now,
            kind: kind.name,
            occurredOn: occurredOn,
            description: description,
            reversesId: Value(reversesId),
            businessId: Value(businessId),
            relatedEntityId: Value(relatedEntityId),
          ),
        );
    for (var i = 0; i < postings.length; i++) {
      await db
          .into(db.ledgerPostings)
          .insert(
            LedgerPostingsCompanion.insert(
              id: uuid.v5(_nameSpace, '$id/posting/$i'),
              familyId: identity.familyId,
              journalId: id,
              accountId: postings[i].accountId,
              position: i,
              amountMinor: postings[i].amountMinor,
            ),
          );
    }
    await (db.update(db.ledgerJournals)..where((t) => t.id.equals(id))).write(
      const LedgerJournalsCompanion(status: Value('posted')),
    );
    if (emitMutation) {
      await mutations.record(
        operationId: op,
        entityType: 'journal',
        entityId: id,
        action: 'post',
        baseRevision: 0,
        after: await journalJson(id),
        commandDigest: command,
      );
    }
    return id;
  }

  Future<JournalDetail> detail(String id) async {
    final journal =
        await (db.select(db.ledgerJournals)..where(
              (t) => t.id.equals(id) & t.familyId.equals(identity.familyId),
            ))
            .getSingleOrNull();
    if (journal == null) {
      throw _missing;
    }
    final postings =
        await (db.select(db.ledgerPostings)
              ..where(
                (t) =>
                    t.journalId.equals(id) &
                    t.familyId.equals(identity.familyId),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.position)]))
            .get();
    return JournalDetail(journal, postings);
  }

  /// Cancellation appends exact opposite postings and a display tombstone.
  /// Balances always include both original and reversal.
  Future<String> reverse(
    String id, {
    required String reason,
    String? operationId,
  }) => storageBoundary(
    () => db.transaction(() async {
      await mutations.authorize();
      final op = operationId ?? uuid.v4();
      reason = _text(reason, 400);
      final command = payloadDigest(
        canonicalJson({'reverse': id, 'reason': reason}),
      );
      final prior = await mutations.existing(op, command);
      if (prior != null) {
        return prior.entityId;
      }
      await ensureUnmanagedJournal(id);
      return _cancel(id, reason: reason, operationId: op, command: command);
    }),
  );

  Future<String> _cancel(
    String id, {
    required String reason,
    required String operationId,
    required String command,
    bool emitMutation = true,
  }) async {
    final original = await detail(id);
    if (original.journal.status != 'posted' ||
        original.journal.deletedAtUs != null ||
        original.journal.kind == 'reversal') {
      throw _invalid;
    }
    final before = await journalJson(id);
    final reverseId = await _post(
      kind: EntryKind.reversal,
      occurredOn: original.journal.occurredOn,
      description: reason,
      postings: original.postings
          .map(
            (p) => PostingInput(
              p.accountId,
              Money.fromMinor(p.amountMinor).negate().minor,
            ),
          )
          .toList(),
      operationId: operationId,
      reversesId: id,
      businessId: original.journal.businessId,
      relatedEntityId: original.journal.relatedEntityId,
      emitMutation: false,
    );
    final now = mutations.now;
    await (db.update(db.ledgerJournals)..where((t) => t.id.equals(id))).write(
      LedgerJournalsCompanion(
        deletedAtUs: Value(now),
        updatedAtUs: Value(now),
        updatedBy: Value(identity.memberId),
        revision: Value(original.journal.revision + 1),
      ),
    );
    final after = await journalJson(id),
        reversal = await journalJson(reverseId);
    if (emitMutation) {
      await mutations.record(
        operationId: operationId,
        entityType: 'journal_reversal',
        entityId: reverseId,
        action: 'reverse',
        baseRevision: original.journal.revision,
        after: reversal,
        commandDigest: command,
        bundle: {'original': after},
      );
    } else {
      await mutations.audit(
        operationId: operationId,
        entityType: 'journal',
        entityId: reverseId,
        action: 'post',
        after: reversal,
      );
    }
    await mutations.audit(
      operationId: operationId,
      entityType: 'journal',
      entityId: id,
      action: 'reverse',
      before: before,
      after: after,
    );
    return reverseId;
  }

  /// One durable correction aggregate prevents a remote partial reversal or replacement.
  Future<String> correct(
    String id, {
    required EntryKind kind,
    required String accountId,
    required String counterAccountId,
    required Money amount,
    required String occurredOn,
    required String description,
    required String reason,
    String? operationId,
  }) => storageBoundary(
    () => db.transaction(() async {
      await mutations.authorize();
      reason = _text(reason, 400);
      description = _text(description, 500);
      final op = operationId ?? uuid.v4();
      final command = payloadDigest(
        canonicalJson({
          'correct': id,
          'kind': kind.name,
          'account_id': accountId,
          'counter_account_id': counterAccountId,
          'amount_minor': amount.minor,
          'currency': amount.currency.code,
          'occurred_on': occurredOn,
          'description': description,
          'reason': reason,
        }),
      );
      final prior = await mutations.existing(op, command);
      if (prior != null) {
        return prior.entityId;
      }
      await ensureUnmanagedJournal(id);
      final original = await detail(id);
      final postings = await _transactionPostings(
        kind,
        accountId,
        counterAccountId,
        amount,
      );
      final reversal = await _cancel(
        id,
        reason: reason,
        operationId: uuid.v5(_nameSpace, '$op/reversal'),
        command: command,
        emitMutation: false,
      );
      final replacement = await _post(
        kind: kind,
        occurredOn: occurredOn,
        description: description,
        postings: postings,
        operationId: op,
        businessId: original.journal.businessId,
        relatedEntityId: original.journal.relatedEntityId,
        emitMutation: false,
      );
      await mutations.record(
        operationId: op,
        entityType: 'journal_correction',
        entityId: replacement,
        action: 'correct',
        baseRevision: original.journal.revision,
        after: await journalJson(replacement),
        commandDigest: command,
        bundle: {
          'original': await journalJson(id),
          'reversal': await journalJson(reversal),
        },
      );
      return replacement;
    }),
  );

  Future<FinanceSnapshot> snapshot() => storageBoundary(
    () => db.transaction(() async {
      await mutations.authorize();
      final accounts =
          await (db.select(db.ledgerAccounts)
                ..where((t) => t.familyId.equals(identity.familyId))
                ..orderBy([
                  (t) => OrderingTerm.asc(t.kind),
                  (t) => OrderingTerm.asc(t.name),
                ]))
              .get();
      final journals =
          await (db.select(db.ledgerJournals)
                ..where((t) => t.familyId.equals(identity.familyId))
                ..orderBy([
                  (t) => OrderingTerm.desc(t.occurredOn),
                  (t) => OrderingTerm.desc(t.createdAtUs),
                ]))
              .get();
      return FinanceSnapshot(
        accounts: accounts,
        journals: journals,
        postings: await (db.select(
          db.ledgerPostings,
        )..where((t) => t.familyId.equals(identity.familyId))).get(),
        budgets:
            await (db.select(db.monthlyBudgets)..where(
                  (t) =>
                      t.familyId.equals(identity.familyId) &
                      t.deletedAtUs.isNull(),
                ))
                .get(),
        reconciliations: await (db.select(
          db.reconciliationChecks,
        )..where((t) => t.familyId.equals(identity.familyId))).get(),
        managedAccountIds: await managedAccounts(),
        journalLinks: {
          for (final link in await (db.select(
            db.aggregateJournalLinks,
          )..where((t) => t.familyId.equals(identity.familyId))).get())
            link.journalId: link,
        },
      );
    }),
  );

  // Drift keys streams by SQL and parameters. Each projection uses a distinct
  // query label so its table subscriptions are not reused by another module.
  Stream<FinanceSnapshot> watch() => db
      .customSelect(
        'SELECT 1 /* ledger projection */',
        readsFrom: {
          db.ledgerAccounts,
          db.ledgerJournals,
          db.ledgerPostings,
          db.monthlyBudgets,
          db.reconciliationChecks,
          db.familyMembers,
          db.vaultDevices,
          db.wealthAssets,
          db.debtContracts,
          db.businesses,
          db.aggregateJournalLinks,
        },
      )
      .watch()
      .asyncMap((_) => snapshot());

  Future<void> setBudget({
    required String accountId,
    required String month,
    required Money amount,
    int? expectedRevision,
  }) => storageBoundary(
    () => db.transaction(() async {
      await mutations.authorize();
      validateDate('$month-01');
      final a = await account(accountId);
      if (a.kind != 'expense' ||
          a.deletedAtUs != null ||
          amount.minor < 0 ||
          amount.currency != Currency.inr) {
        throw _invalid;
      }
      final old =
          await (db.select(db.monthlyBudgets)..where(
                (t) =>
                    t.familyId.equals(identity.familyId) &
                    t.accountId.equals(accountId) &
                    t.month.equals(month) &
                    t.deletedAtUs.isNull(),
              ))
              .getSingleOrNull();
      if (expectedRevision != null &&
          (old?.revision ?? 0) != expectedRevision) {
        throw const AppFailure(
          FailureCode.conflict,
          'This budget changed. Refresh before saving.',
        );
      }
      final now = mutations.now, id = old?.id ?? uuid.v4();
      await db
          .into(db.monthlyBudgets)
          .insertOnConflictUpdate(
            MonthlyBudgetsCompanion.insert(
              id: id,
              familyId: identity.familyId,
              createdBy: old?.createdBy ?? identity.memberId,
              updatedBy: identity.memberId,
              createdAtUs: old?.createdAtUs ?? now,
              updatedAtUs: now,
              accountId: accountId,
              month: month,
              amountMinor: amount.minor,
              revision: Value((old?.revision ?? 0) + 1),
            ),
          );
      final after = await (db.select(
        db.monthlyBudgets,
      )..where((t) => t.id.equals(id))).getSingle();
      await mutations.record(
        operationId: uuid.v4(),
        entityType: 'budget',
        entityId: id,
        action: old == null ? 'create' : 'update',
        baseRevision: old?.revision ?? 0,
        before: old == null ? null : budgetJson(old),
        after: budgetJson(after),
      );
    }),
  );

  Future<void> reconcile({
    required String accountId,
    required String statementDate,
    required Money statementBalance,
    required String notes,
    bool postAdjustment = false,
    String? operationId,
  }) => storageBoundary(
    () => db.transaction(() async {
      await mutations.authorize();
      validateDate(statementDate);
      final summary = _text(notes, 500);
      final operation = operationId ?? uuid.v4();
      final command = payloadDigest(
        canonicalJson({
          'reconcile': accountId,
          'statement_date': statementDate,
          'statement_minor': statementBalance.minor,
          'notes': summary,
          'post_adjustment': postAdjustment,
        }),
      );
      final a = await account(accountId);
      if (statementBalance.currency != Currency.inr) {
        throw _invalid;
      }
      if (await mutations.existing(operation, command) != null) {
        return;
      }
      if (a.kind != 'asset' ||
          !['cash', 'bank'].contains(a.subtype) ||
          a.deletedAtUs != null) {
        throw _invalid;
      }
      final snap = await snapshot();
      final ledger = checkedMinor(
        snap.balances(through: statementDate)[a.id] ?? BigInt.zero,
      );
      final id = aggregateId(operation, 'reconciliation'), now = mutations.now;
      await db
          .into(db.reconciliationChecks)
          .insert(
            ReconciliationChecksCompanion.insert(
              id: id,
              familyId: identity.familyId,
              createdBy: identity.memberId,
              updatedBy: identity.memberId,
              createdAtUs: now,
              updatedAtUs: now,
              accountId: a.id,
              statementDate: statementDate,
              statementMinor: statementBalance.minor,
              ledgerMinor: ledger,
              notes: summary,
            ),
          );
      final record = {
        'id': id,
        'family_id': identity.familyId,
        'revision': 1,
        'created_by': identity.memberId,
        'updated_by': identity.memberId,
        'created_at_us': now,
        'updated_at_us': now,
        'deleted_at_us': null,
        'account_id': a.id,
        'statement_date': statementDate,
        'statement_minor': statementBalance.minor,
        'ledger_minor': ledger,
        'notes': summary,
      };
      Map<String, Object?>? bundle;
      if (postAdjustment && statementBalance.minor != ledger) {
        final difference = statementBalance - Money.fromMinor(ledger);
        final journal = await _post(
          kind: EntryKind.adjustment,
          occurredOn: statementDate,
          description: 'Statement reconciliation',
          operationId: aggregateId(operation, 'adjustment'),
          postings: [
            PostingInput(a.id, difference.minor),
            PostingInput(chartId('reconciliation'), difference.negate().minor),
          ],
          relatedEntityId: id,
          emitMutation: false,
        );
        final adjustment = await journalJson(journal);
        bundle = {'adjustment': adjustment};
        await mutations.audit(
          operationId: operation,
          entityType: 'journal',
          entityId: journal,
          action: 'post',
          after: adjustment,
        );
      }
      await mutations.record(
        operationId: operation,
        entityType: 'reconciliation',
        entityId: id,
        action: 'create',
        baseRevision: 0,
        after: record,
        commandDigest: command,
        bundle: bundle,
      );
    }),
  );

  static Map<String, Object?> accountJson(LedgerAccount a) => {
    'id': a.id,
    'family_id': a.familyId,
    'revision': a.revision,
    'created_by': a.createdBy,
    'updated_by': a.updatedBy,
    'created_at_us': a.createdAtUs,
    'updated_at_us': a.updatedAtUs,
    'deleted_at_us': a.deletedAtUs,
    'name': a.name,
    'kind': a.kind,
    'subtype': a.subtype,
    'currency': a.currency,
    'system_account': a.systemAccount,
  };
  static Map<String, Object?> budgetJson(MonthlyBudget b) => {
    'id': b.id,
    'family_id': b.familyId,
    'revision': b.revision,
    'created_by': b.createdBy,
    'updated_by': b.updatedBy,
    'created_at_us': b.createdAtUs,
    'updated_at_us': b.updatedAtUs,
    'deleted_at_us': b.deletedAtUs,
    'account_id': b.accountId,
    'month': b.month,
    'amount_minor': b.amountMinor,
  };
  Future<Map<String, Object?>> journalJson(String id) async {
    final d = await detail(id), j = d.journal;
    return {
      'id': j.id,
      'family_id': j.familyId,
      'revision': j.revision,
      'created_by': j.createdBy,
      'updated_by': j.updatedBy,
      'created_at_us': j.createdAtUs,
      'updated_at_us': j.updatedAtUs,
      'deleted_at_us': j.deletedAtUs,
      'kind': j.kind,
      'occurred_on': j.occurredOn,
      'description': j.description,
      'currency': j.currency,
      'status': j.status,
      'reverses_id': j.reversesId,
      'business_id': j.businessId,
      'related_entity_id': j.relatedEntityId,
      'postings': [
        for (final p in d.postings)
          {
            'id': p.id,
            'family_id': p.familyId,
            'journal_id': p.journalId,
            'account_id': p.accountId,
            'position': p.position,
            'amount_minor': p.amountMinor,
          },
      ],
    };
  }
}
