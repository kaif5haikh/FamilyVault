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
      expect((await vault.versions(first.documentId)).length, 2);
    },
  );

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
}
