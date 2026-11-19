import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:familyvault/app/app.dart';
import 'package:familyvault/app/vault_providers.dart';
import 'package:familyvault/core/errors/app_failure.dart';
import 'package:familyvault/core/security/sealed_file.dart';
import 'package:familyvault/core/security/vault_identity.dart';
import 'package:familyvault/core/security/vault_lifecycle.dart';
import 'package:familyvault/features/backup/backup_archive.dart';
import 'package:familyvault/features/backup/drive_backup_api.dart';
import 'package:familyvault/features/backup/drive_backup_destination.dart';
import 'package:familyvault/features/backup/drive_sign_in.dart';
import 'package:familyvault/features/backup/vault_backup.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' show FilledButton, TextButton;
import 'package:uuid/uuid.dart';

import '../support/security_fakes.dart';
import '../support/widget_io.dart';

final class _DriveConsentFixture implements DriveSignIn {
  _DriveConsentFixture(this.connection);
  final DriveBackupConnection connection;
  int connects = 0;

  @override
  Future<bool> configured() async => true;

  @override
  Future<DriveBackupConnection> connect() async {
    connects++;
    return connection;
  }

  @override
  Future<void> disconnect() async {}
}

final class _LoopbackHttpOverrides extends HttpOverrides {}

final class _Upload {
  _Upload(this.id, this.properties, this.size);
  final String id;
  final Object? properties;
  final int size;
  final bytes = BytesBuilder(copy: false);

  Map<String, Object?> get info => {
    'id': id,
    'size': '$size',
    'trashed': false,
    'createdTime': '2026-11-19T00:00:00Z',
    'appProperties': properties,
  };
}

final class _DriveFixture {
  _DriveFixture(this.server) {
    listener = server.listen((request) => unawaited(handle(request)));
  }
  final HttpServer server;
  late final StreamSubscription<HttpRequest> listener;
  final files = <String, _Upload>{};
  final sessions = <String, _Upload>{};
  int allocated = 0, starts = 0, mediaReads = 0;
  final offsets = <int>[];
  bool interrupt = false,
      loseFinish = false,
      foreignLocation = false,
      corruptMedia = false;
  Uri get root => Uri.parse('http://127.0.0.1:${server.port}');

  Future<void> handle(HttpRequest request) async {
    final response = request.response;
    void json(Object? data, [int status = 200]) {
      response.statusCode = status;
      response.headers.contentType = ContentType.json;
      response.write(jsonEncode(data));
    }

    try {
      if (request.headers.value(HttpHeaders.authorizationHeader) !=
          'Bearer synthetic-drive') {
        response.statusCode = 401;
        return;
      }
      final path = request.uri.path, params = request.uri.queryParameters;
      if (path == '/drive/v3/files/generateIds') {
        json({
          'ids': ['fixture-${++allocated}'],
        });
      } else if (path == '/drive/v3/files') {
        json({'files': files.values.map((file) => file.info).toList()});
      } else if (path.startsWith('/drive/v3/files/')) {
        final file = files[path.split('/').last];
        if (file == null) {
          response.statusCode = 404;
        } else if (params['alt'] == 'media') {
          mediaReads++;
          final data = Uint8List.fromList(file.bytes.toBytes());
          if (corruptMedia) data[data.length - 1] ^= 1;
          response.contentLength = data.length;
          response.add(data);
        } else {
          json(file.info);
        }
      } else if (path == '/upload/drive/v3/files' && request.method == 'POST') {
        final value = jsonDecode(
          await utf8.decoder.bind(request).join(),
        ) as Map<String, Object?>;
        final id = value['id']! as String;
        if (files.containsKey(id)) {
          response.statusCode = 409;
          return;
        }
        final name = 'session-${++starts}';
        final size = int.parse(
          request.headers.value('x-upload-content-length')!,
        );
        sessions[name] = _Upload(id, value['appProperties'], size);
        response.headers.set(
          HttpHeaders.locationHeader,
          foreignLocation
              ? 'https://fixture.invalid/upload/drive/v3/files?upload_id=$name'
              : root
                    .replace(path: path, queryParameters: {'upload_id': name})
                    .toString(),
        );
      } else if (path == '/upload/drive/v3/files' && request.method == 'PUT') {
        final state = sessions[params['upload_id']];
        if (state == null) {
          response.statusCode = 404;
          return;
        }
        final range = request.headers.value('content-range')!;
        if (!range.startsWith('bytes */')) {
          final match = RegExp(r'^bytes (\d+)-(\d+)/(\d+)$').firstMatch(range)!;
          final start = int.parse(match.group(1)!);
          if (start != state.bytes.length ||
              int.parse(match.group(3)!) != state.size) {
            response.statusCode = 400;
            return;
          }
          offsets.add(start);
          await for (final block in request) {
            state.bytes.add(block);
          }
          if (state.bytes.length != int.parse(match.group(2)!) + 1) {
            response.statusCode = 400;
            return;
          }
          if (interrupt) {
            interrupt = false;
            response.statusCode = 503;
            return;
          }
          if (state.bytes.length == state.size) {
            files[state.id] = state;
            if (loseFinish) {
              loseFinish = false;
              response.statusCode = 503;
              return;
            }
          }
        }
        if (files.containsKey(state.id)) {
          json({'id': state.id});
        } else {
          response.statusCode = 308;
          if (state.bytes.length != 0) {
            response.headers.set('range', 'bytes=0-${state.bytes.length - 1}');
          }
        }
      } else {
        response.statusCode = 404;
      }
    } catch (_) {
      response.statusCode = 500;
    } finally {
      await response.close();
    }
  }

