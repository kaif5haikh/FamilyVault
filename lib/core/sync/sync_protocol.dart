import 'dart:convert';

import '../errors/app_failure.dart';
import 'canonical_json.dart';

typedef SyncJson = Map<String, Object?>;

const syncIntegrityFailure = AppFailure(
  FailureCode.integrity,
  'The sync response could not be verified. Your local records are still saved.',
);

final _uuid = RegExp(r'^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$');
final _digest = RegExp(r'^[0-9a-f]{64}$');

SyncJson syncObject(Object? value) {
  if (value is SyncJson) return value;
  throw syncIntegrityFailure;
}

String _checkedString(Object? value, RegExp pattern) {
  if (value is String && pattern.hasMatch(value)) return value;
  throw syncIntegrityFailure;
}

int _checkedInt(Object? value, int minimum) {
  if (value is int && value >= minimum) return value;
  throw syncIntegrityFailure;
}

/// The original JSON bytes and their SHA-256 are retained across both directions.
final class SyncEnvelope {
  SyncEnvelope._(this.raw, this.digest, this.fields);

  factory SyncEnvelope.verify(String raw, String digest) {
    if (utf8.encode(raw).length > 524288 || payloadDigest(raw) != digest) {
      throw syncIntegrityFailure;
    }
    try {
      final fields = syncObject(jsonDecode(raw));
      // Reject non-integer numeric types throughout the payload on Dart too.
      canonicalJson(fields);
      final result = SyncEnvelope._(raw, digest, fields);
      if (fields['protocol_version'] is! int ||
          fields['protocol_version'] != 1 ||
          result.record['id'] != result.entityId ||
          result.record['family_id'] != result.familyId ||
          result.baseRevision == 9223372036854775807 ||
          !['upsert', 'delete'].contains(fields['mutation_kind'])) {
        throw syncIntegrityFailure;
      }
      _checkedString(fields['operation_id'], _uuid);
      _checkedString(fields['actor_id'], _uuid);
      _checkedString(fields['device_id'], _uuid);
      _checkedString(fields['entity_type'], RegExp(r'^[a-z_]{1,40}$'));
      return result;
    } catch (_) {
      throw syncIntegrityFailure;
    }
  }

  final String raw, digest;
  final SyncJson fields;
  String get operationId => _checkedString(fields['operation_id'], _uuid);
  String get familyId => _checkedString(fields['family_id'], _uuid);
  String get actorId => _checkedString(fields['actor_id'], _uuid);
  String get deviceId => _checkedString(fields['device_id'], _uuid);
  String get entityId => _checkedString(fields['entity_id'], _uuid);
  String get entityType => fields['entity_type']! as String;
  int get baseRevision => _checkedInt(fields['base_revision'], 0);
  SyncJson get record => syncObject(fields['record']);
  SyncJson get bundle => syncObject(fields['bundle']);
  bool get hasBundle => fields['bundle'] != null;

  @override
  String toString() => 'SyncEnvelope([redacted])';
}

final class SyncReceipt {
  SyncReceipt.fromJson(SyncJson value)
    : operationId = _checkedString(value['operation_id'], _uuid),
      digest = _checkedString(value['payload_digest'], _digest),
      sequence = _checkedInt(value['sequence'], 1);

  final String operationId, digest;
  final int sequence;

  void verify(SyncEnvelope envelope) {
    if (operationId != envelope.operationId || digest != envelope.digest) {
      throw syncIntegrityFailure;
    }
  }
}

final class SyncChange {
  SyncChange.fromJson(SyncJson value)
    : receipt = SyncReceipt.fromJson(value),
      acceptedAtUs = _checkedInt(value['accepted_at_us'], 0),
      envelope = SyncEnvelope.verify(
        value['payload_json'] is String ? value['payload_json']! as String : '',
        _checkedString(value['payload_digest'], _digest),
      ) {
    receipt.verify(envelope);
  }

  final SyncReceipt receipt;
  final int acceptedAtUs;
  final SyncEnvelope envelope;
}

final class SyncPage {
  SyncPage.fromJson(SyncJson value)
    : watermark = _checkedInt(value['watermark'], 0),
      changes = switch (value['changes']) {
        final List<Object?> rows when rows.length <= 100 => List.unmodifiable(
          rows.map((row) => SyncChange.fromJson(syncObject(row))),
        ),
        _ => throw syncIntegrityFailure,
      };

  final int watermark;
  final List<SyncChange> changes;

  void verifyAfter(int cursor, String familyId) {
    if (watermark < cursor || changes.isEmpty && watermark > cursor) {
      throw syncIntegrityFailure;
    }
    for (final change in changes) {
      if (change.receipt.sequence != ++cursor ||
          cursor > watermark ||
          change.envelope.familyId != familyId) {
        throw syncIntegrityFailure;
      }
    }
  }
}

abstract interface class SyncTransport {
  Future<SyncReceipt> push(SyncEnvelope envelope);
  Future<SyncPage> pull(int after);
}

/// An accepted change overlaps an unconfirmed optimistic revision.
final class SyncReplayConflict implements Exception {
  const SyncReplayConflict(this.localEntityId, this.serverRecord);
  final String localEntityId;
  final SyncJson serverRecord;
}
