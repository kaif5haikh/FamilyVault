import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:familyvault/core/errors/app_failure.dart';
import 'package:familyvault/core/finance/money.dart';
import 'package:familyvault/core/security/vault_lifecycle.dart';
import 'package:familyvault/core/sync/canonical_json.dart';
import 'package:familyvault/core/sync/sync_protocol.dart';
import 'package:familyvault/features/auth/cloud_access_gateway.dart';
import 'package:familyvault/features/auth/cloud_cache.dart';
import 'package:familyvault/features/auth/cloud_connection.dart';
import 'package:familyvault/features/auth/cloud_device_registration.dart';
import 'package:familyvault/features/finance/data/ledger_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import '../support/cloud_fakes.dart';
import '../support/security_fakes.dart';

const familyId = 'c09ca374-a5df-4a77-9ac2-de3da263fab6';
const openingId = 'f7c7f822-0d16-8f16-8fd7-43a57dd6839f';

class _WorkspaceGateway extends EnrollmentGateway {
  _WorkspaceGateway()
    : super(userId: const Uuid().v4(), memberId: const Uuid().v4());
  String? signingPublic, exchangePublic;
  bool invalidChart = false, offline = false;
  @override
  String? sessionId = const Uuid().v4();
  final accounts = StreamController<String?>.broadcast(sync: true);

  @override
  Stream<String?> get identityChanges => accounts.stream;

  @override
  SyncTransport syncTransport(DeviceProof device) => _EmptyFeed();

  @override
  Future<String> requestDevice({
    required String familyId,
    required DeviceProof device,
    required String name,
    required String signingPublic,
    required String exchangePublic,
  }) {
    this.signingPublic = signingPublic;
    this.exchangePublic = exchangePublic;
    return super.requestDevice(
      familyId: familyId,
      device: device,
      name: name,
      signingPublic: signingPublic,
      exchangePublic: exchangePublic,
    );
  }

  @override
  Future<void> bind(DeviceProof device) {
    if (offline) {
      throw const AppFailure(FailureCode.network, 'Synthetic offline device');
    }
    if (state != 'enrolled') {
      throw const AppFailure(
        FailureCode.unauthorized,
        'Synthetic approval required',
      );
    }
    return super.bind(device);
  }

  @override
  Future<CloudJson> workspace(DeviceProof device) async => {
    ...await super.workspace(device),
    'family': <String, Object?>{
      'id': family,
      'name': 'Synthetic family',
      'mode': 'cloud',
      'currency': 'INR',
      'created_at_us': 1,
    },
    'members': <CloudJson>[
      {
        'id': memberId,
        'family_id': family,
        'display_name': 'Synthetic member',
        'relationship': 'member',
        'role': 'member',
        'active': true,
        'revision': 1,
        'created_at_us': 1,
      },
    ],
    'devices': <CloudJson>[
      {
        'id': device.deviceId,
        'family_id': family,
        'member_id': memberId,
        'state': state,
        'created_at_us': 1,
        'signing_public': signingPublic,
        'exchange_public': exchangePublic,
        'fingerprint': _fingerprint(signingPublic!, exchangePublic!),
      },
    ],
  };

  @override
  Future<List<CloudJson>> chart(DeviceProof device) async => [
    for (final group in const {
      'equity': [
        'opening',
        'reconciliation',
        'asset_revaluation',
        'capital_disposals',
      ],
      'income': [
        'salary',
        'business_income',
        'rental',
        'other_income',
        'interest_received',
      ],
      'expense': [
        'household',
        'groceries',
        'utilities',
        'transport',
        'shopping',
        'medical',
        'education',
        'business_expense',
        'other_expense',
        'interest_paid',
      ],
    }.entries)
      for (final code in group.value)
        {
          'id': invalidChart ? const Uuid().v4() : _chartId(family!, code),
          'family_id': family,
          'revision': 1,
          'created_by': memberId,
          'updated_by': memberId,
          'created_at_us': 1,
          'updated_at_us': 1,
          'deleted_at_us': null,
          'name': code,
          'kind': group.key,
          'subtype': code,
          'currency': 'INR',
          'system_account': true,
        },
  ];
}

