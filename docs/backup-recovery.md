# Backup, export, deletion and disaster recovery — proposal

## Backup is separate from sync

Supabase is the shared live database, not an independent backup. Google Drive
may receive encrypted archives through an explicitly authorized future adapter;
it is not the live database. No Drive account access or cloud setup is performed
now. Do not rely on paid PITR or assume free-tier backup retention/availability.
Retention, cadence, recovery point/time objectives and custodians need review.

## Archive format and creation

An authenticated, versioned manifest identifies family, creator, snapshot time,
database/schema/protocol version, object versions, key versions, ciphertext
digests/sizes and sync watermark. Identifiers and sensitive metadata belong
inside the encrypted envelope. Never include refresh tokens, service keys or
unwrapped document/DB keys in a plaintext archive.

Create a transactionally consistent SQLite snapshot using the SQLite backup API
or a consistent logical export; copying an open database file ignores WAL state.
Coordinate an attachment manifest with the snapshot; include referenced immutable
ciphertext versions. Separate server-confirmed data from local pending operations.
A backup with pending local work is valid but must be marked as such.

Encrypt/authenticate the archive with a random backup key and wrap that key to a
separately held high-entropy recovery key. If a user passphrase option is added,
require a reviewed memory-hard KDF (e.g. Argon2id with versioned tuned parameters)
and weak-password handling; password-only shortcuts are not a foundation feature.
Stream in bounded memory using a reviewed chunked envelope, unique nonces and
manifest binding. AEAD failure makes restore fail closed.

Upload ciphertext and verify destination acknowledgement and digest before
recording backup success. Use opaque names and retain an independent encrypted
copy/recovery material. Never store the only recovery key in the same destination.
Server disaster backup must include database state, audit/receipt/feed floor,
document ciphertext and wrapped key envelopes at a coordinated watermark.

## Restore procedure

1. Use an isolated installation/temp vault; retain the current vault untouched.
2. Obtain recovery material separately, authenticate/decrypt archive and verify
   every manifest digest, envelope version and object reference.
3. Run integrity/foreign-key checks and supported migrations on the restored copy.
   Reject unsupported future schemas; no destructive downgrade/reset fallback.
4. Authenticate online and fetch **current** memberships/device grants. Backup
   permissions and old refresh tokens never grant current access.
5. Preserve entity/operation IDs; register the restored installation as a new
   device. Reconcile pending operations against server receipts and the retention
   floor before replay; a stale snapshot must rebootstrap to avoid resurrection.
6. Check authorized counts/reconciliation totals privately; verify documents can
   actually decrypt. Present results without logging record contents.
7. Switch to the validated vault only after user review; retain the former copy
   until recovery is confirmed. Any permanent cleanup requires explicit approval.

Exercise missing/wrong key, tampered/truncated archive, absent attachment, old
schema, expired cursor, already-accepted pending mutation and revoked member.
Document an actual isolated restore drill before calling backups production-ready.

## Export and recovery portability

Offer explicit-scope export of authorized structured data with currency/units,
dates, stable IDs, version and relationships. Export documents only with current
authorization and successful decryption. Plaintext exports require reauthentication,
an explicit destination and an exposure notice at the export action. Avoid
leaving copies in shared temp directories; avoid CSV formula injection when
human-readable spreadsheet export is implemented. No export implementation yet.

## Deletion

Differentiate user/device revocation, logical record deletion, document version
retention, family deletion and account deletion. Domain deletion emits tombstones
and audit metadata; hard purge occurs only after reviewed retention/cursor/backup
constraints. Document object deletion follows reference/manifest validation.
Auth user deletion must not silently cascade-delete shared financial history.
Preserve required provenance with an approved pseudonymization policy.

Reauthenticate family-wide deletion, export/recovery options and explicit scope
confirmation; revoke memberships/sessions/devices, remove envelopes and eligible
objects, then verify. Explain delayed expiry of encrypted backups and the inability
to erase recipients' downloads. Do not invent legal retention periods. Important
data is never permanently deleted by this initialization work.
