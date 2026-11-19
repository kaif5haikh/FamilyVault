import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hash;
import 'package:cryptography/cryptography.dart';
import 'package:uuid/uuid.dart';

import '../../core/errors/app_failure.dart';
import '../../core/security/sealed_file.dart';
import '../../core/security/vault_keys.dart';
import '../../core/sync/canonical_json.dart';

/// The caller obtains these keys for an approved device from the family roster.
final class DocumentDeviceKeys {
  const DocumentDeviceKeys({
    required this.id,
    required this.signing,
    required this.exchange,
  });
  final String id, signing, exchange;

  factory DocumentDeviceKeys.fromJson(Map<String, Object?> row) {
    const invalid = AppFailure(
      FailureCode.integrity,
      'Family device keys could not be verified.',
    );
    final id = row['id'],
        signing = row['signing_public'],
        exchange = row['exchange_public'];
    if (id is! String ||
        !Uuid.isValidUUID(fromString: id) ||
        signing is! String ||
        exchange is! String) {
      throw invalid;
    }
    final fingerprint = hash.sha256.convert([
      ...DocumentKeyGrant._hexBytes(signing, 32),
      ...DocumentKeyGrant._hexBytes(exchange, 32),
    ]).toString();
    if (row['fingerprint'] != fingerprint) throw invalid;
    return DocumentDeviceKeys(id: id, signing: signing, exchange: exchange);
  }
}

/// One encrypted content key for one recipient and one immutable file version.
final class DocumentKeyGrant {
  const DocumentKeyGrant._(this.fields);
  factory DocumentKeyGrant.fromJson(Map<String, Object?> value) =>
      DocumentKeyGrant._(Map.unmodifiable(value));

  final Map<String, Object?> fields;
  static final _signing = Ed25519();
  static final _exchange = X25519();
  static final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
  static const _invalid = AppFailure(
    FailureCode.integrity,
    'This device could not verify the shared document key.',
  );

  static Future<DocumentKeyGrant> create({
    required String familyId,
    required String documentId,
    required String versionId,
    required String senderId,
    required VaultKeys senderKeys,
    required DocumentDeviceKeys recipient,
    required SecretKey contentKey,
  }) async {
    if (senderKeys.destroyed) throw _invalid;
    final signer = await _signing.newKeyPairFromSeed(senderKeys.signingSeed);
    final ephemeral = await _exchange.newKeyPair();
    try {
      final ephemeralPublic = await ephemeral.extractPublicKey();
      final context = _context(
        familyId,
        documentId,
        versionId,
        senderId,
        recipient,
        _hex(ephemeralPublic.bytes),
      );
      final key = await _derive(ephemeral, recipient.exchange, context);
      try {
        final content = await contentKey.extractBytes();
        if (content.length != 32) throw _invalid;
        final box = await SealedFile.algorithm.encrypt(
          content,
          secretKey: key,
          aad: context,
        );
        final wrapped = base64Encode(box.concatenation());
        final signature = await _signing.sign(
          _signed(context, wrapped),
          keyPair: signer,
        );
        return DocumentKeyGrant.fromJson({
          'version': 1,
          'sender_device_id': senderId,
          'recipient_device_id': recipient.id,
          'ephemeral_public': _hex(ephemeralPublic.bytes),
          'wrapped_key': wrapped,
          'signature': _hex(signature.bytes),
        });
      } finally {
        key.destroy();
      }
    } finally {
      ephemeral.destroy();
      signer.destroy();
    }
  }

  Future<SecretKeyData> open({
    required String familyId,
    required String documentId,
    required String versionId,
    required DocumentDeviceKeys sender,
    required String recipientId,
    required VaultKeys recipientKeys,
  }) async {
    if (recipientKeys.destroyed ||
        fields['version'] != 1 ||
        fields.length != 6 ||
        fields['sender_device_id'] != sender.id ||
        fields['recipient_device_id'] != recipientId) {
      throw _invalid;
    }
    final recipient = await _exchange.newKeyPairFromSeed(
      recipientKeys.exchangeSeed,
    );
    try {
      final publicKey = await recipient.extractPublicKey();
      final ephemeral = fields['ephemeral_public']! as String;
      final wrap = fields['wrapped_key']! as String;
      if (wrap.length != 96) throw _invalid;
      final context = _context(
        familyId,
        documentId,
        versionId,
        sender.id,
        DocumentDeviceKeys(
          id: recipientId,
          signing: '',
          exchange: _hex(publicKey.bytes),
        ),
        ephemeral,
      );
      final signature = Signature(
        _hexBytes(fields['signature']! as String, 64),
        publicKey: SimplePublicKey(
          _hexBytes(sender.signing, 32),
          type: KeyPairType.ed25519,
        ),
      );
      if (!await _signing.verify(
        _signed(context, wrap),
        signature: signature,
      )) {
        throw _invalid;
      }
      final key = await _derive(recipient, ephemeral, context);
      try {
        final box = SecretBox.fromConcatenation(
          base64Decode(wrap),
          nonceLength: 24,
          macLength: 16,
        );
        final clear = await SealedFile.algorithm.decrypt(
          box,
          secretKey: key,
          aad: context,
        );
        if (clear.length != 32) throw _invalid;
        return SecretKeyData(clear, overwriteWhenDestroyed: true);
      } finally {
        key.destroy();
      }
    } catch (_) {
      throw _invalid;
    } finally {
      recipient.destroy();
    }
  }

  static Future<SecretKey> _derive(
    SimpleKeyPair own,
    String remote,
    List<int> context,
  ) async {
    final key = await _exchange.sharedSecretKey(
      keyPair: own,
      remotePublicKey: SimplePublicKey(
        _hexBytes(remote, 32),
        type: KeyPairType.x25519,
      ),
    );
    try {
      if ((await key.extractBytes()).every((byte) => byte == 0)) throw _invalid;
      return await _hkdf.deriveKey(
        secretKey: key,
        nonce: hash.sha256.convert(context).bytes,
        info: const [1],
      );
    } finally {
      key.destroy();
    }
  }

  static List<int> _context(
    String family,
    String doc,
    String version,
    String sender,
    DocumentDeviceKeys recipient,
    String ephemeral,
  ) => utf8.encode(
    canonicalJson([
      'FamilyVault document key grant v1',
      family,
      doc,
      version,
      sender,
      recipient.id,
      recipient.exchange,
      ephemeral,
    ]),
  );

  static List<int> _signed(List<int> context, String wrapped) => [
    ...context,
    ...ascii.encode(wrapped),
  ];

  static String _hex(List<int> bytes) =>
      bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

  static Uint8List _hexBytes(String value, int length) {
    if (value.length != length * 2 || !RegExp(r'^[0-9a-f]+$').hasMatch(value)) {
      throw _invalid;
    }
    return Uint8List.fromList([
      for (var i = 0; i < value.length; i += 2)
        int.parse(value.substring(i, i + 2), radix: 16),
    ]);
  }

  @override
  String toString() => 'DocumentKeyGrant([redacted])';
}
