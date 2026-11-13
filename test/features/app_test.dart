import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:familyvault/app/app.dart';

void main() {
  testWidgets('shell navigates to locked access without collecting records', (
    tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: FamilyVaultApp()));
    expect(find.text('Vault setup pending'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Family access'));
    await tester.pumpAndSettle();
    expect(find.text('Your vault is locked'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(find.byType(TextFormField), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('small screen and enlarged text keep access reachable', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(const ProviderScope(child: FamilyVaultApp()));
    await tester.ensureVisible(find.text('Family access'));
    await tester.tap(find.text('Family access'));
    await tester.pumpAndSettle();
    expect(find.text('Your vault is locked'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
