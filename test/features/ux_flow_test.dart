import 'dart:io';
import 'dart:ui' as ui;

import 'package:familyvault/app/app.dart';
import 'package:familyvault/app/router.dart';
import 'package:familyvault/app/vault_providers.dart';
import 'package:familyvault/core/localization/vault_strings.dart';
import 'package:familyvault/core/security/vault_lifecycle.dart';
import 'package:familyvault/features/finance/data/ledger_repository.dart';
import 'package:familyvault/features/guidance/guided_help.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../support/security_fakes.dart';
import '../support/widget_io.dart';

void main() {
  final evidence = Platform.environment['FAMILYVAULT_UX_EVIDENCE'];
  final boundaryKey = GlobalKey();
  late Directory scratch;
  late MemorySecureStore store;
  late VaultLifecycle lifecycle;

  setUpAll(() async {
    if (evidence == null) return;
    const fonts = '.tools/flutter/bin/cache/artifacts/material_fonts';
    for (final (family, name) in [
      ('Roboto', 'Roboto-Regular.ttf'),
      ('MaterialIcons', 'MaterialIcons-Regular.otf'),
    ]) {
      final file = File('$fonts/$name');
      if (await file.exists()) {
        await (FontLoader(
          family,
        )..addFont(file.readAsBytes().then(ByteData.sublistView))).load();
      }
    }
    final devanagari = File(
      '/usr/share/fonts/google-noto-vf/NotoSansDevanagari[wght].ttf',
    );
    if (await devanagari.exists()) {
      await (FontLoader(
        'Noto Sans Devanagari',
      )..addFont(devanagari.readAsBytes().then(ByteData.sublistView))).load();
    }
  });

  setUp(() async {
    final parent = await Directory('.cache/test-vaults')
        .create(recursive: true);
    scratch = await parent.createTemp('family-ux-');
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

  Future<ProviderContainer> mount(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vaultLifecycleProvider.overrideWithValue(lifecycle),
          secureStoreProvider.overrideWithValue(store),
        ],
        child: RepaintBoundary(key: boundaryKey, child: const FamilyVaultApp()),
      ),
    );
    return ProviderScope.containerOf(
      tester.element(find.byType(FamilyVaultApp)),
    );
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  }

  Future<void> openLocalRecords(WidgetTester tester) async {
    await tester.runAsync(
      () => lifecycle.createOffline(
        familyName: 'Synthetic family',
        ownerName: 'Synthetic member',
      ),
    );
  }

  void phone(WidgetTester tester, {bool large = false}) {
    tester.view.physicalSize = large
        ? const Size(320, 568)
        : const Size(411, 851);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = large ? 2 : 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  Future<void> screenshot(WidgetTester tester, String name) async {
    if (evidence == null) return;
    await tester.pump(const Duration(milliseconds: 350));
    await tester.runAsync(() async {
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = await boundary.toImage();
      try {
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File('$evidence/$name.png')
            .writeAsBytes(bytes!.buffer.asUint8List());
      } finally {
        image.dispose();
      }
    });
  }

  Finder area(String name) => find.byKey(ValueKey('area-$name'));
  Finder action(String name) => find.byKey(ValueKey('action-$name'));
  Finder appBar(String title) => find.widgetWithText(AppBar, title);
  Finder button(String label) => find.widgetWithText(FilledButton, label);

  Future<void> select(WidgetTester tester, String label, String choice) async {
    await tapVisible(
      tester,
      find.ancestor(
        of: find.text(label),
        matching: find.byType(DropdownButtonFormField<String>),
      ),
    );
    await tapVisible(tester, find.text(choice).last);
  }

  testWidgets('first tour can go back and remembers completion on relaunch', (
    tester,
  ) async {
    phone(tester);
    await mount(tester);
    await ready(tester, find.text('Take a short tour'));
    await tapVisible(tester, find.text('Take a short tour'));
    await ready(tester, find.text('Step 1 of 4'));
    await screenshot(tester, 'welcome-tour');
    await tapVisible(tester, button('Next'));
    expect(find.text('Keep important papers together'), findsOneWidget);
    await tapVisible(tester, find.widgetWithText(TextButton, 'Back'));
    expect(find.text('Step 1 of 4'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tapVisible(tester, button('Next'));
    }
    expect(find.text('Step 4 of 4'), findsOneWidget);
    await tapVisible(tester, button('Start using FamilyVault'));
    await ready(tester, find.text('Set up your family records'));
    expect(lifecycle.status.hasVault, isFalse);
    await unmount(tester);
    await mount(tester);
    await ready(tester, button('Start using FamilyVault'));
    expect(find.text('Take a short tour'), findsNothing);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('onboarding can choose Hindi and remembers it on relaunch', (
    tester,
  ) async {
    phone(tester);
    await mount(tester);
    await ready(tester, find.text('Take a short tour'));
    await tapVisible(tester, find.byKey(const ValueKey('language-en')));
    expect(find.text('मराठी (भारत)'), findsNothing);
    await tapVisible(tester, find.text('हिंदी (भारत)'));
    await ready(tester, find.text('परिवार के पैसे और दस्तावेज़'));
    final strings = VaultStrings.of(tester.element(find.byType(Scaffold)));
    for (final topic in HelpTopic.values) {
      expect(
        topic.title(strings),
        isNot(topic.title(const VaultStrings(Locale('en')))),
      );
      expect(topic.first(strings), isNotEmpty);
      expect(topic.second(strings), isNotEmpty);
    }
    expect(
      HelpTopic.search('दस्तावेज़', strings),
      contains(HelpTopic.findPaper),
    );
    expect(HelpTopic.search('बैंक खाता', strings), contains(HelpTopic.bank));
    await tapVisible(tester, find.text(strings.text('seeGuide')));
    await ready(tester, find.text('देखें, पैसे कहाँ जा रहे हैं'));
    await screenshot(tester, 'hindi-tour');
    await tapVisible(
      tester,
      find.widgetWithText(TextButton, strings.text('skip')),
    );
    await ready(tester, find.text(strings.text('createTitle')));
    expect(lifecycle.status.hasVault, isFalse);
    await unmount(tester);
    await mount(tester);
    await ready(tester, find.text('परिवार के पैसे और दस्तावेज़'));
    expect(find.text(strings.text('seeGuide')), findsNothing);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('an older Marathi preference falls back to English', (
    tester,
  ) async {
    phone(tester);
    await store.write('ui.phone_language', 'mr');
    await mount(tester);
    await ready(tester, find.text('Take a short tour'));
    expect(find.byKey(const ValueKey('language-en')), findsOneWidget);
    expect(await store.read('ui.phone_language'), 'mr');
    expect(
      const VaultStrings(Locale('mr', 'IN')).text('welcomeTitle'),
      'कुटुंबाचे पैसे आणि कागदपत्रे',
    );
    await unmount(tester);
  });

  testWidgets(
    'Hindi covers live forms, validation and tabs at large text size',
    (tester) async {
      phone(tester, large: true);
      await openLocalRecords(tester);
      final ledger = lifecycle.status.session!.ledger;
      // This name was typed by a family member and should not be translated.
      await tester.runAsync(
        () => ledger.createAccount(
          name: 'Investment',
          kind: AccountKind.asset,
          subtype: 'cash',
        ),
      );
      final container = await mount(tester);
      final router = container.read(routerProvider);
      await ready(tester, find.text('Money available'));
      router.go('/settings');
      await ready(tester, find.byKey(const ValueKey('language-en')));
      await tapVisible(tester, find.byKey(const ValueKey('language-en')));
      await tapVisible(tester, find.text('हिंदी (भारत)'));
      await ready(tester, appBar('सेटिंग्स'));
      final screens = [
        ('/home', 'हमारे पास पैसे'),
        ('/accounts', 'आपके खाते'),
        ('/assets', 'चीज़ें, मकान और ज़मीन'),
        ('/loans', 'लिए और दिए हुए कर्ज़'),
        ('/documents', 'दस्तावेज़ जोड़ें'),
        ('/family', 'परिवार के लोग'),
        ('/backups', 'सुरक्षित कॉपी बनाएँ'),
        ('/transaction/new?kind=income', 'पैसे कहाँ से मिले?'),
      ];
      for (final (route, label) in screens) {
        router.go(route);
        await ready(tester, find.text(label));
        expect(tester.takeException(), isNull, reason: route);
      }
      final source = find.ancestor(
        of: find.text('पैसे कहाँ से मिले?'),
        matching: find.byType(DropdownButtonFormField<String>),
      );
      await tapVisible(tester, source);
      await tapVisible(tester, find.text('तनख़्वाह').last);
      expect(find.text('Investment'), findsOneWidget);
      await tester.enterText(field('रकम'), '-0.01');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tapVisible(tester, button('हिसाब सेव करें'));
      expect(find.text('शून्य से बड़ी रकम लिखें।'), findsOneWidget);
      expect((await databaseIO(tester, ledger.snapshot)).journals, isEmpty);
      await tester.ensureVisible(field('रकम'));
      await screenshot(tester, 'hindi-money-320');
      await unmount(tester);
      await mount(tester);
      await ready(tester, find.text('हमारे पास पैसे'));
      await databaseIO(tester, lifecycle.lock);
      await ready(tester, find.text('आपके रिकॉर्ड लॉक हैं'));
      expect(tester.takeException(), isNull);
      await unmount(tester);
    },
  );

  testWidgets('offline help finds questions and respects locked records', (
    tester,
  ) async {
    phone(tester);
    await mount(tester);
    await ready(tester, find.text('Show me how'));
    await tapVisible(tester, find.text('Show me how'));
    final search = find.byKey(const ValueKey('help-search'));
    await tester.enterText(search, 'unmatched text');
    await tester.pump();
    expect(
      find.text('Try searching for money, gold, papers or safe copies.'),
      findsOneWidget,
    );
    await tester.enterText(search, 'jewellery');
    await tester.pump();
    expect(find.text('How do I add a bank account?'), findsNothing);
    await tapVisible(tester, find.text('How do I add gold?'));
    await tapVisible(tester, button('Next'));
    expect(
      find.text('Open your family records first to try this in the app.'),
      findsOneWidget,
    );
    expect(
      tester.widget<FilledButton>(button('Open this screen')).onPressed,
      isNull,
    );
    await tapVisible(tester, find.text('Exit guide'));
    expect(search, findsOneWidget);
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('guided income and moving money save exact paise', (
    tester,
  ) async {
    phone(tester);
    await openLocalRecords(tester);
    final ledger = lifecycle.status.session!.ledger;
    final (cash, bank) = (await tester.runAsync(
      () async => (
        await ledger.createAccount(
          name: 'Sample cash',
          kind: AccountKind.asset,
          subtype: 'cash',
        ),
        await ledger.createAccount(
          name: 'Sample bank',
          kind: AccountKind.asset,
          subtype: 'bank',
        ),
      ),
    ))!;
    final container = await mount(tester);
    await ready(tester, find.text('Money available'));
    await tapVisible(tester, find.widgetWithText(TextButton, 'Help'));
    await tester.enterText(find.byKey(const ValueKey('help-search')), 'salary');
    await tester.pump();
    await tapVisible(tester, find.text('How do I add money I received?'));
    await tapVisible(tester, button('Next'));
    await screenshot(tester, 'guide-money-received');
    await tapVisible(tester, button('Open this screen'));
    await ready(tester, field('Amount'));
    expect(
      find.text('For example, salary or money someone paid you.'),
      findsOneWidget,
    );
    await screenshot(tester, 'money-received');
    await tester.enterText(field('Amount'), '-0.01');
    await tapVisible(tester, button('Save money record'));
    expect(find.text('Enter an amount greater than zero.'), findsOneWidget);
    expect((await databaseIO(tester, ledger.snapshot)).journals, isEmpty);
    await tester.enterText(field('Amount'), '123.45');
    await select(tester, 'Which account received it?', 'Sample cash');
    await select(tester, 'Where did it come from?', 'Salary');
    await tapVisible(tester, button('Save money record'));
    await ready(tester, appBar('Money record'));
    final journal = (await databaseIO(tester, ledger.snapshot)).journals.single;
    expect(journal.description, 'Salary');
    expect(journal.kind, 'income');
    container.read(routerProvider).go('/home');
    await ready(tester, find.text('Money available'));
    await tapVisible(tester, action('transfer'));
    await ready(tester, field('Amount'));
    await tester.enterText(field('Amount'), '12.34');
    await select(tester, 'Move from', 'Sample cash');
    final moveTo = find.ancestor(
      of: find.text('Move to'),
      matching: find.byType(DropdownButtonFormField<String>),
    );
    await tapVisible(tester, moveTo);
    expect(find.text('Sample cash').hitTestable(), findsNothing);
    await tapVisible(tester, find.text('Sample bank').last);
    await tapVisible(tester, button('Save money record'));
    await ready(tester, appBar('Money record'));
    final records = await databaseIO(tester, ledger.snapshot);
    expect(records.total(AccountKind.income), BigInt.from(12345));
    expect(records.balances()[cash.id], BigInt.from(11111));
    expect(records.balances()[bank.id], BigInt.from(1234));
    expect(records.journals, hasLength(2));
    container.read(routerProvider).go('/home');
    await ready(tester, find.text('Sample cash → Sample bank'));
    expect(find.text('Sample bank → Sample cash'), findsNothing);
    await tapVisible(tester, find.text('Sample cash → Sample bank'));
    await ready(tester, appBar('Money record'));
    expect(tester.takeException(), isNull);
    await databaseIO(tester, lifecycle.lock);
    await ready(tester, find.text('Your records are locked'));
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });

  testWidgets('tabs keep document search and secondary Back returns to Money', (
    tester,
  ) async {
    phone(tester);
    await openLocalRecords(tester);
    await mount(tester);
    await ready(tester, find.text('Money available'));
    final semantics = tester.ensureSemantics();
    try {
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    } finally {
      semantics.dispose();
    }
    await tapVisible(tester, find.widgetWithText(TextButton, 'Help'));
    await tester.enterText(
      find.byKey(const ValueKey('help-search')),
      'find document',
    );
    await tester.pump();
    await tapVisible(tester, find.text('How do I find a document?'));
    await tapVisible(tester, button('Next'));
    await tapVisible(tester, button('Open this screen'));
    await ready(tester, appBar('Documents'));
    expect(
      find.text('In Documents, type a word from the name you saved.'),
      findsOneWidget,
    );
    final search = find.byKey(const ValueKey('papers-search'));
    await tester.enterText(search, 'Sample policy');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await screenshot(tester, 'documents-search');
    await tapVisible(tester, area('family'));
    await ready(tester, find.text('Synthetic member'));
    expect(find.text('Manage family access'), findsNothing);
    await screenshot(tester, 'family-local');
    await tapVisible(tester, area('money'));
    await tapVisible(tester, find.text('Accounts'));
    await ready(tester, appBar('Accounts'));
    await tester.pageBack();
    await ready(tester, appBar('Money'));
    await tapVisible(tester, area('documents'));
    expect(
      tester
          .widget<EditableText>(
            find.descendant(of: search, matching: find.byType(EditableText)),
          )
          .controller
          .text,
      'Sample policy',
    );
    await tapVisible(tester, area('more'));
    await ready(tester, find.text('Take the tour again'));
    expect(tester.takeException(), isNull);
    await databaseIO(tester, lifecycle.lock);
    await unmount(tester);
  });

  testWidgets('large text keeps tab controls and daily workflows reachable', (
    tester,
  ) async {
    phone(tester, large: true);
    await openLocalRecords(tester);
    final router = (await mount(tester)).read(routerProvider);
    await ready(tester, find.text('Money available'));
    await screenshot(tester, 'home-320-large-text');
    for (final (tab, title) in [
      ('money', 'Money'),
      ('documents', 'Documents'),
      ('family', 'Family'),
      ('more', 'More'),
      ('home', 'Home'),
    ]) {
      await tapVisible(tester, area(tab));
      await ready(tester, appBar(title));
      expect(tester.takeException(), isNull, reason: title);
    }
    await tapVisible(tester, find.byTooltip('Hide amounts on Home'));
    expect(find.text('Amounts are hidden'), findsOneWidget);
    expect(find.text('₹0.00'), findsNothing);
    await tapVisible(tester, action('addExpense'));
    await ready(tester, find.text('Add a cash or bank account first'));
    expect(find.widgetWithText(FilledButton, 'Add an account'), findsOneWidget);
    for (final (path, title) in [
      ('/help', 'Show me how'),
      ('/help/loan', 'Show me how'),
      ('/welcome-tour', 'Take a short tour'),
      ('/backups', 'Safe copies'),
      ('/businesses', 'Business'),
      ('/business/new', 'Add business'),
    ]) {
      router.go(path);
      await ready(tester, appBar(title));
      expect(tester.takeException(), isNull, reason: path);
    }
    expect(tester.takeException(), isNull);
    await databaseIO(tester, lifecycle.lock);
    await unmount(tester);
  });
}
