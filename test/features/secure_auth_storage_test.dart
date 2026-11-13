import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:familyvault/core/security/secure_store.dart';
import 'package:familyvault/features/auth/secure_auth_storage.dart';

final class _MemorySecureStore implements SecureStore {
  final values = <String, String>{};
  bool unavailable = false;

  void _checkAvailable() {
    if (unavailable) throw StateError('Synthetic secure storage unavailable');
  }

  @override
  Future<String?> read(String key) async {
    _checkAvailable();
    return values[key];
  }

  @override
  Future<void> write(String key, String value) async {
    _checkAvailable();
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _checkAvailable();
    values.remove(key);
  }
}

void main() {
  test(
    'sessions and PKCE use isolated secure namespaces and exact deletion',
    () async {
      final store = _MemorySecureStore();
      final first = secureAuthOptions(
        store: store,
        projectNamespace: 'synthetic_a',
      );
      final second = secureAuthOptions(
        store: store,
        projectNamespace: 'synthetic_b',
      );
      expect(first.authFlowType, AuthFlowType.pkce);
      expect(first.detectSessionInUri, isFalse);
      await first.localStorage!.initialize();
      await first.localStorage!.persistSession('synthetic-session');
      await first.pkceAsyncStorage!.setItem(
        key: 'probe',
        value: 'synthetic-verifier',
      );
      expect(await second.localStorage!.hasAccessToken(), isFalse);
      expect(await first.localStorage!.accessToken(), 'synthetic-session');
      await first.localStorage!.removePersistedSession();
      expect(await first.localStorage!.hasAccessToken(), isFalse);
      expect(
        await first.pkceAsyncStorage!.getItem(key: 'probe'),
        'synthetic-verifier',
      );
      await first.pkceAsyncStorage!.removeItem(key: 'probe');
      expect(store.values, isEmpty);
    },
  );

  test('unavailable secure storage fails without fallback or reset', () async {
    final store = _MemorySecureStore();
    final options = secureAuthOptions(
      store: store,
      projectNamespace: 'synthetic',
    );
    await options.localStorage!.persistSession('synthetic-session');
    store.unavailable = true;
    await expectLater(options.localStorage!.initialize(), throwsStateError);
    await expectLater(options.localStorage!.accessToken(), throwsStateError);
    await expectLater(
      options.localStorage!.persistSession('replacement'),
      throwsStateError,
    );
    expect(store.values.values.single, 'synthetic-session');
  });
}
