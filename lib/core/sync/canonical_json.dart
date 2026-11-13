import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../errors/app_failure.dart';

String canonicalJson(Object? value) => jsonEncode(_canonical(value));
Object? _canonical(Object? value) {
  if (value == null || value is String || value is bool || value is int) {
    return value;
  }
  if (value is List<Object?>) return value.map(_canonical).toList();
  if (value is Map<String, Object?>) {
    final keys = value.keys.toList()..sort();
    return {for (final key in keys) key: _canonical(value[key])};
  }
  throw const AppFailure(
    FailureCode.validation,
    'Invalid synchronized data type.',
  );
}

String payloadDigest(String canonical) =>
    sha256.convert(utf8.encode(canonical)).toString();
