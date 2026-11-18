import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:familyvault/app/app.dart';
import 'package:familyvault/app/appearance.dart';
import 'package:familyvault/app/router.dart';
import 'package:familyvault/app/vault_providers.dart';
import 'package:familyvault/core/finance/money.dart';
import 'package:familyvault/core/security/vault_lifecycle.dart';
import 'package:familyvault/features/assets/data/asset_repository.dart';
import 'package:familyvault/features/finance/data/ledger_repository.dart';
import 'package:familyvault/shared/widgets/vault_widgets.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../support/security_fakes.dart';

Finder field(String label) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.labelText == label,
);

Future<void> ready(WidgetTester tester, Finder target) async {
  for (var i = 0; i < 100; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    if (target.evaluate().isNotEmpty &&
        find.byType(CircularProgressIndicator).evaluate().isEmpty) {
      await tester.pump(const Duration(milliseconds: 350));
      return;
    }
  }
  expect(
    target,
    findsWidgets,
    reason: 'The database-backed screen did not become ready.',
  );
  expect(find.byType(CircularProgressIndicator), findsNothing);
}

Future<T> databaseIO<T>(
  WidgetTester tester,
  Future<T> Function() action,
) async {
  // Keep pumping the UI's fake zone while real SQLite isolate responses arrive.
  // Waiting in runAsync alone can queue behind a UI transaction in the fake zone.
  T? result;
  Object? error;
  StackTrace? stack;
  bool done = false;
  unawaited(
    action().then<void>(
      (value) {
        result = value;
        done = true;
      },
      onError: (Object e, StackTrace s) {
        error = e;
        stack = s;
        done = true;
      },
    ),
  );
  for (var i = 0; i < 200 && !done; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump(const Duration(milliseconds: 20));
  }
  if (!done) {
    throw TimeoutException('SQLite UI operation did not finish.');
  }
  if (error != null) {
    Error.throwWithStackTrace(error!, stack!);
  }
  return result as T;
}

