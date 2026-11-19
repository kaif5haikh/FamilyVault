part of 'document_repository.dart';

extension DocumentTransferQueue on DocumentRepository {
  /// An acknowledged upload remains visible until the accepted version arrives.
  Stream<List<VaultDocumentUpload>> watchUploads() async* {
    await _authorize();
    final uploads = _db.vaultDocumentUploads;
    final versions = _db.vaultDocumentVersions;
    final audit = _db.localAuditEvents;
    final query =
        _db.select(uploads).join([
            leftOuterJoin(
              versions,
              versions.id.equalsExp(uploads.id),
              useColumns: false,
            ),
            leftOuterJoin(
              audit,
              audit.familyId.equalsExp(uploads.familyId) &
                  audit.operationId.equalsExp(uploads.operationId) &
                  audit.entityType.equals('document_resolution'),
              useColumns: false,
            ),
          ])
          ..where(
            uploads.familyId.equals(_familyId) &
                (session.identity.isCloud
                    ? uploads.deviceId.equals(_deviceId)
                    : uploads.memberId.equals(_memberId)) &
                audit.id.isNull() &
                (uploads.state.equals('acknowledged').not() |
                    versions.id.isNull()),
          )
          ..orderBy([OrderingTerm.desc(uploads.createdAtUs)]);
    await for (final rows in query.watch()) {
      _checkOpen();
      yield rows.map((row) => row.readTable(uploads)).toList();
    }
  }

  Future<VaultDocumentUpload?> _findUpload(String documentId, String id) =>
      (_db.select(_db.vaultDocumentUploads)..where(
            (t) =>
                t.familyId.equals(_familyId) &
                t.documentId.equals(documentId) &
                t.id.equals(id) &
                (session.identity.isCloud
                    ? t.deviceId.equals(_deviceId)
                    : t.memberId.equals(_memberId)),
          ))
          .getSingleOrNull();

  Future<bool> _retried(VaultDocumentUpload job) async =>
      (await (_db.select(_db.localAuditEvents)..where(
            (t) =>
                t.familyId.equals(_familyId) &
                t.operationId.equals(job.operationId) &
                t.entityType.equals('document_resolution'),
          ))
          .getSingleOrNull()) !=
      null;

  Future<VaultDocumentVersion> retryDraft(
    String documentId,
    String versionId,
    int expectedRevision,
  ) => storageBoundary(() async {
    await _authorize();
    if (!session.identity.isCloud) throw DocumentRepository._missing;
    final draft = await _findUpload(documentId, versionId);
    if (draft == null || draft.state != 'conflicted' || await _retried(draft)) {
      throw DocumentRepository._missing;
    }
    final bytes = await read(documentId, versionId, DocumentAccess.preview);
    try {
      return await _addVersion(
        documentId,
        DocumentInput(
          length: () async => bytes.length,
          openRead: () => Stream.value(bytes),
        ),
        expectedRevision: expectedRevision,
        retry: draft,
      );
    } finally {
      bytes.fillRange(0, bytes.length, 0);
    }
  });

  Future<void> _stage(
    VaultDocumentVersion version,
    int baseRevision,
    DocumentDetails details,
    SecretKeyData key, {
    VaultDocumentUpload? retry,
  }) async {
    await _checkOperationSlot(version.documentId);
    if (retry != null && await _retried(retry)) {
      throw DocumentRepository._changed;
    }
    final title = _title(details);
    final metadata = await _sealMetadata(version, details, key);
    final operation = DocumentRepository._uuid.v4();
    await _db
        .into(_db.vaultDocumentUploads)
        .insert(
          VaultDocumentUploadsCompanion.insert(
            id: version.id,
            operationId: operation,
            familyId: _familyId,
            documentId: version.documentId,
            ownerId: details.ownerId,
            memberId: _memberId,
            deviceId: _deviceId,
            baseRevision: baseRevision,
            version: version.version,
            title: title,
            metadataBox: metadata,
            mimeType: version.mimeType,
            plaintextBytes: version.plaintextBytes,
            ciphertextDigest: version.ciphertextDigest,
            wrappedKey: version.wrappedKey,
            createdAtUs: version.createdAtUs,
          ),
        );
    await _writer.audit(
      operationId: operation,
      entityType: 'document_transfer',
      entityId: version.documentId,
      action: 'queue',
      after: {'version_id': version.id},
    );
    if (retry != null) {
      await _writer.audit(
        operationId: retry.operationId,
        entityType: 'document_resolution',
        entityId: retry.documentId,
        action: 'retry',
        after: {'version_id': retry.id, 'replacement_version_id': version.id},
      );
    }
  }

  Future<String> _sealMetadata(
    VaultDocumentVersion version,
    DocumentDetails details,
    SecretKey key,
  ) async {
    final clear = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'title': _title(details),
          'category': details.category.name,
          'expiry_on': details.expiryOn,
        }),
      ),
    );
    try {
      final box = await SealedFile.algorithm.encrypt(
        clear,
        secretKey: key,
        aad: _metadataContext(
          _familyId,
          version.documentId,
          version.id,
          details.ownerId,
        ),
      );
      return base64Encode(box.concatenation());
    } finally {
      clear.fillRange(0, clear.length, 0);
    }
  }
}

List<int> _metadataContext(
  String family,
  String doc,
  String version,
  String owner,
) => utf8.encode(
  jsonEncode(['FamilyVault document metadata v1', family, doc, version, owner]),
);

extension on VaultDocumentUpload {
  VaultDocumentVersion get fileVersion => VaultDocumentVersion(
    id: id,
    familyId: familyId,
    documentId: documentId,
    version: version,
    mimeType: mimeType,
    plaintextBytes: plaintextBytes,
    ciphertextDigest: ciphertextDigest,
    wrappedKey: wrappedKey,
    createdBy: memberId,
    deviceId: deviceId,
    createdAtUs: createdAtUs,
  );
}
