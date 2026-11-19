import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:familyvault/core/database/app_database.dart';
import 'package:familyvault/core/database/encrypted_connection.dart';
import 'package:familyvault/core/errors/app_failure.dart';
import 'package:familyvault/core/finance/money.dart';
import 'package:familyvault/core/security/vault_keys.dart';
import 'package:familyvault/core/security/vault_lifecycle.dart';
import 'package:familyvault/features/backup/backup_archive.dart';
import 'package:familyvault/features/backup/vault_backup.dart';
import 'package:familyvault/features/document_vault/document_repository.dart';
import 'package:familyvault/features/finance/data/ledger_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/security_fakes.dart';

void main() {
  late Directory root;
  late VaultLifecycle lifecycle;
  late VaultSession source;
  late BackupRecoveryKey key;
  late VaultBackup engine;
  late Directory destination;

  final warning = driftRuntimeOptions.dontWarnAboutMultipleDatabases;
  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);
  tearDownAll(
    () => driftRuntimeOptions.dontWarnAboutMultipleDatabases = warning,
  );
  setUp(() async {
    root = await (await Directory('.cache/test-vaults').create(recursive: true))
        .createTemp('backup-');
    lifecycle = VaultLifecycle(
      store: MemorySecureStore(),
      gate: FakeDeviceGate(),
      root: () async => Directory('${root.path}/source'),
    );
    await lifecycle.initialize();
    await lifecycle.createOffline(
      familyName: 'Synthetic recovery family',
      ownerName: 'Synthetic owner',
    );
    source = lifecycle.status.session!;
    key = BackupRecoveryKey.generate();
    engine = VaultBackup(Directory('${root.path}/staging'));
    destination = Directory('${root.path}/copies');
  });
  tearDown(() async {
    key.destroy();
    await lifecycle.dispose();
    await root.delete(recursive: true);
  });

  test('an independent recovery key opens the verified snapshot without the source vault', () async {
    const marker = 'Synthetic confidential backup PDF';
    final bytes = ascii.encode('%PDF-1.4\n$marker\n${'a' * 300000}\n%%EOF');
    final pdf = await File('${root.path}/mock.pdf').writeAsBytes(bytes);
    final account = await source.ledger.createAccount(
      name: 'Synthetic exact backup balance',
      kind: AccountKind.asset,
      subtype: 'cash',
      openingBalance: Money.fromMinor(9007199254740993),
    );
    final first = await source.documents.add(
      details: DocumentDetails(
        title: 'Synthetic backup title',
        category: DocumentCategory.general,
        ownerId: source.identity.memberId,
      ),
      source: pdf,
    );
    final second = await source.documents.addVersion(first.documentId, 1, pdf);
    final code = key.code;
    final artifact = await engine.capture(
      session: source,
      destination: destination,
      recovery: key,
    );
    expect(artifact.bytes, await artifact.file.length());
    final raw = String.fromCharCodes(await artifact.file.readAsBytes());
    expect(raw, isNot(contains(marker)));
    expect(raw, isNot(contains(code)));
    expect(raw, isNot(contains('Synthetic backup title')));
    await lifecycle.lock();
    expect(source.keys.destroyed, isTrue);

    final clean = VaultBackup(Directory('${root.path}/clean-staging'));
    final separatelyHeld = BackupRecoveryKey.fromCode(code);
    addTearDown(separatelyHeld.destroy);
    final restored = await clean.verify(artifact.file, separatelyHeld);
    addTearDown(restored.close);
    expect(restored.contents.digest, artifact.digest);
    expect(restored.documents, 1);
    expect(restored.pending, greaterThan(0));
    final manifest = restored.contents.manifest;
    final session = VaultSession(
      db: AppDatabase.encrypted(
        file: File('${restored.contents.directory.path}/vault.sqlite3'),
        key: VaultDatabaseKey.fromBytes(manifest.databaseKey),
      ),
      identity: manifest.identity,
      directory: restored.contents.directory,
      keys: VaultKeys.fromRecovery(
        database: manifest.databaseKey,
        documents: manifest.documentKey,
      ),
    );
    try {
      expect(
        (await session.ledger.snapshot()).balances()[account.id],
        BigInt.from(9007199254740993),
      );
      expect(
        (await session.documents.versions(first.documentId)).map((v) => v.id),
        [second.id, first.id],
      );
      expect(
        await session.documents.read(
          first.documentId,
          first.id,
          DocumentAccess.preview,
        ),
        bytes,
      );
    } finally {
      await session.close();
    }
  });

  test('wrong keys, altered archives, truncated copies and missing documents fail closed', () async {
    final input = await File('${root.path}/mock.pdf')
        .writeAsString('%PDF-1.4\nSynthetic fixture bytes');
    final document = await source.documents.add(
      details: DocumentDetails(
        title: 'Synthetic document',
        category: DocumentCategory.general,
        ownerId: source.identity.memberId,
      ),
      source: input,
    );
    final artifact = await engine.capture(
      session: source,
      destination: destination,
      recovery: key,
    );
    final wrong = BackupRecoveryKey.generate();
    addTearDown(wrong.destroy);
    final rejected = throwsA(
      isA<AppFailure>().having((e) => e.code, 'code', FailureCode.integrity),
    );
    await expectLater(engine.verify(artifact.file, wrong), rejected);
    final raw = await artifact.file.readAsBytes();
    final bad = File('${root.path}/corrupt.fvbackup');
    await bad.writeAsBytes(raw.sublist(0, raw.length - 1));
    await expectLater(engine.verify(bad, key), rejected);
    raw[raw.length - 16] ^= 1;
    await bad.writeAsBytes(raw);
    await expectLater(engine.verify(bad, key), rejected);
    expect(await engine.stagingRoot.list().isEmpty, isTrue);
    final absent = source.documents.ciphertext(document.id);
    final held = await absent.rename('${absent.path}.synthetic-held');
    await expectLater(
      engine.capture(session: source, destination: destination, recovery: key),
      throwsA(isA<AppFailure>()),
    );
    expect((await destination.list().toList()).single.path, artifact.file.path);
    await held.rename(absent.path);
  });
}
