import 'dart:math';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../database/app_database.dart';
import '../errors/app_failure.dart';
import '../security/vault_identity.dart';
import 'canonical_json.dart';
import 'sync_protocol.dart';

/// One coordinator is owned by an unlocked cloud session. A due retry always
/// uses the original bytes, even after a crash during delivery.
final class SyncCoordinator {
  SyncCoordinator({
    required this.db,
    required this.identity,
    required this.transport,
    required this.apply,
    this.refreshAccess,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  final AppDatabase db;
  final VaultIdentity identity;
  final SyncTransport transport;
  final Future<void> Function(SyncChange) apply;
  final Future<void> Function()? refreshAccess;
  final DateTime Function() _clock;
  final _jitter = Random();
  Future<void>? _running;
  bool _stopped = false;
  int get _now => _clock().toUtc().microsecondsSinceEpoch;

  Future<void> run() =>
      _running ??= _synchronize().whenComplete(() => _running = null);

  /// Populate a fresh projection from accepted history before publishing it.
  Future<void> replayAll() =>
      _running ??= _synchronize(rebuild: true)
          .whenComplete(() => _running = null);

  Future<void> stop() async {
    _stopped = true;
    try {
      await _running;
    } on AppFailure {
      // No completion is reported during lock. Leases can be retried later.
    }
  }

  void _checkLive() {
    if (_stopped || !identity.isCloud) {
      throw const AppFailure(
        FailureCode.locked,
        'Unlock a family device to sync.',
      );
    }
  }

  Future<void> _synchronize({bool rebuild = false}) async {
    _checkLive();
    try {
      await refreshAccess?.call();
      _checkLive();
      AppFailure? blocked;
      for (var count = 0; !rebuild && count < 64; count++) {
        try {
          final row = await _claim();
          if (row == null) break;
          await _deliver(row);
        } on AppFailure catch (error) {
          if (error.code != FailureCode.conflict &&
              error.code != FailureCode.validation) {
            rethrow;
          }
          // A stale write must never stop the server's history from being
          // fetched for conflict review before a later attempt.
          blocked = error;
          break;
        }
      }
      await _pull(maxPages: rebuild ? null : 10);
      if (blocked != null) throw blocked;
    } on SyncReplayConflict catch (error) {
      await _recordConflict(error.localEntityId, error.serverRecord);
      throw const AppFailure(
        FailureCode.conflict,
        'A shared record changed. Review the conflicting edits.',
      );
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw syncIntegrityFailure;
    }
  }

  Future<PendingMutation?> _claim() => db.transaction(() async {
    _checkLive();
    // These rows are append-only. Use insertion order even when timestamps tie.
    final result = await db
        .customSelect(
          "SELECT * FROM pending_mutations WHERE family_id = ? AND state <> 'acknowledged' ORDER BY rowid LIMIT 1",
          variables: [Variable(identity.familyId)],
          readsFrom: {db.pendingMutations},
        )
        .getSingleOrNull();
    if (result == null) return null;
    final row = db.pendingMutations.map(result.data);
    if (row.state == 'conflicted' || row.state == 'rejected') {
      throw const AppFailure(
        FailureCode.conflict,
        'Review the blocked family change before sending later records.',
      );
    }
    final now = _now;
    if ((row.leaseExpiresAtUs ?? 0) > now || (row.nextAttemptAtUs ?? 0) > now) {
      return null;
    }
    await _write(
      row.operationId,
      PendingMutationsCompanion(
        state: const Value('in_flight'),
        attempts: Value(row.attempts + 1),
        nextAttemptAtUs: const Value(null),
        leaseExpiresAtUs: Value(
          now + const Duration(minutes: 1).inMicroseconds,
        ),
      ),
    );
    return row;
  });

  Future<void> _deliver(PendingMutation row) async {
    try {
      final envelope = SyncEnvelope.verify(row.payloadJson, row.payloadDigest);
      if (envelope.operationId != row.operationId ||
          envelope.actorId != identity.memberId ||
          envelope.familyId != identity.familyId ||
          envelope.deviceId != identity.deviceId ||
          envelope.entityType != row.entityType ||
          envelope.entityId != row.entityId ||
          envelope.baseRevision != row.baseRevision) {
        throw syncIntegrityFailure;
      }
      _checkLive();
      final receipt = await transport.push(envelope);
      _checkLive();
      receipt.verify(envelope);
      final cursor = await _cursor();
      if (receipt.sequence <= cursor) throw syncIntegrityFailure;
      await _acknowledge(receipt);
    } on AppFailure catch (error) {
      if (_stopped) rethrow;
      final state = switch (error.code) {
        FailureCode.conflict => 'conflicted',
        FailureCode.validation => 'rejected',
        _ => 'pending',
      };
      final delay = Duration(
        seconds: (1 << min(row.attempts, 8)) + _jitter.nextInt(4),
      );
      await _write(
        row.operationId,
        PendingMutationsCompanion(
          state: Value(state),
          leaseExpiresAtUs: const Value(null),
          nextAttemptAtUs: Value(
            state == 'pending' ? _now + delay.inMicroseconds : null,
          ),
        ),
      );
      rethrow;
    }
  }

  Future<int> _cursor() async =>
      (await (db.select(db.syncCheckpoints)
                ..where((t) => t.familyId.equals(identity.familyId)))
              .getSingleOrNull())
          ?.lastSequence ??
      0;

  Future<void> _pull({required int? maxPages}) async {
    for (
      var pageIndex = 0;
      maxPages == null || pageIndex < maxPages;
      pageIndex++
    ) {
      _checkLive();
      final cursor = await _cursor();
      final page = await transport.pull(cursor);
      _checkLive();
      page.verifyAfter(cursor, identity.familyId);
      if (page.changes.isEmpty) return;
      var latest = cursor;
      await db.transaction(() async {
        for (final change in page.changes) {
          final receipt = change.receipt;
          final local =
              await (db.select(db.pendingMutations)
                    ..where((t) => t.operationId.equals(receipt.operationId)))
                  .getSingleOrNull();
          if (local == null) {
            await apply(change);
          } else {
            if (local.payloadJson != change.envelope.raw ||
                local.payloadDigest != receipt.digest ||
                local.acceptedRevision != null &&
                    local.acceptedRevision != receipt.sequence) {
              throw syncIntegrityFailure;
            }
            await _acknowledge(receipt);
          }
          latest = receipt.sequence;
        }
        await db
            .into(db.syncCheckpoints)
            .insertOnConflictUpdate(
              SyncCheckpointsCompanion.insert(
                familyId: identity.familyId,
                updatedAtUs: _now,
                lastSequence: Value(latest),
              ),
            );
      });
      if (latest == page.watermark) return;
    }
  }

  /// Retains a verified competing snapshot without moving the replay cursor.
  Future<void> _recordConflict(
    String localEntityId,
    SyncJson serverRecord,
  ) async {
    final result = await db
        .customSelect(
          '''
      SELECT * FROM pending_mutations WHERE family_id = ? AND state <> 'acknowledged'
      AND (entity_id = ? OR json_extract(payload_json, '\$.bundle.original.id') = ?)
      ORDER BY rowid LIMIT 1
      ''',
          variables: [
            Variable(identity.familyId),
            Variable(localEntityId),
            Variable(localEntityId),
          ],
          readsFrom: {db.pendingMutations},
        )
        .getSingleOrNull();
    final local = result == null ? null : db.pendingMutations.map(result.data);
    final revision = serverRecord['revision'];
    if (local == null || revision is! int || revision < 1) return;
    await db.transaction(() async {
      final prior =
          await (db.select(db.syncConflicts)
                ..where((t) => t.operationId.equals(local.operationId)))
              .getSingleOrNull();
      if (prior == null) {
        await db
            .into(db.syncConflicts)
            .insert(
              SyncConflictsCompanion.insert(
                id: const Uuid().v4(),
                operationId: local.operationId,
                serverRevision: revision,
                serverSnapshotJson: canonicalJson(serverRecord),
                detectedAtUs: _now,
              ),
            );
      }
      await _write(
        local.operationId,
        const PendingMutationsCompanion(
          state: Value('conflicted'),
          nextAttemptAtUs: Value(null),
          leaseExpiresAtUs: Value(null),
        ),
      );
    });
  }

  Future<void> _acknowledge(SyncReceipt receipt) => _write(
    receipt.operationId,
    PendingMutationsCompanion(
      state: const Value('acknowledged'),
      acceptedRevision: Value(receipt.sequence),
      leaseExpiresAtUs: const Value(null),
      nextAttemptAtUs: const Value(null),
    ),
  );

  Future<void> _write(
    String operationId,
    PendingMutationsCompanion value,
  ) async {
    final count =
        await (db.update(db.pendingMutations)..where(
              (t) =>
                  t.operationId.equals(operationId) &
                  t.familyId.equals(identity.familyId),
            ))
            .write(value);
    if (count != 1) throw syncIntegrityFailure;
  }
}
