part of 'ledger_replay.dart';

extension _LedgerModuleReplay on LedgerReplay {
  void _moduleRevision(
    SyncEnvelope envelope,
    String id,
    String rowFamily,
    int revision,
    int? previous,
  ) {
    if (id != envelope.entityId ||
        rowFamily != familyId ||
        revision != envelope.baseRevision + 1) {
      throw syncIntegrityFailure;
    }
    if ((previous ?? 0) != envelope.baseRevision) {
      throw SyncReplayConflict(id, envelope.record);
    }
  }

  Iterable<SyncJson> _rows(SyncJson bundle, String field) sync* {
    if (!bundle.containsKey(field)) return;
    final value = bundle[field];
    if (value is! List<Object?>) throw syncIntegrityFailure;
    for (final row in value) {
      yield syncObject(row);
    }
  }

  Future<void> _moduleAccounts(SyncChange change) async {
    for (final row in _rows(change.envelope.bundle, 'accounts')) {
      final account = readDatabaseRecord(row, LedgerAccount.fromJson);
      final prior = await _account(row, account.revision - 1);
      await _audit(change, 'account', row, before: prior);
    }
  }

  Future<void> _moduleJournals(SyncChange change) async {
    final bundle = change.envelope.bundle;
    final journals = <String, SyncJson>{};
    for (final row in _rows(bundle, 'journals')) {
      final id = _journal(row).id;
      if (journals.containsKey(id)) throw syncIntegrityFailure;
      journals[id] = row;
    }
    for (final row in _rows(bundle, 'journal_links')) {
      final link = readDatabaseRecord(row, AggregateJournalLink.fromJson);
      final journal = journals.remove(link.journalId);
      if (journal == null ||
          link.familyId != familyId ||
          link.operationId != change.envelope.operationId) {
        throw syncIntegrityFailure;
      }
      final originalId = journal['reverses_id'];
      if (originalId != null) {
        final original = journals.remove(originalId);
        if (original == null) throw syncIntegrityFailure;
        await _cancel(
          change,
          original,
          journal,
          originalBase: _journal(original).revision - 1,
        );
      } else {
        await _postJournal(journal);
      }
      await db.into(db.aggregateJournalLinks).insert(link);
      await _audit(change, 'journal', journal, action: 'post');
    }
    if (journals.isNotEmpty) throw syncIntegrityFailure;
  }

  Future<SyncJson?> _asset(SyncChange change) async {
    final envelope = change.envelope;
    final raw = envelope.record, bundle = envelope.bundle;
    final asset = readDatabaseRecord(raw, WealthAsset.fromJson);
    final prior = await (db.select(
      db.wealthAssets,
    )..where((t) => t.id.equals(asset.id))).getSingleOrNull();
    _moduleRevision(
      envelope,
      asset.id,
      asset.familyId,
      asset.revision,
      prior?.revision,
    );
    await _moduleAccounts(change);
    await db
        .into(db.wealthAssets)
        .insertOnConflictUpdate(asset.toCompanion(false));
    if (bundle['property'] case final property?) {
      final data = readDatabaseRecord(
        syncObject(property),
        PropertyDetail.fromJson,
      );
      if (data.familyId != familyId || data.assetId != asset.id) {
        throw syncIntegrityFailure;
      }
      await db
          .into(db.propertyDetails)
          .insertOnConflictUpdate(data.toCompanion(false));
    }
    if (bundle['metal'] case final metal?) {
      final data = readDatabaseRecord(syncObject(metal), MetalDetail.fromJson);
      if (data.familyId != familyId || data.assetId != asset.id) {
        throw syncIntegrityFailure;
      }
      await db
          .into(db.metalDetails)
          .insertOnConflictUpdate(data.toCompanion(false));
    }
    if (bundle['investment'] case final investment?) {
      final data = readDatabaseRecord(
        syncObject(investment),
        InvestmentDetail.fromJson,
      );
      if (data.familyId != familyId || data.assetId != asset.id) {
        throw syncIntegrityFailure;
      }
      await db
          .into(db.investmentDetails)
          .insertOnConflictUpdate(data.toCompanion(false));
    }
    for (final row in _rows(bundle, 'ownerships')) {
      final owner = readDatabaseRecord(row, AssetOwnership.fromJson);
      if (owner.familyId != familyId || owner.assetId != asset.id) {
        throw syncIntegrityFailure;
      }
      await db
          .into(db.assetOwnerships)
          .insertOnConflictUpdate(owner.toCompanion(false));
    }
    await _moduleJournals(change);
    for (final row in _rows(bundle, 'valuations')) {
      final quote = readDatabaseRecord(row, AssetValuation.fromJson);
      if (quote.familyId != familyId || quote.assetId != asset.id) {
        throw syncIntegrityFailure;
      }
      await db.into(db.assetValuations).insert(quote);
    }
    return prior == null ? null : databaseRecord(prior);
  }

  Future<SyncJson?> _debt(SyncChange change) async {
    final envelope = change.envelope;
    final raw = envelope.record;
    final loan = readDatabaseRecord(raw, DebtContract.fromJson);
    final prior = await (db.select(
      db.debtContracts,
    )..where((t) => t.id.equals(loan.id))).getSingleOrNull();
    _moduleRevision(
      envelope,
      loan.id,
      loan.familyId,
      loan.revision,
      prior?.revision,
    );
    await _moduleAccounts(change);
    await db
        .into(db.debtContracts)
        .insertOnConflictUpdate(loan.toCompanion(false));
    await _moduleJournals(change);
    for (final row in _rows(envelope.bundle, 'repayments')) {
      final payment = readDatabaseRecord(row, DebtRepayment.fromJson);
      if (payment.familyId != familyId || payment.contractId != loan.id) {
        throw syncIntegrityFailure;
      }
      await db.into(db.debtRepayments).insert(payment);
    }
    return prior == null ? null : databaseRecord(prior);
  }

  Future<SyncJson?> _business(SyncChange change) async {
    final envelope = change.envelope;
    final business = readDatabaseRecord(
      envelope.record,
      BusinessesData.fromJson,
    );
    final prior = await (db.select(
      db.businesses,
    )..where((t) => t.id.equals(business.id))).getSingleOrNull();
    _moduleRevision(
      envelope,
      business.id,
      business.familyId,
      business.revision,
      prior?.revision,
    );
    await _moduleAccounts(change);
    await db
        .into(db.businesses)
        .insertOnConflictUpdate(business.toCompanion(false));
    return prior == null ? null : databaseRecord(prior);
  }
}
