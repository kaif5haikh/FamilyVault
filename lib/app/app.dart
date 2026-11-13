import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'theme.dart';

class FamilyVaultApp extends ConsumerWidget {
  const FamilyVaultApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'FamilyVault',
      debugShowCheckedModeBanner: false,
      theme: VaultTheme.light,
      darkTheme: VaultTheme.dark,
      routerConfig: ref.watch(routerProvider),
    );
  }
}
