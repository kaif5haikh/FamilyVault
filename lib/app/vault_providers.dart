import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../core/security/device_gate.dart';
import '../core/security/secure_store.dart';
import '../core/security/vault_lifecycle.dart';
import '../features/finance/data/ledger_repository.dart';

final secureStoreProvider = Provider<SecureStore>(
  (ref) => const PlatformSecureStore(),
);
final deviceGateProvider = Provider<DeviceGate>((ref) => PlatformDeviceGate());
final vaultLifecycleProvider = Provider<VaultLifecycle>((ref) {
  final lifecycle = VaultLifecycle(
    store: ref.watch(secureStoreProvider),
    gate: ref.watch(deviceGateProvider),
    root: getApplicationSupportDirectory,
  );
  ref.onDispose(() => unawaited(lifecycle.dispose()));
  return lifecycle;
});
final vaultProvider = NotifierProvider<VaultController, VaultStatus>(
  VaultController.new,
);

class VaultController extends Notifier<VaultStatus> {
  late VaultLifecycle _lifecycle;
  @override
  VaultStatus build() {
    _lifecycle = ref.watch(vaultLifecycleProvider);
    final sub = _lifecycle.changes.listen((value) => state = value);
    ref.onDispose(sub.cancel);
    unawaited(Future<void>.microtask(_lifecycle.initialize));
    return _lifecycle.status;
  }

  Future<void> createOffline(String familyName, String ownerName) =>
      _lifecycle.createOffline(familyName: familyName, ownerName: ownerName);
  Future<void> unlock() => _lifecycle.unlock();
  Future<void> lock() => _lifecycle.lock();
  Future<void> retry() => _lifecycle.initialize();
}

final financeProvider = StreamProvider.autoDispose<FinanceSnapshot>((ref) {
  final session = ref.watch(vaultProvider).session;
  if (session == null || session.closed) {
    return const Stream.empty();
  }
  return session.ledger.watch();
});
