import 'dart:io';
import 'dart:typed_data';

import '../../core/database/app_database.dart';
import 'document_key_grant.dart';

typedef DocumentWire = Map<String, Object?>;

final class DocumentUploadTicket {
  const DocumentUploadTicket(this.path, this.token);
  final String path, token;

  @override
  String toString() => 'DocumentUploadTicket([redacted])';
}

final class DocumentChangeRequest {
  const DocumentChangeRequest({
    required this.operationId,
    required this.documentId,
    required this.versionId,
    required this.baseRevision,
    required this.action,
    this.ownerId,
    this.metadataBox,
  });
  final String operationId, documentId, versionId, action;
  final int baseRevision;
  final String? ownerId, metadataBox;
}

/// All calls use the same approved device and Auth session.
abstract interface class DocumentTransport {
  Future<String> reserve(VaultDocumentUpload job);
  Future<DocumentUploadTicket?> ticket(String operation);
  Future<void> upload(DocumentUploadTicket ticket, File ciphertext);
  Future<void> verify(String operation);
  Future<DocumentWire> finalize(
    String operation,
    List<DocumentKeyGrant> grants,
  );
  Future<List<DocumentWire>> list();
  Future<DocumentWire> change(DocumentChangeRequest request);
  Future<List<DocumentWire>> versions(String document);
  Future<List<DocumentWire>> missingGrants();
  Future<void> addGrant(String version, DocumentKeyGrant grant);
  Future<Uint8List> download(String version);
}

final class DocumentRoster {
  const DocumentRoster(this.devices, this.recipients);
  final Map<String, DocumentDeviceKeys> devices;
  final Map<String, DocumentDeviceKeys> recipients;
}
