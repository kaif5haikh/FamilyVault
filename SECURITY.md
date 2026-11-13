# Security policy

FamilyVault handles financial and identity information. The initial foundation
has not passed a production security review and must not hold real family data.

Report suspected vulnerabilities using this private repository's security
advisory/reporting channel when enabled, or contact the repository owner through
an already established private channel. Do not create public issues, attach real
documents, paste access tokens or upload database dumps.

## Required controls

- HTTPS/TLS for every cloud connection, platform certificate verification intact.
- Encrypted local SQLite, per-account keys in OS secure storage, private app files.
- Client-side authenticated encryption of documents before any cloud upload.
- Supabase RLS and private buckets; membership, role and object permissions checked
  on the server. No service-role/secret keys on clients.
- Persist sessions in secure storage, revoke sessions/devices server-side, lock
  locally on background and switch accounts without exposing another cache.
- Server-controlled revisions, append-only audit events and idempotent mutations.
- Encrypted backups with separate recovery material and regularly verified restore.
- No financial amounts, identity identifiers, filenames, document content, auth
  tokens, keys or signed URLs in logs, analytics or crash reports.

See the [threat model](docs/security-threat-model.md),
[permissions](docs/permissions.md) and [recovery design](docs/backup-recovery.md).

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
