import 'dart:io';

import 'package:familyvault/app/app.dart';
import 'package:familyvault/app/vault_providers.dart';
import 'package:familyvault/core/security/vault_lifecycle.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/security_fakes.dart';
import '../support/widget_io.dart';

void main() {
  late Directory scratch;
  late VaultLifecycle lifecycle;
  late MemorySecureStore store;
  setUp(() async {
    final parent = await Directory('.cache/test-vaults')
        .create(recursive: true);
    scratch = await parent.createTemp('app-');
    store = MemorySecureStore();
    lifecycle = VaultLifecycle(
      store: store,
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
      overrides: [
        vaultLifecycleProvider.overrideWithValue(lifecycle),
        secureStoreProvider.overrideWithValue(store),
      ],
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
      expect(find.text('Your records are locked'), findsOneWidget);
      expect(find.text('Unlock records'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.text('Money available'), findsNothing);
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
      await tapVisible(tester, find.text('Start using FamilyVault'));
      await ready(tester, find.text('Set up your family records'));
      expect(find.text('Set up your family records'), findsOneWidget);
      expect(find.byType(TextFormField), findsNothing);
      await tester.ensureVisible(find.text('Set up on this phone'));
      await tester.tap(find.text('Set up on this phone'));
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
      expect(find.widgetWithText(AppBar, 'Home'), findsOneWidget);
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
      expect(find.text('Your records are locked'), findsOneWidget);
      expect(find.text('Money available'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
