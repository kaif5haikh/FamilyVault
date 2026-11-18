import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hash;
import 'package:cryptography/cryptography.dart';

import '../errors/app_failure.dart';

/// Authenticated chunks with a file-specific 128-bit nonce prefix and a
/// big-endian 64-bit chunk counter. Use a fresh content key for each file.
final class SealedFile {
  static final algorithm = Xchacha20.poly1305Aead();
  static final _magic = ascii.encode('FVCHUNK1');
  static const _headerLength = 32;
  static const _tagLength = 16;
  static const chunkSize = 256 * 1024;
  static const invalid = AppFailure(
    FailureCode.integrity,
    'Encrypted file verification failed.',
  );

  static Uint8List randomBytes(int count) {
    final random = Random.secure();
    return Uint8List.fromList(List.generate(count, (_) => random.nextInt(256)));
  }

  static Uint8List _counter(int value) =>
      (ByteData(8)..setUint64(0, value)).buffer.asUint8List();

  static List<int> _nonce(List<int> header, int index) => [
    ...header.sublist(8, 24),
    ..._counter(index),
  ];

  static Uint8List _authenticate(
    List<int> context,
    List<int> header,
    int index,
  ) => Uint8List.fromList([...header, ..._counter(index), ...context]);

  static int byteLength(int clearLength) =>
      _headerLength +
      clearLength +
      ((clearLength + chunkSize - 1) ~/ chunkSize) * _tagLength;

  static Future<String> digest(File file) async =>
      (await hash.sha256.bind(file.openRead()).first).toString();

  /// Creates a new ciphertext file and flushes it before returning its digest.
  /// The caller publishes metadata only after this succeeds.
  static Future<String> encrypt({
    required File source,
    required File destination,
    required int clearLength,
    required SecretKey key,
    required List<int> context,
  }) async {
    if (clearLength < 1 || await source.length() != clearLength) throw invalid;
    final header = Uint8List.fromList([
      ..._magic,
      ...randomBytes(16),
      ..._counter(clearLength),
    ]);
    await destination.create(exclusive: true);
    try {
      final input = await source.open();
      try {
        final output = await destination.open(mode: FileMode.writeOnly);
        try {
          await output.writeFrom(header);
          var remaining = clearLength;
          for (var index = 0; remaining > 0; index++) {
            final count = min(chunkSize, remaining);
            final bytes = await input.read(count);
            try {
              if (bytes.length != count) throw invalid;
              final box = await algorithm.encrypt(
                bytes,
                secretKey: key,
                nonce: _nonce(header, index),
                aad: _authenticate(context, header, index),
              );
              await output.writeFrom(box.cipherText);
              await output.writeFrom(box.mac.bytes);
            } finally {
              bytes.fillRange(0, bytes.length, 0);
            }
            remaining -= count;
          }
          if (await input.readByte() != -1) throw invalid;
          await output.flush();
        } finally {
          await output.close();
        }
      } finally {
        await input.close();
      }
      return await digest(destination);
    } catch (_) {
      await destination.delete();
      rethrow;
    }
  }

  /// Delivers blocks into the caller's private staging area. Publish the result
  /// after every block and the file length have been authenticated.
  static Future<void> decrypt({
    required File source,
    required int clearLength,
    required String expectedDigest,
    required SecretKey key,
    required List<int> context,
    required Future<void> Function(Uint8List bytes) write,
  }) async {
    if (clearLength < 1 ||
        !await source.exists() ||
        await source.length() != byteLength(clearLength) ||
        await digest(source) != expectedDigest) {
      throw invalid;
    }
    final input = await source.open();
    try {
      final header = await input.read(_headerLength);
      if (header.length != _headerLength ||
          Mac(header.sublist(0, 8)) != Mac(_magic)) {
        throw invalid;
      }
      if (ByteData.sublistView(header).getUint64(24) != clearLength) {
        throw invalid;
      }
      var remaining = clearLength;
      for (var index = 0; remaining > 0; index++) {
        final count = min(chunkSize, remaining);
        final cipherText = await input.read(count);
        final tag = await input.read(_tagLength);
        if (cipherText.length != count || tag.length != _tagLength) {
          throw invalid;
        }
        final clear = await algorithm.decrypt(
          SecretBox(cipherText, nonce: _nonce(header, index), mac: Mac(tag)),
          secretKey: key,
          aad: _authenticate(context, header, index),
        );
        await write(clear is Uint8List ? clear : Uint8List.fromList(clear));
        remaining -= count;
      }
      if (await input.readByte() != -1) throw invalid;
    } on SecretBoxAuthenticationError {
      throw invalid;
    } finally {
      await input.close();
    }
  }
}
