import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/database/app_database.dart';
import '../../core/errors/app_failure.dart';
import '../../core/localization/vault_strings.dart';
import '../../core/sync/live_sync.dart';
import '../../shared/widgets/vault_widgets.dart';
import '../finance/data/ledger_repository.dart';
import '../foundation/foundation_pages.dart' show VaultPage;
import 'document_inputs.dart';
import 'document_repository.dart';

String categoryLabel(BuildContext context, DocumentCategory category) =>
    context.tr(switch (category) {
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
    });

String? expiryLabel(BuildContext context, String? expiry) {
  if (expiry == null) return null;
  final date = DateTime.parse(expiry);
  final remaining = date.difference(DateUtils.dateOnly(DateTime.now())).inDays;
  final when = MaterialLocalizations.of(context).formatMediumDate(date);
  return remaining < 0
      ? context.tr('Expired {date}', {'date': when})
      : remaining <= 30
      ? context.tr('Due soon {date}', {'date': when})
      : context.tr('Expires {date}', {'date': when});
}

Future<void> chooseDocument(
  BuildContext context,
  WidgetRef ref,
  DocumentRepository repository, {
  VaultDocument? versionOf,
}) async {
  final strings = VaultStrings.of(context);
  final picker = await showModalBottomSheet<DocumentPicker>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.folder_open_outlined),
            title: Text(strings.text('choosePaperFile')),
            subtitle: Text(context.tr('PDF, JPG or PNG')),
            onTap: () => Navigator.of(context).pop(DocumentPicker.files),
          ),
          ListTile(
            leading: const Icon(Icons.document_scanner_outlined),
            title: Text(strings.text('scanPaper')),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(VaultStrings.of(context).failure(error))),
      );
    }
  }
}

enum DocumentGuide { add, find }

class DocumentsPage extends ConsumerStatefulWidget {
  const DocumentsPage({this.guide, super.key});

  final DocumentGuide? guide;
  @override
  ConsumerState<DocumentsPage> createState() => _DocumentsPageState();
}

class _DocumentsPageState extends ConsumerState<DocumentsPage> {
  String _search = '';
  bool _archive = false;
  DocumentCategory? _category;

