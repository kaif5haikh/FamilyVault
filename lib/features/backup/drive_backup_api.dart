import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart' as hash;
import 'package:uuid/uuid.dart';

import '../../core/errors/app_failure.dart';
import 'vault_backup.dart';

const driveUnavailable = AppFailure(
  FailureCode.network,
  'Google Drive did not respond. Check your connection and try again.',
);
const driveInvalid = AppFailure(
  FailureCode.integrity,
  'The Google Drive backup or receipt could not be verified.',
);
const driveAccessRequired = AppFailure(
  FailureCode.unauthorized,
  'Connect your Google account to use Drive backups.',
);

final class DriveBackupFile {
  const DriveBackupFile({
    required this.id,
    required this.snapshotId,
    required this.bytes,
    required this.created,
    this.digest,
  });
  final String id, snapshotId;
  final int bytes;
  final DateTime created;
  final String? digest;

  factory DriveBackupFile._parse(Object? value) {
    if (value is! Map<String, Object?> || value['trashed'] != false) {
      throw driveInvalid;
    }
    final id = _driveId(value['id']);
    final properties = value['appProperties'];
    final snapshot =
        properties is Map<String, Object?> && properties['fv_backup'] == '1'
        ? properties['snapshot_id']
        : null;
    final size = int.tryParse(value['size']?.toString() ?? '');
    final time = DateTime.tryParse(value['createdTime']?.toString() ?? '');
    final digest = value['sha256Checksum'];
    if (snapshot is! String ||
        !Uuid.isValidUUID(fromString: snapshot) ||
        size == null ||
        size < 1 ||
        time == null ||
        (digest != null &&
            (digest is! String ||
                !RegExp(r'^[a-f0-9]{64}$').hasMatch(digest)))) {
      throw driveInvalid;
    }
    return DriveBackupFile(
      id: id,
      snapshotId: snapshot,
      bytes: size,
      created: time,
      digest: digest as String?,
    );
  }
}

enum DriveUploadPhase { transferring, expired, completed }

final class DriveUploadProgress {
  const DriveUploadProgress._(this.phase, {this.offset = 0, this.fileId});
  final DriveUploadPhase phase;
  final int offset;
  final String? fileId;
}

String _driveId(Object? value) {
  if (value is! String || !RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(value)) {
    throw driveInvalid;
  }
  return value;
}

/// Drive's file-scoped API, with redirects disabled so OAuth cannot reach a
/// different host. Credentials come from the separately authorized account.
final class GoogleDriveBackupApi {
  GoogleDriveBackupApi(this._accessToken)
    : _origin = Uri.https('www.googleapis.com');
  GoogleDriveBackupApi.test(this._accessToken, this._origin) {
    if (_origin.scheme != 'http' ||
        _origin.host != '127.0.0.1' ||
        !_origin.hasPort) {
      throw ArgumentError('Drive test transport requires a loopback endpoint.');
    }
  }
  final Future<String?> Function() _accessToken;
  final Uri _origin;
  static const _fields =
      'id,trashed,size,createdTime,sha256Checksum,appProperties';
  static const _upload = '/upload/drive/v3/files';
  static const _files = '/drive/v3/files';
  static const _timeout = Duration(seconds: 60);

  Uri _uri(String path, [Map<String, String>? query]) =>
      _origin.replace(path: path, queryParameters: query);

  Uri sessionUri(String value) {
    final url = Uri.tryParse(value);
    if (url == null ||
        url.scheme != _origin.scheme ||
        url.host != _origin.host ||
        url.port != _origin.port ||
        url.userInfo.isNotEmpty ||
        url.path != _upload ||
        url.hasFragment ||
        url.queryParameters['upload_id']?.isNotEmpty != true) {
      throw driveInvalid;
    }
    return url;
  }