Future<void> tapVisible(WidgetTester tester, Finder target) async {
  await tester.ensureVisible(target);
  await tester.pump();
  for (var i = 0; i < 30 && target.hitTestable().evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  expect(
    target.hitTestable(),
    findsOneWidget,
    reason:
        'The control must be reachable after scrolling and route animations.',
  );
  await tester.tap(target);
  // A save may be waiting on real SQLite I/O while its progress indicator animates.
  // Let ready() advance real events instead of spinning only Flutter's fake clock.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
}

Future<void> selectValue(
  WidgetTester tester,
  String label,
  String value,
) async {
  await tapVisible(
    tester,
    find.ancestor(
      of: find.text(label),
      matching: find.byType(DropdownButtonFormField<String>),
    ),
  );
  await tapVisible(tester, find.text(value).last);
}

void main() {
  late Directory scratch;
  late VaultLifecycle lifecycle;
  final capture = GlobalKey();
  setUpAll(() async {
    // Actual SDK fonts make the generated synthetic UI capture reviewable.
    final file = File(
      '.tools/flutter/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
    );
    if (await file.exists()) {
      final loader = FontLoader('Roboto')
        ..addFont(file.readAsBytes().then(ByteData.sublistView));
      await loader.load();
    }
    final icons = File(
      '.tools/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    );
    if (await icons.exists()) {
      await (FontLoader(
        'MaterialIcons',
      )..addFont(icons.readAsBytes().then(ByteData.sublistView))).load();
    }
  });
  setUp(() async {
    final parent = await Directory('.cache/test-vaults')
        .create(recursive: true);
    scratch = await parent.createTemp('finance-ui-');
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
  Future<ProviderContainer> app(WidgetTester tester) async {
    if (lifecycle.status.session == null) {
      await tester.runAsync(
        () => lifecycle.createOffline(
          familyName: 'Synthetic test workspace',
          ownerName: 'Synthetic owner',
        ),
      );
    }
    await tester.pumpWidget(
      ProviderScope(
        overrides: [vaultLifecycleProvider.overrideWithValue(lifecycle)],
        child: RepaintBoundary(key: capture, child: const FamilyVaultApp()),
      ),
    );
    return ProviderScope.containerOf(
      tester.element(find.byType(FamilyVaultApp)),
    );
  }

  testWidgets(
    'account, expense, correction and budget forms persist real encrypted records',
    (tester) async {
      final container = await app(tester);
      await ready(tester, find.text('Add your first account'));
      await tapVisible(tester, find.text('Add your first account'));
      await ready(tester, field('Name'));
      await tester.enterText(field('Name'), 'Synthetic cash');
      await tester.enterText(field('Opening balance (optional)'), '1000.00');
      await tapVisible(tester, find.text('Save account'));
      await ready(tester, find.widgetWithText(AppBar, 'Account details'));
      var snapshot = (await databaseIO(
        tester,
        () => lifecycle.status.session!.ledger.snapshot(),
      ));
      final cash = snapshot.accounts.singleWhere(
        (a) => a.name == 'Synthetic cash',
      );
      expect(snapshot.balances()[cash.id], BigInt.from(100000));
      // Saving replaces only the form, preserving the navigation back to overview.
      await tester.pageBack();
      await ready(tester, find.text('Add transaction'));
      await tapVisible(tester, find.text('Add transaction'));
      await ready(tester, field('Amount'));
      await tester.enterText(field('Amount'), '123.45');
      await selectValue(tester, 'Paid from', 'Synthetic cash');
      await selectValue(tester, 'Category', 'Groceries');
      await tester.enterText(field('Description'), 'Synthetic groceries');
      await tapVisible(tester, find.text('Save transaction'));
      await ready(tester, find.widgetWithText(AppBar, 'Transaction details'));
      snapshot = (await databaseIO(
        tester,
        () => lifecycle.status.session!.ledger.snapshot(),
      ))!;
      expect(snapshot.total(AccountKind.expense), BigInt.from(12345));
      await tapVisible(tester, find.text('Correct entry'));
      await ready(tester, field('Amount'));
      await tester.enterText(field('Amount'), '23.45');
      await tester.enterText(
        field('Reason for correction'),
        'Synthetic amount correction',
      );
      await tapVisible(tester, find.text('Save correction'));
      await ready(tester, find.widgetWithText(AppBar, 'Transaction details'));
      snapshot = (await databaseIO(
        tester,
        () => lifecycle.status.session!.ledger.snapshot(),
      ))!;
      expect(snapshot.total(AccountKind.expense), BigInt.from(2345));
      expect(snapshot.journals.length, 4);
      expect(snapshot.journals.where((j) => j.deletedAtUs != null).length, 1);
      container.read(routerProvider).go('/planning');
      await ready(tester, find.text('Set budget'));
      await tapVisible(tester, find.text('Set budget'));
      await ready(tester, field('Monthly limit'));
      await selectValue(tester, 'Expense category', 'Groceries');
      await tester.enterText(field('Monthly limit'), '100.00');
      await tapVisible(tester, find.text('Save budget'));
      await ready(tester, find.text('₹76.55 remaining'));
      snapshot = (await databaseIO(
        tester,
        () => lifecycle.status.session!.ledger.snapshot(),
      ))!;
      expect(snapshot.budgets.single.amountMinor, 10000);
      expect(tester.takeException(), isNull);
      await databaseIO(tester, lifecycle.lock);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  testWidgets(
    'holding forms create, revalue and audit an encrypted property record',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final container = await app(tester);
      await ready(tester, find.text('Net worth'));
      await tapVisible(tester, find.text('More'));
      await tapVisible(tester, find.text('Assets'));
      await ready(tester, find.text('Add holding'));
      await tapVisible(tester, find.text('Add holding'));
      await ready(tester, field('Holding name'));
      await tester.enterText(field('Holding name'), 'Synthetic property');
      await tester.enterText(field('Family ownership (%)'), '50');
      await tapVisible(tester, find.text('Mumbai'));
      await tester.enterText(
        field('Current whole-holding value (optional)'),
        '12345.67',
      );
      await tapVisible(tester, find.text('Save holding'));
      await ready(tester, find.widgetWithText(AppBar, 'Holding details'));
      final session = lifecycle.status.session!,
          repo = AssetRepository(session.ledger);
      final asset = (await databaseIO(tester, repo.snapshot)).assets.single;
      expect(asset.familyOwnershipBps, 5000);
      expect(
        (await databaseIO(tester, repo.snapshot)).properties.single.city,
        'Mumbai',
      );
      expect(
        (await databaseIO(
          tester,
          repo.snapshot,
        )).valuations.single.familyValueMinor,
        617284,
      );
      await tapVisible(tester, find.text('Record valuation'));
      await ready(tester, field('Whole-holding value'));
      await tester.enterText(field('Whole-holding value'), '15000');
      await tester.enterText(
        field('Valuation source or reason'),
        'Synthetic appraisal',
      );
      await tapVisible(
        tester,
        find.widgetWithText(FilledButton, 'Record valuation'),
      );
      await ready(tester, find.text('₹7,500.00'));
      final snapshot = await databaseIO(tester, session.ledger.snapshot);
      expect(snapshot.balances()[asset.accountId], BigInt.from(750000));
      expect(
        (await databaseIO(tester, repo.snapshot)).valuations,
        hasLength(2),
      );
      final managed = snapshot.journals.firstWhere(
        (j) => j.relatedEntityId == asset.id,
      );
      container.read(routerProvider).go('/transaction/${managed.id}');
      await ready(tester, find.text('View related holding'));
      expect(find.text('Reverse entry'), findsNothing);
      await tapVisible(tester, find.text('View related holding'));
      await ready(tester, find.text('Change audit'));
      await tapVisible(tester, find.text('Change audit'));
      expect(find.text('Synthetic owner · create'), findsOneWidget);
      expect(find.text('Synthetic owner · update'), findsOneWidget);
      for (final size in [const Size(320, 568), const Size(1200, 900)]) {
        tester.view.physicalSize = size;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        for (final (path, title) in [
          ('/assets', 'Add holding'),
          ('/asset/new', 'Add a holding'),
          ('/asset/${asset.id}', 'Holding details'),
          ('/asset/${asset.id}/edit', 'Edit holding details'),
          ('/asset/${asset.id}/value', 'Record valuation'),
          ('/asset/${asset.id}/ownership', 'Change family share'),
          ('/asset/${asset.id}/close', 'Close holding'),
          ('/asset/${asset.id}/rent', 'Record rental income'),
        ]) {
          container.read(routerProvider).go(path);
          await ready(tester, find.text(title));
          expect(
            tester.takeException(),
            isNull,
            reason: 'Holding layout at $path / $size with 2x text',
          );
        }
      }
      await databaseIO(tester, lifecycle.lock);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  testWidgets(
    'responsive reports, theme preferences and private navigation work with real records',
    (tester) async {
      late String accountId, entryId;
      await tester.runAsync(() async {
        await lifecycle.createOffline(
          familyName: 'Synthetic test workspace',
          ownerName: 'Synthetic owner',
        );
        final ledger = lifecycle.status.session!.ledger;
        final cash = await ledger.createAccount(
          name: 'Synthetic cash',
          kind: AccountKind.asset,
          subtype: 'cash',
        );
        accountId = cash.id;
        entryId = await ledger.recordTransaction(
          kind: EntryKind.income,
          accountId: cash.id,
          counterAccountId: ledger.chartId('salary'),
          amount: Money.parseInr('125000'),
          occurredOn: LedgerRepository.dateOnly(DateTime.now()),
          description: 'Synthetic income',
        );
        await ledger.recordTransaction(
          kind: EntryKind.expense,
          accountId: cash.id,
          counterAccountId: ledger.chartId('groceries'),
          amount: Money.parseInr('12345.67'),
          occurredOn: LedgerRepository.dateOnly(DateTime.now()),
          description: 'Synthetic expense',
        );
      });
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final container = await app(tester);
      await ready(tester, find.text('Net worth'));
      expect(
        find.descendant(
          of: find.widgetWithText(MetricCard, 'Income'),
          matching: find.text('₹1.25 lakh'),
        ),
        findsOneWidget,
      );
      await tester.runAsync(() async {
        final boundary =
            capture.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 1),
            bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final directory = await Directory('.cache/screenshots')
            .create(recursive: true);
        await File('${directory.path}/m04-overview-synthetic.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
      for (final size in [const Size(320, 568), const Size(1200, 900)]) {
        tester.view.physicalSize = size;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        for (final path in [
          '/home',
          '/transactions',
          '/accounts',
          '/planning',
          '/reports',
          '/settings',
          '/more',
          '/account/new',
          '/account/$accountId',
          '/account/$accountId/edit',
          '/account/$accountId/reconcile',
          '/transaction/new',
          '/transaction/$entryId',
          '/transaction/$entryId/edit',
          '/budget/new',
        ]) {
          container.read(routerProvider).go(path);
          await ready(tester, find.byType(Scaffold).first);
          expect(
            tester.takeException(),
            isNull,
            reason: 'Layout failure at $path / $size with 2x text.',
          );
        }
      }
      tester.platformDispatcher.clearTextScaleFactorTestValue();
      tester.view.physicalSize = const Size(390, 844);
      container.read(routerProvider).go('/settings');
      await ready(tester, find.text('Dark'));
      await tapVisible(tester, find.text('Dark'));
      await ready(tester, find.text('Dark'));
      expect(container.read(appearanceProvider).theme, ThemeMode.dark);
      final prefs = (await databaseIO(
        tester,
        () => lifecycle.status.session!.db
            .select(lifecycle.status.session!.db.vaultPreferences)
            .get(),
      ));
      expect(prefs.singleWhere((p) => p.key == 'ui.theme').value, 'dark');
      await databaseIO(tester, lifecycle.lock);
      await tester.pumpAndSettle();
      container.read(routerProvider).go('/reports');
      await tester.pumpAndSettle();
      expect(find.text('Your vault is locked'), findsOneWidget);
      expect(find.text('Closing net worth'), findsNothing);
      expect(tester.takeException(), isNull);
      await databaseIO(tester, lifecycle.lock);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );
}
