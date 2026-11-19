import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/app_database.dart';
import '../../core/errors/app_failure.dart';
import '../../core/sync/live_sync.dart';
import '../../shared/widgets/vault_widgets.dart';
import '../finance/data/ledger_repository.dart';
import '../foundation/foundation_pages.dart' show VaultPage;
import 'document_inputs.dart';
import 'document_repository.dart';

String categoryLabel(DocumentCategory category) => switch (category) {
  DocumentCategory.aadhaar => 'Aadhaar',
  DocumentCategory.pan => 'PAN',
  DocumentCategory.passport => 'Passport',
  DocumentCategory.drivingLicence => 'Driving licence',
  DocumentCategory.voterId => 'Voter ID',
  DocumentCategory.property => 'Property and land',
  DocumentCategory.utilities => 'Utility bills',
  DocumentCategory.education => 'Education',
  DocumentCategory.medical => 'Medical',
  DocumentCategory.insurance => 'Insurance',
  DocumentCategory.general => 'General',
};

String? expiryLabel(BuildContext context, String? expiry) {
  if (expiry == null) return null;
  final date = DateTime.parse(expiry);
  final remaining = date.difference(DateUtils.dateOnly(DateTime.now())).inDays;
  final when = MaterialLocalizations.of(context).formatMediumDate(date);
  return remaining < 0
      ? 'Expired $when'
      : remaining <= 30
      ? 'Due soon $when'
      : 'Expires $when';
}

Future<void> chooseDocument(
  BuildContext context,
  WidgetRef ref,
  DocumentRepository repository, {
  VaultDocument? versionOf,
}) async {
  final picker = await showModalBottomSheet<DocumentPicker>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.folder_open_outlined),
            title: const Text('Choose a file'),
            subtitle: const Text('PDF, JPG or PNG'),
            onTap: () => Navigator.of(context).pop(DocumentPicker.files),
          ),
          ListTile(
            leading: const Icon(Icons.document_scanner_outlined),
            title: const Text('Scan with camera'),
            onTap: () => Navigator.of(context).pop(DocumentPicker.camera),
          ),
        ],
      ),
    ),
  );
  if (picker == null || !context.mounted || repository.session.closed) return;
  try {
    final selected = await ref
        .read(documentIntakeProvider.notifier)
        .pick(
          repository.session.identity,
          picker,
          documentId: versionOf?.id,
          expectedRevision: versionOf?.revision,
        );
    if (selected != null && context.mounted && !repository.session.closed) {
      unawaited(context.push<void>('/document/import'));
    }
  } on AppFailure catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error.message)));
    }
  }
}

