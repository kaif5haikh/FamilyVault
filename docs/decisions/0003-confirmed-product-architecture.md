# ADR 0003: confirmed product decisions and revised architecture

Date: 2026-11-13. Authority: the owner's “Confirmed Product Decisions and
Architecture Update” instruction. **Product decisions confirmed; revised
architecture pending review.** This ADR supersedes conflicting assumptions in
the initial proposals. It does not approve financial implementation or deployment.

## Confirmed decisions

| Decision | Authoritative requirement | Technical consequence |
| --- | --- | --- |
| Currency | INR by default, ₹, integer paise, Indian grouping/lakh/crore; extensible currencies; no financial floating point | Currency catalog fixes INR scale at 2. Every amount retains currency. Parse/format integer digits without a `double` intermediate. Future non-INR amounts use their currency's minor units, not paise. |
| Shared family finance | Father, mother, sister and administrator use independent authenticated accounts; all authorized members view/add/edit shared records, assets, liabilities, reports and dashboards | Only `administrator` and `member` in this scope. Creator identity grants no exclusive edit rights. Server membership/device checks, expected revisions, soft tombstones and immutable audit apply to every member, including the administrator. |
| Shared document vault | All authorized members view/download/upload shared documents; individual ownership remains metadata | Remove per-document grants from this design. Ownership never filters visibility or blocks another member's ordinary upload/versioning. All enrolled members need keys for shared historical and future versions. Downloads use authenticated, audited authorization, not unrestricted bearer links. |
| Two backup destinations | Encrypted local export/scheduled backups where supported, plus encrypted Google Drive upload/download/history; complete restore and integrity checks | One authenticated archive format, independent destination attempts/receipts and per-destination success. Each snapshot is a separate immutable Drive file. Drive is required as a backup integration, never the synchronization authority. |

Membership administration, enrollment approval/revocation, key recovery/rotation,
destructive purge and family-wide restore are sensitive administrator operations.
Ordinary financial collaboration and document access do not require administrator
approval. Precise backup configuration/operator rules below are proposed technical
policy and still need review; the four product decisions above do not.

## Architecture consequences

1. **Money.** Retain generic `amount_minor`/`currency` names; for INR, one minor unit
   is one paise. Reference metadata may seed INR/₹/scale 2/`en_IN`; no family rows
   or balances are seeded. Use checked signed-64-bit storage, exact integer/rational
   calculations and explicit reviewed rounding. Indian grouping example (synthetic
   formatting specification): 123456789 paise → ₹12,34,567.89; 10000000 paise →
   ₹1,00,000.00 / ₹1 lakh; 1000000000 paise → ₹1,00,00,000.00 / ₹1 crore. Compact
   labels never replace exact values or become input to financial calculations.
2. **Identity and provenance.** `created_by` is immutable; `updated_by` identifies
   the latest authenticated modifier. Every accepted modification/deletion has an
   append-only audit event with actor, device, operation, revision and server time.
   Posted accounting edits use linked corrections/reversals by any authorized
   member, preserving prior facts. No hard deletion or owner-only edit condition.
3. **Backend boundary.** Current active family membership, enrolled device and a
   server-bound authenticated session determine access. Composite FKs prevent
   cross-family references and mismatched actor/device pairs. Caller-supplied
   identity, role, timestamps, audit rows or device headers are never authoritative.
   Production RLS/read policies and validated mutation RPCs remain to be built.
4. **Document ownership and keys.** `owner_user_id` describes whose document it is;
   `created_by` identifies the uploader, who can be another member. Reassigning
   ownership preserves history and cannot change shared access. Key envelopes
   remain recipient-device-specific; family sharing does not mean sharing login
   credentials, device private keys or another device's wrapped-key records.
5. **Audited reads.** A proposed authenticated document gateway checks membership,
   enrolled session, finalized version and integrity metadata, then writes an
   access event before streaming ciphertext. Deny direct unaudited Storage reads
   and client signed-URL minting. Record authorized start versus completion/failure
   separately; a failed connection must not be reported as a completed download.
   Offline cached opens produce queued device events, not proof of a live server read.
6. **Backup independence.** A snapshot has one manifest/ID and separate local/Drive
   copy attempts. A local success cannot imply a Drive success. Upload bytes alone
   cannot produce a valid receipt. A complete, verified artifact may contain an
   explicitly marked pending-outbox section; missing required attachments or an
   unfinished archive are incomplete and never eligible for restore.
