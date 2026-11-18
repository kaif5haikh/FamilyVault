import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/errors/app_failure.dart';

typedef CloudJson = Map<String, Object?>;

final class DeviceProof {
  const DeviceProof(this.deviceId, this.proof);
  final String deviceId, proof;
  CloudJson get parameters => {'p_device': deviceId, 'p_proof': proof};
  @override
  String toString() => 'DeviceProof([redacted])';
}

abstract interface class CloudAccessGateway {
  String? get userId;
  Stream<String?> get identityChanges;
  Future<void> signIn(String email, String password);
  Future<CloudJson> listAccess();
  Future<String> accept(String invitationId);
  Future<String> requestDevice({
    required String familyId,
    required DeviceProof device,
    required String name,
    required String signingPublic,
    required String exchangePublic,
  });
  Future<void> bind(DeviceProof device);
  Future<CloudJson> workspace(DeviceProof device);
  Future<CloudJson> administratorView(DeviceProof device);
  Future<void> invite(
    DeviceProof device,
    String email,
    String name,
    String relationship,
  );
  Future<void> approve(
    DeviceProof device,
    String candidate,
    String fingerprint,
  );
  Future<void> revoke(DeviceProof device, String kind, String target);
  Future<void> signOut(DeviceProof? device);
  Future<List<({String id, String name})>> factors();
  Future<({String factorId, String secret})> enrollTotp();
  Future<void> verifyTotp(String factorId, String code);
}

final class SupabaseAccessGateway implements CloudAccessGateway {
  const SupabaseAccessGateway(this._client);
  final SupabaseClient _client;
  @override
  String? get userId => _client.auth.currentUser?.id;

  @override
  Stream<String?> get identityChanges => _client.auth.onAuthStateChange
      .map((state) => state.session?.user.id)
      .distinct();

  @override
  Future<void> signIn(String email, String password) => _request(() async {
    final result = await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
    if (result.session == null || result.user == null) {
      throw _denied;
    }
  });

  @override
  Future<CloudJson> listAccess() => _rpc<CloudJson>('list_access', const {});

  @override
  Future<String> accept(String invitationId) =>
      _rpc<String>('accept_invite', {'p_invite': invitationId});

  @override
  Future<String> requestDevice({
    required String familyId,
    required DeviceProof device,
    required String name,
    required String signingPublic,
    required String exchangePublic,
  }) => _rpc<String>('request_device', {
    ...device.parameters,
    'p_family': familyId,
    'p_name': name,
    'p_signing_public': signingPublic,
    'p_exchange_public': exchangePublic,
  });

  @override
  Future<void> bind(DeviceProof device) =>
      _command('bind_device', device.parameters);

  @override
  Future<CloudJson> workspace(DeviceProof device) =>
      _rpc<CloudJson>('workspace', device.parameters);

  @override
  Future<CloudJson> administratorView(DeviceProof device) =>
      _rpc<CloudJson>('admin_access', device.parameters);

  @override
  Future<void> invite(
    DeviceProof device,
    String email,
    String name,
    String relationship,
  ) => _command('invite_member', {
    ...device.parameters,
    'p_email': email.trim(),
    'p_name': name.trim(),
    'p_relationship': relationship.trim(),
  });

  @override
  Future<void> approve(
    DeviceProof device,
    String candidate,
    String fingerprint,
  ) => _command('approve_device', {
    ...device.parameters,
    'p_candidate': candidate,
    'p_fingerprint': fingerprint.trim().toLowerCase(),
  });

  @override
  Future<void> revoke(DeviceProof device, String kind, String target) =>
      _command('revoke_access', {
        ...device.parameters,
        'p_kind': kind,
        'p_target': target,
      });

  @override
  Future<void> signOut(DeviceProof? device) async {
    try {
      if (device != null) {
        await _command('sign_out_device', device.parameters);
      }
    } on AppFailure catch (e) {
      if (e.code != FailureCode.unauthorized) {
        rethrow;
      }
    }
    await _request(() => _client.auth.signOut(scope: SignOutScope.local));
  }

  @override
  Future<List<({String id, String name})>> factors() => _request(() async {
    final factors = await _client.auth.mfa.listFactors();
    return factors.totp
        .map((f) => (id: f.id, name: f.friendlyName ?? 'Authenticator'))
        .toList();
  });

  @override
  Future<({String factorId, String secret})> enrollTotp() => _request(() async {
    final result = await _client.auth.mfa.enroll(factorType: FactorType.totp);
    final setup = result.totp;
    if (setup == null) {
      throw _invalidResponse;
    }
    return (factorId: result.id, secret: setup.secret);
  });

  @override
  Future<void> verifyTotp(String factorId, String code) => _request(() async {
    if (!RegExp(r'^[0-9]{6}$').hasMatch(code)) {
      throw const AppFailure(
        FailureCode.validation,
        'Enter the six-digit authenticator code.',
      );
    }
    await _client.auth.mfa.challengeAndVerify(factorId: factorId, code: code);
  });

  Future<void> _command(String name, CloudJson arguments) async {
    await _rpc<Object?>(name, arguments);
  }

  Future<T> _rpc<T>(String name, CloudJson arguments) => _request(() async {
    final Object? response = await _client.rpc<Object?>(
      'fv_$name',
      params: arguments,
    );
    return response as T;
  });

  static const _denied = AppFailure(
    FailureCode.unauthorized,
    'Access could not be verified. Check your account and device approval.',
  );
  static const _invalidResponse = AppFailure(
    FailureCode.integrity,
    'The family service returned an invalid response.',
  );
  static const _network = AppFailure(
    FailureCode.network,
    'The family service is unavailable. Check your connection and try again.',
  );

  Future<T> _request<T>(Future<T> Function() action) async {
    try {
      return await action().timeout(const Duration(seconds: 20));
    } on AppFailure {
      rethrow;
    } on AuthRetryableFetchException {
      throw _network;
    } on AuthException {
      throw _denied;
    } on PostgrestException catch (e) {
      if (e.code == '42501' || e.code == 'PGRST301') {
        throw _denied;
      }
      if (e.code == '22023' || e.code == '23505') {
        throw const AppFailure(
          FailureCode.validation,
          'Check the details or refresh the latest family access status.',
        );
      }
      if (['PGRST000', 'PGRST001', 'PGRST002'].contains(e.code)) {
        throw _network;
      }
      throw _invalidResponse;
    } on SocketException {
      throw _network;
    } on TimeoutException {
      throw _network;
    } on TlsException {
      throw _invalidResponse;
    } catch (_) {
      throw _invalidResponse;
    }
  }
}

List<CloudJson> cloudRows(Object? value) {
  if (value is! List<Object?> || value.any((v) => v is! CloudJson)) {
    throw const AppFailure(
      FailureCode.integrity,
      'Family access information could not be verified.',
    );
  }
  return value.cast<CloudJson>();
}

String cloudText(CloudJson row, String key) {
  final value = row[key];
  if (value is! String) {
    throw const AppFailure(
      FailureCode.integrity,
      'Family access information could not be verified.',
    );
  }
  return value;
}

String groupedFingerprint(String fingerprint) =>
    RegExp(r'.{1,8}').allMatches(fingerprint).map((m) => m[0]!).join(' ');
