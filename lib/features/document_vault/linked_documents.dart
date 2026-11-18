import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/app_database.dart';
import '../../shared/widgets/vault_widgets.dart';
import 'document_inputs.dart';

class LinkedDocuments extends ConsumerWidget {
  const LinkedDocuments({this.assetId, this.journalId, super.key});
  final String? assetId, journalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(documentRepositoryProvider);
    if (repository == null) return const SizedBox.shrink();
    return StreamBuilder<List<VaultDocument>>(
      stream: repository.watchLinked(assetId: assetId, journalId: journalId),
      builder: (context, snapshot) {
        if (snapshot.hasError) return FailureNotice(snapshot.error!);
        final linked = snapshot.data;
        if (linked == null || linked.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeading('Linked documents'),
            for (final document in linked)
              ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text(document.title),
                onTap: () => context.push('/document/${document.id}'),
              ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }
}
