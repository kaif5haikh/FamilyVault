import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../core/database/mutation_writer.dart';
import '../../core/errors/app_failure.dart';
import '../../core/security/sealed_file.dart';
import '../../core/security/vault_lifecycle.dart';
import '../finance/data/ledger_repository.dart';

enum DocumentFormat {
  pdf('application/pdf', 'pdf'),
  jpeg('image/jpeg', 'jpg'),
  png('image/png', 'png');

  const DocumentFormat(this.mime, this.extension);
  final String mime, extension;

  static Future<({DocumentFormat format, int bytes})> inspect(File file) async {
    final bytes = await file.length();
    if (bytes < 8 || bytes > documentByteLimit) {
      throw const AppFailure(
        FailureCode.validation,
        'Choose a PDF, JPG or PNG file up to 24 MB.',
      );
    }
    final input = await file.open();
    try {
      final header = await input.read(8);
      if (_startsWith(header, ascii.encode('%PDF-'))) {
        return (format: pdf, bytes: bytes);
      }
      if (_startsWith(header, const [255, 216, 255])) {
        return (format: jpeg, bytes: bytes);
      }
      if (_startsWith(header, const [137, 80, 78, 71, 13, 10, 26, 10])) {
        return (format: png, bytes: bytes);
      }
      throw const AppFailure(
        FailureCode.validation,
        'Choose a PDF, JPG or PNG file.',
      );
    } finally {
      await input.close();
    }
  }

  static bool _startsWith(List<int> bytes, List<int> prefix) =>
      bytes.length >= prefix.length &&
      prefix.asMap().entries.every((byte) => bytes[byte.key] == byte.value);
}

final class DocumentDetails {
  const DocumentDetails({
    required this.title,
    required this.category,
    required this.ownerId,
    this.expiryOn,
  });
  final String title, ownerId;
  final DocumentCategory category;
  final String? expiryOn;
}

enum DocumentAccess { preview, download }

/// Encrypted version files and encrypted SQLite metadata belong to one unlocked vault.
final class DocumentRepository {
  DocumentRepository(this.session);
  final VaultSession session;
  AppDatabase get _db => session.db;
  MutationWriter get _writer => session.ledger.mutations;
  String get _familyId => session.identity.familyId;
  String get _memberId => session.identity.memberId;
  String get _deviceId => session.identity.deviceId;
  static const _uuid = Uuid();
  static const _missing = AppFailure(
    FailureCode.validation,
    'This document is unavailable in your vault.',
  );
  static const _locked = AppFailure(
    FailureCode.locked,
    'Unlock your vault to open documents.',
  );
  static const _changed = AppFailure(
    FailureCode.conflict,
    'This document changed. Open it again before saving.',
  );

  void _checkOpen() {
    if (session.closed || session.keys.destroyed) throw _locked;
  }

  Future<void> _authorize({bool writing = false}) async {
    _checkOpen();
    if (writing && session.identity.isCloud) {
      throw const AppFailure(
        FailureCode.configuration,
        'Add documents in your local vault while shared document storage is in development.',
      );
    }
    await _writer.authorize();
  }

  Directory get _files =>
      Directory(p.join(session.directory.path, 'documents'));

  File ciphertext(String versionId) {
    if (!Uuid.isValidUUID(fromString: versionId)) throw _missing;
    return File(p.join(_files.path, '$versionId.fvdoc'));
  }

  Future<List<FamilyMember>> members() => storageBoundary(() async {
    await _authorize();
    return (_db.select(
      _db.familyMembers,
    )..where((t) => t.familyId.equals(_familyId))).get();
  });

  Stream<List<VaultDocument>> watch({
    String query = '',
    DocumentCategory? category,
    bool archived = false,
  }) async* {
    await _authorize();
    final needle = query.trim().toLowerCase();
    final request = _db.select(_db.vaultDocuments)
      ..where(
        (table) =>
            table.familyId.equals(_familyId) &
            (archived
                ? table.deletedAtUs.isNotNull()
                : table.deletedAtUs.isNull()) &
            (category == null
                ? const Constant(true)
                : table.category.equals(category.name)),
      )
      ..orderBy([
        (table) => OrderingTerm.desc(table.updatedAtUs),
        (table) => OrderingTerm.asc(table.id),
      ]);
    await for (final rows in request.watch()) {
      _checkOpen();
      yield rows
          .where((row) => row.title.toLowerCase().contains(needle))
          .toList();
    }
  }

