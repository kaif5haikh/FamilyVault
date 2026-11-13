import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../errors/app_failure.dart';
import '../security/vault_identity.dart';
import '../sync/canonical_json.dart';
import 'app_database.dart';

/// Must be used inside the same transaction as the corresponding domain write.
/// Offline workspaces retain their outbox for recovery; they never claim sync.
final class MutationWriter {
  MutationWriter(this.db, this.identity, {DateTime Function()? clock})
    : clock = clock ?? DateTime.now;
  final AppDatabase db;
  final VaultIdentity identity;
  final DateTime Function() clock;
  static const uuid = Uuid();
  int get now => clock().toUtc().microsecondsSinceEpoch;

  Future<void> authorize({bool administrator = false}) async {
    final member =
        await (db.select(db.familyMembers)..where(
              (t) =>
                  t.id.equals(identity.memberId) &
                  t.familyId.equals(identity.familyId) &
                  t.active.equals(true),
            ))
            .getSingleOrNull();
    final device =
        await (db.select(db.vaultDevices)..where(
              (t) =>
                  t.id.equals(identity.deviceId) &
                  t.familyId.equals(identity.familyId) &
                  t.memberId.equals(identity.memberId) &
                  t.state.equals('enrolled'),
            ))
            .getSingleOrNull();
    if (member == null ||
        device == null ||
        (administrator && member.role != 'administrator')) {
      throw const AppFailure(
        FailureCode.unauthorized,
        'This account or device is not authorized.',
      );
    }
  }

  Future<PendingMutation?> existing(String operationId, String command) async {
    final row = await (db.select(
      db.pendingMutations,
    )..where((t) => t.operationId.equals(operationId))).getSingleOrNull();
    if (row != null &&
        (row.familyId != identity.familyId ||
            row.payloadJson.isEmpty ||
            (jsonDecode(row.payloadJson)
                    as Map<String, Object?>)['command_digest'] !=
                command)) {
      throw const AppFailure(
        FailureCode.conflict,
        'This operation identifier was already used for a different change.',
      );
    }
    return row;
  }

  Future<void> record({
    required String operationId,
    required String entityType,
    required String entityId,
    required String action,
    required int baseRevision,
    required Map<String, Object?> after,
    Map<String, Object?>? before,
    String? commandDigest,
    Map<String, Object?>? bundle,
  }) async {
    final body = canonicalJson({
      'protocol_version': 1,
      'operation_id': operationId,
      'family_id': identity.familyId,
      'device_id': identity.deviceId,
      'actor_id': identity.memberId,
      'entity_type': entityType,
      'entity_id': entityId,
      'mutation_kind': action == 'delete' ? 'delete' : 'upsert',
      'base_revision': baseRevision,
      'command_digest': commandDigest,
      'record': after,
      'bundle': ?bundle,
    });
    await db
        .into(db.pendingMutations)
        .insert(
          PendingMutationsCompanion.insert(
            operationId: operationId,
            familyId: identity.familyId,
            deviceId: identity.deviceId,
            entityType: entityType,
            entityId: entityId,
            mutationKind: action == 'delete' ? 'delete' : 'upsert',
            baseRevision: baseRevision,
            payloadJson: body,
            payloadDigest: payloadDigest(body),
            protocolVersion: 1,
            createdAtUs: now,
          ),
        );
    await audit(
      operationId: operationId,
      entityType: entityType,
      entityId: entityId,
      action: action,
      before: before,
      after: after,
    );
  }

  Future<void> audit({
    required String operationId,
    required String entityType,
    required String entityId,
    required String action,
    Map<String, Object?>? before,
    Map<String, Object?>? after,
  }) async {
    await db
        .into(db.localAuditEvents)
        .insert(
          LocalAuditEventsCompanion.insert(
            id: uuid.v4(),
            familyId: identity.familyId,
            actorId: identity.memberId,
            deviceId: identity.deviceId,
            operationId: operationId,
            entityType: entityType,
            entityId: entityId,
            action: action,
            beforeJson: Value(before == null ? null : canonicalJson(before)),
            afterJson: Value(after == null ? null : canonicalJson(after)),
            createdAtUs: now,
          ),
        );
  }
}

Future<T> storageBoundary<T>(Future<T> Function() action) async {
  try {
    return await action();
  } on AppFailure {
    rethrow;
  } catch (_, stack) {
    // SQL errors may contain complete rows or keys. Preserve a stack, not input.
    Error.throwWithStackTrace(
      const AppFailure(
        FailureCode.storage,
        'The change could not be saved. Your previous records are safe.',
      ),
      stack,
    );
  }
}
