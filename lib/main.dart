import 'dart:async';
import 'dart:ui';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/vault_providers.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer();
  void lockAfterError() => unawaited(
    Future<void>.microtask(() => container.read(vaultLifecycleProvider).lock()),
  );
  FlutterError.onError = (_) {
    debugPrint('FamilyVault: framework failure; vault locked.');
    lockAfterError();
  };
  PlatformDispatcher.instance.onError = (_, _) {
    debugPrint('FamilyVault: platform failure; vault locked.');
    lockAfterError();
    return true;
  };
  ErrorWidget.builder = (_) => const ColoredBox(
    color: Color(0xFF102E2B),
    child: Center(
      child: Text(
        'Please reopen FamilyVault.',
        textDirection: TextDirection.ltr,
        style: TextStyle(color: Colors.white),
      ),
    ),
  );
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const FamilyVaultApp(),
    ),
  );
}
