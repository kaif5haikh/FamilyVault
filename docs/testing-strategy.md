# Testing strategy — revised architecture

Product requirements are confirmed; revised architecture/feature implementation
remain gated by [the review checklist](review-gate.md). Use synthetic fixtures,
isolated databases and no actual family documents/financial data. The operation
record identifies actual runs; this strategy also lists required future tests.

## Current executable evidence

| Check | Evidence supplied | What it does not establish |
| --- | --- | --- |
| Existing 9 Flutter tests | Host encrypted Drift/wrong-key recovery, metadata constraints/rollback, safe schema failure, secure-storage adapters, locked navigation/accessibility | Android/iOS keystore enforcement, backend integration or financial features |
| Proposal SQL validation | PostgreSQL DDL/forced deny-all RLS and isolated read denial; v1 SQLite integrity/FKs | Production allow policies, family collaboration or real Auth/session verification |
| Revised design probes | INR metadata, actor/tenant/provenance checks, immutable audit, document/key metadata, future STRICT SQLite, independent backup evidence | Actual crypto/Storage/Drive transfer, complete read audit or restore |
| Repository scans | Indexed path/secret checks and redacted Gitleaks | General privacy/security certification |

```bash
source tool/env.sh
bash tool/check_proposals.sh
flutter analyze --no-pub
flutter test --no-pub --reporter expanded
git diff --check
python3 tool/check_repository.py
git diff --cached --binary -- . | .tools/gitleaks/gitleaks stdin --no-banner --redact
```

SQL/probe changes warrant rerunning their checks; docs-only work does not require
unrelated build matrices or upgrades. No real provider is connected just to
validate this update. Never claim a planned test ran.

## Money and Indian presentation — future

Test exact integer paise parse/arithmetic/export and ₹/Indian grouping with
synthetic values: 0 → ₹0.00; 123456789 → ₹12,34,567.89; 10000000 → ₹1 lakh / exact
₹1,00,000.00; 1000000000 → ₹1 crore / exact ₹1,00,00,000.00. Test negative values,
one-paise differences, lakh/crore boundaries, signed-64-bit limits and checked
overflow. Compact labels cannot change totals or become calculation inputs.

Reject nonintegral/floating/boolean/NaN/Infinity/exponent/coerced API money before
SQL casts; verify locale input with a reviewed exact parser. Test future currency
units and no aggregation across unlike currencies. Interest/EMI/accounting formulas
wait for review. No financial formatter/model is implemented in this milestone.

## Backend roles, sharing and audit — required before release

Use distinct test Auth identities for an administrator, three members, an outsider
and a second family, with no shared credentials. Exercise actual RLS/RPC/Storage
artifacts in an isolated local Supabase environment:

- Each enrolled member reads shared finance/assets/liabilities/reports and adds or
  edits another member's record. Creator stays unchanged; modifier/audit identify
  the caller; concurrent same-revision edits produce explicit conflicts.
- Every member lists/reads/uploads/versions documents owned by another member.
  Ownership changes never change visibility. New devices receive historical keys.
- Reject outsiders/cross-family rows, FKs, RPCs, aggregates, paths and key access.
  Revoked/expired/missing membership/device/session fails even with an old JWT;
  forged role/user/device headers fail.
- Members cannot manage membership/roles, approve themselves, revoke another device,
  rotate recovery keys or restore/purge shared server data. Admin endpoints
  reauthenticate, audit changes and preserve a viable administrator.
- Client DML cannot change creator/family/ID, rewrite/truncate audit or hard-delete
  financial history. Tombstones and linked posted corrections survive sync/export.
- Secure session and PKCE persistence have no preferences fallback, sensitive logs
  or privileged client keys. Test security-definer/view-owner behavior explicitly.

## Documents, gateway and integrity — required

Test enrollment challenge replay/substitution/expiry, bound sessions, wrong-device
key delivery and recovery. Verify client AEAD metadata, nonce/key isolation, size/
digest, corrupt/truncated imports and immutable finalized paths. Interrupted
upload or upload success alone cannot bypass trusted server finalization.

Downloads require logged-in enrolled identity, durable access-start audit before
bytes, and accurate terminal outcomes/request IDs. Force audit failure and assert
no bytes are released. Deny raw Storage/client signed-URL bypass and cross-family
access. Test partial transfer/disconnect/retry/revocation; review stream recheck
policy. Cache-open reports survive restart/deduplicate, but stay labelled device
reports with untrusted client times rather than proven server reads.

## Offline sync and revocation — required

At least two devices/users: offline create/edit/delete/restart; concurrent member
edits; reordered/lost acknowledgements; identical/altered replay; commit/cursor
ordering; partial page crashes; historical snapshot/key backfill; epoch/revocation;
delete-edit conflict; unsupported protocol/schema; receipt/tombstone retention;
already-accepted restored outbox. Test disk/resource failure and OS-denied jobs
with truthful pending/retry states and no data loss.

## Both backups and clean-device restore — required

Run full archive → local copy → clean-device restore **and** archive → Drive
upload/discovery/download → separate clean-device restore. Preserve sources and
use synthetic fixtures. Recover exact paise, relationships, stable IDs, audit,
tombstones, pending operations and every document/key version. Actually decrypt
documents; counts/digests alone are insufficient. Test without the source device,
old keystore, local catalog, auth tokens or an already cached backup file.

Failure cases: transport at 100% only; missing acknowledgement/receipt; wrong size/
digest; missing attachments/recovery envelopes; truncated/corrupt archive/manifest;
wrong/lost recovery key; future/invalid schema; no atomic rename; disk-full/ejection;
locked/deferred scheduled jobs; Drive 401/403/quota/revoked consent/session expiry,
remote deletion and lost responses. Local success + Drive failure (and reverse)
must show separate results and never overall healthy status for both. Incomplete
copies never appear eligible for restore.

Normal restore independently authorizes/enrolls the new device and fetches current
membership; old roles/sessions confer no live access. Reconcile pending IDs without
duplication/resurrection. A separate backend/Auth-loss disaster drill must establish
trusted administration without silently reviving old grants. Record device/OS,
redacted snapshot/results, measured recovery time and failures in private artifacts.

No Drive call, clean-device restore, production RLS test or native-mobile security
test is established by SQL/Flutter host tests in this update.
