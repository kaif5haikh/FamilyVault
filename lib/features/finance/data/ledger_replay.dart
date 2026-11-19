import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/sync/canonical_json.dart';
import '../../../core/sync/database_record.dart';
import '../../../core/sync/sync_protocol.dart';

part 'ledger_module_replay.dart';

/// Replays a server-accepted finance operation using the same local constraints.
/// The caller owns the transaction and commits the cursor with the resulting rows.
final class LedgerReplay {
  const LedgerReplay(this.db, this.familyId);
  final AppDatabase db;
  final String familyId;

  Future<void> apply(SyncChange change) async {
    final envelope = change.envelope;
    if (envelope.familyId != familyId) throw syncIntegrityFailure;
    final record = envelope.record;
    SyncJson? before;
    switch (envelope.entityType) {
      case 'account':
        before = await _account(record, envelope.baseRevision);
        if (envelope.hasBundle) {
          final rows = envelope.bundle['journals'] as List<Object?>;
          await _postJournal(syncObject(rows.single));
        }
      case 'journal':
        await _postJournal(record);
      case 'journal_reversal':
        await _cancel(change, syncObject(envelope.bundle['original']), record);
      case 'journal_correction':
        final reversal = syncObject(envelope.bundle['reversal']);
        await _cancel(
          change,
          syncObject(envelope.bundle['original']),
          reversal,
        );
        await _audit(change, 'journal', reversal, action: 'post');
        await _postJournal(record);
      case 'budget':
        before = await _budget(record, envelope.baseRevision);
      case 'reconciliation':
        final check = readDatabaseRecord(record, ReconciliationCheck.fromJson);
        await db.into(db.reconciliationChecks).insert(check);
        if (envelope.hasBundle) {
          await _postJournal(syncObject(envelope.bundle['adjustment']));
        }
      case 'asset':
        before = await _asset(change);
      case 'debt':
        before = await _debt(change);
      case 'business':
        before = await _business(change);
      case 'stock':
        before = await _stock(change);
      default:
        throw syncIntegrityFailure;
    }
    final fact = envelope.hasBundle
        ? {...record, '_bundle': envelope.bundle}
        : record;
    await _audit(
      change,
      envelope.entityType,
      fact,
      before: before,
      action:
          before?['deleted_at_us'] != null && record['deleted_at_us'] == null
          ? 'restore'
          : null,
    );
  }

  Future<SyncJson?> _account(SyncJson raw, int base) async {
    final updated = readDatabaseRecord(raw, LedgerAccount.fromJson);
    final old = await (db.select(
      db.ledgerAccounts,
    )..where((t) => t.id.equals(updated.id))).getSingleOrNull();
    if (updated.familyId != familyId ||
        updated.systemAccount ||
        updated.revision != base + 1) {
      throw syncIntegrityFailure;
    }
    if ((old?.revision ?? 0) != base) throw SyncReplayConflict(updated.id, raw);
    await db
        .into(db.ledgerAccounts)
        .insertOnConflictUpdate(updated.toCompanion(false));
    return old == null ? null : databaseRecord(old);
  }

  Future<SyncJson?> _budget(SyncJson raw, int base) async {
    final updated = readDatabaseRecord(raw, MonthlyBudget.fromJson);
    final old = await (db.select(
      db.monthlyBudgets,
    )..where((t) => t.id.equals(updated.id))).getSingleOrNull();
    if (updated.familyId != familyId || updated.revision != base + 1) {
      throw syncIntegrityFailure;
    }
    if ((old?.revision ?? 0) != base) throw SyncReplayConflict(updated.id, raw);
    if (updated.deletedAtUs == null) {
      final active =
          await (db.select(db.monthlyBudgets)..where(
                (t) =>
                    t.familyId.equals(familyId) &
                    t.accountId.equals(updated.accountId) &
                    t.month.equals(updated.month) &
                    t.deletedAtUs.isNull(),
              ))
              .getSingleOrNull();
      if (active != null && active.id != updated.id) {
        throw SyncReplayConflict(active.id, raw);
      }
    }
    await db
        .into(db.monthlyBudgets)
        .insertOnConflictUpdate(updated.toCompanion(false));
    return old == null ? null : databaseRecord(old);
  }

  LedgerJournal _journal(SyncJson raw) {
    final fields = Map<String, Object?>.of(raw)..remove('postings');
    final journal = readDatabaseRecord(fields, LedgerJournal.fromJson);
    if (journal.familyId != familyId || journal.status != 'posted') {
      throw syncIntegrityFailure;
    }
    return journal;
  }

  Future<void> _postJournal(SyncJson raw) async {
    final journal = _journal(raw);
    final existing = await (db.select(
      db.ledgerJournals,
    )..where((t) => t.id.equals(journal.id))).getSingleOrNull();
    if (existing != null) throw SyncReplayConflict(journal.id, raw);
    if (journal.revision != 1 || journal.deletedAtUs != null) {
      throw syncIntegrityFailure;
    }
    final postings = [
      for (final rawPosting in raw['postings'] as List<Object?>)
        readDatabaseRecord(syncObject(rawPosting), LedgerPosting.fromJson),
    ];
    if (postings.any(
      (row) => row.familyId != familyId || row.journalId != journal.id,
    )) {
      throw syncIntegrityFailure;
    }
    await db.into(db.ledgerJournals).insert(journal.copyWith(status: 'draft'));
    await db.batch((batch) => batch.insertAll(db.ledgerPostings, postings));
    await (db.update(db.ledgerJournals)..where((t) => t.id.equals(journal.id)))
        .write(const LedgerJournalsCompanion(status: Value('posted')));
  }

  Future<void> _cancel(
    SyncChange change,
    SyncJson originalAfter,
    SyncJson reversal, {
    int? originalBase,
  }) async {
    final updated = _journal(originalAfter);
    final old = await (db.select(
      db.ledgerJournals,
    )..where((t) => t.id.equals(updated.id))).getSingleOrNull();
    if (old == null ||
        old.revision != (originalBase ?? change.envelope.baseRevision) ||
        old.deletedAtUs != null) {
      throw SyncReplayConflict(updated.id, originalAfter);
    }
    if (updated.revision != old.revision + 1 ||
        updated.deletedAtUs == null ||
        reversal['reverses_id'] != old.id) {
      throw syncIntegrityFailure;
    }
    await _postJournal(reversal);
    await (db.update(
      db.ledgerJournals,
    )..where((t) => t.id.equals(updated.id))).write(updated);
    final before = {
      ...databaseRecord(old),
      'postings': originalAfter['postings'],
    };
    await _audit(
      change,
      'journal',
      originalAfter,
      before: before,
      action: 'reverse',
    );
  }

  Future<void> _audit(
    SyncChange change,
    String type,
    SyncJson after, {
    SyncJson? before,
    String? action,
  }) async {
    final envelope = change.envelope;
    await db
        .into(db.localAuditEvents)
        .insert(
          LocalAuditEventsCompanion.insert(
            id: const Uuid().v4(),
            familyId: familyId,
            actorId: envelope.actorId,
            deviceId: envelope.deviceId,
            operationId: envelope.operationId,
            entityType: type,
            entityId: after['id']! as String,
            action:
                action ??
                (envelope.fields['mutation_kind'] == 'delete'
                    ? 'delete'
                    : before == null
                    ? 'create'
                    : 'update'),
            beforeJson: Value(before == null ? null : canonicalJson(before)),
            afterJson: Value(canonicalJson(after)),
            createdAtUs: change.acceptedAtUs,
          ),
        );
  }
}
