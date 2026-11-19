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

The sender retries the same operation when it loses the receipt and compares
the returned reservation, version number, version ID and digest before
acknowledging it. The receiver checks key signatures and decrypts metadata
before installing any new version. It stores ciphertext on first authenticated
access and checks byte length, digest and file authentication. An approved
holder can give a newly approved device the keys to older versions.

The migration, upload queue, receiver and backfill passed development tests
with real local Supabase services. A version conflict preserves the draft for
preview and export. Shared metadata changes, archive and record links require
their own synchronization commands. Deployment and physical device checks
remain pending.
