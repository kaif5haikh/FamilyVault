part of 'document_repository.dart';

extension DocumentBackup on DocumentRepository {
  /// Read the references from the pinned database image. Include staged or
  /// conflicted versions, as well as files already accepted by the family.
  Future<List<({VaultDocumentVersion version, bool confirmed})>> backupVersions(
    AppDatabase snapshot,
  ) async {
    await _authorize();
    final versions = await (snapshot.select(
      snapshot.vaultDocumentVersions,
    )..where((t) => t.familyId.equals(_familyId))).get();
    final queued = await (snapshot.select(
      snapshot.vaultDocumentUploads,
    )..where((t) => t.familyId.equals(_familyId))).get();
    return [
      for (final version in versions) (version: version, confirmed: true),
      for (final job in queued) (version: job.fileVersion, confirmed: false),
    ];
  }

  Future<File> verifiedBackupFile(
    VaultDocumentVersion version, {
    required bool confirmed,
  }) async {
    await _authorize();
    if (version.familyId != _familyId) throw DocumentRepository._missing;
    final file = ciphertext(version.id);
    if (confirmed && _sharing != null && !await file.exists()) {
      await _sharing!.cache(version);
    }
    if (!await file.exists()) {
      throw const AppFailure(
        FailureCode.storage,
        'A document file is missing from this backup. Open the document and try again.',
      );
    }
    final context = _context(
      version.documentId,
      version.id,
      version.mimeType,
      version.plaintextBytes,
    );
    final key = await _unwrap(version.wrappedKey, context);
    try {
      await SealedFile.decrypt(
        source: file,
        clearLength: version.plaintextBytes,
        expectedDigest: version.ciphertextDigest,
        key: key,
        context: context,
        write: (bytes) async => bytes.fillRange(0, bytes.length, 0),
      );
      await _authorize();
      return file;
    } finally {
      key.destroy();
    }
  }
}
