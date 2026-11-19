part of 'ledger_repository.dart';

/// Domain modules coordinate metadata, events and journals in one durable command.
/// Backend operations must independently enforce this contract and authorization.
extension LedgerAggregates on LedgerRepository {
  String aggregateId(String operationId, String label) =>
      LedgerRepository.uuid.v5(
        LedgerRepository._nameSpace,
        '${identity.familyId}/$operationId/$label',
      );

  Future<String> runAggregate({
    required String operationId,
    required String entityType,
    required String entityId,
    required int baseRevision,
    required Map<String, Object?> command,
    required Future<Map<String, Object?>> Function(LedgerAggregate) change,
    String action = 'update',
  }) => storageBoundary(
    () => db.transaction(() async {
      if (identity.isCloud &&
          !const {
            'asset',
            'debt',
            'business',
            'stock',
            'worker',
          }.contains(entityType)) {
        throw const AppFailure(
          FailureCode.configuration,
          'Use your local vault to edit this section while family sync is in development.',
        );
      }
      await mutations.authorize();
      final digest = payloadDigest(
        canonicalJson({
          'entity_type': entityType,
          'entity_id': entityId,
          'base_revision': baseRevision,
          'action': action,
          'command': command,
        }),
      );
      final prior = await mutations.existing(operationId, digest);
      if (prior != null) return prior.entityId;
      final context = LedgerAggregate._(
        this,
        operationId,
        entityType,
        entityId,
      );
      try {
        final after = await change(context);
        await mutations.record(
          operationId: operationId,
          entityType: entityType,
          entityId: entityId,
          action: action,
          baseRevision: baseRevision,
          before: context.before,
          after: after,
          commandDigest: digest,
          bundle: context._bundle,
        );
        return entityId;
      } finally {
        context._active = false;
      }
    }),
  );

  Future<Set<String>> managedAccounts() async {
    final rows = await db.customSelect(
      '''SELECT account_id FROM wealth_assets WHERE family_id = ?
         UNION SELECT account_id FROM debt_contracts WHERE family_id = ?
         UNION SELECT inventory_account_id FROM businesses WHERE family_id = ?
         UNION SELECT cost_of_goods_account_id FROM businesses WHERE family_id = ?
         UNION SELECT salary_account_id FROM businesses WHERE family_id = ?''',
      variables: List.generate(5, (_) => Variable(identity.familyId)),
    ).get();
    return {for (final row in rows) row.read<String>('account_id')};
  }

  /// Sums individual stored integers without SQLite SUM's signed-64 limit.
  /// Module callers use this inside an authorized transaction.
  Future<BigInt> accountBalance(
    String id, {
    String? through,
    bool beforeAssetClosure = false,
  }) async {
    final rows = await db
        .customSelect(
          '''SELECT p.amount_minor FROM ledger_postings p
         JOIN ledger_journals j ON j.family_id = p.family_id AND j.id = p.journal_id
         WHERE p.family_id = ? AND p.account_id = ? AND j.status = 'posted'
         ${through == null ? '' : 'AND j.occurred_on <= ?'}
         ${beforeAssetClosure ? """AND NOT (j.deleted_at_us IS NULL AND EXISTS (
           SELECT 1 FROM aggregate_journal_links l WHERE l.journal_id = j.id
           AND l.family_id = j.family_id AND l.purpose IN ('disposal', 'disposal_bridge')))""" : ''}''',
          variables: [
            Variable(identity.familyId),
            Variable(id),
            if (through != null) Variable(through),
          ],
        )
        .get();
    return rows.fold<BigInt>(
      BigInt.zero,
      (total, row) => total + BigInt.from(row.read<int>('amount_minor')),
    );
  }

