part of 'document_repository.dart';

List<VaultDocumentLink> _readRecordLinks(
  VaultDocument document,
  Object? value,
) {
  if (value is! List<Object?>) throw _invalidSharedDocument;
  final results = <VaultDocumentLink>[];
  final seen = <String>{}, active = <(String?, String?)>{};
  for (final row in value) {
    if (row is! DocumentWire) throw _invalidSharedDocument;
    final id = _docId(row, 'id');
    final journal = row['journal_id'] == null
        ? null
        : _docId(row, 'journal_id');
    final asset = row['asset_id'] == null ? null : _docId(row, 'asset_id');
    final revision = _docInt(row, 'revision');
    final created = _docTime(row, 'created_at'),
        updated = _docTime(row, 'updated_at');
    final removed = row['deleted_at'] == null
        ? null
        : _docTime(row, 'deleted_at');
    if (!seen.add(id) ||
        (journal == null) == (asset == null) ||
        removed == null && !active.add((journal, asset)) ||
        updated < created ||
        updated > document.updatedAtUs ||
        (removed == null
            ? revision != 1 || created != updated
            : revision != 2 || removed != updated)) {
      throw _invalidSharedDocument;
    }
    results.add(
      VaultDocumentLink(
        id: id,
        familyId: document.familyId,
        documentId: document.id,
        journalId: journal,
        assetId: asset,
        createdBy: _docId(row, 'created_by'),
        updatedBy: _docId(row, 'updated_by'),
        revision: revision,
        createdAtUs: created,
        updatedAtUs: updated,
        deletedAtUs: removed,
      ),
    );
  }
  return results;
}

Future<void> _applyRecordLinks(
  AppDatabase db,
  VaultDocument document,
  List<VaultDocumentLink> links,
) async {
  final local =
      await (db.select(db.vaultDocumentLinks)..where(
            (t) =>
                t.familyId.equals(document.familyId) &
                t.documentId.equals(document.id),
          ))
          .get();
  final known = {for (final link in local) link.id: link};
  final incoming = {for (final link in links) link.id: link};
  // Apply removals before new active links to the same record.
  for (final old in local) {
    final next = incoming[old.id];
    if (next == old) continue;
    if (next == null ||
        old.deletedAtUs != null ||
        next.deletedAtUs == null ||
        old.copyWith(
              revision: next.revision,
              updatedAtUs: next.updatedAtUs,
              updatedBy: next.updatedBy,
              deletedAtUs: Value(next.deletedAtUs),
            ) !=
            next) {
      throw _invalidSharedDocument;
    }
    await db.update(db.vaultDocumentLinks).replace(next);
  }
  await db.batch(
    (batch) => batch.insertAll(db.vaultDocumentLinks, [
      for (final link in links)
        if (!known.containsKey(link.id)) link,
    ]),
  );
}
