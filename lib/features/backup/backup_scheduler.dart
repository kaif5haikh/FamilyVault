import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../app/vault_providers.dart';
import '../../core/errors/app_failure.dart';
import '../../core/security/secure_store.dart';
import '../../core/security/vault_identity.dart';
import '../../core/security/vault_lifecycle.dart';
import 'backup_archive.dart';
import 'drive_sign_in.dart';
import 'local_backup_destination.dart';

enum BackupCadence {
  daily(Duration(days: 1)),
  weekly(Duration(days: 7));

  const BackupCadence(this.interval);
  final Duration interval;
}

final class BackupScheduleStatus {
  const BackupScheduleStatus({
    required this.cadence,
    required this.dueAtUs,
    required this.local,
    required this.driveEnabled,
    required this.captureFailed,
    required this.driveFailed,
    this.driveVerifiedAtUs,
  });

  final BackupCadence cadence;
  final int dueAtUs;
  final LocalBackupStatus? local;
  final bool driveEnabled, captureFailed, driveFailed;
  final int? driveVerifiedAtUs;
}

final backupSchedulerProvider = Provider<BackupScheduler>(
  (ref) => BackupScheduler(
    ref.watch(secureStoreProvider),
    ref.watch(localBackupProvider),
  ),
);
final backupScheduleStatusProvider = FutureProvider.autoDispose
    .family<BackupScheduleStatus?, VaultIdentity>(
      (ref, identity) => ref.watch(backupSchedulerProvider).status(identity),
    );

final class _BackupPlan {
  const _BackupPlan(
    this.id,
    this.cadence,
    this.startedAtUs,
    this.recovery,
    this.drive,
  );
  final String id, recovery;
  final BackupCadence cadence;
  final int startedAtUs;
  final String? drive;

  int dueAt(LocalBackupStatus? last) =>
      (last?.createdAtUs ?? startedAtUs) + cadence.interval.inMicroseconds;

  @override
  String toString() => '_BackupPlan([redacted])';
}

final class _BackupAttempt {
  const _BackupAttempt(this.atUs, this.failed, this.snapshotId);
  final int atUs;
  final bool failed;
  final String? snapshotId;
}

