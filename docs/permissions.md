# Permissions — confirmed shared model and proposed backend contract

The owner confirmed shared financial editing and shared document access in
[ADR 0003](decisions/0003-confirmed-product-architecture.md). The active roles are
`administrator` and `member`; `viewer` is not part of this product scope. Father,
mother and sister have independent accounts; the owner is administrator. No real
Auth accounts or relationship rows are seeded. A role never replaces enrollment.

| Action | Administrator | Every other authorized member | Enforcement requirement |
| --- | --- | --- | --- |
| Read shared finance, assets/properties/metals, liabilities, dashboards/reports | Yes | Yes | Current family membership, enrolled session, family-scoped read policy |
| Add income/expenses; edit another member's shared record | Yes | Yes | Validated RPC, expected revision, immutable creator and actor audit; no ownership condition |
| Correct posted accounting facts | Yes | Yes | Linked correction/reversal preserving the prior history; accounting policy still under review |
| Delete a shared financial record | Soft tombstone | Soft tombstone | Audited RPC, related invariants, never client hard DELETE |
| List/read shared document metadata and finalized versions | Yes | Yes | Family membership; ownership has no visibility effect |
| Upload a shared document or create a new version | Yes | Yes | Enrollment, ciphertext reservation, integrity checks and audited finalization |
| Authenticated document download/decryption | Yes | Yes | Audited gateway and key envelope for the caller's enrolled device |
| Change ordinary document metadata | Yes | Yes | Revision check and immutable change audit; never change family scope |
| Invite/remove members or alter roles | Yes, reauthenticated | No | Trusted server control plane; no self-escalation or last-admin loss |
| Approve/revoke device/session; recovery and key rotation | Yes, reauthenticated | No | Proof of device key possession plus trusted approval; no approval required for each ordinary read/upload |
| Permanently purge records/versions or restore shared server state | Yes, explicit reviewed procedure | No | Separate sensitive operation; retention/recovery and destructive-action safeguards |
| Read restricted business data | Separate policy review | Separate policy review | Existing business grant proposal cannot restrict shared family records; billing remains unspecified |

Proposed backup-operator policy, awaiting architecture review: any authorized
member may make an encrypted local export of the shared data after local unlock;
administrator manages shared Drive destination configuration/schedules, recovery
custody and family-wide restore. A member may request enrollment/restore to a new
local cache; this does not authorize enrollment approval or replacement of shared
server state. Shared FamilyVault access does not grant access to somebody else's
Google account. Never share Google or Supabase login credentials.

## Backend authorization contract

1. Resolve caller `auth.uid()` and the verified Auth JWT session identifier on the
   server. Bind that session to an enrolled device only after possession proof and
   administrator approval. A client-supplied `device_id` header is not enrollment.
2. Require current active/non-deleted membership, matching user/device/session,
   enrolled/non-revoked device and a non-revoked/unexpired server binding. Check at
   read, write, key-envelope delivery, download and administrative boundaries.
3. Shared financial reads and edits deliberately omit `created_by = auth.uid()`.
   `created_by` cannot change; set `updated_by` from the caller, never its payload.
   Document ownership likewise never appears in an ordinary read/upload predicate.
4. Scope rows, joins, foreign keys, reports and aggregates to `family_id`. A valid
   family UUID in an object path alone proves no access. Keep authorization epochs
   and server current state authoritative after revocation and on reconnect.
5. Enable/force RLS; no anonymous grants. Direct domain writes stay denied; typed
   RPCs validate revision, provenance, accounting rules and atomic audit/feed writes.
   Account/role/device/key changes and hard purge are separate administrator RPCs.
6. Private Storage denies direct unaudited downloads and client signed-URL creation.
   The proposed gateway authorizes a finalized version, commits an access-start
   audit event, then streams ciphertext and appends a terminal event. Gateway
   credentials, if needed for Storage, are server-only with minimal capabilities.
   Ordinary signed URLs are bearer capabilities and do not satisfy this contract.
7. Every member has a right to shared documents, but private keys/envelopes remain
   device-specific. Return only the caller's envelope to a currently enrolled
   device. Enrollment triggers historical key backfill; pending backfill is a
   readiness state, never an owner-imposed permission restriction.
8. Append-only audit events preserve actor, device, request/operation, revision and
   trusted time. Read events distinguish authorization, transfer completion/failure
   and untrusted offline cache reports. No document contents or identity numbers
   enter audit payloads or operational logs.
9. Security-definer helpers must use qualified names, fixed empty search path,
   minimal owner privileges and restricted EXECUTE grants. Avoid recursive RLS
   on memberships. Editable JWT user metadata never determines roles. Session
   revocation alone may leave an unexpired JWT, so re-check current bindings.

## Evidence boundary

The cloud SQL proposal has **deny-all RLS**, no usable allow policies or mutation
RPCs. Its constraints and append-only audit guards can be tested locally; that
is not proof of production shared access or a working gateway. The application
remains disconnected. [Testing strategy](testing-strategy.md) specifies the
required real Auth/RLS/Storage and multi-device tests before release.
