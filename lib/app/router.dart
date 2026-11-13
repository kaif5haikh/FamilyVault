import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/foundation/foundation_pages.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const WelcomePage()),
      GoRoute(path: '/access', builder: (context, state) => const AccessPage()),
      GoRoute(path: '/about', builder: (context, state) => const AboutPage()),
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
  return router;
});
