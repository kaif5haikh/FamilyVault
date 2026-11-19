part of 'document_repository.dart';

typedef DocumentEditStatus = ({
  String documentId,
  String title,
  String state,
  String action,
});

extension SharedDocumentEdits on DocumentRepository {
  Stream<List<DocumentEditStatus>> watchDocumentEdits() async* {
    await _authorize();
    final edits = _db.pendingMutations, docs = _db.vaultDocuments;
    final query =
        _db.select(edits).join([
            innerJoin(
              docs,
              docs.id.equalsExp(edits.entityId) &
                  docs.familyId.equalsExp(edits.familyId),
            ),
          ])
          ..where(
            edits.familyId.equals(_familyId) &
                edits.deviceId.equals(_deviceId) &
                edits.entityType.equals('document_change') &
                (edits.state.equals('acknowledged').not() |
                    docs.revision.isSmallerThan(edits.acceptedRevision)),
          )
          ..orderBy([OrderingTerm.desc(edits.createdAtUs)]);
    await for (final rows in query.watch()) {
      _checkOpen();
      yield [
        for (final row in rows)
          (
            documentId: row.readTable(docs).id,
            title: row.readTable(docs).title,
            state: row.readTable(edits).state,
            action: _changeRequest(row.readTable(edits)).action,
          ),
      ];
    }
  }

  Future<void> _checkOperationSlot(String documentId) async {
    final upload =
        await (_db.select(_db.vaultDocumentUploads)..where(
              (t) =>
                  t.familyId.equals(_familyId) &
                  t.documentId.equals(documentId) &
                  t.state.equals('pending'),
            ))
            .getSingleOrNull();
    final edit =
        await (_db.select(_db.pendingMutations)..where(
              (t) =>
                  t.familyId.equals(_familyId) &
                  t.entityType.equals('document_change') &
                  t.entityId.equals(documentId) &
                  t.state.equals('pending'),
            ))
            .getSingleOrNull();
    if (upload != null || edit != null) {
      throw const AppFailure(
        FailureCode.conflict,
        'Wait for the current document change to finish sharing.',
      );
    }
  }

  Future<void> _stageChange(
    VaultDocument old,
    String action, {
    VaultDocument? metadata,
    String? linkId,
    String? journalId,
  }) async {
    await _checkOperationSlot(old.id);
    final version =
        await _latestVersion(old.id) ?? (throw DocumentRepository._missing);
    String? box;
    if (metadata != null) {
      final key = await _unwrap(
        version.wrappedKey,
        _context(old.id, version.id, version.mimeType, version.plaintextBytes),
      );
      try {
        box = await _sealMetadata(
          version,
          DocumentDetails(
            title: metadata.title,
            category: DocumentCategory.values.byName(metadata.category),
            ownerId: metadata.ownerId,
            expiryOn: metadata.expiryOn,
          ),
          key,
        );
      } finally {
        key.destroy();
      }
    }
    await _authorize();
    await _writer.record(
      operationId: DocumentRepository._uuid.v4(),
      entityType: 'document_change',
      entityId: old.id,
      action: action,
      baseRevision: old.revision,
      after: {
        'id': old.id,
        'family_id': _familyId,
        'version_id': version.id,
        'action': action,
        'owner_id': metadata?.ownerId,
        'metadata_box': box,
        'link_id': linkId,
        'journal_id': journalId,
      },
    );
  }
}

DocumentChangeRequest _changeRequest(PendingMutation job) {
  final envelope = SyncEnvelope.verify(job.payloadJson, job.payloadDigest);
  if (envelope.familyId != job.familyId ||
      envelope.deviceId != job.deviceId ||
      envelope.operationId != job.operationId ||
      envelope.entityType != 'document_change' ||
      envelope.entityId != job.entityId ||
      envelope.baseRevision != job.baseRevision) {
    throw _invalidSharedDocument;
  }
  final record = envelope.record;
  final action = _docText(record, 'action');
  final linking = action == 'link' || action == 'unlink';
  if (!linking && !['metadata', 'archive', 'restore'].contains(action)) {
    throw _invalidSharedDocument;
  }
  return DocumentChangeRequest(
    operationId: job.operationId,
    documentId: job.entityId,
    versionId: _docId(record, 'version_id'),
    baseRevision: job.baseRevision,
    action: action,
    ownerId: action == 'metadata' ? _docId(record, 'owner_id') : null,
    metadataBox: action == 'metadata' ? _docText(record, 'metadata_box') : null,
    linkId: linking ? _docId(record, 'link_id') : null,
    journalId: linking ? _docId(record, 'journal_id') : null,
  );
}

extension on _SharedDocumentSync {
  Future<AppFailure?> _sendEdits() async {
    _check();
    final now = repository._writer.now;
    final edits =
        await (_db.select(_db.pendingMutations)
              ..where(
                (t) =>
                    t.familyId.equals(_family) &
                    t.deviceId.equals(_device) &
                    t.entityType.equals('document_change') &
                    t.state.equals('pending') &
                    (t.nextAttemptAtUs.isNull() |
                        t.nextAttemptAtUs.isSmallerOrEqualValue(now)),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.createdAtUs)])
              ..limit(8))
            .get();
    for (final job in edits) {
      try {
        final request = _changeRequest(job);
        final receipt = await _call(() => transport.change(request));
        if (receipt['operation_id'] != job.operationId ||
            receipt['document_id'] != job.entityId ||
            receipt['version_id'] != request.versionId ||
            receipt['action'] != request.action ||
            receipt['link_id'] != request.linkId ||
            receipt['journal_id'] != request.journalId ||
            receipt['revision'] != job.baseRevision + 1) {
          throw _invalidSharedDocument;
        }
        await _recordEdit(job, 'acknowledged');
      } on AppFailure catch (error) {
        _check();
        final state = _stateForFailure(error);
        await _recordEdit(job, state);
        if (state == 'pending') return error;
      }
    }
    return null;
  }

  Future<void> _recordEdit(PendingMutation job, String state) =>
      _db.transaction(() async {
        _check();
        final changed =
            await (_db.update(_db.pendingMutations)..where(
                  (t) =>
                      t.operationId.equals(job.operationId) &
                      t.state.equals('pending'),
                ))
                .write(
                  PendingMutationsCompanion(
                    state: Value(state),
                    attempts: Value(job.attempts + 1),
                    nextAttemptAtUs: Value(
                      state == 'pending' ? _retryAt(job.attempts) : null,
                    ),
                    acceptedRevision: Value(
                      state == 'acknowledged' ? job.baseRevision + 1 : null,
                    ),
                  ),
                );
        if (changed == 1 && state != 'pending') {
          await repository._writer.audit(
            operationId: job.operationId,
            entityType: 'document_receipt',
            entityId: job.entityId,
            action: state,
            after: {'revision': job.baseRevision + 1},
          );
        }
      });
}
