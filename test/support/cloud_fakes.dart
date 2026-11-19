import 'package:familyvault/core/errors/app_failure.dart';
import 'package:familyvault/features/auth/cloud_access_gateway.dart';
import 'package:familyvault/features/document_vault/document_transport.dart';

class EnrollmentGateway implements CloudAccessGateway {
  EnrollmentGateway({required this.userId, required this.memberId});
  @override
  String? userId;
  @override
  Stream<String?> get identityChanges => const Stream.empty();
  @override
  DocumentTransport? documentTransport(DeviceProof device) => null;
  final String memberId;
  String state = 'pending';
  String? family, responseFamily;
  bool interrupt = false;
  int requests = 0, bindings = 0, reads = 0;
  final received = <DeviceProof>[];

  @override
  Future<String> requestDevice({
    required String familyId,
    required DeviceProof device,
    required String name,
    required String signingPublic,
    required String exchangePublic,
  }) async {
    requests++;
    family = familyId;
    received.add(device);
    if (interrupt) {
      throw const AppFailure(FailureCode.network, 'Synthetic interruption');
    }
    assert(signingPublic.length == 64 && exchangePublic.length == 64);
    return state;
  }

  @override
  Future<void> bind(DeviceProof device) async {
    bindings++;
  }

  @override
  Future<CloudJson> workspace(DeviceProof device) async {
    reads++;
    return {
      'family_id': responseFamily ?? family,
      'device_id': device.deviceId,
      'member_id': memberId,
      'role': 'member',
      'server_time_us': 10,
      'family': <String, Object?>{},
      'members': <Object?>[],
      'devices': <Object?>[],
    };
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