class DocumentsPage extends ConsumerStatefulWidget {
  const DocumentsPage({super.key});
  @override
  ConsumerState<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends ConsumerState<DocumentsPage> {
  String _search = '';
  bool _archive = false;
  DocumentCategory? _category;

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(documentRepositoryProvider);
    final selection = ref.watch(documentIntakeProvider);
    if (repository == null) return const SizedBox.shrink();
    if (repository.session.identity.isCloud && !repository.sharingAvailable) {
      return const VaultContent(
        children: [
          Text('Shared document storage is unavailable for this account.'),
        ],
      );
    }
    return VaultContent(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Document vault',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            FilledButton.icon(
              onPressed: () => chooseDocument(context, ref, repository),
              icon: const Icon(Icons.add),
              label: const Text('Add'),
            ),
          ],
        ),
        if (repository.sharingAvailable) ...[
          if (repository.session.sync case final sync?)
            StreamBuilder<SyncFeedback>(
              stream: sync.changes,
              initialData: sync.status,
              builder: (context, snapshot) {
                final feedback = snapshot.data;
                final failure =
                    feedback?.documentFailure ??
                    (feedback?.failure?.code == FailureCode.network
                        ? feedback?.failure
                        : null);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextButton.icon(
                      onPressed: feedback?.checking == true ? null : sync.check,
                      icon: const Icon(Icons.sync),
                      label: const Text('Check for shared documents'),
                    ),
                    if (failure != null) FailureNotice(failure),
                  ],
                );
              },
            ),
          StreamBuilder<List<VaultDocumentUpload>>(
            stream: repository.watchUploads(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return FailureNotice(snapshot.error!);
              final uploads = snapshot.data;
              if (uploads == null || uploads.isEmpty) {
                return const SizedBox.shrink();
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeading('Files saved on this device'),
                  for (final job in uploads)
                    Card.outlined(
                      child: ListTile(
                        leading: const Icon(Icons.cloud_upload_outlined),
                        title: Text(job.title),
                        subtitle: Text(switch (job.state) {
                          'acknowledged' =>
                            'Shared. Waiting for the family list to refresh.',
                          'conflicted' =>
                            'The family document changed. Your copy is here.',
                          'rejected' =>
                            'Could not share this version. Your copy is here.',
                          _ => 'Waiting for the family service to confirm this file.',
                        }),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push(
                          '/document/${job.documentId}/version/${job.id}',
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
          StreamBuilder<List<DocumentEditStatus>>(
            stream: repository.watchDocumentEdits(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return FailureNotice(snapshot.error!);
              final edits = snapshot.data;
              if (edits == null || edits.isEmpty) {
                return const SizedBox.shrink();
              }
              return Column(
                children: [
                  for (final edit in edits)
                    Card.outlined(
                      child: ListTile(
                        leading: const Icon(Icons.edit_outlined),
                        title: Text(edit.title),
                        subtitle: Text(switch (edit.state) {
                          'conflicted' =>
                            'The family document changed. Open it to review.',
                          'rejected' => 'Could not share this edit.',
                          'acknowledged' =>
                            'Shared. Waiting for the family list to refresh.',
                          _ => switch (edit.action) {
                            'archive' => 'Waiting to confirm the archive.',
                            'restore' => 'Waiting to confirm the restore.',
                            'link' =>
                              'Waiting to confirm the transaction link.',
                            'unlink' => 'Waiting to confirm removal of the transaction link.',
                            _ => 'Waiting to confirm the edited details.',
                          },
                        }),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () =>
                            context.push('/document/${edit.documentId}'),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
        if (selection?.belongsTo(repository.session.identity) == true)
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Finish adding your selected file'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/document/import'),
          ),
        const SizedBox(height: 16),
        TextField(
          onChanged: (value) => setState(() => _search = value),
          decoration: const InputDecoration(
            labelText: 'Search by title',
            prefixIcon: Icon(Icons.search),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            DropdownButton<DocumentCategory?>(
              value: _category,
              onChanged: (value) => setState(() => _category = value),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('All categories'),
                ),
                for (final category in DocumentCategory.values)
                  DropdownMenuItem(
                    value: category,
                    child: Text(categoryLabel(category)),
                  ),
              ],
            ),
            FilterChip(
              label: const Text('Archived'),
              selected: _archive,
              onSelected: (value) => setState(() => _archive = value),
            ),
          ],
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<VaultDocument>>(
          stream: repository.watch(
            query: _search,
            category: _category,
            archived: _archive,
          ),
          builder: (context, snapshot) {
            if (snapshot.hasError) return FailureNotice(snapshot.error!);
            final items = snapshot.data;
            if (items == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (items.isEmpty) {
              return Text(
                _search.isNotEmpty
                    ? 'No matching documents.'
                    : _archive
                    ? 'No archived documents.'
                    : 'Add your first document to this vault.',
              );
            }
            return Column(
              children: [
                for (final row in items)
                  Card.outlined(
                    child: ListTile(
                      leading: const Icon(Icons.description_outlined),
                      title: Text(row.title),
                      subtitle: Text(
                        [
                          categoryLabel(
                            DocumentCategory.values.byName(row.category),
                          ),
                          ?expiryLabel(context, row.expiryOn),
                        ].join(' · '),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => context.push('/document/${row.id}'),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class DocumentEditorPage extends ConsumerWidget {
  const DocumentEditorPage({this.documentId, super.key});
  final String? documentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(documentRepositoryProvider);
    final selection = ref.watch(documentIntakeProvider);
    final edit = documentId;
    return VaultPage(
      title: edit == null ? 'Add document' : 'Edit document',
      children: [
        if (repository == null ||
            edit == null &&
                (selection == null ||
                    !selection.belongsTo(repository.session.identity)))
          const Text('Choose a file in the document vault to continue.')
        else
          FutureBuilder(
            future: _load(repository, edit),
            builder: (context, snapshot) {
              if (snapshot.hasError) return FailureNotice(snapshot.error!);
              if (snapshot.data case final data?) {
                return _DocumentForm(
                  repository: repository,
                  members: data.$1,
                  document: data.$2,
                  selection: edit == null ? selection : null,
                );
              }
              return const Center(child: CircularProgressIndicator());
            },
          ),
      ],
    );
  }

  Future<(List<FamilyMember>, VaultDocument?)> _load(
    DocumentRepository repository,
    String? id,
  ) async => (
    await repository.members(),
    id == null ? null : await repository.document(id),
  );
}

class _DocumentForm extends ConsumerStatefulWidget {
  const _DocumentForm({
    required this.repository,
    required this.members,
    this.document,
    this.selection,
  });
  final DocumentRepository repository;
  final List<FamilyMember> members;
  final VaultDocument? document;
  final PendingDocumentImport? selection;

  @override
  ConsumerState<_DocumentForm> createState() => _DocumentFormState();
}

class _DocumentFormState extends ConsumerState<_DocumentForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title;
  late DocumentCategory _category;
  late String _owner;
  String? _expiry;
  Object? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final title =
        widget.document?.title ?? widget.selection?.source.label ?? '';
    _title = TextEditingController(
      text: title.length > 120 ? title.substring(0, 120) : title,
    );
    _category = DocumentCategory.values.byName(
      widget.document?.category ?? 'general',
    );
    _owner =
        widget.document?.ownerId ?? widget.repository.session.identity.memberId;
    _expiry = widget.document?.expiryOn;
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final selected = widget.selection;
    if (_busy ||
        selected?.documentId == null && !_form.currentState!.validate()) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final repository = widget.repository;
    final intake = ref.read(documentIntakeProvider.notifier);
    try {
      if (selected?.documentId case final target?) {
        await repository.addVersionInput(
          target,
          selected!.expectedRevision!,
          selected.source.input,
        );
      } else {
        final details = DocumentDetails(
          title: _title.text,
          category: _category,
          ownerId: _owner,
          expiryOn: _expiry,
        );
        if (widget.document case final old?) {
          await repository.update(old.id, old.revision, details);
        } else {
          await repository.addInput(
            details: details,
            source: selected!.source.input,
          );
        }
      }
      if (mounted) context.go('/documents');
      if (selected != null) await intake.clear();
      unawaited(repository.session.sync?.check());
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickExpiry() async {
    final date = await showDatePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200, 12, 31),
      initialDate: _expiry == null ? DateTime.now() : DateTime.parse(_expiry!),
    );
    if (date != null && mounted) {
      setState(() => _expiry = LedgerRepository.dateOnly(date));
    }
  }

  @override
  Widget build(BuildContext context) {
    final version = widget.selection?.documentId != null;
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (version)
            const Text('Save the selected file as the next version.')
          else ...[
            TextFormField(
              controller: _title,
              maxLength: 120,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Document title'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a title'
                  : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<DocumentCategory>(
              initialValue: _category,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Category'),
              items: [
                for (final category in DocumentCategory.values)
                  DropdownMenuItem(
                    value: category,
                    child: Text(categoryLabel(category)),
                  ),
              ],
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _category = value!),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _owner,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Document owner'),
              items: [
                for (final member in widget.members)
                  DropdownMenuItem(
                    value: member.id,
                    child: Text(
                      member.displayName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: _busy
                  ? null
                  : (value) => setState(() => _owner = value!),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _busy ? null : _pickExpiry,
                  icon: const Icon(Icons.event_outlined),
                  label: Text(
                    expiryLabel(context, _expiry) ?? 'Add expiry date',
                  ),
                ),
                if (_expiry != null)
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() => _expiry = null),
                    child: const Text('Remove date'),
                  ),
              ],
            ),
          ],
          if (_error != null) FailureNotice(_error!),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _busy ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(
              _busy
                  ? 'Saving…'
                  : version
                  ? 'Save version'
                  : 'Save document',
            ),
          ),
          if (widget.selection != null)
            TextButton(
              onPressed: _busy
                  ? null
                  : () async {
                      final intake = ref.read(documentIntakeProvider.notifier);
                      if (context.mounted) context.go('/documents');
                      await intake.clear();
                    },
              child: const Text('Cancel import'),
            ),
        ],
      ),
    );
  }
}
