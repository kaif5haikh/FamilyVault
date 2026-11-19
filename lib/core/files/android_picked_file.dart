import 'package:flutter/services.dart';

/// Keeps a transient Android provider URI and streams it without an app copy.
final class AndroidPickedFile {
  AndroidPickedFile._(this.name, this._uri, this._reportedLength);

  static const _channel = MethodChannel('app.familyvault/file-imports');
  final String name, _uri;
  final int? _reportedLength;

  static Future<AndroidPickedFile?> pick(List<String> mimeTypes) async {
    final selected = await _channel.invokeMapMethod<String, Object?>(
      'pick',
      mimeTypes,
    );
    if (selected == null) return null;
    return AndroidPickedFile._(
      selected['name']! as String,
      selected['uri']! as String,
      selected['length'] as int?,
    );
  }

  Future<int> length({int? probeLimit}) async {
    if (_reportedLength case final length?) return length;
    var length = 0;
    await for (final chunk in openRead()) {
      length += chunk.length;
      if (probeLimit != null && length > probeLimit) break;
    }
    return length;
  }

  Stream<Uint8List> openRead() async* {
    final id = (await _channel.invokeMethod<int>('open', _uri))!;
    try {
      while (true) {
        final chunk = await _channel.invokeMethod<Uint8List>('read', id);
        if (chunk == null) break;
        if (chunk.isNotEmpty) yield chunk;
      }
    } finally {
      await _channel.invokeMethod<void>('close', id);
    }
  }
}
