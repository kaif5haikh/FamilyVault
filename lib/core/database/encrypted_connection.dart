import 'dart:io';
import 'dart:isolate';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:sqlite3/sqlite3.dart' as native;

import '../errors/app_failure.dart';

/// A caller supplies a securely generated, securely retained 256-bit vault key.
/// VaultLifecycle creates and retains keys in OS secure storage after device auth.
final class VaultDatabaseKey {
  VaultDatabaseKey.fromBytes(List<int> bytes) {
    if (bytes.length != 32 || bytes.any((value) => value < 0 || value > 255)) {
      throw ArgumentError('Vault keys must contain exactly 32 bytes');
    }
    _hex = bytes.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
  }

  late final String _hex;

  @override
  String toString() => 'VaultDatabaseKey([redacted])';
}

/// Contains a safe numeric classification, never SQL text or an encryption key.
final class VaultOpenFailure implements Exception {
  const VaultOpenFailure(this.sqliteResultCode);

  final int sqliteResultCode;

  @override
  String toString() => 'VaultOpenFailure(code: $sqliteResultCode)';
}

QueryExecutor openEncryptedConnection({
  required File file,
  required VaultDatabaseKey key,
}) {
  return NativeDatabase.createInBackground(
    file,
    setup: (database) => _openVault(database, key),
  );
}

void _openVault(native.Database database, VaultDatabaseKey key) {
  if (database.select('PRAGMA cipher;').isEmpty) {
    throw StateError('An encrypted SQLite engine is required');
  }
  try {
    // Fixed-length hex. Never expose a failed key statement.
    database.execute("PRAGMA key = '${key._hex}';");
    database.select('SELECT count(*) FROM sqlite_schema;');
    database.execute('PRAGMA foreign_keys = ON;');
    database.execute('PRAGMA secure_delete = ON;');
    database.execute('PRAGMA temp_store = MEMORY;');
  } on SqliteException catch (error) {
    throw VaultOpenFailure(error.extendedResultCode);
  }
}

/// Copies a live vault from a pinned SQLite read transaction to a new, keyed
/// database. Source WAL pages and uncommitted changes stay under SQLite control.
Future<void> snapshotEncryptedDatabase({
  required File source,
  required VaultDatabaseKey sourceKey,
  required File destination,
  required VaultDatabaseKey destinationKey,
}) async {
  const failed = AppFailure(
    FailureCode.storage,
    'Could not create the encrypted vault snapshot.',
  );
  if (sourceKey._hex == destinationKey._hex) throw failed;
  final from = source.absolute.path, to = destination.absolute.path;
  var created = false, complete = false;
  try {
    await destination.create(exclusive: true);
    created = true;
    await Isolate.run(() => _snapshot(from, sourceKey, to, destinationKey));
    complete = true;
  } on AppFailure {
    rethrow;
  } catch (_) {
    throw failed;
  } finally {
    if (created && !complete) await destination.delete();
  }
}

Future<void> _snapshot(
  String from,
  VaultDatabaseKey sourceKey,
  String to,
  VaultDatabaseKey destinationKey,
) async {
  final source = native.sqlite3.open(from, mode: native.OpenMode.readOnly);
  try {
    _openVault(source, sourceKey);
    source.execute('PRAGMA busy_timeout = 3000');
    final destination = native.sqlite3.open(
      to,
      mode: native.OpenMode.readWrite,
    );
    try {
      _openVault(destination, destinationKey);
      source.execute('BEGIN');
      source.select('SELECT count(*) FROM sqlite_schema');
      final wait = Stopwatch()..start();
      await for (final _ in source.backup(destination, nPage: -1)) {
        if (wait.elapsed > const Duration(seconds: 30)) {
          throw const AppFailure(
            FailureCode.storage,
            'The vault is busy. Try backing it up again.',
          );
        }
      }
      source.execute('COMMIT');
      destination.execute('PRAGMA journal_mode = DELETE');
      _verifyDatabase(destination);
    } finally {
      destination.close();
    }
  } finally {
    source.close();
  }
}

Future<int> verifyEncryptedDatabase(File file, VaultDatabaseKey key) {
  final path = file.absolute.path;
  return Isolate.run(() {
    final db = native.sqlite3.open(path, mode: native.OpenMode.readOnly);
    try {
      _openVault(db, key);
      _verifyDatabase(db);
      return db.select('PRAGMA user_version').single.values.single as int;
    } finally {
      db.close();
    }
  });
}

void _verifyDatabase(native.Database db) {
  final check = db.select('PRAGMA integrity_check');
  if (check.length != 1 ||
      check.single.values.single != 'ok' ||
      db.select('PRAGMA foreign_key_check').isNotEmpty) {
    throw const AppFailure(
      FailureCode.integrity,
      'The encrypted snapshot failed database verification.',
    );
  }
}