  Future<void> close() async {
    await server.close(force: true);
    await listener.cancel();
  }
}

void main() {
  late Directory root;
  late _DriveFixture drive;
  late MemorySecureStore store;
  late VaultIdentity identity;

  void driveTest(String name, Future<void> Function() work) {
    test(
      name,
      () => HttpOverrides.runWithHttpOverrides(work, _LoopbackHttpOverrides()),
    );
  }

  DriveBackupDestination destination({MemorySecureStore? catalog}) =>
      DriveBackupDestination(
        api: GoogleDriveBackupApi.test(
          () async => 'synthetic-drive',
          drive.root,
        ),
        store: catalog ?? store,
        accountId: 'fixture-account',
      );

  setUp(() async {
    root = await (await Directory('.cache/test-vaults').create(recursive: true))
        .createTemp('drive-');
    drive = _DriveFixture(
      await HttpServer.bind(InternetAddress.loopbackIPv4, 0),
    );
    store = MemorySecureStore();
    identity = VaultIdentity(
      familyId: const Uuid().v4(),
      memberId: const Uuid().v4(),
      deviceId: const Uuid().v4(),
      mode: 'offline',
    );
  });
  tearDown(() async {
    await drive.close();
    await root.delete(recursive: true);
  });

  Future<BackupArtifact> blob(int size) async {
    final id = const Uuid().v4();
    final file = await File('${root.path}/$id.fvbackup')
        .writeAsBytes(Uint8List(size));
    return BackupArtifact(id, file, await SealedFile.digest(file), size);
  }

  driveTest('resumes an interrupted upload and a lost completion response under the same file ID', () async {
    final artifact = await blob(9 * 1024 * 1024);
    drive.interrupt = drive.loseFinish = true;
    await expectLater(
      destination().upload(identity, artifact),
      throwsA(isA<AppFailure>()),
    );
    expect(drive.files, isEmpty);
    expect(drive.offsets, [0]);
    expect(await destination().verifiedAt(identity, artifact), isNull);
    final saved = await destination().upload(identity, artifact);
    expect(saved.file.snapshotId, artifact.id);
    expect(saved.digest, artifact.digest);
    expect(drive.offsets, [0, 8 * 1024 * 1024]);
    expect(drive.allocated, 1);
    expect(drive.starts, 1);
    expect(drive.mediaReads, 1);
    expect(
      await destination().verifiedAt(identity, artifact),
      saved.completedAtUs,
    );
    expect(
      (await destination().upload(identity, artifact)).file.id,
      saved.file.id,
    );
    expect(drive.files.length, 1);
    expect((await destination().history()).files.single.id, saved.file.id);
  });

  driveTest(
    'clears a rejected token and requests fresh access on the next action',
    () async {
      var expired = true;
      final api = GoogleDriveBackupApi.test(
        () async => expired ? 'expired-fixture' : 'synthetic-drive',
        drive.root,
        clearRejectedToken: (token) async {
          expect(token, 'expired-fixture');
          expired = false;
        },
      );
      await expectLater(
        api.list(),
        throwsA(
          isA<AppFailure>().having(
            (error) => error.code,
            'code',
            FailureCode.unauthorized,
          ),
        ),
      );
      expect((await api.list()).files, isEmpty);
    },
  );

  driveTest(
    'expired sessions reuse the allocated ID and reject another upload host',
    () async {
      final artifact = await blob(9 * 1024 * 1024);
      drive.interrupt = true;
      await expectLater(
        destination().upload(identity, artifact),
        throwsA(isA<AppFailure>()),
      );
      drive.sessions.clear();
      drive.foreignLocation = true;
      await expectLater(
        destination().upload(identity, artifact),
        throwsA(
          isA<AppFailure>().having(
            (e) => e.code,
            'code',
            FailureCode.integrity,
          ),
        ),
      );
      drive.foreignLocation = false;
      final saved = await destination().upload(identity, artifact);
      expect(saved.file.id, 'fixture-1');
      expect(drive.allocated, 1);
      expect(drive.files.length, 1);
    },
  );

  driveTest('opens an independent downloaded archive in a clean vault and detects corrupt cloud bytes', () async {
    final source = VaultLifecycle(
      store: MemorySecureStore(),
      gate: FakeDeviceGate(),
      root: () async => Directory('${root.path}/source'),
    );
    addTearDown(source.dispose);
    await source.initialize();
    await source.createOffline(
      familyName: 'Synthetic Drive family',
      ownerName: 'Synthetic owner',
    );
    final key = BackupRecoveryKey.generate();
    addTearDown(key.destroy);
    final engine = VaultBackup(Directory('${root.path}/verification'));
    final artifact = await engine.capture(
      session: source.status.session!,
      destination: Directory('${root.path}/out'),
      recovery: key,
    );
    final flow = destination();
    final receipt = await flow.upload(
      source.status.session!.identity,
      artifact,
    );
    await source.lock();
    await artifact.file.delete();
    final clean = Directory('${root.path}/clean');
    final recovery = destination(catalog: MemorySecureStore());
    final wrongKey = BackupRecoveryKey.generate();
    addTearDown(wrongKey.destroy);
    await expectLater(
      recovery.fetch(receipt.file, clean, wrongKey),
      throwsA(isA<AppFailure>()),
    );
    expect(await clean.exists(), isFalse);
    drive.corruptMedia = true;
    final corrupted = await recovery.fetch(receipt.file, clean, key);
    await expectLater(
      engine.verify(corrupted, key),
      throwsA(isA<AppFailure>()),
    );
    drive.corruptMedia = false;
    final downloaded = await recovery.fetch(
      (await recovery.history()).files.single,
      clean,
      key,
    );
    final verified = await engine.verify(downloaded, key);
    addTearDown(verified.close);
    final restored = VaultLifecycle(
      store: MemorySecureStore(),
      gate: FakeDeviceGate(),
      root: () async => Directory('${root.path}/clean-vault'),
    );
    addTearDown(restored.dispose);
    await restored.initialize();
    await restored.restoreBackup(verified);
    expect(restored.status.phase, VaultPhase.open);
    expect(
      restored.status.session!.identity.familyId,
      verified.contents.manifest.identity.familyId,
    );
  });

  testWidgets(
    'clean app selects a Drive version and verifies its key before activation',
    (tester) async {
      Future<T?> disk<T>(Future<T> Function() work) => tester.runAsync(
        () =>
            HttpOverrides.runWithHttpOverrides(work, _LoopbackHttpOverrides()),
      );
      final gate = FakeDeviceGate();
      final target = VaultLifecycle(
        store: MemorySecureStore(),
        gate: gate,
        root: () async => Directory('${root.path}/widget-target'),
      );
      final flow = destination(catalog: MemorySecureStore());
      final consent = _DriveConsentFixture(
        DriveBackupConnection('drive-fixture@example.invalid', flow),
      );
      final container = ProviderContainer(
        overrides: [
          vaultLifecycleProvider.overrideWithValue(target),
          driveSignInProvider.overrideWithValue(consent),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await target.dispose();
      });
      final seeded = (await disk(() async {
        final source = VaultLifecycle(
          store: MemorySecureStore(),
          gate: FakeDeviceGate(),
          root: () async => Directory('${root.path}/widget-source'),
        );
        final key = BackupRecoveryKey.generate();
        try {
          await source.initialize();
          await source.createOffline(
            familyName: 'Synthetic Drive family',
            ownerName: 'Synthetic owner',
          );
          final session = source.status.session!;
          final artifact = await VaultBackup(Directory('${root.path}/verify'))
              .capture(
                session: session,
                destination: Directory('${root.path}/out'),
                recovery: key,
              );
          await destination().upload(session.identity, artifact);
          await artifact.file.delete();
          await target.initialize();
          return (code: key.code, family: session.identity.familyId);
        } finally {
          key.destroy();
          await source.dispose();
        }
      }))!;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const FamilyVaultApp(),
        ),
      );
      await ready(tester, find.text('Family access'));
      await tapVisible(tester, find.text('Family access'));
      await ready(tester, find.text('Restore an encrypted backup'));
      await tapVisible(tester, find.text('Restore an encrypted backup'));
      expect(consent.connects, 0);
      await tapVisible(tester, find.text('Connect Google Drive'));
      await ready(tester, find.text('drive-fixture@example.invalid'));
      expect(consent.connects, 1);

      Future<void> press(void Function()? onPressed) async {
        await disk(onPressed! as Future<void> Function());
        await tester.pump();
      }

      await disk(() async {
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Show backup history'),
            )
            .onPressed!();
      });
      await ready(tester, find.textContaining(' bytes'));
      await tapVisible(tester, find.textContaining(' bytes'));
      await tester.enterText(field('Recovery key'), seeded.code);
      expect(drive.mediaReads, 1);
      await press(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Verify backup'),
            )
            .onPressed,
      );
      expect(drive.mediaReads, 2);
      await ready(tester, find.text('Restore vault'));
      expect(target.status.phase, VaultPhase.setup);
      expect(gate.calls, 0);
      await press(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Restore vault'),
            )
            .onPressed,
      );
      await ready(tester, find.text('On this device'));
      expect(target.status.session!.identity.familyId, seeded.family);
      expect(gate.calls, 1);
    },
  );
}
