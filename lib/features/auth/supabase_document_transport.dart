part of 'cloud_access_gateway.dart';

final class _SupabaseDocuments implements DocumentTransport {
  const _SupabaseDocuments(this.gateway, this.device);
  final SupabaseAccessGateway gateway;
  final DeviceProof device;
  static const _bucket = 'familyvault-ciphertext';
  static const _invalid = AppFailure(
    FailureCode.integrity,
    'The document service returned an invalid response.',
  );

  Future<T> _rpc<T>(String name, [CloudJson arguments = const {}]) =>
      gateway._rpc<T>('document_$name', {...device.parameters, ...arguments});

  @override
  Future<String> reserve(VaultDocumentUpload job) => _rpc('reserve', {
    'p_operation': job.operationId,
    'p_document': job.documentId,
    'p_version': job.id,
    'p_owner': job.ownerId,
    'p_base': job.baseRevision,
    'p_mime': job.mimeType,
    'p_bytes': job.plaintextBytes,
    'p_digest': job.ciphertextDigest,
    'p_metadata': job.metadataBox,
  });

  Future<Object?> _edge(String action, String id) => gateway._request(() async {
    final abort = Completer<void>();
    final timer = Timer(const Duration(seconds: 50), abort.complete);
    try {
      final response = await gateway._client.functions.invoke(
        'vault-object',
        headers: {'x-fv-device': device.deviceId, 'x-fv-proof': device.proof},
        body: {'action': action, 'id': id},
        abortSignal: abort.future,
      );
      return response.data;
    } on FunctionsFetchException {
      throw SupabaseAccessGateway._network;
    } on FunctionException catch (error) {
      if (error.status == 401 || error.status == 403) {
        throw SupabaseAccessGateway._denied;
      }
      if (error.status == 409 || error.status == 429 || error.status >= 500) {
        throw SupabaseAccessGateway._network;
      }
      if (error.status == 404) {
        throw const AppFailure(
          FailureCode.configuration,
          'Shared document storage is unavailable on this server.',
        );
      }
      throw _invalid;
    } catch (_) {
      if (abort.isCompleted) throw SupabaseAccessGateway._network;
      rethrow;
    } finally {
      timer.cancel();
    }
  }, timeout: const Duration(seconds: 55));

  @override
  Future<DocumentUploadTicket?> ticket(String operation) async {
    final value = await _edge('ticket', operation);
    if (value is! CloudJson) throw _invalid;
    if (value['verified'] == true || value['object_present'] == true) {
      return null;
    }
    final path = cloudText(value, 'object_path');
    final token = cloudText(value, 'token');
    if (!RegExp(r'^[A-Za-z0-9_.-]{1,12000}$').hasMatch(token)) throw _invalid;
    return DocumentUploadTicket(path, token);
  }

  @override
  Future<void> upload(DocumentUploadTicket ticket, File ciphertext) =>
      gateway._request(() async {
        try {
          final path = await gateway._client.storage
              .from(_bucket)
              .uploadToSignedUrl(
                ticket.path,
                ticket.token,
                ciphertext,
                const FileOptions(
                  contentType: 'application/octet-stream',
                  upsert: false,
                ),
                0,
              );
          if (path != ticket.path) throw _invalid;
        } on StorageException catch (error) {
          if (error.statusCode == '413') {
            throw const AppFailure(
              FailureCode.validation,
              'The document exceeds the storage limit.',
            );
          }
          throw SupabaseAccessGateway._network;
        }
      }, timeout: const Duration(seconds: 90));

  @override
  Future<void> verify(String operation) async {
    final response = await _edge('verify', operation);
    if (response is! CloudJson || response['verified'] != true) throw _invalid;
  }

  @override
  Future<DocumentWire> finalize(
    String operation,
    List<DocumentKeyGrant> grants,
  ) => _rpc('finalize', {
    'p_reservation': operation,
    'p_grants': grants.map((g) => g.fields).toList(),
  });

  @override
  Future<DocumentWire> change(DocumentChangeRequest request) => _rpc('change', {
    'p_operation': request.operationId,
    'p_document': request.documentId,
    'p_version': request.versionId,
    'p_base': request.baseRevision,
    'p_action': request.action,
    'p_owner': request.ownerId,
    'p_metadata': request.metadataBox,
  });

  @override
  Future<List<DocumentWire>> list() async =>
      cloudRows(await _rpc<Object?>('list'));

  @override
  Future<List<DocumentWire>> versions(String document) async =>
      cloudRows(await _rpc<Object?>('versions', {'p_document': document}));

  @override
  Future<List<DocumentWire>> missingGrants() async =>
      cloudRows(await _rpc<Object?>('missing_grants'));

  @override
  Future<void> addGrant(String version, DocumentKeyGrant grant) async {
    await _rpc<Object?>('add_grant', {
      'p_version': version,
      'p_grant': grant.fields,
    });
  }

  @override
  Future<Uint8List> download(String version) async {
    final response = await _edge('download', version);
    if (response is! Uint8List) throw _invalid;
    return response;
  }
}
