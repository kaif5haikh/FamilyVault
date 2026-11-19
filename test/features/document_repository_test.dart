import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hash;
import 'package:cryptography/cryptography.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:familyvault/core/database/app_database.dart';
import 'package:familyvault/core/errors/app_failure.dart';
import 'package:familyvault/core/finance/money.dart';
import 'package:familyvault/core/security/sealed_file.dart';
import 'package:familyvault/core/security/vault_identity.dart';
import 'package:familyvault/core/security/vault_keys.dart';
import 'package:familyvault/core/security/vault_lifecycle.dart';
import 'package:familyvault/features/document_vault/document_repository.dart';
import 'package:familyvault/features/finance/data/ledger_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import '../support/vault_fixture.dart';

void main() {
  late VaultFixture fixture;
  late VaultSession session;
  late DocumentRepository vault;
  late File source;
  late Uint8List content;

  Matcher failure(FailureCode code) =>
      isA<AppFailure>().having((e) => e.code, 'code', code);

  setUp(() async {
    fixture = await VaultFixture.create();
    session = VaultSession(
      db: fixture.db,
      identity: fixture.identity,
      keys: VaultKeys.generate(),
      directory: fixture.directory,
    );
    vault = DocumentRepository(session);
    source = File('${fixture.directory.path}/synthetic-source.pdf');
    content = Uint8List.fromList([
      ...ascii.encode('%PDF-1.4\nsynthetic-document-bytes\n'),
      ...List<int>.filled(SealedFile.chunkSize * 2, 77),
      ...ascii.encode('\n%%EOF'),
    ]);
    await source.writeAsBytes(content);
  });

  tearDown(() async {
    session.keys.destroy();
    await fixture.dispose();
  });

  DocumentDetails sample({
    String? owner,
    String title = 'Synthetic property file',
  }) => DocumentDetails(
    title: title,
    category: DocumentCategory.property,
    ownerId: owner ?? fixture.identity.memberId,
    expiryOn: '2030-08-01',
  );

  test('storage keeps document text and bytes encrypted and audits access by the viewing member', () async {
    final owner = const Uuid().v4();
    await fixture.db
        .into(fixture.db.familyMembers)
        .insert(
          FamilyMembersCompanion.insert(
            id: owner,
            familyId: fixture.identity.familyId,
            displayName: 'Synthetic other owner',
            relationship: 'member',
            role: 'member',
            createdAtUs: 1,
          ),
        );
    final version = await vault.add(
      details: sample(owner: owner),
      source: source,
    );
    expect(version.version, 1);
    expect(version.mimeType, 'application/pdf');
    final row = await vault.document(version.documentId);
    expect(row.ownerId, owner);
    expect(row.createdBy, fixture.identity.memberId);
    expect(
      (await vault
              .watch(query: 'PROPERTY', category: DocumentCategory.property)
              .first)
          .single
          .id,
      row.id,
    );
    expect(
      String.fromCharCodes(await vault.ciphertext(version.id).readAsBytes())
          .contains('synthetic-document-bytes'),
      isFalse,
    );
    expect(
      String.fromCharCodes(await fixture.file.readAsBytes())
          .contains('Synthetic property file'),
      isFalse,
    );
    final opened = await vault.read(row.id, version.id, DocumentAccess.preview);
    expect(hash.sha256.convert(opened), hash.sha256.convert(content));
    final audit = await (fixture.db.select(
      fixture.db.localAuditEvents,
    )..where((t) => t.entityType.equals('document_access'))).getSingle();
    expect(audit.actorId, fixture.identity.memberId);
    expect(audit.afterJson, contains(version.id));
    expect(audit.afterJson, isNot(contains(row.title)));
  });

  test(
    'only one competing revision appends, and archive retains both versions',
    () async {
      final first = await vault.add(details: sample(), source: source);
      final secondSource = File(
        '${fixture.directory.path}/synthetic-source.png',
      );
      await secondSource.writeAsBytes(
        base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/mL8AAAAASUVORK5CYII=',
        ),
      );
      final outcomes = await Future.wait([
        for (var i = 0; i < 2; i++)
          vault
              .addVersion(first.documentId, 1, secondSource)
              .then<Object>((value) => value, onError: (Object e) => e),
      ]);
      final second = outcomes.whereType<VaultDocumentVersion>().single;
      expect(
        outcomes.whereType<AppFailure>().single.code,
        FailureCode.conflict,
      );
      expect(second.mimeType, 'image/png');
      expect(second.version, 2);
      expect(
        (await vault.versions(first.documentId)).map((row) => row.version),
        [2, 1],
      );
      await expectLater(
        fixture.db.delete(fixture.db.vaultDocumentVersions).go(),
        throwsA(anything),
      );
      await vault.archive(first.documentId, 2);
      expect(await vault.watch().first, isEmpty);
      expect((await vault.watch(archived: true).first).single.revision, 3);
      await vault.archive(first.documentId, 3, restore: true);
      final restored = (await vault.watch().first).single;
      expect(restored.id, first.documentId);
      expect(restored.revision, 4);
      expect(restored.deletedAtUs, isNull);
      expect(await vault.watch(archived: true).first, isEmpty);
      expect((await vault.versions(first.documentId)).length, 2);
    },
  );

  test('removing the expiry date clears the saved metadata', () async {
    final version = await vault.add(details: sample(), source: source);
    final original = await vault.document(version.documentId);
    expect(original.expiryOn, isNotNull);
    await vault.update(
      original.id,
      original.revision,
      DocumentDetails(
        title: original.title,
        category: DocumentCategory.property,
        ownerId: original.ownerId,
      ),
    );
    final updated = await vault.document(original.id);
    expect(updated.expiryOn, isNull);
    expect(updated.revision, original.revision + 1);
    expect((await vault.versions(updated.id)).single.id, version.id);
  });

  test('bad input and damaged container files cannot produce a document access receipt', () async {
    final invalid = File(
      '${fixture.directory.path}/synthetic-not-an-image.jpg',
    );
    await invalid.writeAsString('Synthetic plain text fixture');
    await expectLater(
      vault.add(details: sample(), source: invalid),
      throwsA(failure(FailureCode.validation)),
    );
    expect(await vault.watch().first, isEmpty);
    final doc = await vault.add(details: sample(), source: source);
    final stored = vault.ciphertext(doc.id);
    final raw = await stored.readAsBytes();
    raw[50] ^= 1;
    await stored.writeAsBytes(raw);
    await expectLater(
      vault.read(doc.documentId, doc.id, DocumentAccess.preview),
      throwsA(failure(FailureCode.integrity)),
    );
    await stored.writeAsBytes(raw.sublist(0, raw.length - 255));
    await expectLater(
      vault.read(doc.documentId, doc.id, DocumentAccess.download),
      throwsA(failure(FailureCode.integrity)),
    );
    expect(
      await (fixture.db.select(
        fixture.db.localAuditEvents,
      )..where((t) => t.entityType.equals('document_access'))).get(),
      isEmpty,
    );
  });

  test('a valid ciphertext digest still requires the correct key and document context', () async {
    final file = File('${fixture.directory.path}/context.fvdoc');
    final first = SecretKeyData(
      SealedFile.randomBytes(32),
      overwriteWhenDestroyed: true,
    );
    final second = SecretKeyData(
      SealedFile.randomBytes(32),
      overwriteWhenDestroyed: true,
    );
    addTearDown(first.destroy);
    addTearDown(second.destroy);
    final context = ascii.encode('Synthetic document one');
    final digest = await SealedFile.encrypt(
      source: source,
      destination: file,
      clearLength: content.length,
      key: first,
      context: context,
    );
    for (final (key, bound) in [
      (first, ascii.encode('Synthetic document two')),
      (second, context),
    ]) {
      var delivered = 0;
      await expectLater(
        SealedFile.decrypt(
          source: file,
          clearLength: content.length,
          expectedDigest: digest,
          key: key,
          context: bound,
          write: (bytes) async => delivered += bytes.length,
        ),
        throwsA(failure(FailureCode.integrity)),
      );
      expect(delivered, 0);
    }
  });

  test('a failed audit cannot publish a version, and linking preserves the journal', () async {
    await fixture.db.customStatement(
      """CREATE TRIGGER fail_document_audit BEFORE INSERT ON local_audit_events
      WHEN NEW.entity_type = 'document' BEGIN SELECT RAISE(ABORT,'Synthetic I/O error'); END""",
    );
    await expectLater(
      vault.add(details: sample(), source: source),
      throwsA(failure(FailureCode.storage)),
    );
    expect(
      await fixture.db.select(fixture.db.vaultDocumentVersions).get(),
      isEmpty,
    );
    expect(await vault.watch().first, isEmpty);
    await fixture.db.customStatement('DROP TRIGGER fail_document_audit');
    final doc = await vault.add(details: sample(), source: source);
    final cash = await fixture.ledger.createAccount(
      name: 'Synthetic cash',
      kind: AccountKind.asset,
      subtype: 'cash',
      openingBalance: Money.fromMinor(200),
    );
    final journal = (await fixture.ledger.snapshot()).journals.single;
    final link = await vault.link(doc.documentId, journalId: journal.id);
    expect(await vault.link(doc.documentId, journalId: journal.id), link);
    expect((await vault.links(doc.documentId)).single.journalId, journal.id);
    expect(
      (await vault.watchLinked(journalId: journal.id).first).single.id,
      doc.documentId,
    );
    await vault.unlink(link);
    expect(await vault.links(doc.documentId), isEmpty);
    expect(
      (await fixture.ledger.snapshot()).balances()[cash.id],
      BigInt.from(200),
    );
    expect(
      (await fixture.db.select(fixture.db.vaultDocumentLinks).get())
          .single
          .deletedAtUs,
      isNotNull,
    );
  });

  test('an offline shared upload keeps a readable private draft and stable operation across reopening', () async {
    final identity = VaultIdentity(
      familyId: fixture.identity.familyId,
      memberId: fixture.identity.memberId,
      deviceId: fixture.identity.deviceId,
      mode: 'cloud',
    );
    // Only the identity's sharing mode changes in this isolated fixture.
    final cloud = VaultSession(
      db: fixture.db,
      identity: identity,
      keys: session.keys.copy(),
      directory: fixture.directory,
    );
    addTearDown(cloud.keys.destroy);
    final uploads = DocumentRepository(cloud);
    await fixture.db.customStatement(
      '''CREATE TRIGGER fail_queue_audit BEFORE INSERT ON local_audit_events
      WHEN NEW.entity_type = 'document_transfer' BEGIN SELECT RAISE(ABORT, 'Synthetic queue failure'); END''',
    );
    await expectLater(
      uploads.add(details: sample(), source: source),
      throwsA(failure(FailureCode.storage)),
    );
    expect(await uploads.watchUploads().first, isEmpty);
    await fixture.db.customStatement('DROP TRIGGER fail_queue_audit');

    final draft = await uploads.add(details: sample(), source: source);
    final queued = (await uploads.watchUploads().first).single;
    expect(queued.id, draft.id);
    expect(queued.state, 'pending');
    expect(await uploads.watch().first, isEmpty);
    expect(queued.metadataBox, isNot(contains('Synthetic property file')));
    expect(
      await SealedFile.digest(uploads.ciphertext(draft.id)),
      queued.ciphertextDigest,
    );
    await expectLater(
      fixture.db.customStatement(
        'UPDATE vault_document_uploads SET base_revision = 3 WHERE id = ?',
        [draft.id],
      ),
      throwsA(anything),
    );

    final keys = cloud.keys.copy();
    await cloud.close();
    fixture.db = AppDatabase.encrypted(file: fixture.file, key: fixture.key);
    final reopened = VaultSession(
      db: fixture.db,
      identity: identity,
      keys: keys,
      directory: fixture.directory,
    );
    addTearDown(reopened.keys.destroy);
    final after = DocumentRepository(reopened);
    expect((await after.watchUploads().first).single, queued);
    expect(
      (await after.describeVersion(draft.documentId, draft.id)).title,
      'Synthetic property file',
    );
    expect(
      await after.read(draft.documentId, draft.id, DocumentAccess.preview),
      content,
    );
    await expectLater(
      after.read(const Uuid().v4(), draft.id, DocumentAccess.preview),
      throwsA(failure(FailureCode.validation)),
    );
  });
}
