import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/vault_providers.dart';
import '../../core/database/app_database.dart';
import '../../core/localization/vault_strings.dart';
import '../../core/security/vault_identity.dart';
import '../../shared/widgets/vault_widgets.dart';
import 'cloud_providers.dart';
import 'family_admin_panel.dart';

final _familyMembersProvider = StreamProvider.autoDispose<List<FamilyMember>>((
  ref,
) {
  final session = ref.watch(vaultProvider).session;
  if (session == null || session.closed) return const Stream.empty();
  final db = session.db;
  return (db.select(db.familyMembers)
        ..where((row) => row.familyId.equals(session.identity.familyId))
        ..orderBy([(row) => OrderingTerm.asc(row.displayName)]))
      .watch();
});

class FamilyPage extends ConsumerWidget {
  const FamilyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(vaultProvider).session;
    if (session == null || session.closed) return const SizedBox.shrink();
    final strings = VaultStrings.of(context);
    final identity = session.identity;
    final shared = identity.isCloud;
    final config = ref.watch(cloudConfigProvider);
    return VaultContent(
      maxWidth: 680,
      children: [
        Card.filled(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                VaultIcon(
                  icon: shared
                      ? Icons.group_outlined
                      : Icons.phone_android_outlined,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.text(shared ? 'sharedFamily' : 'localOnly'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        strings.text(
                          shared ? 'sharedFamilyHelp' : 'localFamilyHelp',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        SectionHeading(strings.text('people')),
        ref
            .watch(_familyMembersProvider)
            .when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => FailureNotice(error),
              data: (members) {
                final mayManage =
                    shared &&
                    members.any(
                      (member) =>
                          member.id == identity.memberId &&
                          member.active &&
                          member.role == 'administrator',
                    );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final member in members)
                      ListTile(
                        leading: const Icon(Icons.person_outline),
                        title: Text(member.displayName),
                        subtitle: Text(
                          [
                            if (member.id == identity.memberId)
                              strings.text('you'),
                            if (shared)
                              strings.text(
                                member.role == 'administrator'
                                    ? 'familyManager'
                                    : 'familyMember',
                              ),
                            if (!member.active) strings.text('accessEnded'),
                            if (!shared && member.id == identity.memberId)
                              strings.text('phone'),
                          ].join(' · '),
                        ),
                      ),
                    if (shared) Text(strings.text('managedAccess')),
                    if (mayManage)
                      ExpansionTile(
                        title: Text(strings.text('manageFamily')),
                        children: [_FamilyControls(identity: identity)],
                      ),
                  ],
                );
              },
            ),
        const SizedBox(height: 16),
        if (!shared)
          if (config.cloudConfigured)
            OutlinedButton.icon(
              onPressed: ref.read(vaultProvider.notifier).lock,
              icon: const Icon(Icons.lock_outline),
              label: Text(strings.text('lockToJoin')),
            )
          else
            Text(strings.text('familyUnavailable')),
        const SizedBox(height: 12),
        VaultLink(
          icon: Icons.help_outline,
          title: strings.text('help'),
          onTap: () => context.push('/help/invite'),
        ),
      ],
    );
  }
}

class _FamilyControls extends ConsumerWidget {
  const _FamilyControls({required this.identity});

  final VaultIdentity identity;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(cloudGatewayProvider)
      .when(
        loading: () => const LinearProgressIndicator(),
        error: (error, _) => FailureNotice(error),
        data: (gateway) => FamilyAdminPanel(
          key: ValueKey(identity.deviceId),
          familyId: identity.familyId,
          memberId: identity.memberId,
          gateway: gateway,
        ),
      );
}