/// Scheduling uses only an open vault and a separately enrolled Drive account.
/// Attempt records and verified backup receipts survive process restarts.
final class BackupScheduler {
  BackupScheduler(this._store, this._local, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  static const _retry = Duration(minutes: 10);
  static const _invalid = AppFailure(
    FailureCode.storage,
    'Could not read or update this backup schedule.',
  );
  final SecureStore _store;
  final LocalBackupDestination _local;
  final DateTime Function() _clock;
  final _running = <String>{};

  int get _now => _clock().microsecondsSinceEpoch;

  String _scope(VaultIdentity i) =>
      'familyvault.backup.schedule.${i.familyId}.${i.memberId}.${i.deviceId}';

  String _account(DriveBackupConnection connection) =>
      sha256.convert(utf8.encode(connection.destination.accountId)).toString();

  LocalBackupDestination _destination(_BackupPlan plan) =>
      LocalBackupDestination(
        root: _local.root,
        store: _local.store,
        files: _local.files,
        catalogNamespace: 'familyvault.backup.scheduled.${plan.id}',
      );

  Future<void> enable(
    VaultSession session,
    BackupCadence cadence,
    BackupRecoveryKey key, {
    DriveBackupConnection? drive,
  }) => _settings(() async {
    if (session.closed) throw _invalid;
    await _store.write(
      _scope(session.identity),
      jsonEncode({
        'id': const Uuid().v4(),
        'cadence': cadence.name,
        'start_us': _now,
        'recovery': key.code,
        'drive': drive == null ? null : _account(drive),
      }),
    );
  });

  Future<void> disable(VaultIdentity identity) =>
      _settings(() => _store.delete(_scope(identity)));

  Future<BackupScheduleStatus?> status(VaultIdentity identity) =>
      _settings(() async {
        final scope = _scope(identity);
        final plan = await _plan(scope);
        if (plan == null) return null;
        final local = await _destination(plan).read(identity);
        final capture = await _attempt(scope, plan, 'capture');
        final drive = plan.drive == null
            ? null
            : await _attempt(scope, plan, 'drive');
        final matching = drive?.snapshotId == local?.artifact.id;
        return BackupScheduleStatus(
          cadence: plan.cadence,
          dueAtUs: plan.dueAt(local),
          local: local,
          driveEnabled: plan.drive != null,
          captureFailed:
              capture?.failed == true &&
              capture?.snapshotId == local?.artifact.id,
          driveFailed: matching && drive?.failed == true,
          driveVerifiedAtUs: matching && drive?.failed == false
              ? drive!.atUs
              : null,
        );
      });

  Future<void> exportLatest(VaultIdentity identity) => _settings(() async {
    final plan = await _plan(_scope(identity));
    if (plan == null) throw _invalid;
    final destination = _destination(plan);
    final latest = await destination.read(identity);
    if (latest == null) throw _invalid;
    await destination.export(identity, latest);
  });

  Future<bool> runDue(
    VaultSession session, {
    required bool Function() foreground,
    DriveBackupConnection? drive,
  }) async {
    final scope = _scope(session.identity);
    if (session.closed || !foreground() || !_running.add(scope)) return false;
    try {
      return await _settings(() async {
        final plan = await _plan(scope);
        if (plan == null) return false;
        Future<bool> active() async =>
            foreground() &&
            !session.closed &&
            (await _plan(scope))?.id == plan.id;

        final destination = _destination(plan);
        var local = await destination.read(session.identity);
        var changed = false;
        if (_now >= plan.dueAt(local) && await active()) {
          final attempt = await _attempt(scope, plan, 'capture');
          if (_retryReady(attempt)) {
            final key = BackupRecoveryKey.fromCode(plan.recovery);
            try {
              local = await destination.create(session, key);
              changed = true;
            } on AppFailure {
              if (!await active()) return false;
              await _saveAttempt(
                scope,
                plan,
                'capture',
                failed: true,
                snapshotId: local?.artifact.id,
              );
              return true;
            } finally {
              key.destroy();
            }
          }
        }
        if (local == null ||
            drive == null ||
            plan.drive != _account(drive) ||
            !await active()) {
          return changed;
        }
        final artifact = local.artifact;
        final attempt = await _attempt(scope, plan, 'drive');
        if (attempt?.snapshotId == artifact.id &&
            (!attempt!.failed || !_retryReady(attempt))) {
          return changed;
        }
        final int verified;
        try {
          final existing = await drive.destination.verifiedAt(
            session.identity,
            artifact,
          );
          verified =
              existing ??
              (await drive.destination.upload(
                session.identity,
                artifact,
              )).completedAtUs;
        } on AppFailure {
          await _saveAttempt(
            scope,
            plan,
            'drive',
            failed: true,
            snapshotId: artifact.id,
          );
          return true;
        }
        await _saveAttempt(
          scope,
          plan,
          'drive',
          failed: false,
          snapshotId: artifact.id,
          verifiedAtUs: verified,
        );
        return true;
      });
    } finally {
      _running.remove(scope);
    }
  }

  bool _retryReady(_BackupAttempt? attempt) =>
      attempt == null ||
      !attempt.failed ||
      (_now - attempt.atUs).abs() >= _retry.inMicroseconds;

  Future<_BackupPlan?> _plan(String scope) async {
    final raw = await _store.read(scope);
    if (raw == null) return null;
    final data = jsonDecode(raw) as Map<String, Object?>;
    final id = data['id']! as String, start = data['start_us']! as int;
    if (!Uuid.isValidUUID(fromString: id) || start < 1) throw _invalid;
    return _BackupPlan(
      id,
      BackupCadence.values.byName(data['cadence']! as String),
      start,
      data['recovery']! as String,
      data['drive'] as String?,
    );
  }

  Future<_BackupAttempt?> _attempt(
    String scope,
    _BackupPlan plan,
    String kind,
  ) async {
    final raw = await _store.read('$scope.${plan.id}.$kind');
    if (raw == null) return null;
    final data = jsonDecode(raw) as Map<String, Object?>;
    return _BackupAttempt(
      data['at_us']! as int,
      data['failed']! as bool,
      data['snapshot'] as String?,
    );
  }

  Future<void> _saveAttempt(
    String scope,
    _BackupPlan plan,
    String kind, {
    required bool failed,
    String? snapshotId,
    int? verifiedAtUs,
  }) => _store.write(
    '$scope.${plan.id}.$kind',
    jsonEncode({
      'at_us': verifiedAtUs ?? _now,
      'failed': failed,
      'snapshot': snapshotId,
    }),
  );

  Future<T> _settings<T>(Future<T> Function() work) async {
    try {
      return await work();
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw _invalid;
    }
  }
}
