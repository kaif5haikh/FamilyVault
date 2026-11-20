import 'package:local_auth/local_auth.dart';

import '../errors/app_failure.dart';

abstract interface class DeviceGate {
  Future<bool> authenticate();
}

final class PlatformDeviceGate implements DeviceGate {
  PlatformDeviceGate({LocalAuthentication? authentication, this.reason})
    : _authentication = authentication ?? LocalAuthentication();
  final LocalAuthentication _authentication;
  final String Function()? reason;
  @override
  Future<bool> authenticate() async {
    try {
      if (!await _authentication.isDeviceSupported()) {
        throw const AppFailure(
          FailureCode.configuration,
          'Set up a screen lock or biometrics in device settings to protect your vault.',
        );
      }
      return await _authentication.authenticate(
        localizedReason: reason?.call() ?? 'Unlock your private FamilyVault',
        sensitiveTransaction: true,
        persistAcrossBackgrounding: false,
      );
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const AppFailure(
        FailureCode.locked,
        'Device verification could not be completed. Unlock your device and try again.',
      );
    }
  }
}
