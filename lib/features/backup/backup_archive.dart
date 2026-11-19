import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../core/errors/app_failure.dart';
import '../../core/security/sealed_file.dart';
import '../../core/security/vault_identity.dart';

part 'backup_reader.dart';

const invalidBackup = AppFailure(
  FailureCode.integrity,
  'This backup is incomplete, damaged or could not be opened with this recovery key.',
);

final class BackupRecoveryKey {
  BackupRecoveryKey._(Uint8List bytes)
    : _key = SecretKeyData(bytes, overwriteWhenDestroyed: true);
  factory BackupRecoveryKey.generate() =>
      BackupRecoveryKey._(SealedFile.randomBytes(32));
  factory BackupRecoveryKey.fromCode(String code) {
    final value = code.trim();
    if (!RegExp(r'^FV1\.[A-Za-z0-9_-]{43}$').hasMatch(value)) {
      throw const AppFailure(
        FailureCode.validation,
        'Enter the full FamilyVault recovery key.',
      );
    }
    final raw = base64Url.decode(base64Url.normalize(value.substring(4)));
    return BackupRecoveryKey._(raw);
  }
  final SecretKeyData _key;
  String get code => 'FV1.${base64UrlEncode(_key.bytes).replaceAll('=', '')}';
  void destroy() => _key.destroy();
  @override
  String toString() => 'BackupRecoveryKey([redacted])';
}

final class BackupEntry {
  const BackupEntry(this.name, this.bytes, this.digest);
  final String name, digest;
  final int bytes;
  static const database = 'vault.sqlite3';
  static final _document = RegExp(
    r'^documents/[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}\.fvdoc$',
  );
  static final _digest = RegExp(r'^[a-f0-9]{64}$');

  static Future<BackupEntry> measure(Directory source, String name) async {
    _checkName(name);
    final file = File(p.join(source.path, name));
    return BackupEntry(
      name,
      await file.length(),
      await SealedFile.digest(file),
    );
  }

  static void _checkName(String name) {
    if (name != database && !_document.hasMatch(name)) throw invalidBackup;
  }

  factory BackupEntry._parse(Object? json) {
    if (json is! Map<String, Object?> ||
        json.length != 3 ||
        json['name'] is! String ||
        json['bytes'] is! int ||
        json['digest'] is! String) {
      throw invalidBackup;
    }
    final entry = BackupEntry(
      json['name']! as String,
      json['bytes']! as int,
      json['digest']! as String,
    );
    entry._validate();
    return entry;
  }

  void _validate() {
    _checkName(name);
    if (bytes < 1 || !_digest.hasMatch(digest)) throw invalidBackup;
  }

  Map<String, Object?> _serialize() => {
    'name': name,
    'bytes': bytes,
    'digest': digest,
  };
}

final class BackupManifest {
  BackupManifest({
    required this.id,
    required this.createdAtUs,
    required this.schemaVersion,
    required this.identity,
    required List<int> databaseKey,
    required List<int> documentKey,
    required List<BackupEntry> entries,
  }) : entries = List.unmodifiable(entries),
       _database = SecretKeyData(
         Uint8List.fromList(databaseKey),
         overwriteWhenDestroyed: true,
       ),
       _documents = SecretKeyData(
         Uint8List.fromList(documentKey),
         overwriteWhenDestroyed: true,
       ) {
    try {
      if (!Uuid.isValidUUID(fromString: id) ||
          createdAtUs < 1 ||
          schemaVersion < 1 ||
          ![
            identity.familyId,
            identity.memberId,
            identity.deviceId,
          ].every((id) => Uuid.isValidUUID(fromString: id)) ||
          !['offline', 'cloud'].contains(identity.mode) ||
          databaseKey.length != 32 ||
          documentKey.length != 32 ||
          entries.isEmpty ||
          entries.first.name != BackupEntry.database ||
          entries.map((e) => e.name).toSet().length != entries.length) {
        throw invalidBackup;
      }
      for (final entry in entries) {
        entry._validate();
      }
    } catch (_) {
      destroy();
      rethrow;
    }
  }

  final String id;
  final int createdAtUs, schemaVersion;
  final VaultIdentity identity;
  final List<BackupEntry> entries;
  final SecretKeyData _database, _documents;
  List<int> get databaseKey => _database.bytes;
  List<int> get documentKey => _documents.bytes;

  void destroy() {
    _database.destroy();
    _documents.destroy();
  }

  Map<String, Object?> _serialize() => {
    'format': 1,
    'id': id,
    'created_at_us': createdAtUs,
    'schema': schemaVersion,
    'identity': identity.toJson(),
    'database_key': base64Encode(databaseKey),
    'document_key': base64Encode(documentKey),
    'entries': [for (final e in entries) e._serialize()],
  };

