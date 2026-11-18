import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

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
