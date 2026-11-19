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
  }) => encryptStream(
    source: source.openRead(),
    destination: destination,
    clearLength: clearLength,
    key: key,
    context: context,
  );

  static Future<String> encryptStream({
    required Stream<List<int>> source,
    required File destination,
    required int clearLength,
    required SecretKey key,
    required List<int> context,
    List<int> prefix = const [],
  }) async {
    if (clearLength < 1) throw invalid;
    final header = Uint8List.fromList([
      ..._magic,
      ...randomBytes(16),
      ..._counter(clearLength),
    ]);
    await destination.create(exclusive: true);
    try {
      final output = await destination.open(mode: FileMode.writeOnly);
      final buffer = Uint8List(chunkSize);
      try {
        if (prefix.isNotEmpty) await output.writeFrom(prefix);
        await output.writeFrom(header);
        var length = 0, filled = 0, index = 0;
        Future<void> writeBlock() async {
          final box = await algorithm.encrypt(
            Uint8List.sublistView(buffer, 0, filled),
            secretKey: key,
            nonce: _nonce(header, index),
            aad: _authenticate(context, header, index),
          );
          await output.writeFrom(box.cipherText);
          await output.writeFrom(box.mac.bytes);
          index++;
          filled = 0;
        }

        await for (final segment in source) {
          length += segment.length;
          if (length > clearLength) throw invalid;
          for (var offset = 0; offset < segment.length;) {
            final count = min(chunkSize - filled, segment.length - offset);
            buffer.setRange(filled, filled + count, segment, offset);
            offset += count;
            filled += count;
            if (filled == chunkSize) await writeBlock();
          }
        }
        if (length != clearLength) throw invalid;
        if (filled != 0) await writeBlock();
        await output.flush();
      } finally {
        buffer.fillRange(0, buffer.length, 0);
        await output.close();
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
    int prefixLength = 0,
  }) async {
    if (clearLength < 1 ||
        prefixLength < 0 ||
        !await source.exists() ||
        await source.length() != prefixLength + byteLength(clearLength) ||
        await digest(source) != expectedDigest) {
      throw invalid;
    }
    final input = await source.open();
    try {
      if (prefixLength != 0) await input.setPosition(prefixLength);
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

  /// Returns the untrusted clear length after checking it against actual size.
  /// The caller must still authenticate the sealed file before using any data.
  static Future<int> inspectLength(File source, {int prefixLength = 0}) async {
    if (prefixLength < 0) throw invalid;
    final input = await source.open();
    try {
      await input.setPosition(prefixLength);
      final header = await input.read(_headerLength);
      if (header.length != _headerLength ||
          Mac(header.sublist(0, 8)) != Mac(_magic)) {
        throw invalid;
      }
      final clear = ByteData.sublistView(header).getUint64(24);
      final size = await input.length() - prefixLength;
      if (clear < 1 || clear > size || byteLength(clear) != size) throw invalid;
      return clear;
    } finally {
      await input.close();
    }
  }
}
