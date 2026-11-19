import 'dart:io';

import 'package:familyvault/core/errors/app_failure.dart';
import 'package:familyvault/core/security/vault_lifecycle.dart';
import 'package:familyvault/features/document_vault/expiry_reminders.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/security_fakes.dart';

final class _ReminderFixture implements DocumentReminderPlatform {
  bool permission = false;
  int requests = 0;
  final batches = <List<int>>[];

  @override
  bool get supported => true;

  @override
  Future<bool> request() async {
    requests++;
    return permission;
  }

  @override
  Future<bool> allowed() async => permission;

  @override
  Future<void> replace(List<int> times) async => batches.add(List.of(times));
}

void main() {
  test(
    'expiry notifications use future local dates and combine duplicate times',
    () {
      final now = DateTime(2026, 10, 15, 10);
      final times = documentReminderTimes([
        '2026-11-14',
        '2026-11-14',
        '2026-12-31',
        '2026-02-30',
        null,
      ], now);
      expect(times, [
        DateTime(2026, 11, 14, 9).millisecondsSinceEpoch,
        DateTime(2026, 12, 1, 9).millisecondsSinceEpoch,
        DateTime(2026, 12, 31, 9).millisecondsSinceEpoch,
      ]);
      final many = List.generate(
        60,
        (i) => DateTime(2027, 1, i + 1).toIso8601String().split('T').first,
      );
      expect(documentReminderTimes(many, now), hasLength(32));
    },
  );

  test(
    'device consent, vault state and switch-off control reminder delivery',
    () async {
      final root = await (await Directory(
        '.cache/test-vaults',
      ).create(recursive: true)).createTemp('expiry-');
      addTearDown(() => root.delete(recursive: true));
      final store = MemorySecureStore();
      final native = _ReminderFixture();
      final lifecycle = VaultLifecycle(
        store: store,
        gate: FakeDeviceGate(),
        root: () async => root,
      );
      addTearDown(lifecycle.dispose);
      await lifecycle.initialize();
      await lifecycle.createOffline(
        familyName: 'Synthetic deadline fixture',
        ownerName: 'Synthetic owner',
      );
      final session = lifecycle.status.session!;
      final service = DocumentReminderService(
        store,
        native,
        clock: () => DateTime(2026, 10, 15),
      );
      expect(await service.enabled(session.identity), isFalse);
      await expectLater(
        service.setEnabled(session.identity, true),
        throwsA(
          isA<AppFailure>().having(
            (e) => e.code,
            'code',
            FailureCode.configuration,
          ),
        ),
      );
      expect(await service.enabled(session.identity), isFalse);
      expect(native.batches, isEmpty);
      native.permission = true;
      await service.setEnabled(session.identity, true);
      await service.refresh(session, ['2026-12-31']);
      await service.refresh(session, ['2026-12-31']);
      expect(native.requests, 2);
      expect(native.batches, hasLength(1));
      expect(native.batches.single, hasLength(2));

      native.permission = false;
      await service.refresh(session, ['2026-12-31']);
      expect(native.batches.last, isEmpty);
      expect(await service.enabled(session.identity), isTrue);
      native.permission = true;
      await service.refresh(session, ['2026-12-31']);
      await lifecycle.lock();
      await service.refresh(session, ['2027-01-01']);
      expect(native.batches, hasLength(3));
      await service.setEnabled(session.identity, false);
      expect(native.batches.last, isEmpty);
      expect(await service.enabled(session.identity), isFalse);
    },
  );
}
