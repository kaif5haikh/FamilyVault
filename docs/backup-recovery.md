# Backup and recovery

The owner requires encrypted local backups **and** Google Drive backups. These
are independent destinations using one authenticated archive format. Supabase is
the live synchronization authority; Drive is never a live financial database.
No Drive account, OAuth client/token, cloud project or paid service is configured
by this development work. See [ADR 0003](decisions/0003-confirmed-product-architecture.md).

The versioned archive engine and local verification are implemented. They
snapshot encrypted SQLite, seal document files and the manifest, and verify the
archive with a separately held key. A clean-directory test reopened the exact
paise balance and decrypted an older document version after the source vault
closed. The restore flow installs a separate local vault with a fresh device
identity. The app has a verified local copy workflow. Drive and scheduling
remain in development. [ADR 0019](decisions/0019-encrypted-backup-envelope.md) · [ADR 0020](decisions/0020-local-backup-restore.md)

## Create or restore a local copy

Open **Settings**, then **Encrypted backups**. Enter your existing recovery
key or create a new one and store it separately. Create the backup, then use
**Save a verified copy** to choose a Files destination. Keep the copy somewhere
you can access after losing this device. The app records a verified export
after reading the destination bytes back and matching their digest and length.

On a fresh install, choose **Restore an encrypted backup** under **Family
access**. Pick the file, enter the recovery key and choose **Verify backup**.
After verification, choose **Restore vault** and complete device verification.
The recovered local copy retains the financial IDs, history and saved changes.
To open the live family workspace, sign in and enroll through **Family access**.

Flutter tests use the actual archive and SQLite engine with a file picker fixture.
Android compilation passed. Testing the native picker on physical devices and
building the iOS implementation remain pending.

## Snapshot and archive

A snapshot freezes consistent authorized records, immutable document ciphertext,
all recovery-wrapped keys needed to decrypt them, schema/protocol/envelope versions,
family/snapshot IDs, authorization epoch, server watermark and attachment digests.
Use SQLite backup API/consistent logical export, not a copy of an open WAL file.
Coordinate document references with the DB snapshot; no missing attachment or
missing recovery key envelope may be classified as a complete full-vault backup.
Record whether pending offline operations are included and preserve their IDs.

Encrypt/authenticate manifest, database data, attachment index and recovery key
material with a reviewed versioned, bounded-memory AEAD archive. Use independent
random backup keys and a separately held high-entropy recovery key. The archive
may include wrapped keys; it must never contain the only usable recovery key,
unwrapped private keys in plaintext, refresh tokens, Drive tokens or service keys.
An OS-device-bound key alone cannot recover on a clean device. Recovery custodians,
enrollment and any optional passphrase KDF are still protocol review decisions.

The producer authenticates/decrypts/verifies the finished archive against the
snapshot before marking the artifact complete. Record schema/format, manifest
and ciphertext digests, exact size and validation time. Catalog fields alone do
not prove those operations occurred. A complete archive with a clearly labelled
pending-outbox section is distinct from an unfinished archive or missing files.

## Independent copy state and success

Artifact state: `building → complete` or `failed`. Destination attempt state:
`queued → writing → verifying → verified`, with `failed`/`cancelled` outcomes.
Start a copy only from a complete artifact. A destination receipt requires target
acknowledgement, matching complete size/SHA-256 and verification evidence. Transport
progress at 100%, an HTTP upload response or an existing filename alone is not
success. Retrying creates/continues a known attempt; never reuse a failed receipt.

One snapshot can have a verified local copy and a failed/deferred Drive copy.
Report each separately, including last successful time, pending/error/retry state,
and whether a complete verified backup exists at **both** required destinations.
Do not mark a skipped job successful or show overall healthy status from one copy.

## Local destination

Offer encrypted export to an explicitly selected local destination. Produce a
staged file, flush/durably commit where supported, read it back, authenticate the
archive and verify size/digest before recording a verified copy. Prefer atomic
rename plus durable directory update when the filesystem supports them. Mobile
document providers can lack atomic rename/fsync: write a commit marker last,
read back all bytes and do not claim stronger durability than the provider offers.
Orphan temporary files/markers never become restorable entries automatically.

Manual backups are required. Scheduled backups use platform-permitted jobs with
unlocked key availability, storage and power constraints. Cadence/time zone/retention
are not yet chosen. Android/iOS can delay or refuse jobs; record deferred/failed
attempts and provide foreground/manual recovery. A file solely on the source phone
is lost with that phone; independent custody/removable storage needs review.
Local destination URIs, bookmarks, job leases and OAuth key references stay in the
account/device encrypted local store, outside the shared backend catalog.

## Google Drive destination

