import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/appearance.dart';
import '../../app/vault_providers.dart';
import '../../core/errors/app_failure.dart';
import '../../core/security/secure_store.dart';
import '../../core/security/vault_identity.dart';
import '../../core/security/vault_lifecycle.dart';

const _unavailable = AppFailure(
  FailureCode.configuration,
  'Allow FamilyVault notifications in your device settings to use reminders.',
);
const _failed = AppFailure(
  FailureCode.storage,
  'Could not update document reminders.',
);

/// Timestamps only. Titles, categories and document identifiers stay in the vault.
List<int> documentReminderTimes(Iterable<String?> expiries, DateTime now) {
  final times = <int>{};
  for (final text in expiries.nonNulls) {
    final expiry = DateTime.tryParse(text);
    if (expiry == null || expiry.toIso8601String().split('T').first != text) {
      continue;
    }
    for (final lead in [30, 0]) {
      final day = DateTime(expiry.year, expiry.month, expiry.day - lead, 9);
      if (day.isAfter(now)) times.add(day.millisecondsSinceEpoch);
    }
  }
  return (times.toList()..sort()).take(32).toList(growable: false);
}

abstract interface class DocumentReminderPlatform {
  bool get supported;
  Future<bool> request();
  Future<bool> allowed();
  Future<void> replace(List<int> times, {required String language});
}

final class NativeDocumentReminders implements DocumentReminderPlatform {
  const NativeDocumentReminders();
  static const _channel = MethodChannel('app.familyvault/document-reminders');

  @override
  bool get supported => Platform.isAndroid || Platform.isIOS;

  @override
  Future<bool> request() async => await _call<bool>('request') ?? false;

  @override
  Future<bool> allowed() async => await _call<bool>('allowed') ?? false;

  @override
  Future<void> replace(List<int> times, {required String language}) =>
      _call<void>('replace', {'times': times, 'language': language});

  Future<T?> _call<T>(String method, [Object? arguments]) async {
    if (!supported) return null;
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } catch (_) {
      throw _failed;
    }
  }
}

final documentReminderServiceProvider = Provider<DocumentReminderService>(
  (ref) => DocumentReminderService(
    ref.watch(secureStoreProvider),
    const NativeDocumentReminders(),
  ),
);
final documentReminderEnabledProvider = FutureProvider.autoDispose
    .family<bool, VaultIdentity>(
      (ref, identity) =>
          ref.watch(documentReminderServiceProvider).enabled(identity),
    );
final documentReminderPermissionProvider = FutureProvider.autoDispose<bool>(
  (ref) => ref.watch(documentReminderServiceProvider).platform.allowed(),
);

final documentReminderMonitorProvider = Provider<void>((ref) {
  final service = ref.watch(documentReminderServiceProvider);
  if (!service.platform.supported) return;
  final status = ref.watch(vaultProvider);
  final session = status.session;
  if (session == null || session.closed) {
    if (status.failure?.code == FailureCode.unauthorized) {
      unawaited(service.clear().catchError((Object _) {}));
    }
    return;
  }
  final preference = ref.watch(
    documentReminderEnabledProvider(session.identity),
  );
  if (preference.asData?.value != true) {
    if (preference.asData?.value == false) {
      unawaited(service.clear().catchError((Object _) {}));
    }
    return;
  }
  final language = ref.watch(
    appearanceProvider.select((value) => value.locale.languageCode),
  );
  final subscription = session.documents.watch().listen(
    (rows) => unawaited(
      service
          .refresh(
            session,
            rows.map((row) => row.expiryOn).toList(),
            language: language,
          )
          .catchError((Object _) {}),
    ),
    onError: (Object _) {},
  );
  ref.onDispose(() => unawaited(subscription.cancel()));
});

final class DocumentReminderService {
  DocumentReminderService(
    this._store,
    this.platform, {
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final SecureStore _store;
  final DocumentReminderPlatform platform;
  final DateTime Function() _clock;
  Future<void> _updates = Future.value();
  List<int>? _applied;
  String? _appliedLanguage;

  String _scope(VaultIdentity i) =>
      'familyvault.document-reminders.${i.familyId}.${i.memberId}.${i.deviceId}';

  Future<bool> enabled(VaultIdentity identity) async {
    try {
      return await _store.read(_scope(identity)) == 'enabled';
    } catch (_) {
      throw _failed;
    }
  }

  Future<void> setEnabled(VaultIdentity identity, bool enable) async {
    if (enable && !await platform.request()) throw _unavailable;
    await _serialize(() async {
      if (enable) {
        await _store.write(_scope(identity), 'enabled');
      } else {
        await _store.delete(_scope(identity));
        await _replace(const []);
      }
    });
  }

  Future<void> refresh(
    VaultSession session,
    Iterable<String?> expiries, {
    String language = 'en',
  }) => _serialize(() async {
    if (session.closed || !await enabled(session.identity)) return;
    final allowed = await platform.allowed();
    if (session.closed) return;
    await _replace(
      allowed ? documentReminderTimes(expiries, _clock()) : const [],
      language: language,
    );
  });

  Future<void> clear() => _serialize(() => _replace(const []));

  Future<void> _replace(List<int> times, {String language = 'en'}) async {
    final selected = language == 'hi' ? 'hi' : 'en';
    if (listEquals(_applied, times) && _appliedLanguage == selected) return;
    await platform.replace(times, language: selected);
    _applied = times;
    _appliedLanguage = selected;
  }

  Future<void> _serialize(Future<void> Function() action) {
    final operation = _updates.then((_) => action()).onError<Object>((
      error,
      _,
    ) {
      if (error is AppFailure) throw error;
      throw _failed;
    });
    _updates = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }
}
