import 'dart:io';

import 'package:familyvault/app/app.dart';
import 'package:familyvault/app/vault_providers.dart';
import 'package:familyvault/core/config/app_config.dart';
import 'package:familyvault/core/security/vault_lifecycle.dart';
import 'package:familyvault/features/auth/cloud_access_gateway.dart';
import 'package:familyvault/features/auth/cloud_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:uuid/uuid.dart';

import '../support/cloud_fakes.dart';
import '../support/security_fakes.dart';

final class _AdminGateway extends EnrollmentGateway {
  _AdminGateway({
    required super.userId,
    required super.memberId,
    required this.familyId,
  }) {
    state = 'enrolled';
  }
  final String familyId;
  bool verified = false;

  @override
  Future<CloudJson> listAccess() async => {
    'families': <CloudJson>[
      {
        'family_id': familyId,
        'member_id': memberId,
        'role': 'administrator',
        'family_name': 'Synthetic shared family',
      },
    ],
    'invitations': <CloudJson>[],
  };

  @override
  Future<CloudJson> workspace(DeviceProof device) async => {
    ...await super.workspace(device),
    'role': 'administrator',
    'members': <CloudJson>[
      {
        'id': memberId,
        'display_name': 'Synthetic admin',
        'role': 'administrator',
        'active': true,
      },
    ],
    'devices': <CloudJson>[
      {'id': device.deviceId, 'name': 'Synthetic phone', 'state': 'enrolled'},
    ],
  };

  @override
  Future<List<({String id, String name})>> factors() async => [
    (id: 'fixture-factor', name: 'Synthetic authenticator'),
  ];

  @override
  Future<void> verifyTotp(String factorId, String code) async {
    expect(factorId, 'fixture-factor');
    expect(code == '123456', isTrue);
    verified = true;
  }

  @override
  Future<CloudJson> administratorView(DeviceProof device) async {
    expect(verified, isTrue);
    return {'invitations': <CloudJson>[], 'audit': <CloudJson>[]};
  }
}

void main() {
  testWidgets(
    'family enrollment and admin verification work from the opaque lock screen',
    (tester) async {
      final scratch = (await tester.runAsync(() async {
        final parent = await Directory('.cache/test-vaults')
            .create(recursive: true);
        return parent.createTemp('access-ui-');
      }))!;
      final store = MemorySecureStore(), gate = FakeDeviceGate();
      final lifecycle = VaultLifecycle(
        store: store,
        gate: gate,
        root: () async => scratch,
      );
      addTearDown(() async {
        await lifecycle.dispose();
        await scratch.delete(recursive: true);
      });
      await tester.runAsync(() async {
        await lifecycle.initialize();
        await lifecycle.createOffline(
          familyName: 'Synthetic offline',
          ownerName: 'Synthetic local owner',
        );
        await lifecycle.lock();
      });
      const uuid = Uuid();
      final gateway = _AdminGateway(
        userId: uuid.v4(),
        memberId: uuid.v4(),
        familyId: uuid.v4(),
      );
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vaultLifecycleProvider.overrideWithValue(lifecycle),
            secureStoreProvider.overrideWithValue(store),
            deviceGateProvider.overrideWithValue(gate),
            cloudConfigProvider.overrideWithValue(
              const AppConfig(
                supabaseUrl: 'https://fixture.example.invalid',
                publishableKey: 'sb_publishable_fixture_only',
              ),
            ),
            cloudGatewayProvider.overrideWith((ref) async => gateway),
          ],
          child: const FamilyVaultApp(),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> tap(String label) async {
        final target = find.text(label);
        await tester.ensureVisible(target);
        await tester.pump();
        await tester.tap(target);
        await tester.pumpAndSettle();
      }

      expect(find.text('Your vault is locked'), findsOneWidget);
      await tap('Open family access');
      await tap('Synthetic shared family');
      expect(find.text('Device approved'), findsOneWidget);
      expect(find.text('Net worth'), findsNothing);
      await tap('Verify administrator access');
      await tap('Continue');
      final code = find.byWidgetPredicate(
        (w) =>
            w is TextField && w.decoration?.labelText == 'Authenticator code',
      );
      await tester.enterText(code, '123456');
      await tap('Verify code');
      expect(find.text('Add invitation'), findsOneWidget);
      expect(find.text('Synthetic admin'), findsOneWidget);
      expect(lifecycle.status.phase, VaultPhase.locked);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
