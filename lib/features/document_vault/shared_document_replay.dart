part of 'document_repository.dart';

Future<void> _replayDocuments(
  _SharedDocumentSync sync,
  DocumentRoster roster,
) async {
  final rows = await sync._call(sync.transport.list);
  AppFailure? failure;
  var waiting = false;
  for (final row in rows) {
    try {
      final available = await _replayDocument(sync, row, roster);
      waiting |= !available;
    } on AppFailure catch (error) {
      if (error.code != FailureCode.integrity) rethrow;
      failure = error;
    }
  }
  if (failure != null) throw failure;
  if (waiting) {
    throw const AppFailure(
      FailureCode.configuration,
      'Waiting for another approved device to share older document keys.',
    );
  }
}

Future<bool> _replayDocument(
  _SharedDocumentSync sync,
  DocumentWire row,
  DocumentRoster roster,
) async {
  final repository = sync.repository, db = sync._db;
  final id = _docId(row, 'id'), revision = _docInt(row, 'revision');
  final existing =
      await (db.select(db.vaultDocuments)
            ..where((t) => t.familyId.equals(sync._family) & t.id.equals(id)))
          .getSingleOrNull();
  if (revision <= (existing?.revision ?? 0)) return true;
  if (row['key_grant'] == null) return false;
  if (row['archived_at'] != null) throw _invalidSharedDocument;
  final latest = _docId(row, 'latest_version_id'),
      owner = _docId(row, 'owner_id');
  final history = [...await sync._call(() => sync.transport.versions(id))]
    ..sort((a, b) => _docInt(a, 'version').compareTo(_docInt(b, 'version')));
  // A new version could have finalized between the list and history calls.
  if (history.length > revision) return true;
  if (history.length != revision || history.last['id'] != latest) {
    throw _invalidSharedDocument;
  }
  final seen = <String>{};
  for (final (index, entry) in history.indexed) {
    if (entry['version'] != index + 1 || !seen.add(_docId(entry, 'id'))) {
      throw _invalidSharedDocument;
    }
  }
  final local =
      await (db.select(db.vaultDocumentVersions)
            ..where(
              (t) => t.familyId.equals(sync._family) & t.documentId.equals(id),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.version)]))
          .get();
  if (local.length != (existing?.revision ?? 0)) throw _invalidSharedDocument;
  for (final (index, saved) in local.indexed) {
    if (saved.id != history[index]['id'] ||
        saved.ciphertextDigest != history[index]['ciphertext_digest']) {
      throw _invalidSharedDocument;
    }
  }
  final incoming = history.skip(local.length);
  if (incoming.any((entry) => entry['key_grant'] == null)) return false;

  final versions = <VaultDocumentVersion>[];
  DocumentDetails? metadata;
  for (final entry in incoming) {
    final versionId = _docId(entry, 'id');
    final mime = _docText(entry, 'mime_type');
    final size = _docInt(entry, 'plaintext_bytes');
    final digest = _docText(entry, 'ciphertext_digest');
    if (size < 8 ||
        size > documentByteLimit ||
        entry['ciphertext_bytes'] != SealedFile.byteLength(size) ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(digest) ||
        !DocumentFormat.values.any((format) => format.mime == mime)) {
      throw _invalidSharedDocument;
    }
    final key = await sync._openGrant(
      entry['key_grant'],
      id,
      versionId,
      roster,
    );
    try {
      final wrapped = await repository._wrap(
        key,
        repository._context(id, versionId, mime, size),
      );
      versions.add(
        VaultDocumentVersion(
          id: versionId,
          documentId: id,
          familyId: sync._family,
          version: _docInt(entry, 'version'),
          mimeType: mime,
          plaintextBytes: size,
          ciphertextDigest: digest,
          wrappedKey: wrapped,
          createdBy: _docId(entry, 'created_by'),
          deviceId: _docId(entry, 'device_id'),
          createdAtUs: _docTime(entry, 'finalized_at'),
        ),
      );
      if (versionId == latest) {
        metadata = await _openMetadata(
          row,
          key,
          sync._family,
          id,
          versionId,
          owner,
        );
      }
    } finally {
      key.destroy();
    }
  }
  final details = metadata ?? (throw _invalidSharedDocument);
  final document = VaultDocument(
    id: id,
    familyId: sync._family,
    revision: revision,
    title: details.title,
    category: details.category.name,
    ownerId: owner,
    expiryOn: details.expiryOn,
    createdBy: _docId(row, 'created_by'),
    updatedBy: _docId(row, 'updated_by'),
    createdAtUs: _docTime(row, 'created_at'),
    updatedAtUs: _docTime(row, 'updated_at'),
  );
  if (document.updatedBy != versions.last.createdBy ||
      document.updatedAtUs != versions.last.createdAtUs ||
      (existing != null &&
          (document.createdBy != existing.createdBy ||
              document.createdAtUs != existing.createdAtUs))) {
    throw _invalidSharedDocument;
  }
  await db.transaction(() async {
    await repository._authorize();
    if (existing == null) {
      await db.into(db.vaultDocuments).insert(document);
    }
    for (final version in versions) {
      if (existing != null) {
        // Each increment corresponds to a validated immutable server version.
        // Only the completed transaction exposes the newest metadata.
        await db
            .update(db.vaultDocuments)
            .replace(
              document.copyWith(
                revision: version.version,
                updatedBy: version.createdBy,
                updatedAtUs: version.createdAtUs,
              ),
            );
      }
      await db.into(db.vaultDocumentVersions).insert(version);
    }
    sync._check();
  });
  return true;
}

Future<DocumentDetails> _openMetadata(
  DocumentWire row,
  SecretKey key,
  String family,
  String doc,
  String version,
  String owner,
) async {
  final raw = _docText(row, 'metadata_box');
  if (raw.length < 56 || raw.length > 4096) throw _invalidSharedDocument;
  List<int>? clear;
  try {
    clear = await SealedFile.algorithm.decrypt(
      SecretBox.fromConcatenation(
        base64Decode(raw),
        nonceLength: 24,
        macLength: 16,
      ),
      secretKey: key,
      aad: _metadataContext(family, doc, version, owner),
    );
    final value = jsonDecode(utf8.decode(clear));
    if (value is! DocumentWire ||
        value.length != 3 ||
        !value.containsKey('expiry_on')) {
      throw _invalidSharedDocument;
    }
    final title = _docText(value, 'title'),
        expiry = value['expiry_on'] as String?;
    if (title.trim() != title ||
        title.length > 120 ||
        title.contains('\u0000')) {
      throw _invalidSharedDocument;
    }
    if (expiry != null) LedgerRepository.validateDate(expiry);
    return DocumentDetails(
      title: title,
      category: DocumentCategory.values.byName(_docText(value, 'category')),
      ownerId: owner,
      expiryOn: expiry,
    );
  } catch (_) {
    throw _invalidSharedDocument;
  } finally {
    clear?.fillRange(0, clear.length, 0);
  }
}

int _docTime(DocumentWire row, String field) {
  final value = DateTime.tryParse(_docText(row, field));
  if (value == null || !value.isUtc || value.microsecondsSinceEpoch < 0) {
    throw _invalidSharedDocument;
  }
  return value.microsecondsSinceEpoch;
}
