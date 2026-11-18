import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../app/vault_providers.dart';
import '../../core/errors/app_failure.dart';
import '../../core/security/vault_identity.dart';
import 'document_repository.dart';

enum DocumentPicker { files, camera }

final class SelectedDocument {
  const SelectedDocument(this.label, this.input, {this.cleanUp});
  final String label;
  final DocumentInput input;
  final Future<void> Function()? cleanUp;
}

abstract interface class DocumentIo {
  Future<SelectedDocument?> pick(DocumentPicker picker);
  Future<bool> save({
    required String name,
    required String mime,
    required Uint8List bytes,
  });
}

final documentIoProvider = Provider<DocumentIo>(
  (ref) => const NativeDocumentIo(),
);

final class NativeDocumentIo implements DocumentIo {
  const NativeDocumentIo();

  @override
  Future<SelectedDocument?> pick(DocumentPicker picker) async {
    try {
      if (picker == DocumentPicker.camera) {
        final photo = await ImagePicker().pickImage(
          source: ImageSource.camera,
          imageQuality: 95,
          requestFullMetadata: false,
        );
        if (photo == null) return null;
        return SelectedDocument(
          'Scanned document',
          DocumentInput(length: photo.length, openRead: photo.openRead),
          cleanUp: () => _removeCapture(photo.path),
        );
      }
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      );
      if (file == null) return null;
      return SelectedDocument(
        p.basenameWithoutExtension(file.name),
        DocumentInput(
          length: () async => await file.length() ?? (throw _unavailable),
          openRead: file.readAsByteStream,
        ),
      );
    } catch (_) {
      throw _unavailable;
    }
  }

  @override
  Future<bool> save({
    required String name,
    required String mime,
    required Uint8List bytes,
  }) async {
    try {
      return await FilePicker.saveFile(
            fileName: name,
            bytes: bytes,
            mimeType: mime,
          ) !=
          null;
    } catch (_) {
      throw const AppFailure(
        FailureCode.storage,
        'The document could not be saved to the selected location.',
      );
    }
  }

  static const _unavailable = AppFailure(
    FailureCode.storage,
    'The document picker could not open the selected file.',
  );

  static Future<void> _removeCapture(String path) async {
    try {
      final capture = File(path);
      final appCache = await (await getTemporaryDirectory())
          .resolveSymbolicLinks();
      final actual = await capture.resolveSymbolicLinks();
      // A camera capture created for this import is disposable only in app cache.
      if (p.isWithin(appCache, actual)) await capture.delete();
    } on FileSystemException {
      // The phone may already have removed its cached capture.
    }
  }
}

final documentRepositoryProvider = Provider.autoDispose<DocumentRepository?>((
  ref,
) {
  final session = ref.watch(vaultProvider).session;
  return session == null || session.closed ? null : DocumentRepository(session);
});

final class PendingDocumentImport {
  const PendingDocumentImport(
    this.scope,
    this.source, {
    this.documentId,
    this.expectedRevision,
  });
  final VaultIdentity scope;
  final SelectedDocument source;
  final String? documentId;
  final int? expectedRevision;

  bool belongsTo(VaultIdentity identity) =>
      scope.familyId == identity.familyId &&
      scope.memberId == identity.memberId &&
      scope.deviceId == identity.deviceId;
}

/// Native file and camera screens can pause FamilyVault and lock the keys.
/// Carry a transient source handle across the lock, scoped to this vault.
final class DocumentIntake extends Notifier<PendingDocumentImport?> {
  bool _picking = false;
  @override
  PendingDocumentImport? build() => null;

  Future<PendingDocumentImport?> pick(
    VaultIdentity identity,
    DocumentPicker picker, {
    String? documentId,
    int? expectedRevision,
  }) async {
    if (_picking) return null;
    _picking = true;
    try {
      final source = await ref.read(documentIoProvider).pick(picker);
      if (source == null) return null;
      await clear();
      final selected = PendingDocumentImport(
        identity,
        source,
        documentId: documentId,
        expectedRevision: expectedRevision,
      );
      state = selected;
      return selected;
    } finally {
      _picking = false;
    }
  }

  Future<void> clear() async {
    final prior = state;
    state = null;
    try {
      await prior?.source.cleanUp?.call();
    } catch (_) {
      // The operating system owns the temporary capture directory.
    }
  }
}

final documentIntakeProvider =
    NotifierProvider<DocumentIntake, PendingDocumentImport?>(
      DocumentIntake.new,
    );
