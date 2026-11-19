import 'dart:async';
import 'dart:typed_data';

import 'package:drift/drift.dart' show BooleanExpressionOperators;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../core/database/app_database.dart';
import '../../core/errors/app_failure.dart';
import '../../shared/widgets/vault_widgets.dart';
import '../foundation/foundation_pages.dart' show VaultPage;
import 'document_inputs.dart';
import 'document_pages.dart';
import 'document_repository.dart';

typedef _DocumentRecord = ({
  VaultDocument details,
  String owner,
  List<VaultDocumentVersion> versions,
  List<VaultDocumentLink> links,
});

class DocumentDetailPage extends ConsumerStatefulWidget {
  const DocumentDetailPage({required this.documentId, super.key});
  final String documentId;

  @override
  ConsumerState<DocumentDetailPage> createState() => _DocumentDetailPageState();
}

class _DocumentDetailPageState extends ConsumerState<DocumentDetailPage> {
  Future<_DocumentRecord>? _record;
  Object? _error;
  bool _busy = false;

  Future<_DocumentRecord> _load(DocumentRepository repository) async {
    final doc = await repository.document(widget.documentId);
    final members = await repository.members();
    return (
      details: doc,
      owner:
          members
              .where((member) => member.id == doc.ownerId)
              .firstOrNull
              ?.displayName ??
          'Family member',
      versions: await repository.versions(doc.id),
      links: await repository.links(doc.id),
    );
  }

