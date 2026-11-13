final class VaultIdentity {
  const VaultIdentity({
    required this.familyId,
    required this.memberId,
    required this.deviceId,
    required this.mode,
  });
  final String familyId;
  final String memberId;
  final String deviceId;
  final String mode;
  bool get isCloud => mode == 'cloud';
  Map<String, Object?> toJson() => {
    'family_id': familyId,
    'member_id': memberId,
    'device_id': deviceId,
    'mode': mode,
  };
  factory VaultIdentity.fromJson(Map<String, Object?> json) => VaultIdentity(
    familyId: json['family_id']! as String,
    memberId: json['member_id']! as String,
    deviceId: json['device_id']! as String,
    mode: json['mode']! as String,
  );
  @override
  String toString() => 'VaultIdentity([redacted], $mode)';
}
