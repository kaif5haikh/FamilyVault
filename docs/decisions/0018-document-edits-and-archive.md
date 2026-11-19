# ADR 0018 Shared document edits and archive

Metadata, archive and restore advance the document revision without changing
a file version. An approved member with the latest version's addressed key
can edit. The server checks the expected revision and source version under
the family write lock, records the original request and actor in immutable
history, and returns the same receipt on a matching retry. Ownership remains
metadata. Every prior file remains available to authorized devices.

Drift v6 adds a partial index for one pending metadata or archive edit per
document on each device. The edit and its audit event share a local transaction.
The document worker reads these edits, while the financial feed processes its
own outbox records. Titles, categories and dates are sealed using the current
file key and an owner-bound context. A receipt advances the queue only after
the operation, document, version, action and accepted revision agree.

The accepted projection stays visible until the server accepts an edit. A
conflict keeps the draft command and brings in the accepted revision. Connected
replicas can advance to a later validated document revision and import its
consecutive file history in the same transaction. The local vault still checks
one revision per edit. Finance recovery preserves pending document edits and
the existing document projection.

Executable PostgreSQL checks and a three-device Dart round trip verified these
behaviors with local services. A configured hosted deployment and physical
device tests remain pending.
