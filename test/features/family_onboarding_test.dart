import 'dart:io';

import 'package:familyvault/app/app.dart';
import 'package:familyvault/app/vault_providers.dart';
import 'package:familyvault/core/config/app_config.dart';
import 'package:familyvault/core/localization/vault_strings.dart';
import 'package:familyvault/core/security/vault_lifecycle.dart';
import 'package:familyvault/features/auth/cloud_access_gateway.dart';
import 'package:familyvault/features/auth/cloud_device_registration.dart';
import 'package:familyvault/features/auth/cloud_providers.dart';
import 'package:familyvault/features/auth/family_admin_panel.dart';
import 'package:familyvault/features/foundation/foundation_pages.dart';
import 'package:familyvault/features/guidance/guided_help.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:uuid/uuid.dart';

import '../support/cloud_fakes.dart';
import '../support/security_fakes.dart';
import '../support/widget_io.dart';

void main() {
  const uuid = Uuid();
  late Directory scratch;
  late VaultLifecycle lifecycle;
  late MemorySecureStore store;
  late FakeDeviceGate gate;
  late _FamilyGateway gateway;
  late CloudDeviceRegistration registration;

  setUp(() async {
    final parent = await Directory('.cache/test-vaults')
        .create(recursive: true);
    scratch = await parent.createTemp('family-onboarding-');
    store = MemorySecureStore();
    gate = FakeDeviceGate();
    lifecycle = VaultLifecycle(
      store: store,
      gate: gate,
      root: () async => scratch,
    );
    await lifecycle.initialize();
    gateway = _FamilyGateway(uuid.v4(), uuid.v4(), uuid.v4());
    registration = CloudDeviceRegistration(
      store: store,
      gate: gate,
      gateway: gateway,
      namespace: 'synthetic-family-ux',
    );
  });

  tearDown(() async {
    await lifecycle.dispose();
    await scratch.delete(recursive: true);
  });

  Widget scope(Widget child) => ProviderScope(
    overrides: [
      vaultLifecycleProvider.overrideWithValue(lifecycle),
      secureStoreProvider.overrideWithValue(store),
      cloudConfigProvider.overrideWithValue(
        const AppConfig(
          supabaseUrl: 'https://example.invalid',
          publishableKey: 'sb_publishable_fixture',
        ),
      ),
      cloudGatewayProvider.overrideWith((_) async => gateway),
      cloudRegistrationProvider.overrideWith((_) async => registration),
    ],
    child: child,
  );

  void small(WidgetTester tester) {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  test('offline guidance finds family relationships in English and Hindi', () {
    expect(
      HelpTopic.search(
        'How do I invite my mother?',
        const VaultStrings(Locale('en', 'IN')),
      ),
      contains(HelpTopic.invite),
    );
    expect(
      HelpTopic.search('बहन न्योता', const VaultStrings(Locale('hi', 'IN'))),
      contains(HelpTopic.invite),
    );
  });

  testWidgets(
    'a Hindi invitation can be reviewed and only joins after explicit acceptance',
    (tester) async {
      small(tester);
      store.values['ui.phone_language'] = 'hi';
      await tester.pumpWidget(scope(const FamilyVaultApp()));
      final choice = find.text('मेरे पास परिवार का न्योता है');
      await ready(tester, choice);
      await tapVisible(tester, choice);
      final review = find.text('परिवार का न्योता देखें');
      await ready(tester, review);
      await tapVisible(tester, review);
      expect(find.text('Synthetic owner ने बुलाया है'), findsOneWidget);
      expect(gateway.acceptCount, 0);
      await tapVisible(tester, find.text('अभी नहीं'));
      expect(gateway.acceptCount, 0);
      await tapVisible(tester, review);
      await tapVisible(tester, find.text('न्योता स्वीकार करें'));
      await ready(tester, find.text('आप Synthetic family से जुड़ गए हैं।'));
      expect(gateway.acceptCount, 1);
      expect(gateway.requests, 0);
      await tapVisible(tester, find.text('इस फ़ोन को तैयार करें'));
      await ready(tester, find.text('इस फ़ोन को इजाज़त मिलना बाकी है'));
      expect(gateway.requests, 1);
      expect(gateway.bindings, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'administrator form validates email, verifies and shows pending invitation after saving',
    (tester) async {
      await tester.runAsync(
        () => registration.enroll(
          familyId: gateway.familyId,
          memberId: gateway.memberId,
          name: 'Sample phone',
        ),
      );
      await tester.pumpWidget(
        scope(
          MaterialApp(
            home: VaultPage(
              title: 'Add family member',
              children: [
                FamilyAdminPanel(
                  familyId: gateway.familyId,
                  memberId: gateway.memberId,
                  gateway: gateway,
                  startsWithInvite: true,
                ),
              ],
            ),
          ),
        ),
      );
      await tapVisible(tester, find.text('Save invitation'));
      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(gateway.saved, isEmpty);
      await tester.enterText(field('Their name'), 'Synthetic father');
      await tester.enterText(
        field('Their email address'),
        'father@example.invalid',
      );
      await tester.enterText(field('Relationship'), 'Father');
      await tapVisible(tester, find.text('Save invitation'));
      await tapVisible(tester, find.text('Continue'));
      await tester.enterText(field('Authenticator code'), '001234');
      await tapVisible(tester, find.text('Verify code'));
      await ready(
        tester,
        find.text(
          'The invitation is ready. Ask them to sign in with the email you used.',
        ),
      );
      expect(gateway.verified, isTrue);
      expect(gateway.saved, [
        'father@example.invalid',
        'Synthetic father',
        'Father',
      ]);
      expect(find.text('Pending invitations'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

class _FamilyGateway extends EnrollmentGateway {
  _FamilyGateway(String user, String member, this.familyId)
    : super(userId: user, memberId: member);

  final String familyId;
  final saved = <String>[];
  int acceptCount = 0;
  bool verified = false;
  static const _invitation = {
    'invite_id': 'synthetic-invite',
    'family_name': 'Synthetic family',
    'invited_by_name': 'Synthetic owner',
  };

  @override
  Future<CloudJson> listAccess() async => {
    'invitations': acceptCount == 0 ? [_invitation] : [],
    'families': [
      if (acceptCount != 0)
        {
          'family_id': familyId,
          'family_name': 'Synthetic family',
          'role': 'member',
          'member_id': memberId,
        },
    ],
  };

  @override
  Future<String> accept(String invitationId) async {
    expect(invitationId, 'synthetic-invite');
    acceptCount++;
    return familyId;
  }

  @override
  Future<List<({String id, String name})>> factors() async => [
    (id: 'fixture-factor', name: 'Synthetic verification'),
  ];

  @override
  Future<void> verifyTotp(String factorId, String code) async {
    verified = factorId == 'fixture-factor' && code == '001234';
  }

  @override
  Future<void> invite(
    DeviceProof device,
    String email,
    String name,
    String relationship,
  ) async {
    expect(verified, isTrue);
    saved.addAll([email, name, relationship]);
  }

  @override
  Future<CloudJson> administratorView(DeviceProof device) async => {
    'invitations': [
      if (saved.isNotEmpty)
        {'id': 'synthetic-invite', 'email': saved[0], 'display_name': saved[1]},
    ],
    'audit': [],
  };
}
