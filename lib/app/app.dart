import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/localization/vault_strings.dart';
import '../features/document_vault/expiry_reminders.dart';
import 'router.dart';
import 'theme.dart';
import 'privacy_boundary.dart';
import 'appearance.dart';

class FamilyVaultApp extends ConsumerWidget {
  const FamilyVaultApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(documentReminderMonitorProvider);
    final appearance = ref.watch(appearanceProvider);
    return MaterialApp.router(
      title: 'FamilyVault',
      debugShowCheckedModeBanner: false,
      theme: VaultTheme.light,
      darkTheme: VaultTheme.dark,
      locale: appearance.locale,
      themeMode: appearance.theme,
      supportedLocales: VaultStrings.supported,
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      builder: (context, child) =>
          PrivacyBoundary(child: child ?? const SizedBox.shrink()),
      routerConfig: ref.watch(routerProvider),
    );
  }
}