  @override
  Widget build(BuildContext context) {
    final strings = VaultStrings.of(context);
    final repository = ref.watch(documentRepositoryProvider);
    final selection = ref.watch(documentIntakeProvider);
    if (repository == null) return const SizedBox.shrink();
    if (repository.session.identity.isCloud && !repository.sharingAvailable) {
      return VaultContent(
        children: [
          Text(context.tr('Shared papers are unavailable for this account.')),
        ],
      );
    }
    return VaultContent(
      children: [
        if (widget.guide == DocumentGuide.add) ...[
          Text(strings.text('help.addPaper.first')),
          const SizedBox(height: 8),
        ],
        FilledButton.icon(
          key: const ValueKey('documents-add'),
          onPressed: () => chooseDocument(context, ref, repository),
          icon: const Icon(Icons.note_add_outlined),
          label: Text(strings.text('addDocument')),
        ),
        if (selection?.belongsTo(repository.session.identity) == true)
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(strings.text('finishPaper')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/document/import'),
          ),
        const SizedBox(height: 16),
        TextField(
          key: const ValueKey('papers-search'),
          onChanged: (value) => setState(() => _search = value),
          decoration: InputDecoration(
            labelText: strings.text('paperSearch'),
            prefixIcon: const Icon(Icons.search),
            helperText: widget.guide == DocumentGuide.find
                ? strings.text('help.findPaper.first')
                : null,
            helperMaxLines: 4,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            PopupMenuButton<String>(
              tooltip: strings.text('paperCategory'),
              onSelected: (value) => setState(() {
                _category = value == 'all'
                    ? null
                    : DocumentCategory.values.byName(value);
              }),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'all',
                  child: Text(strings.text('allCategories')),
                ),
                for (final category in DocumentCategory.values)
                  PopupMenuItem(
                    value: category.name,
                    child: Text(categoryLabel(context, category)),
                  ),
              ],
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 48),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.filter_list, size: 20),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _category == null
                            ? strings.text('allCategories')
                            : categoryLabel(context, _category!),
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
            FilterChip(
              label: Text(strings.text('archivedPapers')),
              selected: _archive,
              onSelected: (value) => setState(() => _archive = value),
            ),
            TextButton.icon(
              onPressed: () => context.push('/help?area=documents'),
              icon: const Icon(Icons.help_outline),
              label: Text(strings.text('shortHelp')),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (repository.sharingAvailable ||
            repository.session.identity.sharedChart)
          ExpansionTile(
            title: Text(strings.text('documentUpdates')),
            leading: const Icon(Icons.cloud_outlined),
            tilePadding: EdgeInsets.zero,
            maintainState: true,
            children: [
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
                          onPressed: feedback?.checking == true
                              ? null
                              : sync.check,
                          icon: const Icon(Icons.sync),
                          label: Text(context.tr('Check for shared documents')),
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
                      SectionHeading(context.tr('Papers saved on this phone')),
                      for (final job in uploads)
                        Card.outlined(
                          child: ListTile(
                            leading: const Icon(Icons.cloud_upload_outlined),
                            title: Text(job.title),
                            subtitle: Text(
                              !repository.sharingAvailable
                                  ? context.tr(
                                      'Brought back and saved on this phone.',
                                    )
                                  : switch (job.state) {
                                      'acknowledged' => context.tr(
                                        'Shared. The family list is updating.',
                                      ),
                                      'conflicted' => context.tr(
                                        'The family document changed. Your copy is here.',
                                      ),
                                      'rejected' => context.tr(
                                        'Could not share this version. Your copy is here.',
                                      ),
                                      _ => context.tr(
                                        'Saved here. Waiting to share with the family.',
                                      ),
                                    },
                            ),
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
              if (repository.sharingAvailable)
                StreamBuilder<List<DocumentEditStatus>>(
                  stream: repository.watchDocumentEdits(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return FailureNotice(snapshot.error!);
                    }
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
                                'conflicted' => context.tr(
                                  'The family document changed. Open it to review.',
                                ),
                                'rejected' => context.tr(
                                  'Could not share this edit.',
                                ),
                                'acknowledged' => context.tr(
                                  'Shared. The family list is updating.',
                                ),
                                _ => switch (edit.action) {
                                  'archive' => context.tr(
                                    'Waiting to confirm the archive.',
                                  ),
                                  'restore' => context.tr(
                                    'Waiting to confirm the restore.',
                                  ),
                                  'link' => context.tr(
                                    'Waiting to confirm the transaction link.',
                                  ),
                                  'unlink' => context.tr(
                                    'Waiting to confirm removal of the transaction link.',
                                  ),
                                  _ => context.tr(
                                    'Waiting to confirm the edited details.',
                                  ),
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
          ),
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
                    ? context.tr('No matching documents.')
                    : _archive
                    ? context.tr('No archived documents.')
                    : context.tr('Add your first document to this vault.'),
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
                            context,
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
      title: edit == null
          ? VaultStrings.of(context).text('addDocument')
          : context.tr('Edit document'),
      children: [
        if (repository == null ||
            edit == null &&
                (selection == null ||
                    !selection.belongsTo(repository.session.identity)))
          Text(context.tr('Choose a file in the document vault to continue.'))
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
      if (mounted) {
        savedNotice(
          context,
          cloud: repository.session.identity.isCloud,
          message: VaultStrings.of(context)
              .text(widget.document == null ? 'paperAdded' : 'paperEdited'),
        );
        context.go('/documents');
      }
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
    final strings = VaultStrings.of(context);
    return Form(
      key: _form,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (version)
            Text(context.tr('Save the selected file as the next version.'))
          else ...[
            TextFormField(
              controller: _title,
              maxLength: 120,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: strings.text('paperName')),
              validator: (value) => value == null || value.trim().isEmpty
                  ? context.tr('Enter a title')
                  : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<DocumentCategory>(
              initialValue: _category,
              isExpanded: true,
              decoration: InputDecoration(labelText: context.tr('Category')),
              items: [
                for (final category in DocumentCategory.values)
                  DropdownMenuItem(
                    value: category,
                    child: Text(categoryLabel(context, category)),
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
              decoration: InputDecoration(
                labelText: strings.text('whosePaper'),
                helperText: widget.repository.session.identity.isCloud
                    ? strings.text('sharedPaperOwnerHelp')
                    : null,
                helperMaxLines: 4,
              ),
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
                    expiryLabel(context, _expiry) ??
                        context.tr('Add expiry date'),
                  ),
                ),
                if (_expiry != null)
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => setState(() => _expiry = null),
                    child: Text(context.tr('Remove date')),
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
                  ? context.tr('Saving…')
                  : version
                  ? strings.text('savePaperVersion')
                  : strings.text('savePaper'),
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
              child: Text(context.tr('Cancel import')),
            ),
        ],
      ),
    );
  }
}
