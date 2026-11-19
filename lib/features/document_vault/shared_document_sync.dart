part of 'document_repository.dart';

const _invalidSharedDocument = AppFailure(
  FailureCode.integrity,
  'The shared document or its receipt could not be verified.',
);

final class _SharedDocumentSync {
  _SharedDocumentSync(this.repository, this.transport, this.requireSession);
  final DocumentRepository repository;
  final DocumentTransport transport;
  final void Function() requireSession;
  Future<void>? _running;
  AppDatabase get _db => repository._db;
  String get _family => repository._familyId;
  String get _device => repository._deviceId;

  void _check() {
    repository._checkOpen();
    requireSession();
  }

  Future<T> _call<T>(Future<T> Function() callback) async {
    _check();
    final result = await callback();
    _check();
    return result;
  }

  Future<void> run(DocumentRoster roster) =>
      _running ??= storageBoundary(() => _run(roster))
          .whenComplete(() => _running = null);

  Future<void> _run(DocumentRoster roster) async {
    await repository._authorize();
    if (!roster.recipients.containsKey(_device) ||
        roster.recipients.length > 100) {
      throw _invalidSharedDocument;
    }
    final table = _db.vaultDocumentUploads;
    final now = repository._writer.now;
    final pending =
        await (_db.select(table)
              ..where(
                (t) =>
                    t.familyId.equals(_family) &
                    t.deviceId.equals(_device) &
                    t.state.equals('pending') &
                    (t.nextAttemptAtUs.isNull() |
                        t.nextAttemptAtUs.isSmallerOrEqualValue(now)),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.createdAtUs)])
              ..limit(8))
            .get();
    AppFailure? feedback;
    for (final job in pending) {
      try {
        await _deliver(job, roster);
        await _record(job, 'acknowledged');
      } on AppFailure catch (error) {
        _check();
        final state = _stateForFailure(error);
        await _record(job, state);
        if (state == 'pending') {
          feedback = error;
          break;
        }
      }
    }
    final editFeedback = await _sendEdits();
    feedback ??= editFeedback;
    await _backfill(roster);
    await _pull(roster);
    if (feedback != null) throw feedback;
  }

  String _stateForFailure(AppFailure error) => switch (error.code) {
    FailureCode.conflict => 'conflicted',
    FailureCode.integrity || FailureCode.validation => 'rejected',
    FailureCode.network || FailureCode.configuration => 'pending',
    _ => throw error,
  };

  int _retryAt(int attempts) =>
      repository._writer.now +
      Duration(seconds: 2 << min(attempts, 7)).inMicroseconds;

  Future<void> _reserve(VaultDocumentUpload job) async {
    if (job.memberId != repository._memberId ||
        await _call(() => transport.reserve(job)) != job.operationId) {
      throw _invalidSharedDocument;
    }
  }

  Future<void> _deliver(VaultDocumentUpload job, DocumentRoster roster) async {
    await _reserve(job);
    final ticket = await _call(() => transport.ticket(job.operationId));
    if (ticket != null) {
      if (ticket.path != '$_family/${job.operationId}.fvdoc') {
        throw _invalidSharedDocument;
      }
      final file = repository.ciphertext(job.id);
      if (!await file.exists() ||
          await file.length() != SealedFile.byteLength(job.plaintextBytes) ||
          await SealedFile.digest(file) != job.ciphertextDigest) {
        throw _invalidSharedDocument;
      }
      try {
        await _call(() => transport.upload(ticket, file));
      } on AppFailure catch (error) {
        // A response can be lost after immutable Storage accepted the bytes.
        // The trusted reader still needs to confirm the exact digest.
        if (error.code != FailureCode.network) rethrow;
      }
    }
    await _call(() => transport.verify(job.operationId));
    final context = repository._context(
      job.documentId,
      job.id,
      job.mimeType,
      job.plaintextBytes,
    );
    final key = await repository._unwrap(job.wrappedKey, context);
    final List<DocumentKeyGrant> grants;
    try {
      grants = [
        for (final recipient in roster.recipients.values)
          await _grant(job.documentId, job.id, recipient, key),
      ];
    } finally {
      key.destroy();
    }
    final DocumentWire receipt;
    try {
      receipt = await _call(() => transport.finalize(job.operationId, grants));
    } on AppFailure catch (error) {
      if (error.code != FailureCode.conflict) rethrow;
      // Rechecking the exact reservation distinguishes a changed document from
      // a recipient joining while the upload was pending.
      await _reserve(job);
      throw const AppFailure(
        FailureCode.network,
        'Waiting to confirm the shared document.',
      );
    }
    if (receipt['reservation_id'] != job.operationId ||
        receipt['version_id'] != job.id ||
        receipt['version'] != job.version ||
        receipt['ciphertext_digest'] != job.ciphertextDigest) {
      throw _invalidSharedDocument;
    }
  }

  Future<void> _record(VaultDocumentUpload job, String state) =>
      _db.transaction(() async {
        _check();
        final changed =
            await (_db.update(_db.vaultDocumentUploads)..where(
                  (t) => t.id.equals(job.id) & t.state.equals('pending'),
                ))
                .write(
                  VaultDocumentUploadsCompanion(
                    state: Value(state),
                    attempts: Value(job.attempts + 1),
                    nextAttemptAtUs: Value(
                      state == 'pending' ? _retryAt(job.attempts) : null,
                    ),
                  ),
                );
        if (changed == 1 && state != 'pending') {
          await repository._writer.audit(
            operationId: job.operationId,
            entityType: 'document_receipt',
            entityId: job.documentId,
            action: state,
            after: {'version_id': job.id},
          );
        }
      });

  Future<DocumentKeyGrant> _grant(
    String doc,
    String version,
    DocumentDeviceKeys recipient,
    SecretKey key,
  ) {
    _check();
    return DocumentKeyGrant.create(
      familyId: _family,
      documentId: doc,
      versionId: version,
      senderId: _device,
      senderKeys: repository.session.keys,
      recipient: recipient,
      contentKey: key,
    );
  }

  Future<SecretKeyData> _openGrant(
    Object? envelope,
    String doc,
    String version,
    DocumentRoster roster,
  ) {
    _check();
    if (envelope is! DocumentWire) throw _invalidSharedDocument;
    final sender = roster.devices[envelope['sender_device_id']];
    if (sender == null) throw _invalidSharedDocument;
    return DocumentKeyGrant.fromJson(envelope).open(
      familyId: _family,
      documentId: doc,
      versionId: version,
      sender: sender,
      recipientId: _device,
      recipientKeys: repository.session.keys,
    );
  }

  Future<void> _backfill(DocumentRoster roster) async {
    for (final row in await _call(transport.missingGrants)) {
      final recipient = roster.recipients[row['recipient_id']];
      if (recipient == null) {
        continue; // The next approved directory includes the new recipient.
      }
      final doc = _docId(row, 'document_id'),
          version = _docId(row, 'version_id');
      final key = await _openGrant(row['key_grant'], doc, version, roster);
      final DocumentKeyGrant grant;
      try {
        grant = await _grant(doc, version, recipient, key);
      } finally {
        key.destroy();
      }
      await _call(() => transport.addGrant(version, grant));
    }
  }

  Future<void> cache(VaultDocumentVersion version) async {
    final target = repository.ciphertext(version.id);
    if (await target.exists()) return;
    final bytes = await _call(() => transport.download(version.id));
    if (bytes.length != SealedFile.byteLength(version.plaintextBytes)) {
      throw _invalidSharedDocument;
    }
    await repository._files.create(recursive: true);
    final partial = File(
      '${target.path}.${DocumentRepository._uuid.v4()}.partial',
    );
    try {
      await partial.create(exclusive: true);
      await partial.writeAsBytes(bytes, flush: true);
      if (await SealedFile.digest(partial) != version.ciphertextDigest) {
        throw _invalidSharedDocument;
      }
      _check();
      if (!await target.exists()) await partial.rename(target.path);
      _check();
    } finally {
      if (await partial.exists()) await partial.delete();
    }
  }

  Future<void> _pull(DocumentRoster roster) => _replayDocuments(this, roster);
}

String _docText(DocumentWire row, String field) {
  final value = row[field];
  if (value is! String || value.isEmpty) throw _invalidSharedDocument;
  return value;
}

String _docId(DocumentWire row, String field) {
  final id = _docText(row, field);
  if (!Uuid.isValidUUID(fromString: id) || id != id.toLowerCase()) {
    throw _invalidSharedDocument;
  }
  return id;
}

int _docInt(DocumentWire row, String field) {
  final value = row[field];
  if (value is! int || value <= 0) throw _invalidSharedDocument;
  return value;
}
