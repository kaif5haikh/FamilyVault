import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Values and storage exceptions must never be written to application logs.
abstract interface class SecureStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

final class PlatformSecureStore implements SecureStore {
  const PlatformSecureStore({FlutterSecureStorage? storage})
    : _storage = storage ?? _defaultStorage;

  static const _defaultStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      storageNamespace: 'familyvault.v1',
      resetOnError: false,
      migrateOnAlgorithmChange: false,
    ),
    iOptions: IOSOptions(
      accountName: 'familyvault.v1',
      accessibility: KeychainAccessibility.passcode,
      synchronizable: false,
    ),
  );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
