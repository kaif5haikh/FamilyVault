import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:familyvault/core/database/app_database.dart'
    show DocumentCategory;
import 'package:familyvault/core/errors/app_failure.dart';
import 'package:familyvault/core/finance/money.dart';
import 'package:familyvault/core/security/sealed_file.dart';
import 'package:familyvault/core/security/vault_lifecycle.dart';
import 'package:familyvault/features/backup/backup_archive.dart';
import 'package:familyvault/features/backup/backup_file_io.dart';
import 'package:familyvault/features/backup/local_backup_destination.dart';
import 'package:familyvault/features/backup/vault_backup.dart';
import 'package:familyvault/features/document_vault/document_repository.dart';
import 'package:familyvault/features/finance/data/ledger_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/security_fakes.dart';

final class _Files implements BackupFileDestination {
  _Files(this.root);
  final Directory root;
  bool cancel = false, alter = false;
  @override
  Future<({int bytes, String digest})?> copy(BackupArtifact artifact) async {
    if (cancel) return null;
    await root.create(recursive: true);
    final file = File('${root.path}/saved-copy.fvbackup');
    await artifact.file.copy(file.path);
    if (alter) {
      final changed = await file.open(mode: FileMode.append);
      await changed.writeByte(0);
      await changed.close();
    }
    return (bytes: await file.length(), digest: await SealedFile.digest(file));
  }
}

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
    final cleanSupport = Directory('${root.path}/clean-device');
    final recovered = VaultLifecycle(
      store: MemorySecureStore(),
      gate: FakeDeviceGate(),
      root: () async => cleanSupport,
    );
    addTearDown(recovered.dispose);
    await recovered.initialize();
    await recovered.restoreBackup(restored);
    final session = recovered.status.session!;
    expect(session.identity.deviceId, isNot(source.identity.deviceId));
    expect(session.identity.familyId, source.identity.familyId);
    expect(session.identity.isCloud, isFalse);
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
    await expectLater(
      recovered.restoreBackup(restored),
      throwsA(isA<AppFailure>()),
    );
    await recovered.lock();
    await recovered.unlock();
    expect(
      recovered.status.session!.identity.deviceId,
      session.identity.deviceId,
    );
  });

  test(
    'restore can resume after secure storage fails to record final activation',
    () async {
      final artifact = await engine.capture(
        session: source,
        destination: destination,
        recovery: key,
      );
      final verified = await engine.verify(artifact.file, key);
      addTearDown(verified.close);
      final store = MemorySecureStore()..failWrite = 2;
      final support = Directory('${root.path}/restart-target');
      final first = VaultLifecycle(
        store: store,
        gate: FakeDeviceGate(),
        root: () async => support,
      );
      await first.initialize();
      await expectLater(
        first.restoreBackup(verified),
        throwsA(isA<AppFailure>()),
      );
      expect(first.status.phase, VaultPhase.locked);
      final retained = jsonDecode(
        (await store.read(VaultLifecycle.catalogKey))!,
      ) as Map<String, Object?>;
      expect(retained['state'], 'restoring');
      await first.dispose();

      final resumed = VaultLifecycle(
        store: store,
        gate: FakeDeviceGate(),
        root: () async => support,
      );
      addTearDown(resumed.dispose);
      await resumed.initialize();
      expect(resumed.status.phase, VaultPhase.locked);
      await resumed.unlock();
      expect(resumed.status.phase, VaultPhase.open);
      expect(
        resumed.status.session!.identity.familyId,
        source.identity.familyId,
      );
      expect(
        (await resumed.status.session!.ledger.snapshot()).accounts.length,
        (await source.ledger.snapshot()).accounts.length,
      );
    },
  );

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
    final scratch = Directory('${root.path}/picker-stage');
    final wrongInput = (
      length: () async => 112,
      openRead: () => Stream<List<int>>.value(List.filled(112, 65)),
    );
    await expectLater(stageSelectedBackup(wrongInput, scratch, key), rejected);
    expect(await scratch.exists(), isFalse);
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

  test('a file export needs a matching readback before recording a verified receipt', () async {
    final store = MemorySecureStore(),
        files = _Files(Directory('${root.path}/selected-destination'));
    LocalBackupDestination make() => LocalBackupDestination(
      root: () async => root,
      store: store,
      files: files,
    );
    final service = make();
    final latest = await service.create(source, key);
    expect((await make().read(source.identity))?.exportedAtUs, isNull);
    files.cancel = true;
    expect(await service.export(source.identity, latest), isNull);
    files.cancel = false;
    files.alter = true;
    await expectLater(
      service.export(source.identity, latest),
      throwsA(isA<AppFailure>()),
    );
    expect((await make().read(source.identity))?.exportedAtUs, isNull);
    files.alter = false;
    final completed = (await service.export(source.identity, latest))!;
    expect(
      (await make().read(source.identity))?.exportedAtUs,
      completed.exportedAtUs,
    );
    expect(completed.exportedAtUs, isNotNull);
    final clean = VaultBackup(Directory('${root.path}/independent-restore'));
    final verified = await clean.verify(
      File('${files.root.path}/saved-copy.fvbackup'),
      key,
    );
    await verified.close();
  });
}