  Future<bool> isManagedAccount(String id) async =>
      (await db
              .customSelect(
                '''SELECT 1 FROM wealth_assets WHERE family_id = ? AND account_id = ?
        UNION ALL SELECT 1 FROM debt_contracts WHERE family_id = ? AND account_id = ?
        UNION ALL SELECT 1 FROM businesses WHERE family_id = ?
          AND (inventory_account_id = ? OR cost_of_goods_account_id = ? OR salary_account_id = ?) LIMIT 1''',
                variables: [
                  Variable(identity.familyId),
                  Variable(id),
                  Variable(identity.familyId),
                  Variable(id),
                  Variable(identity.familyId),
                  Variable(id),
                  Variable(id),
                  Variable(id),
                ],
              )
              .get())
          .isNotEmpty;

  Future<void> ensureUnmanagedAccount(String id) async {
    if (await isManagedAccount(id)) {
      throw const AppFailure(
        FailureCode.validation,
        'Change this account through its asset, loan or business record.',
      );
    }
  }

  Future<void> ensureUnmanagedJournal(String id) async {
    final link =
        await (db.select(db.aggregateJournalLinks)..where(
              (t) =>
                  t.familyId.equals(identity.familyId) & t.journalId.equals(id),
            ))
            .getSingleOrNull();
    if (link != null) {
      throw const AppFailure(
        FailureCode.validation,
        'Correct this entry through its asset, loan or business record.',
      );
    }
    for (final p in (await detail(id)).postings) {
      await ensureUnmanagedAccount(p.accountId);
    }
  }
}

final class LedgerAggregate {
  LedgerAggregate._(
    this._ledger,
    this.operationId,
    this.entityType,
    this.entityId,
  );
  final LedgerRepository _ledger;
  final String operationId, entityType, entityId;
  bool _active = true;
  int _journalIndex = 0;
  Map<String, Object?>? before;
  final _bundle = <String, Object?>{};
  final _accounts = <Map<String, Object?>>[];
  final _journals = <Map<String, Object?>>[];
  final _links = <Map<String, Object?>>[];

  void _check() {
    if (!_active) {
      throw StateError('This aggregate transaction has ended');
    }
  }

  String id(String label) => _ledger.aggregateId(operationId, label);
  void include(String key, Object? value) {
    _check();
    _bundle[key] = value;
  }

  Future<LedgerAccount> createAccount({
    required String label,
    required String name,
    required AccountKind kind,
    required String subtype,
  }) async {
    _check();
    final a = await _ledger._insertAccount(
      id: id('account/$label'),
      name: name,
      kind: kind,
      subtype: subtype,
      emitMutation: false,
    );
    await _retainAccount(a);
    return a;
  }

  Future<LedgerAccount> systemAccount(
    String code,
    String name,
    AccountKind kind,
  ) async {
    _check();
    final id = _ledger.chartId(code);
    final prior =
        await (_ledger.db.select(_ledger.db.ledgerAccounts)..where(
              (t) =>
                  t.familyId.equals(_ledger.identity.familyId) &
                  t.id.equals(id),
            ))
            .getSingleOrNull();
    if (prior != null) {
      if (!prior.systemAccount ||
          prior.kind != kind.name ||
          prior.subtype != code ||
          prior.deletedAtUs != null) {
        throw LedgerRepository._invalid;
      }
      return prior;
    }
    final a = await _ledger._insertAccount(
      id: id,
      name: name,
      kind: kind,
      subtype: code,
      system: true,
      emitMutation: false,
    );
    await _retainAccount(a);
    return a;
  }

  Future<void> _retainAccount(LedgerAccount a) async {
    final json = LedgerRepository.accountJson(a);
    _accounts.add(json);
    _bundle['accounts'] = _accounts;
    await _ledger.mutations.audit(
      operationId: operationId,
      entityType: 'account',
      entityId: a.id,
      action: 'create',
      after: json,
    );
  }

