import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';

/// A caller supplies a securely generated, securely retained 256-bit vault key.
/// This phase intentionally does not create/persist keys or unlock a real vault.
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
    setup: (database) {
      // A production check, not an assert: ordinary SQLite must fail closed.
      if (database.select('PRAGMA cipher;').isEmpty) {
        throw StateError('An encrypted SQLite engine is required');
      }
      try {
        // Fixed-length hex; no user input. Never expose a failed key statement.
        database.execute("PRAGMA key = '${key._hex}';");
        // Detect a wrong key/corruption before migrations or metadata writes.
        database.select('SELECT count(*) FROM sqlite_schema;');
        database.execute('PRAGMA foreign_keys = ON;');
        database.execute('PRAGMA secure_delete = ON;');
        database.execute('PRAGMA temp_store = MEMORY;');
      } on SqliteException catch (error) {
        throw VaultOpenFailure(error.extendedResultCode);
      }
    },
  );
}