The Dart adapter uses the file APIs covered by the narrow `drive.file` scope
for encrypted backup files created by the app. It receives a separately supplied
access token. OAuth consent and platform client configuration remain pending.
Cloud archives and catalog entries omit OAuth credentials. Recovery from Drive
requires access to the Google account that can see those backups.
The hidden `appDataFolder` alternative has different discovery/sharing behavior
and is not silently substituted for user-accessible backup files.

Use resumable binary uploads and opaque names/app metadata. Each snapshot version
is a **new file**, not an overwrite or reliance on provider revision retention.
The authenticated encrypted manifest/catalog identifies snapshot, lineage and
watermark; Drive filename/modified time is not an authority. Retries reconcile
known attempt IDs and verify any candidate remote file before treating it as the
same backup. Do not create public links or automatically share files externally.

After a final upload acknowledgement, retrieve file metadata and verify identity,
non-trashed state, complete size and SHA-256 where provided. If the strong digest
is unavailable, read/download the completed ciphertext and hash it; MD5 alone is
not the application's authenticity/integrity test. Verify authenticated archive
contents again before every restore regardless of cached upload success.
Interrupted/resumable-session expiry, 401/403, quota, deletion and unavailable
network remain incomplete/failed states. No automatic paid quota purchase.

Download backups with the separately authorized Drive connection. Scan/discover
app-created versions and rebuild a local catalog from authenticated manifests,
not from a source-device database that may have been lost. Clean Android and iOS
installs, a missing catalog and the operator's Drive credentials are required test
cases. A Drive account/file unavailable to the recovering member remains a real
recovery dependency; local export is an independent alternative.

The transport and a clean restore from a downloaded archive passed the local
Drive API fixture. Native account consent and the hosted provider drill are
pending. [Scopes](https://developers.google.com/workspace/drive/api/guides/api-specific-auth),
[resumable uploads](https://developers.google.com/workspace/drive/api/guides/manage-uploads),
[file checksums](https://developers.google.com/workspace/drive/api/reference/rest/v3/files),
[revision handling](https://developers.google.com/workspace/drive/api/guides/manage-revisions),
[app data folder](https://developers.google.com/workspace/drive/api/guides/appdata).

## Restore and clean-device acceptance

1. Begin on a clean installation/isolation directory; preserve the existing vault.
   Select a verified local export or independently downloaded Drive version.
2. Obtain recovery material separately. Authenticate manifest and all envelope
   metadata; check every digest/length/key reference and reject missing, truncated,
   wrong-key, tampered or unsupported archives before activating any restored data.
3. Reconstruct DB and document files, validate SQLite integrity/FKs, apply only
   reviewed migrations and actually decrypt/verify every referenced document.
   Metadata-only validation is not complete recovery. Do not restore auth tokens.
4. In normal online recovery, independently authenticate the member, approve/enroll
   the new device, fetch current membership/session bindings and rewrap keys for it.
   Old grants/device approvals from a backup do not authorize current live access.
5. Preserve record/operation IDs; reconcile pending work against current receipts
   and the retention floor before retry. Rebootstrap stale cursors to prevent
   duplication, permission resurrection and deleted-record resurrection.
6. Compare snapshot counts, relationships, exact paise values and decryption results
   privately. Present a clear validation report; switch only after validation and
   explicit confirmation. Shared-server replacement is administrator-only and a
   separate reviewed, destructive recovery operation.

If Supabase/Auth itself is unavailable or lost, the recovery key permits isolated
archive verification/decryption. This must not silently reactivate old accounts,
roles or device grants. A quarantined offline recovery mode and trusted administrator
re-establishment procedure need review before a disaster-recovery claim. Full
backend recovery must restore coordinated data/receipts/audit/ciphertext at a known
watermark, then establish current authentication and authorization independently.

Test **both** destinations on clean devices: missing/wrong recovery key, absent
source device/catalog, corrupted/truncated copy, missing document/key envelope,
pending already-accepted operations, stale schema/cursor, revoked membership/device,
Drive consent revoked/quota failure and interrupted copy. Record an actual restore
drill and recovery time before declaring production readiness. The host drill
verified local and fixture Drive archives after restoring into separate app
directories. Hosted Drive and physical-device recovery drills remain pending.

## Export, retention and deletion

Authorized structured exports preserve IDs, dates, currency/scale and relationships;
exact INR output is paise with Indian presentation. Plaintext export needs an
explicit destination and reauthentication; do not create shared temporary copies
or spreadsheet formula injection. All exports remain outside Git.

Financial records use soft deletion and immutable audit. Family-wide purge/account
removal are separate administrator workflows; Auth deletion must not cascade away
shared history. Backup file deletion/retention and recovery custodians need review;
no cadence, legal retention, RPO/RTO or paid PITR dependency is invented here.
Do not delete the last verified independent copy before a replacement is verified.
Key revocation cannot erase old downloads/backups. Hash lineage cannot by itself
prove the newest backup exists if an attacker deletes the newest catalog/files;
trusted recovery checkpoints and rollback detection require review.