  Future<VaultDocument> document(String id) => storageBoundary(() async {
    await _authorize();
    return _load(id);
  });

  Future<VaultDocument> _load(String id) async =>
      await (_db.select(_db.vaultDocuments)
            ..where((t) => t.familyId.equals(_familyId) & t.id.equals(id)))
          .getSingleOrNull() ??
      (throw _missing);

  Future<List<VaultDocumentVersion>> versions(String documentId) =>
      storageBoundary(() async {
        await _authorize();
        await _load(documentId);
        return (_db.select(_db.vaultDocumentVersions)
              ..where(
                (t) =>
                    t.familyId.equals(_familyId) &
                    t.documentId.equals(documentId),
              )
              ..orderBy([(t) => OrderingTerm.desc(t.version)]))
            .get();
      });

  String _title(DocumentDetails details) {
    final title = details.title.trim();
    if (title.isEmpty || title.length > 120 || title.contains('\u0000')) {
      throw const AppFailure(
        FailureCode.validation,
        'Enter a document title up to 120 characters.',
      );
    }
    final expiry = details.expiryOn;
    if (expiry != null) LedgerRepository.validateDate(expiry);
    return title;
  }

  Future<VaultDocumentVersion> add({
    required DocumentDetails details,
    required File source,
  }) async {
    final title = _title(details), documentId = _uuid.v4();
    return _addVersion(
      documentId,
      source,
      prepare: () async {
        final now = _writer.now;
        await _db
            .into(_db.vaultDocuments)
            .insert(
              VaultDocumentsCompanion.insert(
                id: documentId,
                familyId: _familyId,
                createdBy: _memberId,
                updatedBy: _memberId,
                createdAtUs: now,
                updatedAtUs: now,
                title: title,
                category: details.category.name,
                ownerId: details.ownerId,
                expiryOn: Value(details.expiryOn),
              ),
            );
        return 1;
      },
    );
  }

  Future<VaultDocumentVersion> addVersion(
    String documentId,
    int expectedRevision,
    File source,
  ) => _addVersion(
    documentId,
    source,
    prepare: () async {
      final document = await _load(documentId);
      if (document.deletedAtUs != null ||
          document.revision != expectedRevision) {
        throw _changed;
      }
      final existing =
          await (_db.select(_db.vaultDocumentVersions)
                ..where(
                  (t) =>
                      t.familyId.equals(_familyId) &
                      t.documentId.equals(documentId),
                )
                ..orderBy([(t) => OrderingTerm.desc(t.version)])
                ..limit(1))
              .getSingle();
      await (_db.update(
        _db.vaultDocuments,
      )..where((t) => t.id.equals(documentId))).write(
        VaultDocumentsCompanion(
          revision: Value(document.revision + 1),
          updatedAtUs: Value(_writer.now),
          updatedBy: Value(_memberId),
        ),
      );
      return existing.version + 1;
    },
  );

  Future<VaultDocumentVersion> _addVersion(
    String documentId,
    File source, {
    required Future<int> Function() prepare,
  }) => storageBoundary(() async {
    await _authorize(writing: true);
    final inspected = await DocumentFormat.inspect(source);
    final id = _uuid.v4(), file = ciphertext(id);
    final temp = File('${file.path}.partial');
    final context = _context(
      documentId,
      id,
      inspected.format.mime,
      inspected.bytes,
    );
    final contentKey = SecretKeyData(
      SealedFile.randomBytes(32),
      overwriteWhenDestroyed: true,
    );
    try {
      await _files.create(recursive: true);
      final digest = await SealedFile.encrypt(
        source: source,
        destination: temp,
        clearLength: inspected.bytes,
        key: contentKey,
        context: context,
      );
      final wrapped = await _wrap(contentKey, context);
      return await _db.transaction(() async {
        await _authorize(writing: true);
        final sequence = await prepare();
        if (await file.exists()) throw SealedFile.invalid;
        await temp.rename(file.path);
        final version = VaultDocumentVersion(
          id: id,
          familyId: _familyId,
          documentId: documentId,
          version: sequence,
          mimeType: inspected.format.mime,
          plaintextBytes: inspected.bytes,
          ciphertextDigest: digest,
          wrappedKey: wrapped,
          createdBy: _memberId,
          deviceId: _deviceId,
          createdAtUs: _writer.now,
        );
        await _db.into(_db.vaultDocumentVersions).insert(version);
        await _audit(
          documentId,
          sequence == 1 ? 'create' : 'version',
          versionId: id,
        );
        return version;
      });
    } finally {
      contentKey.destroy();
      if (await temp.exists()) await temp.delete();
    }
  });

