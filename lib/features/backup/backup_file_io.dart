import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../core/errors/app_failure.dart';
import 'backup_archive.dart';

typedef BackupInput = ({
  Future<int> Function() length,
  Stream<List<int>> Function() openRead,
});

abstract interface class BackupFilePicker {
  Future<BackupInput?> pick();
}

final backupFilePickerProvider = Provider<BackupFilePicker>(
  (ref) => const NativeBackupFilePicker(),
);

final class NativeBackupFilePicker implements BackupFilePicker {
  const NativeBackupFilePicker();

  @override
  Future<BackupInput?> pick() async {
    try {
      final result = await FilePicker.pickFile(type: FileType.any);
      if (result == null) return null;
      return (
        length: () async => await result.length() ?? (throw invalidBackup),
        openRead: result.readAsByteStream,
      );
    } catch (_) {
      throw const AppFailure(
        FailureCode.storage,
        'The selected backup could not be opened.',
      );
    }
  }
}

Future<File> stageSelectedBackup(
  BackupInput input,
  Directory root,
  BackupRecoveryKey recovery,
) async {
  final expected = await input.length();
  if (expected < BackupArchive.prefixSize + 32) throw invalidBackup;
  final stream = StreamIterator(input.openRead());
  Directory? directory;
  try {
    final prefix = <int>[];
    var remainder = <int>[];
    while (prefix.length < BackupArchive.prefixSize &&
        await stream.moveNext()) {
      final part = stream.current;
      final count = min(BackupArchive.prefixSize - prefix.length, part.length);
      prefix.addAll(part.take(count));
      if (count < part.length) remainder = part.sublist(count);
    }
    await BackupArchive.authenticatePrefix(prefix, recovery);
    var received = prefix.length + remainder.length;
    if (received > expected) throw invalidBackup;
    directory = await (await root.create(recursive: true))
        .createTemp('selected-');
    final file = File(p.join(directory.path, 'selected.fvbackup'));
    final destination = await file.open(mode: FileMode.writeOnly);
    try {
      await destination.writeFrom(prefix);
      await destination.writeFrom(remainder);
      while (await stream.moveNext()) {
        final bytes = stream.current;
        received += bytes.length;
        if (received > expected) throw invalidBackup;
        await destination.writeFrom(bytes);
      }
      if (received != expected) throw invalidBackup;
      await destination.flush();
    } finally {
      await destination.close();
    }
    return file;
  } catch (_) {
    await directory?.delete(recursive: true);
    rethrow;
  } finally {
    await stream.cancel();
  }
}
