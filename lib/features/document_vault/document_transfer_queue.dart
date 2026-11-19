part of 'document_repository.dart';

extension DocumentTransferQueue on DocumentRepository {
  /// An acknowledged upload remains visible until the accepted version arrives.
  Stream<List<VaultDocumentUpload>> watchUploads() async* {
    await _authorize();
    final uploads = _db.vaultDocumentUploads;
    final versions = _db.vaultDocumentVersions;
    final query =
        _db.select(uploads).join([
            leftOuterJoin(
              versions,
              versions.id.equalsExp(uploads.id),
              useColumns: false,
            ),
          ])
          ..where(
            uploads.familyId.equals(_familyId) &
                uploads.deviceId.equals(_deviceId) &
                (uploads.state.equals('acknowledged').not() |
                    versions.id.isNull()),
          )
          ..orderBy([OrderingTerm.desc(uploads.createdAtUs)]);
    await for (final rows in query.watch()) {
      _checkOpen();
      yield rows.map((row) => row.readTable(uploads)).toList();
    }
  }

  Future<void> _stage(
    VaultDocumentVersion version,
    int baseRevision,
    DocumentDetails details,
    SecretKeyData key,
  ) async {
    final pending =
        await (_db.select(_db.vaultDocumentUploads)..where(
              (t) =>
                  t.familyId.equals(_familyId) &
                  t.documentId.equals(version.documentId) &
                  t.state.equals('pending'),
            ))
            .getSingleOrNull();
    if (pending != null) {
      throw const AppFailure(
        FailureCode.conflict,
        'Wait for the current version to finish sharing before adding another.',
      );
    }
    final title = _title(details);
    final clear = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'title': title,
          'category': details.category.name,
          'expiry_on': details.expiryOn,
        }),
      ),
    );
    final String metadata;
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
      metadata = base64Encode(box.concatenation());
    } finally {
      clear.fillRange(0, clear.length, 0);
    }
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
