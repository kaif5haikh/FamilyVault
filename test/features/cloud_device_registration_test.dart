import 'package:familyvault/core/errors/app_failure.dart';
import 'package:familyvault/features/auth/cloud_device_registration.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

import '../support/cloud_fakes.dart';
import '../support/security_fakes.dart';

void main() {
  const uuid = Uuid();
  late MemorySecureStore store;
  late FakeDeviceGate gate;
  late EnrollmentGateway gateway;
  late CloudDeviceRegistration registration;
  late String family, member, user;

  setUp(() {
    family = uuid.v4();
    member = uuid.v4();
    user = uuid.v4();
    store = MemorySecureStore();
    gate = FakeDeviceGate();
    gateway = EnrollmentGateway(userId: user, memberId: member);
    registration = CloudDeviceRegistration(
      store: store,
      gate: gate,
      gateway: gateway,
      namespace: 'synthetic',
    );
  });

  Future<EnrollmentResult> enroll() => registration.enroll(
    familyId: family,
    memberId: member,
    name: 'Synthetic phone',
  );
  Matcher failure(FailureCode code) =>
      isA<AppFailure>().having((e) => e.code, 'code', code);

  test('device enrollment is durable across interruption and binds only after server approval', () async {
    gateway.interrupt = true;
    await expectLater(enroll(), throwsA(failure(FailureCode.network)));
    expect(store.writes, 1);
    gateway.interrupt = false;
    final pending = await enroll();
    expect(pending.state, 'pending');
    expect(pending.workspace, isNull);
    expect(gateway.bindings, 0);
    expect(gateway.received[0].deviceId, pending.deviceId);
    expect(gateway.received[0].proof == gateway.received[1].proof, isTrue);
    gateway.state = 'enrolled';
    final approved = await enroll();
    expect(approved.deviceId, pending.deviceId);
    expect(approved.fingerprint, pending.fingerprint);
    expect(gateway.bindings, 1);
    expect(gateway.reads, 1);
    expect(store.writes, 1);
    expect(gateway.received[0].proof == gateway.received[2].proof, isTrue);
    expect(gateway.received[0].proof.length, 64);
    expect(
      gateway.received[0].toString().contains(gateway.received[0].proof),
      isFalse,
    );
  });

  test('local screen-lock denial and changing accounts during a challenge stop enrollment', () async {
    gate.allowed = false;
    await expectLater(enroll(), throwsA(failure(FailureCode.locked)));
    expect(store.values, isEmpty);
    expect(gateway.requests, 0);
    gate.challenge = () async {
      gateway.userId = uuid.v4();
      return true;
    };
    await expectLater(enroll(), throwsA(failure(FailureCode.unauthorized)));
    expect(store.values, isEmpty);
    expect(gateway.requests, 0);
  });

  test('profile keys are isolated by account, family and server and are wiped after use', () async {
    final first = await enroll();
    gateway.userId = uuid.v4();
    final second = await enroll();
    expect(second.deviceId, isNot(first.deviceId));
    gateway.userId = user;
    final original = await enroll();
    expect(original.deviceId, first.deviceId);
    expect(store.values.length, 2);
    final anotherServer = CloudDeviceRegistration(
      store: store,
      gate: gate,
      gateway: gateway,
      namespace: 'synthetic-alternate',
    );
    final alternate = await anotherServer.enroll(
      familyId: family,
      memberId: member,
      name: 'Synthetic alternative',
    );
    expect(alternate.deviceId, isNot(first.deviceId));
    final used = await registration.withVerifiedDevice(
      family,
      member,
      action: (device) async => device,
    );
    expect(used.keys.destroyed, isTrue);
    expect(() => used.proof, throwsA(failure(FailureCode.locked)));
  });

  test('cross-family workspace results and revoked enrollment cannot open a workspace', () async {
    gateway.state = 'revoked';
    final revoked = await enroll();
    expect(revoked.state, 'revoked');
    expect(gateway.bindings, 0);
    expect(gateway.reads, 0);
    gateway.state = 'enrolled';
    gateway.responseFamily = uuid.v4();
    await expectLater(enroll(), throwsA(failure(FailureCode.integrity)));
    expect(store.writes, 1);
  });
}
