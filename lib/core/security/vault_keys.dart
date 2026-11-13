import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import '../errors/app_failure.dart';

/// Independent random keys. Never print/export without an authenticated envelope.
final class VaultKeys {
  VaultKeys._(
    this.database,
    this.documents,
    this.signingSeed,
    this.exchangeSeed,
  );
  factory VaultKeys.generate() {
    final random = Random.secure();
    Uint8List bytes() =>
        Uint8List.fromList(List.generate(32, (_) => random.nextInt(256)));
    return VaultKeys._(bytes(), bytes(), bytes(), bytes());
  }
  factory VaultKeys.fromJson(Map<String, Object?> value) {
    Uint8List decode(String name) {
      final encoded = value[name];
      if (encoded is! String) {
        throw _invalid;
      }
      final result = base64Decode(encoded);
      if (result.length != 32) {
        throw _invalid;
      }
      return result;
    }

    return VaultKeys._(
      decode('database'),
      decode('documents'),
      decode('signing'),
      decode('exchange'),
    );
  }
  static const _invalid = AppFailure(
    FailureCode.integrity,
    'Vault keys are unavailable. Restore an encrypted backup with its recovery key.',
  );
  final Uint8List database, documents, signingSeed, exchangeSeed;
  bool _destroyed = false;
  bool get destroyed => _destroyed;
  Map<String, Object?> toJson() {
    if (_destroyed) {
      throw _invalid;
    }
    return {
      'database': base64Encode(database),
      'documents': base64Encode(documents),
      'signing': base64Encode(signingSeed),
      'exchange': base64Encode(exchangeSeed),
    };
  }

  void destroy() {
    for (final key in [database, documents, signingSeed, exchangeSeed]) {
      key.fillRange(0, key.length, 0);
    }
    _destroyed = true;
  }

  @override
  String toString() => 'VaultKeys([redacted])';
}
