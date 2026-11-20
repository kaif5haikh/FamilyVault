import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/localization/vault_strings.dart';
import '../../core/database/app_database.dart';
import '../../shared/widgets/vault_widgets.dart';
import 'document_inputs.dart';

final _linkedDocumentsProvider = StreamProvider.autoDispose
    .family<List<VaultDocument>, ({String? assetId, String? journalId})>((
      ref,
      link,
    ) {
      final repository = ref.watch(documentRepositoryProvider);
      return repository?.watchLinked(
            assetId: link.assetId,
            journalId: link.journalId,
          ) ??
          const Stream.empty();
    });

class LinkedDocuments extends ConsumerWidget {
  const LinkedDocuments({this.assetId, this.journalId, super.key});
  final String? assetId, journalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(documentRepositoryProvider) == null) {
      return const SizedBox.shrink();
    }
    return ref
        .watch(
          _linkedDocumentsProvider((assetId: assetId, journalId: journalId)),
        )
        .when(
          skipLoadingOnReload: false,
          loading: () => const SizedBox.shrink(),
          error: (error, _) => FailureNotice(error),
          data: (linked) => linked.isEmpty
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeading(context.tr('Linked documents')),
                    for (final document in linked)
                      ListTile(
                        leading: const Icon(Icons.description_outlined),
                        title: Text(document.title),
                        onTap: () => context.push('/document/${document.id}'),
                      ),
                    const SizedBox(height: 16),
                  ],
                ),
        );
  }
}
