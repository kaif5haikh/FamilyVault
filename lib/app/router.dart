import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/foundation/foundation_pages.dart';
import '../features/finance/presentation/finance_home_page.dart';
import 'vault_providers.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(vaultProvider, (_, _) => refresh.value++);
  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, route) {
      final session = ref.read(vaultProvider).session;
      final open = session != null && !session.closed;
      final path = route.uri.path;
      if (path == '/home' && !open) {
        return '/access';
      }
      if (open && (path == '/' || path == '/access')) {
        return '/home';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const WelcomePage()),
      GoRoute(path: '/access', builder: (context, state) => const AccessPage()),
      GoRoute(path: '/about', builder: (context, state) => const AboutPage()),
      GoRoute(
        path: '/home',
        builder: (context, state) => const FinanceHomePage(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      appBar: AppBar(title: const Text('Page unavailable')),
      body: Center(
        child: FilledButton(
          onPressed: () => context.go('/'),
          child: const Text('Return to FamilyVault'),
        ),
      ),
    ),
  );
  ref.onDispose(router.dispose);
  ref.onDispose(refresh.dispose);
  return router;
});