  Future<Uint8List> read(
    String documentId,
    String versionId,
    DocumentAccess purpose,
  ) => storageBoundary(() async {
    await _authorize();
    final version =
        await (_db.select(_db.vaultDocumentVersions)..where(
              (t) =>
                  t.familyId.equals(_familyId) &
                  t.documentId.equals(documentId) &
                  t.id.equals(versionId),
            ))
            .getSingleOrNull();
    if (version == null) throw _missing;
    final context = _context(
      documentId,
      versionId,
      version.mimeType,
      version.plaintextBytes,
    );
    final key = await _unwrap(version.wrappedKey, context);
    final output = Uint8List(version.plaintextBytes);
    var written = 0;
    try {
      await SealedFile.decrypt(
        source: ciphertext(versionId),
        clearLength: version.plaintextBytes,
        expectedDigest: version.ciphertextDigest,
        key: key,
        context: context,
        write: (block) async {
          output.setRange(written, written + block.length, block);
          written += block.length;
          block.fillRange(0, block.length, 0);
        },
      );
      await _db.transaction(() async {
        await _authorize();
        await _audit(documentId, purpose.name, versionId: versionId);
      });
      _checkOpen();
      return output;
    } catch (_) {
      output.fillRange(0, output.length, 0);
      rethrow;
    } finally {
      key.destroy();
    }
  });

  Future<void> update(
    String id,
    int expectedRevision,
    DocumentDetails details,
  ) => _edit(
    id,
    expectedRevision,
    action: 'metadata',
    change: (_) => VaultDocumentsCompanion(
      title: Value(_title(details)),
      category: Value(details.category.name),
      ownerId: Value(details.ownerId),
      expiryOn: Value(details.expiryOn),
    ),
  );

  Future<void> archive(
    String id,
    int expectedRevision, {
    bool restore = false,
  }) => _edit(
    id,
    expectedRevision,
    action: restore ? 'restore' : 'archive',
    change: (document) {
      if ((document.deletedAtUs == null) == restore) throw _changed;
      return VaultDocumentsCompanion(
        deletedAtUs: Value(restore ? null : _writer.now),
      );
    },
  );

  Future<List<VaultDocumentLink>> links(String documentId) =>
      storageBoundary(() async {
        await _authorize();
        await _load(documentId);
        return (_db.select(_db.vaultDocumentLinks)..where(
              (t) =>
                  t.familyId.equals(_familyId) &
                  t.documentId.equals(documentId) &
                  t.deletedAtUs.isNull(),
            ))
            .get();
      });

  Future<String> link(
    String documentId, {
    String? journalId,
    String? assetId,
  }) => storageBoundary(
    () => _db.transaction(() async {
      await _authorize(writing: true);
      final document = await _load(documentId);
      if ((journalId == null) == (assetId == null) ||
          document.deletedAtUs != null) {
        throw _missing;
      }
      final existing =
          await (_db.select(_db.vaultDocumentLinks)..where(
                (t) =>
                    t.familyId.equals(_familyId) &
                    t.documentId.equals(documentId) &
                    t.deletedAtUs.isNull() &
                    (journalId != null
                        ? t.journalId.equals(journalId)
                        : t.assetId.equals(assetId!)),
              ))
              .getSingleOrNull();
      if (existing != null) return existing.id;
      final id = _uuid.v4(), now = _writer.now;
      await _db
          .into(_db.vaultDocumentLinks)
          .insert(
            VaultDocumentLinksCompanion.insert(
              id: id,
              familyId: _familyId,
              documentId: documentId,
              createdBy: _memberId,
              updatedBy: _memberId,
              createdAtUs: now,
              updatedAtUs: now,
              journalId: Value(journalId),
              assetId: Value(assetId),
            ),
          );
      await _writer.audit(
        operationId: _uuid.v4(),
        entityType: 'document_link',
        entityId: id,
        action: 'create',
        after: {
          'document_id': documentId,
          'journal_id': journalId,
          'asset_id': assetId,
        },
      );
      return id;
    }),
  );

