import 'dart:io';
import 'dart:ui' as ui;

import 'package:familyvault/app/app.dart';
import 'package:familyvault/app/appearance.dart';
import 'package:familyvault/app/router.dart';
import 'package:familyvault/app/vault_providers.dart';
import 'package:familyvault/core/finance/money.dart';
import 'package:familyvault/core/security/vault_lifecycle.dart';
import 'package:familyvault/features/assets/data/asset_repository.dart';
import 'package:familyvault/features/business/data/business_repository.dart';
import 'package:familyvault/features/finance/data/ledger_repository.dart';
import 'package:familyvault/features/liabilities/data/debt_repository.dart';
import 'package:familyvault/shared/widgets/vault_widgets.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../support/security_fakes.dart';
import '../support/widget_io.dart';

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
      await tester.enterText(field('Starting amount (optional)'), '1000.00');
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
      await ready(tester, find.byKey(const ValueKey('action-addExpense')));
      await tapVisible(tester, find.byKey(const ValueKey('action-addExpense')));
      await ready(tester, field('Amount'));
      await tester.enterText(field('Amount'), '123.45');
      await selectValue(tester, 'Which account did you use?', 'Synthetic cash');
      await selectValue(tester, 'What was it spent on?', 'Groceries');
      await tester.enterText(field('Note (optional)'), 'Synthetic groceries');
      await tapVisible(tester, find.text('Save money record'));
      await ready(tester, find.widgetWithText(AppBar, 'Money record'));
      snapshot = (await databaseIO(
        tester,
        () => lifecycle.status.session!.ledger.snapshot(),
      ))!;
      expect(snapshot.total(AccountKind.expense), BigInt.from(12345));
      await tapVisible(tester, find.text('Correct this record'));
      await ready(tester, field('Amount'));
      await tester.enterText(field('Amount'), '23.45');
      await tester.enterText(
        field('Why are you correcting this?'),
        'Synthetic amount correction',
      );
      await tapVisible(tester, find.text('Save correction'));
      await ready(tester, find.widgetWithText(AppBar, 'Money record'));
      snapshot = (await databaseIO(
        tester,
        () => lifecycle.status.session!.ledger.snapshot(),
      ))!;
      expect(snapshot.total(AccountKind.expense), BigInt.from(2345));
      expect(snapshot.journals.length, 4);
      expect(snapshot.journals.where((j) => j.deletedAtUs != null).length, 1);
      container.read(routerProvider).go('/planning');
      await ready(tester, find.text('Plan spending'));
      await tapVisible(tester, find.text('Plan spending'));
      await ready(tester, field('Monthly limit'));
      await selectValue(tester, 'Expense category', 'Groceries');
      await tester.enterText(field('Monthly limit'), '100.00');
      await tapVisible(tester, find.text('Save spending plan'));
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
      await ready(tester, find.text('Money available'));
      await tapVisible(tester, find.byKey(const ValueKey('area-money')));
      await tapVisible(tester, find.text('What we own'));
      await ready(tester, find.text('Add an item'));
      await tapVisible(tester, find.text('Add an item'));
      await ready(tester, field('Item name'));
      await tester.enterText(field('Item name'), 'Synthetic property');
      await tester.enterText(field('Family share (%)'), '50');
      await tapVisible(tester, find.text('Mumbai'));
      await tester.enterText(
        field('Estimated value of the whole item (optional)'),
        '12345.67',
      );
      await tapVisible(tester, find.text('Save item'));
      await ready(tester, find.widgetWithText(AppBar, 'Item details'));
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
      await tapVisible(tester, find.text('Update estimated value'));
      await ready(tester, field('Value of the whole item'));
      await tester.enterText(field('Value of the whole item'), '15000');
      await tester.enterText(
        field('Where did the estimate come from?'),
        'Synthetic appraisal',
      );
      await tapVisible(
        tester,
        find.widgetWithText(FilledButton, 'Save estimate'),
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
      await ready(tester, find.text('Open the related item'));
      expect(find.text('Undo this record'), findsNothing);
      await tapVisible(tester, find.text('Open the related item'));
      await ready(tester, find.text('Change audit'));
      await tapVisible(tester, find.text('Change audit'));
      expect(find.text('Synthetic owner · create'), findsOneWidget);
      expect(find.text('Synthetic owner · update'), findsOneWidget);
      for (final size in [const Size(320, 568), const Size(1200, 900)]) {
        tester.view.physicalSize = size;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        for (final (path, title) in [
          ('/assets', 'Add an item'),
          ('/asset/new', 'Add something we own'),
          ('/asset/${asset.id}', 'Item details'),
          ('/asset/${asset.id}/edit', 'Edit item details'),
          ('/asset/${asset.id}/value', 'Update estimated value'),
          ('/asset/${asset.id}/ownership', 'Change family share'),
          ('/asset/${asset.id}/close', 'Close this item'),
          ('/asset/${asset.id}/rent', 'Add rent received'),
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
    'loan forms record an actual split payment and retain the correction history',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = await app(tester);
      await ready(tester, find.text('Money available'));
      final session = lifecycle.status.session!;
      final cash = await databaseIO(
        tester,
        () => session.ledger.createAccount(
          name: 'Synthetic loan cash',
          kind: AccountKind.asset,
          subtype: 'cash',
          openingBalance: Money.fromMinor(100000),
          openedOn: LedgerRepository.dateOnly(DateTime.now()),
        ),
      );
      container.read(routerProvider).go('/loans');
      await ready(tester, find.text('Add loan'));
      await tapVisible(tester, find.text('Add loan'));
      await ready(tester, field('Loan name'));
      await tester.enterText(field('Loan name'), 'Synthetic loan');
      await tester.enterText(field('Lender'), 'Synthetic lender');
      await tester.enterText(field('Original loan amount'), '1000');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump(const Duration(milliseconds: 350));
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Save loan'));
      final repaymentButton = find.widgetWithText(
        FilledButton,
        'Add a payment',
      );
      await ready(tester, repaymentButton);
      await tapVisible(tester, repaymentButton);
      await ready(tester, field('Amount paid toward the loan'));
      await tester.enterText(field('Amount paid toward the loan'), '250.01');
      await tester.enterText(field('Interest paid'), '4.99');
      await selectValue(tester, 'Paid from', 'Synthetic loan cash');
      await tapVisible(
        tester,
        find.widgetWithText(FilledButton, 'Save repayment'),
      );
      await ready(tester, find.text('₹749.99'));
      // A save notice can still cover the bottom of the next long form.
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 350));
      await tapVisible(tester, find.text('Correct payment'));
      await ready(tester, field('Reason for correction'));
      await tester.enterText(field('Amount paid toward the loan'), '200');
      await tester.enterText(field('Interest paid'), '2.01');
      await tester.enterText(
        field('Reason for correction'),
        'Synthetic corrected repayment',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tapVisible(
        tester,
        find.widgetWithText(FilledButton, 'Save repayment correction'),
      );
      await ready(tester, find.text('₹800.00'));
      final debt = await databaseIO(
        tester,
        DebtRepository(session.ledger).snapshot,
      );
      final loan = debt.contracts.single;
      final finance = await databaseIO(tester, session.ledger.snapshot);
      expect(finance.balances()[loan.accountId], BigInt.from(-80000));
      expect(finance.balances()[cash.id], BigInt.from(79799));
      expect(finance.total(AccountKind.expense), BigInt.from(201));
      expect(debt.repayments, hasLength(2));
      expect(finance.journals.where((j) => j.reversesId != null), hasLength(1));
      expect(tester.takeException(), isNull);
      await databaseIO(tester, lifecycle.lock);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );

  testWidgets(
    'business forms connect revenue, weighted stock cost and profit to the same ledger',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = await app(tester);
      await ready(tester, find.text('Money available'));
      final session = lifecycle.status.session!;
      final repo = BusinessRepository(session.ledger);
      await databaseIO(
        tester,
        () => session.ledger.createAccount(
          name: 'Synthetic business cash',
          kind: AccountKind.asset,
          subtype: 'cash',
        ),
      );
      final router = container.read(routerProvider);
      router.go('/businesses');
      await ready(tester, find.text('Add business'));
      await tapVisible(tester, find.text('Add business'));
      await ready(tester, field('Business name'));
      await tester.enterText(field('Business name'), 'Synthetic business');
      await tapVisible(
        tester,
        find.widgetWithText(FilledButton, 'Save business'),
      );
      await ready(
        tester,
        find.widgetWithText(FilledButton, 'Add money from sales'),
      );
      final business = (await databaseIO(
        tester,
        repo.snapshot,
      )).businesses.single;
      await tapVisible(
        tester,
        find.widgetWithText(FilledButton, 'Add money from sales'),
      );
      await ready(tester, field('Amount'));
      await tester.enterText(field('Amount'), '100');
      await selectValue(tester, 'Received into', 'Synthetic business cash');
      await tester.enterText(field('Description'), 'Synthetic proceeds');
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 350));
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Save entry'));
      await ready(tester, find.text('₹100.00'));
      await tapVisible(tester, find.text('Add stock item'));
      await ready(tester, field('Stock item name'));
      await tester.enterText(field('Stock item name'), 'Synthetic tyre');
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 350));
      await tapVisible(
        tester,
        find.widgetWithText(FilledButton, 'Save stock item'),
      );
      final savedStock = await databaseIO(tester, repo.snapshot);
      final formError = find
          .byType(FailureNotice)
          .evaluate()
          .firstOrNull
          ?.widget;
      expect(
        savedStock.items,
        hasLength(1),
        reason: formError is FailureNotice
            ? '${formError.error}'
            : 'The form persisted the stock item.',
      );
      final movementButton = find.widgetWithText(
        FilledButton,
        'Record stock movement',
      );
      await ready(tester, movementButton);
      await tapVisible(tester, movementButton);
      await ready(tester, field('Quantity in pieces'));
      await tester.enterText(field('Quantity in pieces'), '3');
      await tester.enterText(field('Total stock cost'), '12.34');
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 350));
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Save entry'));
      await ready(tester, find.text('3 pieces'));
      await tapVisible(tester, movementButton);
      await ready(tester, field('Quantity in pieces'));
      await tapVisible(
        tester,
        find.byType(DropdownButtonFormField<StockEntryKind>),
      );
      await tapVisible(tester, find.text('Stock issued').last);
      await tester.enterText(field('Quantity in pieces'), '1');
      await tester.pump(const Duration(seconds: 5));
      await tester.pump(const Duration(milliseconds: 350));
      await tapVisible(tester, find.widgetWithText(FilledButton, 'Save entry'));
      await ready(tester, find.text('2 pieces'));
      final data = await databaseIO(tester, repo.snapshot);
      expect(data.positions.values.single.costPoolMinor, 823);
      expect(data.movements, hasLength(2));
      router.go('/business/${business.id}');
      await ready(tester, find.text('₹95.89'));
      expect(tester.takeException(), isNull);
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
      await ready(tester, find.text('Money available'));
      expect(
        find.descendant(
          of: find.widgetWithText(Card, 'Money available'),
          matching: find.text('₹1.25 lakh'),
        ),
        findsOneWidget,
      );
      if (Platform.environment['FAMILYVAULT_UX_EVIDENCE'] case final output?) {
        await tester.runAsync(() async {
          final boundary =
              capture.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary;
          final image = await boundary.toImage(pixelRatio: 1);
          try {
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File('$output/home-synthetic.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
          } finally {
            image.dispose();
          }
        });
      }
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
      expect(find.text('Your records are locked'), findsOneWidget);
      expect(find.text('Estimated family value'), findsNothing);
      expect(tester.takeException(), isNull);
      await databaseIO(tester, lifecycle.lock);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(Duration.zero);
    },
  );
}
