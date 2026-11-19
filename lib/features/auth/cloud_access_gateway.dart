import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../core/errors/app_failure.dart';
import '../../core/database/app_database.dart';
import '../../core/sync/sync_protocol.dart';
import '../document_vault/document_key_grant.dart';
import '../document_vault/document_transport.dart';

part 'supabase_document_transport.dart';

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
  String? get sessionId;
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
  Future<List<CloudJson>> chart(DeviceProof device);
  SyncTransport syncTransport(DeviceProof device);
  DocumentTransport? documentTransport(DeviceProof device);
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
  String? get sessionId {
    final session = _client.auth.currentSession;
    if (session == null) return null;
    try {
      final jwt = session.accessToken.split('.');
      if (jwt.length != 3) return null;
      final claims = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(jwt[1]))),
      ) as CloudJson;
      final id = claims['session_id'];
      if (claims['sub'] == session.user.id &&
          id is String &&
          Uuid.isValidUUID(fromString: id)) {
        return id;
      }
    } catch (_) {
      // The local identifier only scopes a previous server grant.
    }
    return null;
  }

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
  Future<List<CloudJson>> chart(DeviceProof device) async =>
      cloudRows(await _rpc<Object?>('sync_chart', device.parameters));

  @override
  SyncTransport syncTransport(DeviceProof device) =>
      _SupabaseSync(this, device);

  @override
  DocumentTransport documentTransport(DeviceProof device) =>
      _SupabaseDocuments(this, device);

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
    AppFailure? revocationFailure;
    try {
      if (device != null) {
        await _command('sign_out_device', device.parameters);
      }
    } on AppFailure catch (e) {
      if (e.code != FailureCode.unauthorized) {
        revocationFailure = e;
      }
    }
    await _request(() => _client.auth.signOut(scope: SignOutScope.local));
    if (revocationFailure != null) throw revocationFailure;
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

  Future<T> _request<T>(
    Future<T> Function() action, {
    Duration timeout = const Duration(seconds: 20),
  }) async {
    try {
      return await action().timeout(timeout);
    } on AppFailure {
      rethrow;
    } on AuthRetryableFetchException {
      throw _network;
    } on AuthException {
      throw _denied;
    } on PostgrestException catch (e) {
      final code = e.code ?? '';
      if (['42501', 'PGRST301', 'PGRST303', '401', '403'].contains(code)) {
        throw _denied;
      }
      if (code == 'PT409') {
        throw const AppFailure(
          FailureCode.conflict,
          'Shared records changed. Review the latest family records.',
        );
      }
      if (code == 'PT424') {
        throw const AppFailure(
          FailureCode.network,
          'Waiting for the related family transaction to sync.',
        );
      }
      if (code.startsWith('22') || code.startsWith('23')) {
        throw const AppFailure(
          FailureCode.validation,
          'Check the details or refresh the latest family access status.',
        );
      }
      if ([
        'PGRST000',
        'PGRST001',
        'PGRST002',
        '408',
        '429',
        '502',
        '503',
        '504',
      ].contains(code)) {
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

final class _SupabaseSync implements SyncTransport {
  const _SupabaseSync(this.gateway, this.device);
  final SupabaseAccessGateway gateway;
  final DeviceProof device;

  @override
  Future<SyncReceipt> push(SyncEnvelope envelope) async => SyncReceipt.fromJson(
    await gateway._rpc<CloudJson>('sync_push', {
      ...device.parameters,
      'p_envelope': envelope.raw,
    }),
  );

  @override
  Future<SyncPage> pull(int after) async => SyncPage.fromJson(
    await gateway._rpc<CloudJson>('sync_pull', {
      ...device.parameters,
      'p_after': after,
    }),
  );
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
