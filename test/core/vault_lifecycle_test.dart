import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:familyvault/core/errors/app_failure.dart';
import 'package:familyvault/core/finance/money.dart';
import 'package:familyvault/core/security/vault_lifecycle.dart';
import 'package:familyvault/features/finance/data/ledger_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/security_fakes.dart';

void main() {
  late Directory scratch;
  late MemorySecureStore store;
  late FakeDeviceGate gate;
  late VaultLifecycle lifecycle;
  setUp(() async {
    final parent = await Directory('.cache/test-vaults')
        .create(recursive: true);
    scratch = await parent.createTemp('lifecycle-');
    store = MemorySecureStore();
    gate = FakeDeviceGate();
    lifecycle = VaultLifecycle(
      store: store,
      gate: gate,
      root: () async => scratch,
    );
    await lifecycle.initialize();
  });
  tearDown(() async {
    await lifecycle.dispose();
    await scratch.delete(recursive: true);
  });
  Future<void> create() => lifecycle.createOffline(
    familyName: 'Synthetic workspace',
    ownerName: 'Synthetic owner',
  );

  test('setup uses independent keys, exact persistence, device authentication and zeroizes on lock', () async {
    expect(lifecycle.status.phase, VaultPhase.setup);
    await create();
    expect(lifecycle.status.phase, VaultPhase.open);
    expect(gate.calls, 1);
    final session = lifecycle.status.session!, keys = session.keys;
    expect(keys.database, isNot(orderedEquals(keys.documents)));
    final account = await session.ledger.createAccount(
      name: 'Synthetic cash',
      kind: AccountKind.asset,
      subtype: 'cash',
      openingBalance: Money.fromMinor(12345),
    );
    await lifecycle.lock();
    expect(lifecycle.status.phase, VaultPhase.locked);
    expect(session.closed, isTrue);
    expect(keys.destroyed, isTrue);
    expect(keys.database.every((b) => b == 0), isTrue);
    await lifecycle.unlock();
    expect(gate.calls, 2);
    final snapshot = await lifecycle.status.session!.ledger.snapshot();
    expect(snapshot.balances()[account.id], BigInt.from(12345));
    final catalog = jsonDecode(store.values[VaultLifecycle.catalogKey]!) as Map;
    expect(catalog['state'], 'ready');
    expect(catalog.containsKey('initial_owner_name'), isFalse);
    expect(lifecycle.status.session.toString(), 'VaultSession([redacted])');
    expect(keys.toString(), 'VaultKeys([redacted])');
  });
  test('authentication cancellation cannot create or open a vault', () async {
    gate.allowed = false;
    await create();
    expect(lifecycle.status.phase, VaultPhase.setup);
    expect(store.values, isEmpty);
    gate.allowed = true;
    await create();
    await lifecycle.lock();
    gate.allowed = false;
    await lifecycle.unlock();
    expect(lifecycle.status.phase, VaultPhase.locked);
    expect(lifecycle.status.session, isNull);
  });
  test('storage failure never falls back to unprotected keys or creates a database', () async {
    store.unavailable = true;
    await create();
    expect(lifecycle.status.session, isNull);
    expect(await Directory('${scratch.path}/vaults').exists(), isFalse);
    expect(store.values, isEmpty);
    await lifecycle.initialize();
    expect(lifecycle.status.phase, VaultPhase.unavailable);
    store.unavailable = false;
    await lifecycle.initialize();
    expect(lifecycle.status.phase, VaultPhase.setup);
  });
  test('an interrupted final catalog write resumes without duplicate chart or key loss', () async {
    store.failWrite = 2;
    await create();
    expect(lifecycle.status.phase, VaultPhase.locked);
    final pending = jsonDecode(store.values[VaultLifecycle.catalogKey]!) as Map;
    expect(pending['state'], 'initializing');
    final savedKeys = pending['keys'];
    store.failWrite = null;
    await lifecycle.unlock();
    expect(lifecycle.status.phase, VaultPhase.open);
    expect(
      (await lifecycle.status.session!.ledger.snapshot()).accounts.length,
      15,
    );
    final finished =
        jsonDecode(store.values[VaultLifecycle.catalogKey]!) as Map;
    expect(finished['keys'], savedKeys);
    expect(finished['state'], 'ready');
  });
  test(
    'locking during authentication invalidates the in-flight open',
    () async {
      final challenge = Completer<bool>();
      gate.challenge = () => challenge.future;
      final opening = create();
      await Future<void>.delayed(Duration.zero);
      expect(lifecycle.status.phase, VaultPhase.opening);
      await lifecycle.lock();
      challenge.complete(true);
      await opening;
      expect(lifecycle.status.phase, VaultPhase.setup);
      expect(lifecycle.status.session, isNull);
      expect(store.values, isEmpty);
    },
  );
  test('a missing ready database is preserved as a recovery error instead of silently reset', () async {
    await create();
    final dbFile = File(
      '${lifecycle.status.session!.directory.path}/vault.sqlite3',
    );
    await lifecycle.lock();
    await dbFile.rename('${dbFile.path}.synthetic-missing');
    await lifecycle.unlock();
    expect(lifecycle.status.session, isNull);
    expect(lifecycle.status.failure!.code, FailureCode.integrity);
    expect(await dbFile.exists(), isFalse);
    expect(store.values, isNotEmpty);
  });
  test(
    'catalog loss with remaining files and invalid catalog are fail-closed',
    () async {
      await create();
      await lifecycle.lock();
      final saved = store.values.remove(VaultLifecycle.catalogKey)!;
      await lifecycle.initialize();
      expect(lifecycle.status.phase, VaultPhase.unavailable);
      await create();
      expect(lifecycle.status.session, isNull);
      expect(store.values, isEmpty);
      store.values[VaultLifecycle.catalogKey] = '{"version":99}';
      await lifecycle.initialize();
      expect(lifecycle.status.phase, VaultPhase.unavailable);
      store.values[VaultLifecycle.catalogKey] = saved;
      await lifecycle.initialize();
      await lifecycle.unlock();
      expect(lifecycle.status.phase, VaultPhase.open);
    },
  );
}
