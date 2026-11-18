import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../core/security/vault_lifecycle.dart';
import '../features/foundation/foundation_pages.dart';
import 'vault_providers.dart';

class PrivacyBoundary extends ConsumerStatefulWidget {
  const PrivacyBoundary({required this.child, super.key});
  final Widget child;
  @override
  ConsumerState<PrivacyBoundary> createState() => _PrivacyBoundaryState();
}

class _PrivacyBoundaryState extends ConsumerState<PrivacyBoundary>
    with WidgetsBindingObserver {
  bool _obscured = false;
  Timer? _idle;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    ref.listenManual(vaultProvider, (_, next) {
      _idle?.cancel();
      if (next.phase == VaultPhase.open) {
        _touch();
      }
    }, fireImmediately: true);
  }

  void _touch() {
    _idle?.cancel();
    if (ref.read(vaultProvider).phase == VaultPhase.open) {
      _idle = Timer(
        const Duration(minutes: 5),
        () => unawaited(ref.read(vaultProvider.notifier).lock()),
      );
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final obscure = state != AppLifecycleState.resumed;
    if (_obscured != obscure && mounted) {
      setState(() => _obscured = obscure);
    }
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _idle?.cancel();
      unawaited(ref.read(vaultProvider.notifier).lock());
    }
  }

  @override
  void dispose() {
    _idle?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = ref.watch(vaultProvider);
    final locked = status.hasVault && status.phase != VaultPhase.open;
    return Listener(
      onPointerDown: (_) => _touch(),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Offstage(offstage: locked, child: widget.child),
          if (locked)
            Positioned.fill(
              child: Navigator(
                onGenerateRoute: (_) =>
                    MaterialPageRoute<void>(builder: (_) => const AccessPage()),
              ),
            ),
          if (_obscured)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0xFF102E2B),
                child: Center(
                  child: Icon(
                    Icons.shield_outlined,
                    color: Colors.white,
                    size: 64,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
