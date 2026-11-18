import 'dart:convert';

import 'package:uuid/uuid.dart';

import '../../core/errors/app_failure.dart';
import '../../core/security/vault_identity.dart';
import '../../core/sync/canonical_json.dart';
import 'cloud_access_gateway.dart';
import 'cloud_device_registration.dart';

const cloudAccessExpired = AppFailure(
  FailureCode.unauthorized,
  'Connect to verify family access again.',
);

/// Stores a bounded local grant issued after live device authorization. A cached
/// Auth session alone never grants access to an unopened or revoked cache.
final class CloudCacheAccess {
  CloudCacheAccess(this.registration, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;
  final CloudDeviceRegistration registration;
  final DateTime Function() _clock;
  static const duration = Duration(hours: 12);
  static const refreshInterval = Duration(minutes: 5);

  String scope(String user, VaultIdentity identity) => payloadDigest(
    '${registration.profileKey(user, identity.familyId)}:${identity.deviceId}',
  );

  String _leaseKey(String user, VaultIdentity identity) =>
      'familyvault.access.${scope(user, identity)}.v1';

  String _selectionKey(String user) =>
      'familyvault.cloud.last.${registration.namespace}.$user.v1';

  Future<VaultIdentity?> last(String user) async {
    final raw = await registration.store.read(_selectionKey(user));
    if (raw == null) return null;
    try {
      final selection = VaultIdentity.fromJson(jsonDecode(raw) as CloudJson);
      if (selection.isCloud &&
          [
            selection.familyId,
            selection.memberId,
            selection.deviceId,
          ].every((id) => Uuid.isValidUUID(fromString: id))) {
        return selection;
      }
    } catch (_) {
      // Preserve the catalog and require live enrollment if it cannot be read.
    }
    throw cloudAccessExpired;
  }

  void requireSession(String user, String session) {
    final gateway = registration.gateway;
    if (gateway.userId != user || gateway.sessionId != session) {
      throw cloudAccessExpired;
    }
  }

  Future<void> confirm(
    String user,
    String session,
    VaultIdentity identity, {
    bool remember = false,
  }) async {
    requireSession(user, session);
    final key = _leaseKey(user, identity);
    final prior = await _readLease(key);
    final now = _clock().toUtc().microsecondsSinceEpoch;
    final issued = prior?['issued_at_us'];
    if (prior?['session_id'] != session ||
        issued is! int ||
        now < issued ||
        now - issued >= refreshInterval.inMicroseconds) {
      await registration.store.write(
        key,
        jsonEncode({
          'session_id': session,
          'issued_at_us': now,
          'seen_at_us': now,
        }),
      );
    }
    if (remember) {
      await registration.store.write(
        _selectionKey(user),
        jsonEncode(identity.toJson()),
      );
    }
    requireSession(user, session);
  }

  Future<void> allowOffline(
    String user,
    String session,
    VaultIdentity identity,
  ) async {
    try {
      requireSession(user, session);
      final key = _leaseKey(user, identity);
      final value = await _readLease(key);
      final issued = value?['issued_at_us'], seen = value?['seen_at_us'];
      final now = _clock().toUtc().microsecondsSinceEpoch;
      if (value?['session_id'] != session ||
          issued is! int ||
          seen is! int ||
          issued > seen ||
          seen > now ||
          now - issued >= duration.inMicroseconds) {
        throw cloudAccessExpired;
      }
      if (now - seen >= const Duration(minutes: 1).inMicroseconds) {
        await registration.store.write(
          key,
          jsonEncode({...value!, 'seen_at_us': now}),
        );
      }
      requireSession(user, session);
    } catch (_) {
      // The local clock and protected grant both need to be readable offline.
      throw cloudAccessExpired;
    }
  }

  Future<void> revoke(String user, VaultIdentity identity) =>
      registration.store.delete(_leaseKey(user, identity));

  Future<CloudJson?> _readLease(String key) async {
    final raw = await registration.store.read(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as CloudJson;
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }
}
