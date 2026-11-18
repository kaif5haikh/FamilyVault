import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/vault_providers.dart';
import '../../core/database/app_database.dart';
import '../../core/database/mutation_writer.dart';
import 'vault_widgets.dart';

final _auditProvider = StreamProvider.autoDispose
    .family<List<(LocalAuditEvent, String)>, String>((ref, id) {
      final session = ref.watch(vaultProvider).session;
      if (session == null || session.closed) {
        return const Stream.empty();
      }
      final db = session.db, family = session.identity.familyId;
      return db
          .customSelect(
            'SELECT 1 /* record audit projection */',
            readsFrom: {db.localAuditEvents, db.familyMembers, db.vaultDevices},
          )
          .watch()
          .asyncMap(
            (_) => storageBoundary(
              () => db.transaction(() async {
                await session.ledger.mutations.authorize();
                final query = db.select(db.localAuditEvents).join([
                  innerJoin(
                    db.familyMembers,
                    db.familyMembers.id.equalsExp(db.localAuditEvents.actorId) &
                        db.familyMembers.familyId.equalsExp(
                          db.localAuditEvents.familyId,
                        ),
                  ),
                ]);
                query.where(
                  db.localAuditEvents.familyId.equals(family) &
                      db.localAuditEvents.entityId.equals(id),
                );
                query.orderBy([
                  OrderingTerm.desc(db.localAuditEvents.createdAtUs),
                ]);
                return (await query.get())
                    .map(
                      (row) => (
                        row.readTable(db.localAuditEvents),
                        row.readTable(db.familyMembers).displayName,
                      ),
                    )
                    .toList();
              }),
            ),
          );
    });

class RecordAudit extends ConsumerWidget {
  const RecordAudit({required this.entityId, super.key});
  final String entityId;
  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(_auditProvider(entityId))
      .when(
        skipLoadingOnRefresh: false,
        skipLoadingOnReload: false,
        loading: () => const LinearProgressIndicator(),
        error: (e, _) => FailureNotice(e),
        data: (rows) => ExpansionTile(
          title: const Text('Change audit'),
          subtitle: Text('${rows.length} retained events'),
          children: [
            for (final (row, member) in rows)
              ListTile(
                title: Text('$member · ${row.action}'),
                subtitle: Text(
                  DateFormat('d MMM y, HH:mm', 'en_IN').format(
                    DateTime.fromMicrosecondsSinceEpoch(
                      row.createdAtUs,
                      isUtc: true,
                    ).toLocal(),
                  ),
                ),
              ),
          ],
        ),
      );
}