  Future<void> renameAccount(String id, String name) async {
    _check();
    final a = await _ledger.account(id);
    await (_ledger.db.update(
      _ledger.db.ledgerAccounts,
    )..where((t) => t.id.equals(id))).write(
      LedgerAccountsCompanion(
        name: Value(LedgerRepository._text(name, 120)),
        revision: Value(a.revision + 1),
        updatedBy: Value(_ledger.identity.memberId),
        updatedAtUs: Value(_ledger.mutations.now),
      ),
    );
    final after = LedgerRepository.accountJson(await _ledger.account(id));
    _accounts.add(after);
    _bundle['accounts'] = _accounts;
    await _ledger.mutations.audit(
      operationId: operationId,
      entityType: 'account',
      entityId: id,
      action: 'update',
      before: LedgerRepository.accountJson(a),
      after: after,
    );
  }

  Future<LedgerAccount> liquidAccount(String id) async {
    _check();
    final a = await _ledger.account(id);
    if (a.deletedAtUs != null ||
        a.kind != 'asset' ||
        !['cash', 'bank'].contains(a.subtype)) {
      throw const AppFailure(
        FailureCode.validation,
        'Choose an active cash or bank account.',
      );
    }
    await _ledger.ensureUnmanagedAccount(id);
    return a;
  }

  Future<String> post({
    required EntryKind kind,
    required String occurredOn,
    required String description,
    required List<PostingInput> postings,
    required String purpose,
    String? businessId,
    String? relatedEntityId,
    String? aggregateType,
  }) async {
    _check();
    final journal = await _ledger._post(
      kind: kind,
      occurredOn: occurredOn,
      description: description,
      postings: postings,
      operationId: id('journal/${_journalIndex++}'),
      businessId: businessId,
      relatedEntityId: relatedEntityId ?? entityId,
      emitMutation: false,
    );
    await _retainJournal(
      journal,
      purpose: purpose,
      aggregateType: aggregateType,
      aggregateId: relatedEntityId,
    );
    await _ledger.mutations.audit(
      operationId: operationId,
      entityType: 'journal',
      entityId: journal,
      action: 'post',
      after: await _ledger.journalJson(journal),
    );
    return journal;
  }

  Future<String> reverse(
    String journalId,
    String reason, {
    String? aggregateType,
    String? aggregateId,
  }) async {
    _check();
    final original = await _ledger.detail(journalId);
    final link =
        await (_ledger.db.select(_ledger.db.aggregateJournalLinks)..where(
              (t) =>
                  t.journalId.equals(journalId) &
                  t.familyId.equals(_ledger.identity.familyId),
            ))
            .getSingleOrNull();
    if (link == null ||
        link.aggregateId != (aggregateId ?? entityId) ||
        link.aggregateType != (aggregateType ?? entityType)) {
      throw LedgerRepository._invalid;
    }
    final reversal = await _ledger._cancel(
      journalId,
      reason: LedgerRepository._text(reason, 400),
      operationId: id('journal/${_journalIndex++}'),
      command: '',
      emitMutation: false,
    );
    _journals.add(await _ledger.journalJson(original.journal.id));
    await _retainJournal(
      reversal,
      purpose: 'reversal',
      aggregateType: aggregateType,
      aggregateId: aggregateId,
    );
    return reversal;
  }

  Future<void> _retainJournal(
    String journal, {
    required String purpose,
    String? aggregateType,
    String? aggregateId,
  }) async {
    final link = AggregateJournalLinksCompanion.insert(
      journalId: journal,
      familyId: _ledger.identity.familyId,
      aggregateType: aggregateType ?? entityType,
      aggregateId: aggregateId ?? entityId,
      operationId: operationId,
      purpose: Value(purpose),
    );
    await _ledger.db.into(_ledger.db.aggregateJournalLinks).insert(link);
    _journals.add(await _ledger.journalJson(journal));
    _links.add({
      'journal_id': journal,
      'family_id': _ledger.identity.familyId,
      'aggregate_type': aggregateType ?? entityType,
      'aggregate_id': aggregateId ?? entityId,
      'operation_id': operationId,
      'purpose': purpose,
    });
    _bundle['journals'] = _journals;
    _bundle['journal_links'] = _links;
  }
}
