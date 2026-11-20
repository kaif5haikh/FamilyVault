import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/vault_providers.dart';
import '../../core/database/app_database.dart';
import '../../core/localization/vault_strings.dart';
import '../../shared/widgets/vault_widgets.dart';
import '../foundation/foundation_pages.dart';
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

final _familyNameProvider = StreamProvider.autoDispose<String?>((ref) {
  final session = ref.watch(vaultProvider).session;
  if (session == null || session.closed) return const Stream.empty();
  final db = session.db;
  return (db.select(db.familySpaces)
        ..where((row) => row.id.equals(session.identity.familyId)))
      .watchSingleOrNull()
      .map((row) => row?.name);
});

bool _canManage(List<FamilyMember> members, String memberId) => members.any(
  (member) =>
      member.id == memberId && member.active && member.role == 'administrator',
);

class FamilyPage extends ConsumerWidget {
  const FamilyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(vaultProvider).session;
    if (session == null || session.closed) return const SizedBox.shrink();
    final strings = VaultStrings.of(context);
    final identity = session.identity;
    final shared = identity.isCloud;
    final configured = ref.watch(cloudConfigProvider).cloudConfigured;
    final name =
        ref.watch(_familyNameProvider).asData?.value ?? strings.text('family');
    return VaultContent(
      maxWidth: 680,
      children: [
        Card.filled(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const VaultIcon(icon: Icons.group_outlined),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 4),
                      Text(
                        strings.text(
                          shared ? 'familySpaceHelp' : 'localFamilyHelp',
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ref
            .watch(_familyMembersProvider)
            .when(
              loading: () => const LinearProgressIndicator(),
              error: (error, _) => FailureNotice(error),
              data: (members) {
                final mayManage =
                    shared && _canManage(members, identity.memberId);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (mayManage)
                      FilledButton.icon(
                        onPressed: () =>
                            context.push('/family/manage?invite=1'),
                        icon: const Icon(Icons.person_add_alt_outlined),
                        label: Text(strings.text('addFamilyMember')),
                      ),
                    const SizedBox(height: 12),
                    SectionHeading(strings.text('people')),
                    for (final member in members)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          child: Text(
                            member.displayName.trim().characters.firstOrNull ??
                                '?',
                          ),
                        ),
                        title: Text(member.displayName),
                        subtitle: Text(
                          [
                            if (member.id == identity.memberId)
                              strings.text('you'),
                            if (!shared) strings.text('phone'),
                            if (shared)
                              strings.text(
                                member.role == 'administrator'
                                    ? 'familyManager'
                                    : 'familyMember',
                              ),
                            if (shared)
                              strings.text(
                                member.active
                                    ? 'familyHasAccess'
                                    : 'accessEnded',
                              ),
                          ].join(' · '),
                        ),
                      ),
                    if (shared)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(strings.text('familyRolesHelp')),
                      ),
                    if (mayManage)
                      VaultLink(
                        icon: Icons.devices_outlined,
                        title: strings.text('familyInvitesAndPhones'),
                        onTap: () => context.push('/family/manage'),
                      ),
                  ],
                );
              },
            ),
        if (!shared)
          if (configured)
            OutlinedButton.icon(
              onPressed: () async {
                final router = GoRouter.of(context);
                await ref.read(vaultProvider.notifier).lock();
                router.go('/access?join=1');
              },
              icon: const Icon(Icons.login),
              label: Text(strings.text('joinFamily')),
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

class FamilyManagementPage extends ConsumerWidget {
  const FamilyManagementPage({required this.invite, super.key});

  final bool invite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = VaultStrings.of(context);
    final session = ref.watch(vaultProvider).session;
    final identity = session?.identity;
    return VaultPage(
      title: strings.text(
        invite ? 'addFamilyMember' : 'familyInvitesAndPhones',
      ),
      children: [
        if (identity == null || !identity.isCloud)
          Text(strings.text('familyAdminOnly'))
        else
          ref
              .watch(_familyMembersProvider)
              .when(
                loading: () => const LinearProgressIndicator(),
                error: (error, _) => FailureNotice(error),
                data: (members) {
                  if (!_canManage(members, identity.memberId)) {
                    return Text(strings.text('familyAdminOnly'));
                  }
                  return ref
                      .watch(cloudGatewayProvider)
                      .when(
                        loading: () => const LinearProgressIndicator(),
                        error: (error, _) => FailureNotice(error),
                        data: (gateway) => FamilyAdminPanel(
                          key: ValueKey(identity.deviceId),
                          familyId: identity.familyId,
                          memberId: identity.memberId,
                          startsWithInvite: invite,
                          gateway: gateway,
                        ),
                      );
                },
              ),
      ],
    );
  }
}
