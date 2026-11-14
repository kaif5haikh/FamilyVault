import 'dart:io';

import 'package:familyvault/app/app.dart';
import 'package:familyvault/app/vault_providers.dart';
import 'package:familyvault/core/security/vault_lifecycle.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/security_fakes.dart';

void main() {
  late Directory scratch;
  late VaultLifecycle lifecycle;
  setUp(() async {
    final parent = await Directory('.cache/test-vaults')
        .create(recursive: true);
    scratch = await parent.createTemp('app-');
    lifecycle = VaultLifecycle(
      store: MemorySecureStore(),
      gate: FakeDeviceGate(),
      root: () async => scratch,
    );
    await lifecycle.initialize();
  });
  tearDown(() async {
    await lifecycle.dispose();
    await scratch.delete(recursive: true);
  });
  Future<void> app(WidgetTester tester) => tester.pumpWidget(
    ProviderScope(
      overrides: [vaultLifecycleProvider.overrideWithValue(lifecycle)],
      child: const FamilyVaultApp(),
    ),
  );
  testWidgets(
    'locked access collects no records and exposes only device verification',
    (tester) async {
      await tester.runAsync(() async {
        await lifecycle.createOffline(
          familyName: 'Synthetic test',
          ownerName: 'Synthetic owner',
        );
        await lifecycle.lock();
      });
      await app(tester);
      await tester.pumpAndSettle();
      // Returning vaults show the opaque lock screen immediately.
      expect(find.text('Your vault is locked'), findsOneWidget);
      expect(find.text('Unlock vault'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.text('Net worth'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'small screen and enlarged text keep access and explicit setup reachable',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await app(tester);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Family access'));
      await tester.tap(find.text('Family access'));
      await tester.pumpAndSettle();
      expect(find.text('Create your private vault'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      await tester.ensureVisible(find.text('Create a local vault'));
      await tester.tap(find.text('Create a local vault'));
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'backgrounding masks and locks the active vault and removes financial navigation',
    (tester) async {
      await tester.runAsync(
        () => lifecycle.createOffline(
          familyName: 'Synthetic test',
          ownerName: 'Synthetic owner',
        ),
      );
      await app(tester);
      await tester.pump();
      expect(find.widgetWithText(AppBar, 'Overview'), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
      await tester.runAsync(() async {
        tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
        await Future<void>.delayed(const Duration(milliseconds: 100));
      });
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(lifecycle.status.phase, VaultPhase.locked);
      expect(find.text('Your vault is locked'), findsOneWidget);
      expect(find.text('Net worth'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