7. **Recovery.** Keep an independently held recovery key; wrapped keys may be in
   an encrypted archive, the sole usable recovery key may not. A clean device must
   authenticate/verify the manifest, reconstruct the vault, pass DB/FK/document
   checks, and enroll/revalidate current online permissions before synchronization.
   Disaster recovery when Supabase/Auth is lost needs a separately reviewed
   offline recovery mode and administrator bootstrap, not resurrected old grants.

## Database and authorization review

See [database design](../database.md), [permission matrix](../permissions.md),
[PostgreSQL proposal](../design/postgresql.sql),
[future SQLite proposal](../design/sqlite-next.sql) and
[constraint review](../database-constraint-review.md).

The revised SQL removes `viewer` and document ACL tables, adds INR metadata,
modifier provenance, device/session enrollment state, access-event audit and
independent backup catalog/attempt evidence. Temporal, currency, tenant, actor,
version and completion checks are validated where represented in DDL. Cross-row
authorization, audit immutability, accounting balance, key availability and
provider verification still require trusted server code and adversarial tests.
Both proposals deliberately retain deny-all cloud RLS/no client write grants.

The existing Drift v1 tables and `drift_schemas/vault/drift_schema_v1.json` are
unchanged. `sqlite-next.sql` is an isolated design extension applied only to a
scratch database after the v1 proposal; it is not a migration or version bump.
Future financial mirror column mappings remain specified in the database design.

## Unresolved risks and decisions

- Family time zone/report periods; accounting model/chart, rounding, interest/EMI,
  inventory costing, ownership precision and dashboard formulas remain open.
  Currency and shared visibility are already settled and must not be re-opened
  as defaults awaiting an owner decision.
- Ordinary members can copy shared financial and identity/medical records.
  Device/key revocation cannot erase existing downloads or instantly reach offline
  devices. The offline unlock lease and cache-retention policy need review.
- Key exchange, trusted device enrollment, historical key redistribution and
  recovery custodians require protocol review. An enrolled member awaiting key
  rewrapping has a readiness failure, not reduced document permission.
- Full document download auditing requires a controlled read path. RLS alone does
  not record every SELECT; a signed URL is a bearer capability. Locally reported
  views can be delayed, duplicated or bypassed on a compromised device.
- Proposed Drive scope is `drive.file` for app-created encrypted backup files.
  Consent/client setup, account custody, quota, revocation, mobile background limits,
  retention and clean-device file discovery must be tested. No Drive connection,
  OAuth token, paid quota or production project is provisioned in this update.
- Two destinations improve failure independence but share archive/key/implementation
  failure modes. A local copy on the source phone alone is not independent of loss
  of that phone. Retention, schedules, RPO/RTO and independent custody remain open.
- Business access/approval policy remains separately reviewable; restricted billing
  remains unspecified. No new business restrictions apply to shared family records.

## Implementation requirements and evidence boundary

| Area | Existing implementation/test evidence | Required after revised review |
| --- | --- | --- |
| Mobile foundation | Locked/disconnected shell; encrypted native-host Drift metadata and secure-storage adapters; existing tests | Money model/formatter, financial repositories and reviewed migrations; no implementation in this update |
| Shared access | SQL proposal constraints and deny-all isolation validation only | Real Supabase Auth/session binding, RLS allow rules, atomic RPCs and four-member/cross-family tests |
| Documents | Architecture and SQL metadata only | Enrollment/key exchange, encryption, audited gateway, integrity and interrupted-upload tests |
| Backups | Architecture and catalog/completion constraints only | Local/Drive adapters, scheduling, authenticated archive and clean-device restore for each destination |
| Security | Existing host tests and secret scanning | Android/iOS device, live backend-policy, adversarial read/audit, key-recovery and disaster drills |

The operation record states the actual checks run for this revision. Passing SQL
or regression tests is not a completed Drive integration, backup restore, backend
authorization deployment, production security review or architecture approval.

Primary API references informing the proposal:
[Drive scopes](https://developers.google.com/workspace/drive/api/guides/api-specific-auth),
[resumable uploads](https://developers.google.com/workspace/drive/api/guides/manage-uploads),
[file metadata/checksums](https://developers.google.com/workspace/drive/api/reference/rest/v3/files),
[Drive revision retention](https://developers.google.com/workspace/drive/api/guides/manage-revisions),
[Supabase authenticated downloads](https://supabase.com/docs/guides/storage/serving/downloads).
