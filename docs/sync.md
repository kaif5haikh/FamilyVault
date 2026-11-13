# Offline synchronization protocol — design, not yet implemented

## Identity and durable local writes

Use UUIDv4 for entities, devices and operations. Entity identity never changes
across devices or restores. A mutation envelope contains operation ID, family ID,
device ID, entity type/ID, mutation kind, expected base revision, schema version
and canonical payload digest. Actor identity is derived from the authenticated
server session, never trusted from the envelope.

One Drift transaction commits the domain change and an immutable outbox envelope.
Persist before showing success. Later edits get new operation IDs; never rewrite
an operation already attempted. UI distinguishes saved locally, pending, retrying,
conflicted, rejected and server-confirmed. Connectivity signals only wake retries.

The foundation creates metadata tables only; domain-write transactions, transport
and worker scheduling are future work.

## Push and acknowledgement

1. A single coordinator per vault leases eligible operations; a crashed worker's
   lease can expire. Serialize aggregate dependencies (e.g. journal and postings).
2. Refresh/revalidate session and current device/membership grants before sending.
   Check protocol/schema compatibility. Unknown grants block uploads.
3. Server transaction locks a per-family sync clock row, checks session/device
   revocation, membership, resource permissions and expected entity revision.
4. Look up `(family_id, actor_id, operation_id)`. An identical replay returns its
   prior receipt. Reuse with a different payload digest is rejected. Idempotency
   receipts outlive the maximum supported retry/restore window; old restored
   clients must rebootstrap rather than replay after that window.
5. Validate domain invariants. Commit entity revisions, receipt, audit metadata
   and change events in the **same transaction**. A whole transfer is one aggregate
   operation; no half-transfer or partial posting acceptance.
6. Only a receipt whose operation ID, digest and accepted revision match the
   pending operation can mark it acknowledged locally. Persist receipt and merge
   canonical server state atomically. Lost response means retry the same operation.

Retries use bounded exponential backoff with jitter; honor server retry hints.
Timeout/5xx remains pending. Auth errors pause; permission/validation rejection is
durable and visible. Never discard local data or retry a rejected operation as
another new transaction automatically. Record no payloads in operational logs.

## Pull and commit ordering

Do **not** use device timestamps, `updated_at`, PostgreSQL sequences or
transaction IDs as a lossless commit cursor: a lower allocated value can commit
after a higher value that was already pulled.

Proposed small-family solution: every writer locks the same family clock row
until commit and increments its transactional counter for each change event.
This serializes family mutations and makes visible event order safe for cursor
advancement. All writers, including administration and document finalization,
must take this lock. Cross-family operations are disallowed. Revisit throughput
only with evidence; a WAL/CDC protocol is an alternative requiring more machinery.

Pull RPC captures a committed upper bound and returns authorized events after the
cursor, an explicit `scanned_through` cursor and authorization epoch. Pagination
advances through scanned events, even if hidden events are filtered, without
revealing hidden payloads. The server applies authorization at query time. Each
page and cursor commit atomically in Drift. A partial page cannot advance its
cursor. Realtime is only a wake-up signal; periodic/foreground/manual pulls are
the recovery path for lost notifications.

Before serving a pull, compare the caller's authorization epoch. Grant/membership
changes bump it under the family lock and invalidate that user's snapshot. On
mismatch, suspend reads, purge or quarantine revoked cache/key material, obtain
a complete authorized snapshot at a fixed watermark, then resume incremental
pull. Newly granted old records require snapshot backfill; a filtered change
feed alone cannot discover them. An offline stale cache remains a documented
revocation limitation, bounded by the reviewed local-unlock lease policy.

## Conflicts and duplicate prevention

Compare server revisions (optimistic concurrency); never use last-write-wins for
amounts, ownership, repayment, stock or permissions. Preserve base/local/server
versions in the encrypted conflict store and require an explicit authorized
resolution. A resolution uses a new operation referencing the rejected conflict
and latest server revision. Delete-vs-edit is a conflict; tombstones do not
silently resurrect. Append immutable ledger/valuation/repayment events, correcting
them with linked reversals instead of overwriting posted history.

UUID/operation uniqueness prevents replay duplication, not two independent user
entries representing the same event. Such semantic duplicates need reviewed
user-facing detection/confirmation; do not guess from equal amount/date.

## Document transfer state machine

`local encrypted → queued → reserved → uploading → object uploaded →
verifying → finalized → acknowledged`. Failure at any step remains incomplete.

- Encrypt a new document version locally with a fresh key and nonce; store an
  authenticated versioned envelope, ciphertext length and SHA-256 digest.
- A server reservation allocates an immutable opaque object path tied to the
  document version, authorized uploader and operation. Deny overwrite/upsert.
- Upload **ciphertext** to a private bucket. Validate plaintext file type/size
  locally before encryption. Ciphertext is `application/octet-stream`; never
  pretend an encrypted blob is a PDF for MIME allowlisting.
- Storage upload success does not acknowledge metadata or sync. A trusted server
  finalizer checks caller/grants/reservation and actual stored object's complete
  size and checksum (read/stream bytes or trusted provider checksum; never trust
  an arbitrary ETag or a client-provided digest by itself).
- Finalizer commits immutable version metadata, receipt, audit and change event
  under the family lock. Only then acknowledge local synchronization.
- On interruption, inspect reservation/object/finalization state and retry safely.
  Reconcile abandoned reservations and unreferenced objects after a reviewed grace
  period; never garbage-collect pending local-only material.
- Download with authorization/short-lived signed URLs, verify ciphertext digest,
  authenticate the envelope and decrypt locally. Private buckets still require
  document ACL/key grants. Do not log object paths or signed URLs.

PostgreSQL and Storage do not share an atomic transaction; reservations,
finalization and reconciliation are required to bridge that boundary.

## Tombstones, recovery and test plan

Keep tombstones/feed/receipts until all supported device cursors and backup replay
windows are covered. Devices behind the retention floor must take a fresh
authorized snapshot. Never treat an old backup as a new family or blindly replay
its outbox. Exports preserve stable IDs and provenance.

Future fault tests: offline restart; concurrent same-revision edits; repeated and
altered-payload operation replay; lost receipt; concurrent commit ordering;
out-of-order dependency uploads; reconnect after revocation; new grant backfill;
delete/edit; expired cursor; disk full; killed upload; uploaded-but-not-finalized
object; corrupted ciphertext; background scheduling denied; account switch;
restored pending operation already accepted remotely.