class _EmptyFeed implements SyncTransport {
  @override
  Future<SyncReceipt> push(SyncEnvelope envelope) async =>
      throw StateError('Unexpected fixture upload');

  @override
  Future<SyncPage> pull(int after) async =>
      SyncPage.fromJson({'watermark': 0, 'changes': []});
}

String _chartId(String family, String code) {
  final hex = payloadDigest('$family/chart/$code');
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-8${hex.substring(13, 16)}'
      '-8${hex.substring(17, 20)}-${hex.substring(20, 32)}';
}

String _fingerprint(String signing, String exchange) {
  final hex = signing + exchange;
  return sha256.convert([
    for (var i = 0; i < hex.length; i += 2)
      int.parse(hex.substring(i, i + 2), radix: 16),
  ]).toString();
}

void main() {
  late Directory root;
  late MemorySecureStore store;
  late FakeDeviceGate gate;
  late _WorkspaceGateway gateway;
  late CloudDeviceRegistration registration;
  late CloudWorkspaceCache cache;
  late DateTime clock;
  final sessions = <VaultSession>[];
  setUp(() async {
    final parent = await Directory('.cache/test-vaults')
        .create(recursive: true);
    root = await parent.createTemp('cloud-cache-');
    store = MemorySecureStore();
    gate = FakeDeviceGate();
    gateway = _WorkspaceGateway()..state = 'enrolled';
    registration = CloudDeviceRegistration(
      store: store,
      gate: gate,
      gateway: gateway,
      namespace: 'test',
    );
    clock = DateTime.utc(2026, 11, 18);
    cache = CloudWorkspaceCache(
      registration,
      root: () async => root,
      clock: () => clock,
    );
    await registration.enroll(
      familyId: familyId,
      memberId: gateway.memberId,
      name: 'Synthetic phone',
    );
  });
  tearDown(() async {
    for (final session in sessions) {
      await session.close();
    }
    sessions.clear();
    await root.delete(recursive: true);
    await gateway.accounts.close();
  });
  Future<VaultSession> open(
    CloudWorkspaceCache cache,
    _WorkspaceGateway gateway,
  ) async {
    final session = await cache.open(familyId, gateway.memberId);
    sessions.add(session);
    return session;
  }

  test('uses canonical chart IDs without local mutations and isolates two accounts', () async {
    final first = await open(cache, gateway);
    expect(first.ledger.chartId('opening'), openingId);
    expect((await first.ledger.snapshot()).accounts, hasLength(19));
    expect(await first.db.select(first.db.pendingMutations).get(), isEmpty);
    await first.ledger.createAccount(
      name: 'Synthetic cash',
      kind: AccountKind.asset,
      subtype: 'cash',
      openingBalance: Money.fromMinor(237),
    );
    await first.close();
    expect(first.keys.destroyed, isTrue);
    final reopened = await open(cache, gateway);
    expect(reopened.directory.path, first.directory.path);
    expect(
      (await reopened.ledger.snapshot()).total(AccountKind.asset),
      BigInt.from(237),
    );
    await reopened.close();

    final other = _WorkspaceGateway()..state = 'enrolled';
    final otherRegistration = CloudDeviceRegistration(
      store: store,
      gate: gate,
      gateway: other,
      namespace: 'test',
    );
    await otherRegistration.enroll(
      familyId: familyId,
      memberId: other.memberId,
      name: 'Synthetic second phone',
    );
    final second = await open(
      CloudWorkspaceCache(otherRegistration, root: () async => root),
      other,
    );
    expect(second.directory.path, isNot(first.directory.path));
    expect((await second.ledger.snapshot()).journals, isEmpty);
    expect(await Directory('${root.path}/vaults').exists(), isFalse);
    await other.accounts.close();
  });

  test(
    'requires approval and a verified chart before publishing a session',
    () async {
      gateway.state = 'revoked';
      await expectLater(
        open(cache, gateway),
        throwsA(
          isA<AppFailure>().having(
            (e) => e.code,
            'code',
            FailureCode.unauthorized,
          ),
        ),
      );
      expect(await Directory('${root.path}/cloud-vaults').exists(), isFalse);
      gateway.state = 'enrolled';
      gateway.invalidChart = true;
      await expectLater(
        open(cache, gateway),
        throwsA(
          isA<AppFailure>().having(
            (e) => e.code,
            'code',
            FailureCode.integrity,
          ),
        ),
      );
      gateway.invalidChart = false;
      final usable = await open(cache, gateway);
      expect((await usable.ledger.snapshot()).accounts, hasLength(19));
    },
  );

  test('a missing ready cache is preserved for recovery', () async {
    final first = await open(cache, gateway);
    await first.close();
    final original = File('${first.directory.path}/vault.sqlite3');
    final held = await original.rename('${first.directory.path}/held.sqlite3');
    await expectLater(
      open(cache, gateway),
      throwsA(
        isA<AppFailure>().having((e) => e.code, 'code', FailureCode.integrity),
      ),
    );
    expect(await original.exists(), isFalse);
    await held.rename(original.path);
    expect((await open(cache, gateway)).closed, isFalse);
  });

  test('a remembered approved account can unlock offline only within its session grant', () async {
    final initial = await open(cache, gateway);
    final saved = await cache.access.last(gateway.userId!);
    expect(saved!.deviceId, initial.identity.deviceId);
    final account = await initial.ledger.createAccount(
      name: 'Synthetic cash',
      kind: AccountKind.asset,
      subtype: 'cash',
    );
    await initial.close();

    gateway.offline = true;
    clock = clock.add(const Duration(hours: 2));
    final offline = await open(cache, gateway);
    expect((await offline.ledger.account(account.id)).name, 'Synthetic cash');
    await offline.close();
    final code = isA<AppFailure>().having(
      (e) => e.code,
      'code',
      FailureCode.unauthorized,
    );
    clock = clock.subtract(const Duration(minutes: 5));
    await expectLater(open(cache, gateway), throwsA(code));
    clock = clock.add(const Duration(hours: 12));
    await expectLater(open(cache, gateway), throwsA(code));

    gateway.offline = false;
    final renewed = await open(cache, gateway);
    await renewed.close();
    gateway.offline = true;
    gateway.sessionId = const Uuid().v4();
    await expectLater(open(cache, gateway), throwsA(code));
  });

  test(
    'online access denial clears an otherwise valid offline grant',
    () async {
      final session = await open(cache, gateway);
      await session.close();
      final code = isA<AppFailure>().having(
        (e) => e.code,
        'code',
        FailureCode.unauthorized,
      );
      gateway.state = 'revoked';
      await expectLater(open(cache, gateway), throwsA(code));
      gateway.offline = true;
      await expectLater(open(cache, gateway), throwsA(code));
    },
  );

  test('switching the auth account locks the shared cache and preserves the local vault', () async {
    final lifecycle = VaultLifecycle(
      store: store,
      gate: gate,
      root: () async => root,
    );
    addTearDown(lifecycle.dispose);
    await lifecycle.initialize();
    await lifecycle.createOffline(
      familyName: 'Local sample vault',
      ownerName: 'Local owner',
    );
    final original = lifecycle.status.session!.identity;
    await lifecycle.lock();
    await lifecycle.openConnected(
      () => connectFamily(
        cache: cache,
        familyId: familyId,
        memberId: gateway.memberId,
        onRevoked: (error) => lifecycle.lock(reason: error),
      ),
    );
    final connected = lifecycle.status.session!;
    expect(connected.identity.isCloud, isTrue);
    final locked = lifecycle.changes.firstWhere(
      (status) => status.phase == VaultPhase.locked,
    );
    gateway.userId = null;
    gateway.accounts.add(null);
    expect((await locked).failure?.code, FailureCode.unauthorized);
    await lifecycle.unlock();
    expect(connected.closed, isTrue);
    expect(connected.keys.destroyed, isTrue);
    expect(lifecycle.status.session!.identity.familyId, original.familyId);
    await lifecycle.lock();
  });
}