  Future<T> _request<T>(
    String method,
    Uri url,
    Future<T> Function(HttpClientResponse) read, {
    Map<String, String> headers = const {},
    Stream<List<int>>? body,
    int? bytes,
  }) async {
    if (url.origin != _origin.origin ||
        url.userInfo.isNotEmpty ||
        url.hasFragment) {
      throw driveInvalid;
    }
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final token = await _accessToken().timeout(_timeout);
      if (token == null || token.isEmpty || token.contains(RegExp(r'\s'))) {
        throw driveAccessRequired;
      }
      final request = await client.openUrl(method, url).timeout(_timeout);
      request.followRedirects = false;
      request.headers.set(HttpHeaders.authorizationHeader, 'Bearer $token');
      headers.forEach(request.headers.set);
      if (bytes != null) request.contentLength = bytes;
      if (body != null) await request.addStream(body).timeout(_timeout);
      final response = await request.close().timeout(_timeout);
      return await read(response);
    } on AppFailure {
      rethrow;
    } on IOException {
      throw driveUnavailable;
    } on TimeoutException {
      throw driveUnavailable;
    } catch (_) {
      throw driveInvalid;
    } finally {
      client.close(force: true);
    }
  }

  Never _failed(HttpClientResponse response) {
    final status = response.statusCode;
    if (status == 401) throw driveAccessRequired;
    if (status == 403) {
      throw const AppFailure(
        FailureCode.configuration,
        'Google Drive refused this request. Check access and available storage.',
      );
    }
    if (status >= 500 || status == 429 || status == 408) throw driveUnavailable;
    throw driveInvalid;
  }

  Future<Map<String, Object?>> _json(HttpClientResponse response) async {
    final payload = <int>[];
    await for (final bytes in response.timeout(_timeout)) {
      if (payload.length + bytes.length > 1024 * 1024) throw driveInvalid;
      payload.addAll(bytes);
    }
    final result = jsonDecode(utf8.decode(payload));
    if (result is! Map<String, Object?>) throw driveInvalid;
    return result;
  }

  Future<String> allocateId() => _request(
    'GET',
    _uri('$_files/generateIds', {'count': '1', 'space': 'drive'}),
    (response) async {
      if (response.statusCode != 200) _failed(response);
      final ids = (await _json(response))['ids'];
      if (ids is! List<Object?> || ids.length != 1) throw driveInvalid;
      return _driveId(ids.single);
    },
  );

  Future<DriveBackupFile?> metadata(String id) => _request(
    'GET',
    _uri('$_files/${_driveId(id)}', {'fields': _fields}),
    (response) async {
      if (response.statusCode == 404) return null;
      if (response.statusCode != 200) _failed(response);
      final item = DriveBackupFile._parse(await _json(response));
      if (item.id != id) throw driveInvalid;
      return item;
    },
  );

  Future<({List<DriveBackupFile> files, String? nextPage})> list({
    String? page,
  }) => _request(
    'GET',
    _uri(_files, {
      'q': "trashed = false and appProperties has { key='fv_backup' and value='1' }",
      'fields': 'nextPageToken,files($_fields)',
      'spaces': 'drive',
      'pageSize': '50',
      'orderBy': 'createdTime desc',
      'pageToken': ?page,
    }),
    (response) async {
      if (response.statusCode != 200) _failed(response);
      final rows = await _json(response);
      final items = rows['files'] ?? const <Object?>[],
          next = rows['nextPageToken'];
      if (items is! List<Object?> ||
          items.length > 50 ||
          (next != null && (next is! String || next.length > 4096))) {
        throw driveInvalid;
      }
      return (
        files: items.map(DriveBackupFile._parse).toList(),
        nextPage: next as String?,
      );
    },
  );

  Future<Uri?> start(BackupArtifact artifact, String fileId) async {
    if (!Uuid.isValidUUID(fromString: artifact.id) || artifact.bytes < 1) {
      throw driveInvalid;
    }
    final payload = utf8.encode(
      jsonEncode({
        'id': _driveId(fileId),
        'name': 'FamilyVault-${artifact.id}.fvbackup',
        'mimeType': 'application/octet-stream',
        'appProperties': {'fv_backup': '1', 'snapshot_id': artifact.id},
      }),
    );
    return _request(
      'POST',
      _uri(_upload, {'uploadType': 'resumable', 'fields': 'id'}),
      (response) async {
        if (response.statusCode == 409) return null;
        if (response.statusCode != 200 && response.statusCode != 201) {
          _failed(response);
        }
        final location = response.headers.value(HttpHeaders.locationHeader);
        if (location == null) throw driveInvalid;
        return sessionUri(location);
      },
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'X-Upload-Content-Type': 'application/octet-stream',
        'X-Upload-Content-Length': '${artifact.bytes}',
      },
      bytes: payload.length,
      body: Stream.value(payload),
    );
  }

  Future<DriveUploadProgress> status(Uri session, int size) =>
      _transfer(session, size, 'bytes */$size', 0, null);

  Future<DriveUploadProgress> upload(
    Uri session,
    BackupArtifact artifact,
    int start,
    int end,
  ) {
    if (start < 0 ||
        end <= start ||
        end > artifact.bytes ||
        (end < artifact.bytes && (end - start) % (256 * 1024) != 0)) {
      throw driveInvalid;
    }
    return _transfer(
      session,
      artifact.bytes,
      'bytes $start-${end - 1}/${artifact.bytes}',
      end - start,
      artifact.file.openRead(start, end),
    );
  }

  Future<DriveUploadProgress> _transfer(
    Uri session,
    int size,
    String range,
    int bytes,
    Stream<List<int>>? body,
  ) => _request(
    'PUT',
    sessionUri(session.toString()),
    (response) async {
      if (response.statusCode == 404) {
        return const DriveUploadProgress._(DriveUploadPhase.expired);
      }
      if (response.statusCode == 200 || response.statusCode == 201) {
        return DriveUploadProgress._(
          DriveUploadPhase.completed,
          offset: size,
          fileId: _driveId((await _json(response))['id']),
        );
      }
      if (response.statusCode != 308) _failed(response);
      final received = response.headers.value(HttpHeaders.rangeHeader);
      if (received == null) {
        return const DriveUploadProgress._(DriveUploadPhase.transferring);
      }
      final match = RegExp(r'^bytes=0-(\d+)$').firstMatch(received);
      final last = int.tryParse(match?.group(1) ?? '');
      if (last == null || last < 0 || last >= size - 1) throw driveInvalid;
      return DriveUploadProgress._(
        DriveUploadPhase.transferring,
        offset: last + 1,
      );
    },
    headers: {
      'Content-Range': range,
      'Content-Type': 'application/octet-stream',
    },
    bytes: bytes,
    body: body,
  );

  Future<String> checksum(DriveBackupFile file) => _content(
    file,
    (bytes) async => (await hash.sha256.bind(bytes).first).toString(),
  );

  Future<String> download(DriveBackupFile file, File target) async {
    await target.create(exclusive: true);
    try {
      return await _content(file, (bytes) async {
        final output = await target.open(mode: FileMode.writeOnly);
        try {
          await for (final block in bytes) {
            await output.writeFrom(block);
          }
          await output.flush();
        } finally {
          await output.close();
        }
        final digest = (await hash.sha256.bind(target.openRead()).first)
            .toString();
        if (file.digest != null && digest != file.digest) throw driveInvalid;
        return digest;
      });
    } catch (_) {
      await target.delete();
      rethrow;
    }
  }

  Future<T> _content<T>(
    DriveBackupFile file,
    Future<T> Function(Stream<List<int>>) handle,
  ) => _request('GET', _uri('$_files/${_driveId(file.id)}', {'alt': 'media'}), (
    response,
  ) async {
    if (response.statusCode != 200) _failed(response);
    if (response.contentLength != -1 && response.contentLength != file.bytes) {
      throw driveInvalid;
    }
    Stream<List<int>> validated() async* {
      var size = 0;
      await for (final block in response.timeout(_timeout)) {
        size += block.length;
        if (size > file.bytes) throw driveInvalid;
        yield block;
      }
      if (size != file.bytes) throw driveInvalid;
    }

    return handle(validated());
  });
}