  Future<void> unlink(String id) => storageBoundary(
    () => _db.transaction(() async {
      await _authorize(writing: true);
      final old =
          await (_db.select(_db.vaultDocumentLinks)
                ..where((t) => t.familyId.equals(_familyId) & t.id.equals(id)))
              .getSingleOrNull();
      if (old == null) throw _missing;
      if (old.deletedAtUs != null) return;
      final now = _writer.now;
      await (_db.update(
        _db.vaultDocumentLinks,
      )..where((t) => t.id.equals(id))).write(
        VaultDocumentLinksCompanion(
          revision: Value(old.revision + 1),
          updatedAtUs: Value(now),
          updatedBy: Value(_memberId),
          deletedAtUs: Value(now),
        ),
      );
      await _writer.audit(
        operationId: _uuid.v4(),
        entityType: 'document_link',
        entityId: id,
        action: 'archive',
      );
    }),
  );

  Future<void> _edit(
    String id,
    int expectedRevision, {
    required String action,
    required VaultDocumentsCompanion Function(VaultDocument) change,
  }) => storageBoundary(
    () => _db.transaction(() async {
      await _authorize(writing: true);
      final old = await _load(id);
      if (old.revision != expectedRevision ||
          (action == 'metadata' && old.deletedAtUs != null)) {
        throw _changed;
      }
      final updated = old
          .copyWithCompanion(change(old))
          .copyWith(
            revision: old.revision + 1,
            updatedBy: _memberId,
            updatedAtUs: _writer.now,
          );
      await (_db.update(
        _db.vaultDocuments,
      )..where((t) => t.id.equals(id))).write(updated);
      await _audit(id, action);
    }),
  );

  List<int> _context(String doc, String version, String mimeType, int length) =>
      utf8.encode(
        jsonEncode([
          'FamilyVault document v1',
          _familyId,
          doc,
          version,
          mimeType,
          length,
        ]),
      );

  Future<Uint8List> _wrap(SecretKeyData key, List<int> context) async {
    _checkOpen();
    final wrapping = SecretKeyData(
      Uint8List.fromList(session.keys.documents),
      overwriteWhenDestroyed: true,
    );
    try {
      final box = await SealedFile.algorithm.encrypt(
        key.bytes,
        secretKey: wrapping,
        aad: [...ascii.encode('document-key'), ...context],
      );
      return box.concatenation();
    } finally {
      wrapping.destroy();
    }
  }

  Future<SecretKeyData> _unwrap(Uint8List wrapped, List<int> context) async {
    _checkOpen();
    final wrapping = SecretKeyData(
      Uint8List.fromList(session.keys.documents),
      overwriteWhenDestroyed: true,
    );
    try {
      final box = SecretBox.fromConcatenation(
        wrapped,
        nonceLength: 24,
        macLength: 16,
      );
      final clear = await SealedFile.algorithm.decrypt(
        box,
        secretKey: wrapping,
        aad: [...ascii.encode('document-key'), ...context],
      );
      return SecretKeyData(clear, overwriteWhenDestroyed: true);
    } on SecretBoxAuthenticationError {
      throw SealedFile.invalid;
    } finally {
      wrapping.destroy();
    }
  }

  Future<void> _audit(String id, String action, {String? versionId}) =>
      _writer.audit(
        operationId: _uuid.v4(),
        entityType: action == 'preview' || action == 'download'
            ? 'document_access'
            : 'document',
        entityId: id,
        action: action,
        after: versionId == null ? null : {'version_id': versionId},
      );
}
