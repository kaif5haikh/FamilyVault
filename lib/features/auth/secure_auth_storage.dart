import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/security/secure_store.dart';

/// Secure token and PKCE storage for the configured Supabase client.
/// There is no implicit initialization or fallback to preferences.
FlutterAuthClientOptions secureAuthOptions({
  required SecureStore store,
  required String projectNamespace,
}) {
  if (!RegExp(r'^[a-z0-9_-]{1,64}$').hasMatch(projectNamespace)) {
    throw ArgumentError('Invalid authentication storage namespace');
  }
  final prefix = 'familyvault.auth.$projectNamespace.v1';
  return FlutterAuthClientOptions(
    authFlowType: AuthFlowType.pkce,
    detectSessionInUri: false,
    localStorage: SecureSessionStorage(store, '$prefix.session'),
    pkceAsyncStorage: SecurePkceStorage(store, '$prefix.pkce.'),
  );
}

final class SecureSessionStorage extends LocalStorage {
  const SecureSessionStorage(this._store, this._key);

  final SecureStore _store;
  final String _key;

  @override
  Future<void> initialize() async {
    // Probe storage now so an inaccessible store fails before restoring a session.
    await _store.read(_key);
  }

  @override
  Future<bool> hasAccessToken() async => await _store.read(_key) != null;

  @override
  Future<String?> accessToken() => _store.read(_key);

  @override
  Future<void> persistSession(String persistSessionString) =>
      _store.write(_key, persistSessionString);

  @override
  Future<void> removePersistedSession() => _store.delete(_key);
}

/// Supabase's PKCE verifier uses a separate persistence interface from sessions.
final class SecurePkceStorage extends GotrueAsyncStorage {
  SecurePkceStorage(this._store, this._prefix);

  final SecureStore _store;
  final String _prefix;

  @override
  Future<String?> getItem({required String key}) => _store.read('$_prefix$key');

  @override
  Future<void> setItem({required String key, required String value}) =>
      _store.write('$_prefix$key', value);

  @override
  Future<void> removeItem({required String key}) =>
      _store.delete('$_prefix$key');
}
