import 'dart:convert';

import 'package:crypto/crypto.dart' as hash;
import 'package:cryptography/cryptography.dart';
import 'package:uuid/uuid.dart';

import '../../core/errors/app_failure.dart';
import '../../core/security/device_gate.dart';
import '../../core/security/secure_store.dart';
import '../../core/security/vault_identity.dart';
import '../../core/security/vault_keys.dart';
import 'cloud_access_gateway.dart';

final class CloudDevice {
  CloudDevice(this.identity, this.keys);
  final VaultIdentity identity;
  final VaultKeys keys;

  DeviceProof get proof {
    if (keys.destroyed) {
      throw const AppFailure(
        FailureCode.locked,
        'Unlock the device vault before continuing.',
      );
    }
    // Use a separate derivation context so no private signing bytes leave the device.
    final bytes = utf8.encode(
      'FamilyVault device proof v1:${identity.deviceId}',
    );
    return DeviceProof(
      identity.deviceId,
      hash.Hmac(hash.sha256, keys.signingSeed).convert(bytes).toString(),
    );
  }

  Future<({String signing, String exchange, String fingerprint})>
  publicIdentity() async {
    if (keys.destroyed) {
      throw const AppFailure(FailureCode.locked, 'Device keys are locked.');
    }
    final signing = await Ed25519().newKeyPairFromSeed(keys.signingSeed);
    final exchange = await X25519().newKeyPairFromSeed(keys.exchangeSeed);
    try {
      final signingKey = (await signing.extractPublicKey()).bytes;
      final exchangeKey = (await exchange.extractPublicKey()).bytes;
      String hex(List<int> bytes) =>
          bytes.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
      return (
        signing: hex(signingKey),
        exchange: hex(exchangeKey),
        fingerprint: hash.sha256.convert([
          ...signingKey,
          ...exchangeKey,
        ]).toString(),
      );
    } finally {
      signing.destroy();
      exchange.destroy();
    }
  }

  @override
  String toString() => 'CloudDevice([redacted])';
}

final class EnrollmentResult {
  const EnrollmentResult({
    required this.state,
    required this.deviceId,
    required this.fingerprint,
    this.workspace,
  });
  final String state, deviceId, fingerprint;
  final CloudJson? workspace;
  @override
  String toString() => 'EnrollmentResult($state)';
}

/// Persists one protected key set per Supabase project, account and family.
/// OS verification precedes reading or allocating cloud keys on this device.
final class CloudDeviceRegistration {
  CloudDeviceRegistration({
    required this.store,
    required this.gate,
    required this.gateway,
    required this.namespace,
  });
  final SecureStore store;
  final DeviceGate gate;
  final CloudAccessGateway gateway;
  final String namespace;
  static const _uuid = Uuid();
  static const _accessDenied = AppFailure(
    FailureCode.unauthorized,
    'This family membership is unavailable for your account.',
  );
  static const _invalid = AppFailure(
    FailureCode.integrity,
    'The device registration could not be verified. Existing keys have been preserved.',
  );
  bool _busy = false;

  String profileKey(String userId, String familyId) {
    if (!RegExp(r'^[a-z0-9_-]{1,64}$').hasMatch(namespace) ||
        ![userId, familyId].every((id) => Uuid.isValidUUID(fromString: id))) {
      throw _invalid;
    }
    return 'familyvault.cloud.$namespace.$userId.$familyId.v1';
  }

  Future<EnrollmentResult> enroll({
    required String familyId,
    required String memberId,
    required String name,
  }) => withVerifiedDevice(
    familyId,
    memberId,
    create: true,
    action: (device) async {
      final identity = await device.publicIdentity();
      final state = await gateway.requestDevice(
        familyId: familyId,
        device: device.proof,
        name: name,
        signingPublic: identity.signing,
        exchangePublic: identity.exchange,
      );
      if (!['pending', 'enrolled', 'revoked'].contains(state)) {
        throw _invalid;
      }
      if (state != 'enrolled') {
        return EnrollmentResult(
          state: state,
          deviceId: device.identity.deviceId,
          fingerprint: identity.fingerprint,
        );
      }
      await gateway.bind(device.proof);
      final workspace = await gateway.workspace(device.proof);
      verifyWorkspace(workspace, device.identity);
      return EnrollmentResult(
        state: state,
        deviceId: device.identity.deviceId,
        fingerprint: identity.fingerprint,
        workspace: workspace,
      );
    },
  );

  Future<T> withVerifiedDevice<T>(
    String familyId,
    String memberId, {
    bool create = false,
    required Future<T> Function(CloudDevice device) action,
  }) async {
    if (_busy) {
      throw const AppFailure(
        FailureCode.conflict,
        'Wait for the current device check to finish.',
      );
    }
    final userId = gateway.userId;
    if (userId == null || !Uuid.isValidUUID(fromString: memberId)) {
      throw _accessDenied;
    }
    final key = profileKey(userId, familyId);
    _busy = true;
    VaultKeys? keys;
    try {
      if (!await gate.authenticate()) {
        throw const AppFailure(
          FailureCode.locked,
          'Device verification was cancelled.',
        );
      }
      if (gateway.userId != userId) {
        throw _accessDenied;
      }
      final stored = await store.read(key);
      final VaultIdentity identity;
      if (stored == null) {
        if (!create) {
          throw _accessDenied;
        }
        keys = VaultKeys.generate();
        identity = VaultIdentity(
          familyId: familyId,
          memberId: memberId,
          deviceId: _uuid.v4(),
          mode: 'cloud',
        );
        // Write before calling the server. Interrupted requests reuse the same keys and ID.
        await store.write(
          key,
          jsonEncode({'identity': identity.toJson(), 'keys': keys.toJson()}),
        );
      } else {
        final json = jsonDecode(stored) as CloudJson;
        identity = VaultIdentity.fromJson(json['identity']! as CloudJson);
        if (!identity.isCloud ||
            identity.familyId != familyId ||
            identity.memberId != memberId ||
            !Uuid.isValidUUID(fromString: identity.deviceId)) {
          throw _invalid;
        }
        keys = VaultKeys.fromJson(json['keys']! as CloudJson);
      }
      if (gateway.userId != userId) {
        throw _accessDenied;
      }
      final result = await action(CloudDevice(identity, keys));
      if (gateway.userId != userId) {
        throw _accessDenied;
      }
      return result;
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw _invalid;
    } finally {
      keys?.destroy();
      _busy = false;
    }
  }

  static void verifyWorkspace(CloudJson json, VaultIdentity identity) {
    if (json['family_id'] != identity.familyId ||
        json['device_id'] != identity.deviceId ||
        json['member_id'] != identity.memberId ||
        !['member', 'administrator'].contains(json['role']) ||
        json['server_time_us'] is! int ||
        json['family'] is! CloudJson ||
        json['members'] is! List<Object?> ||
        json['devices'] is! List<Object?>) {
      throw _invalid;
    }
  }
}