  factory BackupManifest._parse(List<int> bytes) {
    Uint8List? database, documents;
    try {
      final value = jsonDecode(utf8.decode(bytes));
      if (value is! Map<String, Object?> ||
          value.length != 8 ||
          value['format'] != 1) {
        throw invalidBackup;
      }
      database = base64Decode(value['database_key']! as String);
      documents = base64Decode(value['document_key']! as String);
      return BackupManifest(
        id: value['id']! as String,
        createdAtUs: value['created_at_us']! as int,
        schemaVersion: value['schema']! as int,
        identity: VaultIdentity.fromJson(
          value['identity']! as Map<String, Object?>,
        ),
        databaseKey: database,
        documentKey: documents,
        entries: (value['entries']! as List<Object?>)
            .map(BackupEntry._parse)
            .toList(),
      );
    } catch (_) {
      throw invalidBackup;
    } finally {
      database?.fillRange(0, database.length, 0);
      documents?.fillRange(0, documents.length, 0);
    }
  }

  @override
  String toString() => 'BackupManifest([redacted])';
}

final class ExtractedBackup {
  const ExtractedBackup._(this.directory, this.manifest, this.digest);
  final Directory directory;
  final BackupManifest manifest;
  final String digest;

  Future<void> close() async {
    manifest.destroy();
    if (await directory.exists()) await directory.delete(recursive: true);
  }
}

/// An authenticated, versioned envelope containing only already encrypted files.
/// The manifest, keys and file index are authenticated inside the chunk stream.
final class BackupArchive {
  static final _magic = ascii.encode('FVBACK01');
  static const prefixSize = 80;
  static const _manifestLimit = 2 * 1024 * 1024;

  static Future<void> authenticatePrefix(
    List<int> prefix,
    BackupRecoveryKey recovery,
  ) async {
    (await _unwrapPrefix(prefix, recovery)).destroy();
  }

  static Future<SecretKeyData> _unwrapPrefix(
    List<int> prefix,
    BackupRecoveryKey recovery,
  ) async {
    if (prefix.length != prefixSize ||
        Mac(prefix.take(_magic.length).toList()) != Mac(_magic)) {
      throw invalidBackup;
    }
    try {
      return SecretKeyData(
        await SealedFile.algorithm.decrypt(
          SecretBox.fromConcatenation(
            prefix.sublist(_magic.length),
            nonceLength: 24,
            macLength: 16,
          ),
          secretKey: recovery._key,
          aad: _magic,
        ),
        overwriteWhenDestroyed: true,
      );
    } on SecretBoxAuthenticationError {
      throw invalidBackup;
    }
  }

  static Future<String> write({
    required Directory source,
    required File destination,
    required BackupManifest manifest,
    required BackupRecoveryKey recovery,
  }) async {
    final key = SecretKeyData(
      SealedFile.randomBytes(32),
      overwriteWhenDestroyed: true,
    );
    final metadata = Uint8List.fromList(
      utf8.encode(jsonEncode(manifest._serialize())),
    );
    try {
      if (metadata.length > _manifestLimit) throw invalidBackup;
      final wrapped = await SealedFile.algorithm.encrypt(
        key.bytes,
        secretKey: recovery._key,
        aad: _magic,
      );
      final prefix = [..._magic, ...wrapped.concatenation()];
      final clearLength = manifest.entries.fold(
        4 + metadata.length,
        (total, e) => total + e.bytes,
      );
      Stream<List<int>> framed() async* {
        yield (ByteData(4)..setUint32(0, metadata.length)).buffer.asUint8List();
        yield metadata;
        for (final entry in manifest.entries) {
          final file = File(p.join(source.path, entry.name));
          if (await file.length() != entry.bytes) throw invalidBackup;
          yield* file.openRead();
        }
      }

      return await SealedFile.encryptStream(
        source: framed(),
        destination: destination,
        clearLength: clearLength,
        key: key,
        context: prefix,
        prefix: prefix,
      );
    } finally {
      metadata.fillRange(0, metadata.length, 0);
      key.destroy();
    }
  }

  static Future<ExtractedBackup> extract({
    required File archive,
    required Directory stagingRoot,
    required BackupRecoveryKey recovery,
  }) async {
    final length = await SealedFile.inspectLength(
      archive,
      prefixLength: prefixSize,
    );
    final prefix = await archive
        .openRead(0, prefixSize)
        .expand((block) => block)
        .toList();
    final key = await _unwrapPrefix(prefix, recovery);
    _BackupReader? reader;
    var done = false;
    try {
      final stage = await (await stagingRoot.create(recursive: true))
          .createTemp('restore-');
      reader = _BackupReader(stage);
      final digest = await SealedFile.digest(archive);
      await SealedFile.decrypt(
        source: archive,
        clearLength: length,
        expectedDigest: digest,
        key: key,
        context: prefix,
        prefixLength: prefixSize,
        write: reader.write,
      );
      final manifest = reader.finish();
      done = true;
      return ExtractedBackup._(stage, manifest, digest);
    } finally {
      key.destroy();
      if (!done) await reader?.discard();
    }
  }
}
