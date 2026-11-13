import 'package:familyvault/core/security/device_gate.dart';
import 'package:familyvault/core/security/secure_store.dart';

final class MemorySecureStore implements SecureStore {
  final values = <String, String>{};
  bool unavailable = false;
  int writes = 0;
  int? failWrite;
  void _check() {
    if (unavailable) {
      throw StateError('Synthetic secure storage failure');
    }
  }

  @override
  Future<String?> read(String key) async {
    _check();
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    _check();
    writes++;
    if (writes == failWrite) {
      throw StateError('Synthetic interrupted catalog write');
    }
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _check();
    values.remove(key);
  }
}

final class FakeDeviceGate implements DeviceGate {
  bool allowed = true;
  int calls = 0;
  Future<bool> Function()? challenge;
  @override
  Future<bool> authenticate() async {
    calls++;
    return challenge == null ? allowed : challenge!();
  }
}
