part of 'backup_archive.dart';

final class _BackupReader {
  _BackupReader(this.directory);
  final Directory directory;
  Uint8List _metadata = Uint8List(4);
  bool _readingLength = true;
  int _read = 0, _index = 0;
  BackupManifest? _manifest;
  RandomAccessFile? _file;

  Future<void> write(Uint8List block) async {
    try {
      for (var offset = 0; offset < block.length;) {
        final manifest = _manifest;
        if (manifest == null) {
          final count = min(_metadata.length - _read, block.length - offset);
          _metadata.setRange(_read, _read + count, block, offset);
          offset += count;
          _read += count;
          if (_read == _metadata.length) _readMetadata();
          continue;
        }
        if (_index >= manifest.entries.length) throw invalidBackup;
        final entry = manifest.entries[_index];
        final path = File(p.join(directory.path, entry.name));
        var file = _file;
        if (file == null) {
          await path.parent.create(recursive: true);
          await path.create(exclusive: true);
          file = _file = await path.open(mode: FileMode.writeOnly);
        }
        final count = min(entry.bytes - _read, block.length - offset);
        await file.writeFrom(block, offset, offset + count);
        _read += count;
        offset += count;
        if (_read == entry.bytes) {
          await file.flush();
          await file.close();
          _file = null;
          if (await SealedFile.digest(path) != entry.digest) {
            throw invalidBackup;
          }
          _index++;
          _read = 0;
        }
      }
    } finally {
      block.fillRange(0, block.length, 0);
    }
  }

  void _readMetadata() {
    if (_readingLength) {
      final length = ByteData.sublistView(_metadata).getUint32(0);
      if (length < 1 || length > BackupArchive._manifestLimit) {
        throw invalidBackup;
      }
      _metadata = Uint8List(length);
      _readingLength = false;
    } else {
      _manifest = BackupManifest._parse(_metadata);
      _metadata.fillRange(0, _metadata.length, 0);
    }
    _read = 0;
  }

  BackupManifest finish() {
    final result = _manifest;
    if (result == null || _index != result.entries.length || _file != null) {
      throw invalidBackup;
    }
    return result;
  }

  Future<void> discard() async {
    _metadata.fillRange(0, _metadata.length, 0);
    _manifest?.destroy();
    try {
      await _file?.close();
    } finally {
      await directory.delete(recursive: true);
    }
  }
}
