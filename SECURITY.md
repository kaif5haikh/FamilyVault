# Security policy

FamilyVault handles financial and identity information. This development
release is for synthetic records. Hosted configuration and a production
security review are separate from the verified local release checks.

Report suspected vulnerabilities through GitHub private vulnerability
reporting when enabled, or contact the repository owner through
an already established private channel. Do not create public issues, attach real
documents, paste access tokens or upload database dumps.

## Required controls

- HTTPS/TLS for every cloud connection, platform certificate verification intact.
- Encrypted local SQLite, per-account keys in OS secure storage, private app files.
- Client-side authenticated encryption of documents before any cloud upload.
- Supabase RLS/private buckets; current membership, enrolled session/device and
  administrator boundaries checked on the server. Every authorized member shares
  ordinary financial/document access; document ownership is not an access rule.
  No service-role/secret keys on clients.
- Persist sessions in secure storage, revoke sessions/devices server-side, lock
  locally on background and switch accounts without exposing another cache.
- Server-controlled revisions, append-only audit events and idempotent mutations.
- Authenticated document downloads through an audited gateway, with direct
  unaudited Storage/client signed-URL paths denied.
- Independent encrypted local and Google Drive backups, separate recovery material,
  truthful destination status and verified clean-device restore from each.
- No financial amounts, identity identifiers, filenames, document content, auth
  tokens, keys or signed URLs in logs, analytics or crash reports.

See the [threat model](docs/security-threat-model.md),
[permissions](docs/permissions.md) and [recovery design](docs/backup-recovery.md).

## Export and removal

Create a verified encrypted export from **Settings**, then **Encrypted
backups**. Keep the recovery key separately and verify that the copy opens
on a clean installation. Individual document exports are decrypted copies
managed by the chosen file destination.

Revoke a member's device and sessions from an authorized administrator account
when access ends. Archive records to retain the financial audit history.
Sign out of the phone and confirm active sessions separately. To permanently
remove a local copy, confirm a verified independent backup and approve any
app data removal on the intended device.

For hosted deletion, the operator must agree the affected family, retained
history, synchronized copies and backup destinations with the owner before
any irreversible change. Membership revocation leaves shared records and
existing backups intact. Full hosted deletion and recovery are operator
procedures that need separate review.

## Incident response

1. Stop affected clients and quarantine access; preserve metadata evidence without
   copying sensitive payloads into tickets/logs.
2. Revoke affected sessions, device grants and memberships as applicable. Rotate
   compromised credentials and encryption keys with a reviewed migration plan.
3. Investigate authorization/audit metadata, determine exposed records and inform
   affected family members privately. Follow applicable obligations after review.
4. Restore only from authenticated, verified backups; validate isolation and the
   fix before reopening access.

Deleting a Git file does not remove historical exposure. Rotate any exposed
credential immediately; review history cleanup separately with the owner.

## Limits

Offline devices cannot receive instantaneous revocation or remote erasure.
Recipients can retain downloaded data and encryption keys. Client-side document
encryption reduces cloud exposure, but does not protect an unlocked compromised
device. PostgreSQL financial metadata remains visible to trusted backend operators;
this design does not claim full end-to-end encryption of all financial data.
