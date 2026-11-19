# ADR 0017 Staged document versions

Drift v5 adds a durable upload queue to the existing encrypted vault. Staging
records the selected family owner, original editor and device, base revision,
next version number, ciphertext digest, encrypted metadata and locally wrapped
file key. The file is flushed and renamed before the SQLite transaction commits
the queue row and its audit event. A restart uses the same operation ID and
the same encrypted request.

A staged version is available for preview on its device. Only a confirmed
server version enters the shared document history. This lets a concurrent family
edit advance the accepted history while the conflicting draft stays readable. A
document may have one pending upload on a device. Draft payloads and completed
or blocked queue rows are retained. Recovery from a finance conflict copies
these rows and document audit events into the replacement encrypted cache.

The metadata box uses the version content key and its own nonce and context.
The context binds the family, document, version and owner. The queued title used
for local display stays within the encrypted SQLite file. The shared service
receives the opaque box and the owner ID for provenance.

The additive migration and draft persistence are implemented and tested.
The mobile publisher and receiver will verify real server receipts before
making version promises in the interface.