  Future<void> _change(
    DocumentRepository repository,
    Future<void> Function() apply,
  ) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await apply();
      if (mounted && repository.sharingAvailable) {
        context.go('/documents');
        unawaited(repository.session.sync?.check());
      } else if (mounted) {
        setState(() => _record = _load(repository));
      }
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _link(DocumentRepository repository, String doc) async {
    final db = repository.session.db;
    final family = repository.session.identity.familyId;
    final snapshot = await repository.session.ledger.snapshot();
    final assets = await (db.select(
      db.wealthAssets,
    )..where((t) => t.familyId.equals(family) & t.deletedAtUs.isNull())).get();
    if (!mounted || repository.session.closed) return;
    final choices = <({String label, String? journal, String? asset})>[
      for (final asset in assets)
        (label: asset.name, journal: null, asset: asset.id),
      for (final record in snapshot.journals.where(
        (row) => row.deletedAtUs == null && row.kind != 'reversal',
      ))
        (
          label: '${record.occurredOn}  ${record.description}',
          journal: record.id,
          asset: null,
        ),
    ];
    final target =
        await showDialog<({String label, String? journal, String? asset})>(
          context: context,
          builder: (context) => SimpleDialog(
            title: const Text('Link to a record'),
            children: [
              if (choices.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text('Add an asset or transaction first.'),
                ),
              for (final choice in choices)
                SimpleDialogOption(
                  onPressed: () => Navigator.of(context).pop(choice),
                  child: Text(choice.label),
                ),
            ],
          ),
        );
    if (target != null) {
      await repository.link(
        doc,
        journalId: target.journal,
        assetId: target.asset,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(documentRepositoryProvider);
    if (repository == null) return const SizedBox.shrink();
    return VaultPage(
      title: 'Document',
      children: [
        FutureBuilder<_DocumentRecord>(
          future: _record ??= _load(repository),
          builder: (context, snapshot) {
            if (snapshot.hasError) return FailureNotice(snapshot.error!);
            final record = snapshot.data;
            if (record == null) {
              return const Center(child: CircularProgressIndicator());
            }
            final doc = record.details;
            final archived = doc.deletedAtUs != null;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doc.title,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  '${categoryLabel(DocumentCategory.values.byName(doc.category))} · ${record.owner}',
                ),
                if (expiryLabel(context, doc.expiryOn) case final expiry?)
                  Text(expiry),
                if (_error != null) FailureNotice(_error!),
                const SizedBox(height: 12),
                if (!repository.session.identity.isCloud ||
                    repository.sharingAvailable)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (!archived) ...[
                        OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () => context.push('/document/${doc.id}/edit'),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Edit details'),
                        ),
                        OutlinedButton.icon(
                          onPressed: _busy
                              ? null
                              : () => chooseDocument(
                                  context,
                                  ref,
                                  repository,
                                  versionOf: doc,
                                ),
                          icon: const Icon(Icons.add),
                          label: const Text('Add version'),
                        ),
                        if (!repository.session.identity.isCloud)
                          OutlinedButton.icon(
                            onPressed: _busy
                                ? null
                                : () => _change(
                                    repository,
                                    () => _link(repository, doc.id),
                                  ),
                            icon: const Icon(Icons.link),
                            label: const Text('Link record'),
                          ),
                      ],
                      TextButton.icon(
                        onPressed: _busy
                            ? null
                            : () => _change(
                                repository,
                                () => repository.archive(
                                  doc.id,
                                  doc.revision,
                                  restore: archived,
                                ),
                              ),
                        icon: Icon(
                          archived
                              ? Icons.unarchive_outlined
                              : Icons.archive_outlined,
                        ),
                        label: Text(
                          archived ? 'Restore document' : 'Archive document',
                        ),
                      ),
                    ],
                  ),
                const SizedBox(height: 18),
                const SectionHeading('Versions'),
                for (final version in record.versions)
                  Card.outlined(
                    child: ListTile(
                      title: Text('Version ${version.version}'),
                      subtitle: Text(
                        '${version.mimeType == 'application/pdf' ? 'PDF' : 'Image'} · ${_size(version.plaintextBytes)}',
                      ),
                      onTap: () => context.push(
                        '/document/${doc.id}/version/${version.id}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                    ),
                  ),
                if (record.links.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  const SectionHeading('Linked records'),
                  for (final link in record.links)
                    ListTile(
                      leading: const Icon(Icons.link),
                      title: Text(
                        link.assetId == null ? 'Transaction' : 'Asset',
                      ),
                      onTap: () => context.push(
                        link.assetId == null
                            ? '/transaction/${link.journalId}'
                            : '/asset/${link.assetId}',
                      ),
                      trailing: IconButton(
                        tooltip: 'Unlink record',
                        icon: const Icon(Icons.link_off),
                        onPressed: _busy
                            ? null
                            : () => _change(
                                repository,
                                () => repository.unlink(link.id),
                              ),
                      ),
                    ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  String _size(int bytes) =>
      bytes < 1024 ? '$bytes B' : '${(bytes + 1023) ~/ 1024} KB';
}

class DocumentPreviewPage extends ConsumerStatefulWidget {
  const DocumentPreviewPage({
    required this.documentId,
    required this.versionId,
    super.key,
  });
  final String documentId, versionId;

  @override
  ConsumerState<DocumentPreviewPage> createState() =>
      _DocumentPreviewPageState();
}

class _DocumentPreviewPageState extends ConsumerState<DocumentPreviewPage> {
  Future<void>? _loading;
  VaultDocumentVersion? _version;
  String _title = 'Document preview';
  Uint8List? _data;
  ImageProvider<Object>? _image;
  bool _saving = false;

  Future<void> _load(DocumentRepository repository) async {
    final info = await repository.describeVersion(
      widget.documentId,
      widget.versionId,
    );
    final version = info.version;
    final bytes = await repository.read(
      widget.documentId,
      version.id,
      DocumentAccess.preview,
    );
    if (!mounted || repository.session.closed) {
      bytes.fillRange(0, bytes.length, 0);
      return;
    }
    _version = version;
    _title = info.title;
    _data = bytes;
    if (version.mimeType != 'application/pdf') {
      _image = ResizeImage(
        MemoryImage(bytes),
        width: 2048,
        height: 4096,
        policy: ResizeImagePolicy.fit,
      );
    }
  }

  Future<void> _download(DocumentRepository repository) async {
    if (_saving || _version == null) return;
    final io = ref.read(documentIoProvider);
    final version = _version!;
    final format = DocumentFormat.values.firstWhere(
      (item) => item.mime == version.mimeType,
    );
    final title = _title.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1f]'), '_');
    setState(() => _saving = true);
    Uint8List? bytes;
    try {
      bytes = await repository.read(
        widget.documentId,
        widget.versionId,
        DocumentAccess.download,
      );
      if (!mounted || repository.session.closed) return;
      final saved = await io.save(
        name: '$title.${format.extension}',
        mime: format.mime,
        bytes: bytes,
      );
      if (saved && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Document saved.')));
      }
    } on AppFailure catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      bytes?.fillRange(0, bytes.length, 0);
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    final image = _image;
    if (image != null) unawaited(image.evict());
    final data = _data;
    data?.fillRange(0, data.length, 0);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repository = ref.watch(documentRepositoryProvider);
    if (repository == null) return const SizedBox.shrink();
    return FutureBuilder<void>(
      future: _loading ??= _load(repository),
      builder: (context, snapshot) => Scaffold(
        appBar: AppBar(
          title: Text(_title),
          actions: [
            IconButton(
              onPressed: _data == null || _saving
                  ? null
                  : () => _download(repository),
              tooltip: 'Save a copy',
              icon: const Icon(Icons.download_outlined),
            ),
          ],
        ),
        body: snapshot.hasError
            ? Center(child: FailureNotice(snapshot.error!))
            : _body(context),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final data = _data;
    if (data == null) return const Center(child: CircularProgressIndicator());
    if (_version?.mimeType == 'application/pdf') {
      return PdfViewer.data(
        data,
        sourceName: widget.versionId,
        params: PdfViewerParams(
          textSelectionParams: const PdfTextSelectionParams(enabled: false),
          linkHandlerParams: PdfLinkHandlerParams(onLinkTap: (_) {}),
          errorBannerBuilder: (_, _, _, _) =>
              const Center(child: Text('This PDF could not be opened.')),
        ),
      );
    }
    return InteractiveViewer(
      maxScale: 5,
      child: Center(
        child: Image(
          image: _image!,
          fit: BoxFit.contain,
          semanticLabel: _title,
          errorBuilder: (_, _, _) =>
              const Text('This image could not be opened.'),
        ),
      ),
    );
  }
}
