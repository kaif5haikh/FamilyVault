# Permission matrix — proposed defaults for review

Roles are per-family: `administrator`, `member`, `viewer`. Family relationship is
not a role. No role assignments or private document access are inferred for the
four people. Default deny when membership/grants are absent, expired or revoked.

| Action | Administrator | Member | Viewer |
| --- | --- | --- | --- |
| Invite/revoke members, assign roles, revoke devices | Yes, trusted server control plane | No | No |
| Read shared family finance/assets/liabilities | Yes | Yes | Yes |
| Create shared records | Yes | Yes, within granted module | No |
| Edit draft records | Yes, within scope/revision | Own or explicitly granted | No |
| Change posted financial history | Linked correction with audit | Authorized linked correction | No |
| Read restricted business records | Explicit business grant | Explicit business grant | Explicit read grant |
| Read private documents | Owner/explicit document grant | Owner/explicit document grant | Explicit read grant |
| Upload/version documents | Ownership or document write grant | Ownership or document write grant | No |
| Grant document access | Owner or explicit manage grant | Owner or explicit manage grant | No |
| Download/decrypt document | Read grant plus usable key envelope | Same | Same |
| Export | Authorized scope with reauthentication | Authorized scope with reauthentication | Only if explicit export grant |
| Family-wide restore/delete | Reauthenticated administrator plus reviewed recovery flow | No | No |

Administrator control over membership does not itself grant decryption of private
documents. Recovery custodians/key escrow access must be decided explicitly.
The prototype does not implement these controls yet and accepts no real records.

## Database enforcement

- Every domain row includes `family_id`. Composite `(family_id, id)` foreign keys
  prevent linking a record to another tenant's account/document/business.
- Enable and force RLS on application tables; revoke all anonymous access. Policies
  derive the user from `auth.uid()` and current active membership from the DB.
- Shared reads require active membership and module/resource permission. Document
  metadata, version rows, key envelopes and storage objects use document-specific
  ACLs; do not apply a generic family-read policy to documents.
- Deny direct client DML on authoritative domain tables. Validated mutation RPCs
  enforce revision, scope, privilege, financial invariants and audit atomically.
- Document ACL/key changes are online-only privileged operations. A storage path
  containing a family/user UUID is not proof of authorization.
- Helpers must avoid recursive RLS on memberships: tightly scoped definer helper,
  fully qualified tables, fixed search path and minimal EXECUTE permissions.
- No role checks from editable `user_metadata`. Administrative role changes,
  device registration and membership onboarding need explicit trusted RPCs.
- Revoke sessions with Supabase Auth and maintain current session/device deny
  checks at privileged RPC entry. Unexpired JWTs are not instantly invalidated by
  refresh-token revocation; resource membership checks close the key access gap.
- Supabase service-role bypasses RLS: keep it server-only, restrict workers and
  audit any administrative action. Views/aggregations must preserve invoker RLS.

## Required adversarial tests before rollout

Test two independent families and owner/member/viewer/outsider identities:
cross-family reads/writes/FKs; member escalation; owner change; forged JWT metadata;
revoked membership with old token; direct DML; guessed object paths; private
document list/download/key access; signed URL TTL; aggregate inference; storage
overwrite; unauthorized finalization; restore that attempts to restore old grants.
The SQL proposal deliberately defines no permissive read policies before these
module-specific rules are implemented and tested.
