import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/localization/vault_strings.dart';
import '../../app/vault_providers.dart';
import '../../core/database/app_database.dart';
import '../../core/errors/app_failure.dart';
import '../../core/security/vault_lifecycle.dart';
import '../../shared/widgets/vault_widgets.dart';
import '../foundation/foundation_pages.dart' show VaultPage;
import 'cloud_cache.dart';
import 'cloud_connection.dart';
import 'cloud_providers.dart';

typedef _SavedChange = ({PendingMutation local, SyncConflict? competing});

class SyncRecoveryPage extends ConsumerStatefulWidget {
  const SyncRecoveryPage({super.key});
  @override
  ConsumerState<SyncRecoveryPage> createState() => _SyncRecoveryPageState();
}

class _SyncRecoveryPageState extends ConsumerState<SyncRecoveryPage> {
  late Future<({List<_SavedChange> blocked, List<_SavedChange> retained})>
  _review;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _review = _load();
  }

  Future<CloudWorkspaceCache> _cache() async {
    final root = ref.read(vaultLifecycleProvider).root;
    return CloudWorkspaceCache(
      await ref.read(cloudRegistrationProvider.future),
      root: root,
    );
  }

  Future<({List<_SavedChange> blocked, List<_SavedChange> retained})>
  _load() async {
    final session = ref.read(vaultProvider).session;
    if (session == null || session.closed || !session.identity.isCloud) {
      return (blocked: <_SavedChange>[], retained: <_SavedChange>[]);
    }
    final db = session.db;
    final conflicts = {
      for (final row in await db.select(db.syncConflicts).get())
        row.operationId: row,
    };
    final pending = await db.select(db.pendingMutations).get();
    return (
      blocked: [
        for (final row in pending)
          if (row.state == 'conflicted' || row.state == 'rejected')
            (local: row, competing: conflicts[row.operationId]),
      ],
      retained: await (await _cache()).savedChanges(session),
    );
  }

  Future<void> _useShared(VaultSession session) async {
    final replace = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Keep the family’s version?')),
        content: Text(
          context.tr(
            'FamilyVault will fetch the accepted family records. Changes waiting on this device will stay encrypted in Changes saved on this phone.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.tr('Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.tr('Use family records')),
          ),
        ],
      ),
    );
    if (replace != true || !mounted || session.closed) return;
    setState(() => _busy = true);
    final controller = ref.read(vaultProvider.notifier);
    final identity = session.identity;
    try {
      final cache = await _cache();
      await controller.lock();
      await controller.openConnected(
        () => connectFamily(
          cache: cache,
          familyId: identity.familyId,
          memberId: identity.memberId,
          expectedDevice: identity.deviceId,
          rebuild: true,
          onRevoked: (error) => controller.lock(reason: error),
        ),
      );
    } on AppFailure catch (error) {
      await controller.lock(reason: error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(vaultProvider).session;
    return VaultPage(
      title: context.tr('Changes saved on this phone'),
      children: [
        FutureBuilder<
          ({List<_SavedChange> blocked, List<_SavedChange> retained})
        >(
          future: _review,
          builder: (context, snapshot) {
            if (snapshot.hasError) return FailureNotice(snapshot.error!);
            final data = snapshot.data;
            if (data == null) {
              return const Center(child: CircularProgressIndicator());
            }
            final canRebuild =
                session != null &&
                (data.blocked.isNotEmpty ||
                    session.sync?.status.failure?.code == FailureCode.conflict);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (canRebuild) ...[
                  SectionHeading(context.tr('Changes to review')),
                  for (final row in data.blocked) _SavedChangeTile(row),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _useShared(session),
                    icon: const Icon(Icons.restore),
                    label: Text(context.tr('Use family records')),
                  ),
                ],
                if (data.retained.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  SectionHeading(
                    context.tr('Earlier changes from this device'),
                  ),
                  for (final row in data.retained) _SavedChangeTile(row),
                ],
                if (!canRebuild && data.retained.isEmpty)
                  Text(context.tr('There are no saved changes to review.')),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SavedChangeTile extends StatelessWidget {
  const _SavedChangeTile(this.row);
  final _SavedChange row;

  @override
  Widget build(BuildContext context) {
    const format = JsonEncoder.withIndent('  ');
    final envelope = jsonDecode(row.local.payloadJson) as Map<String, Object?>;
    final record = envelope['record'] as Map<String, Object?>;
    final label =
        record['name'] ??
        record['description'] ??
        record['notes'] ??
        record['month'];
    final shared = row.competing;
    return Card.outlined(
      child: ExpansionTile(
        title: Text(
          label is String ? label : row.local.entityType.replaceAll('_', ' '),
        ),
        subtitle: Text(context.tr('Saved on this phone')),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.tr('Device entry')),
          Text(format.convert(record)),
          if (shared != null) ...[
            const SizedBox(height: 12),
            Text(context.tr('Accepted family entry')),
            Text(format.convert(jsonDecode(shared.serverSnapshotJson))),
          ],
        ],
      ),
    );
  }
}
