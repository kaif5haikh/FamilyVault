import 'dart:io';

import 'package:familyvault/core/security/vault_lifecycle.dart';
import 'package:familyvault/features/backup/backup_archive.dart';
import 'package:familyvault/features/backup/backup_scheduler.dart';
import 'package:familyvault/features/backup/local_backup_destination.dart';
import 'package:familyvault/features/backup/vault_backup.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/security_fakes.dart';

void main() {
  test('scheduled capture retries after a failed receipt and restores on a clean app', () async {
    final root = await (await Directory(
      '.cache/test-vaults',
    ).create(recursive: true)).createTemp('schedule-');
    addTearDown(() => root.delete(recursive: true));
    final store = MemorySecureStore();
    final lifecycle = VaultLifecycle(
      store: store,
      gate: FakeDeviceGate(),
      root: () async => root,
    );
    addTearDown(lifecycle.dispose);
    await lifecycle.initialize();
    await lifecycle.createOffline(
      familyName: 'Synthetic scheduled family',
      ownerName: 'Synthetic owner',
    );
    final session = lifecycle.status.session!;
    final local = LocalBackupDestination(
      root: lifecycle.root,
      store: store,
      files: const NativeBackupDestination(),
    );
    var clock = DateTime.now().subtract(const Duration(days: 1));
    BackupScheduler scheduler() =>
        BackupScheduler(store, local, clock: () => clock);
    final recovery = BackupRecoveryKey.generate();
    addTearDown(recovery.destroy);
    await scheduler().enable(session, BackupCadence.daily, recovery);
    expect(await scheduler().runDue(session, foreground: () => true), isFalse);
    clock = clock.add(const Duration(days: 1, seconds: 5));
    expect(await scheduler().runDue(session, foreground: () => false), isFalse);
    expect((await scheduler().status(session.identity))?.local, isNull);
    store.failWrite = store.writes + 1;
    expect(await scheduler().runDue(session, foreground: () => true), isTrue);
    final failed = (await scheduler().status(session.identity))!;
    expect(failed.captureFailed, isTrue);
    expect(failed.local, isNull);
    expect(await scheduler().runDue(session, foreground: () => true), isFalse);
    clock = clock.add(const Duration(minutes: 11));
    final worker = scheduler();
    final results = await Future.wait([
      worker.runDue(session, foreground: () => true),
      worker.runDue(session, foreground: () => true),
    ]);
    expect(results, [true, false]);
    final scheduled = (await scheduler().status(session.identity))!;
    expect(scheduled.captureFailed, isFalse);
    expect(scheduled.local, isNotNull);
    expect(await local.read(session.identity), isNull);

    final verified = await VaultBackup(Directory('${root.path}/recover'))
        .verify(scheduled.local!.artifact.file, recovery);
    addTearDown(verified.close);
    final restored = VaultLifecycle(
      store: MemorySecureStore(),
      gate: FakeDeviceGate(),
      root: () async => Directory('${root.path}/fresh'),
    );
    addTearDown(restored.dispose);
    await restored.initialize();
    await restored.restoreBackup(verified);
    expect(
      restored.status.session!.identity.familyId,
      session.identity.familyId,
    );

    await lifecycle.lock();
    clock = clock.add(const Duration(days: 1));
    expect(await scheduler().runDue(session, foreground: () => true), isFalse);
    await scheduler().disable(session.identity);
    expect(await scheduler().status(session.identity), isNull);
    expect(await scheduled.local!.artifact.file.exists(), isTrue);
  });
}
