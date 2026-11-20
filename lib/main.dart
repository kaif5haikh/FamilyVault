import 'dart:async';
import 'dart:ui';

import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/appearance.dart';
import 'app/vault_providers.dart';
import 'core/localization/vault_strings.dart';

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
  ErrorWidget.builder = (_) {
    const reopen = 'Please reopen FamilyVault.';
    var message = reopen;
    try {
      message = VaultStrings(container.read(appearanceProvider).locale)
          .message(reopen);
    } catch (_) {
      // An early framework failure may leave the preference unavailable.
    }
    return ColoredBox(
      color: const Color(0xFF102E2B),
      child: Center(
        child: Text(
          message,
          textDirection: TextDirection.ltr,
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  };
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const FamilyVaultApp(),
    ),
  );
}
