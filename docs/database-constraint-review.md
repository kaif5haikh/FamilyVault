# Database constraints and backend authorization review

Scope: every table class in the revised PostgreSQL/future SQLite proposals,
against the owner's confirmed requirements (ADR 0003). DDL validation runs only
in isolated synthetic databases. Existing Drift v1/application code is not
migrated. **These findings are not a production security approval.**

## DDL coverage and outstanding enforcement

| Table(s) | Reviewed constraints / proposal coverage | Enforcement still required |
| --- | --- | --- |
| `currencies` | Three-letter code, scale range, fixed INR scale 2/₹/en_IN, public reference seed | Trusted catalog changes; stable/versioned units for future currencies; exact parser/formatter and pre-cast input checks |
| `families` | INR default FK, revision/time checks | Stable tenant identity, active-family checks, trusted administrator bootstrap and independent Auth accounts |
| `family_members` | Unique family/user, admin/member roles, active-versus-deleted check, historical rows retained | Current membership evaluation, trusted role assignment, prevent escalation/last-admin loss; no creator-only sharing filter |
| `devices`, `device_sessions` | Same-family member/approver FK; enrollment approval/public-bundle/revocation consistency; actor/device uniqueness; session expiry/revocation and matching user/device FK | Private-key proof, admin approval authority, verified Auth session binding and current membership/device/session checks; rows/headers are not proof |
| `sync_clocks`, `operation_receipts`, `change_events` | Nonnegative counters; unique actor/operation and sequence; SHA-256 size; actor/device FK; typed snapshot object | Family lock/commit ordering, server-computed digest, replay/retention, immutable feed/receipt discipline and authorized snapshots |
| `audit_events`, `document_access_events` | Matching family/actor/device, unique access phase, gateway-vs-cache classification; append-only UPDATE/DELETE and cloud TRUNCATE guards | Stamp real actor/time; atomic mutation audit; read start before bytes and terminal outcomes; DDL/superuser controls; no payload/PII logging |
| `businesses`, `business_grants` | Tenant/member FKs, read/write/manage enum, revision/provenance | Business policy remains separately reviewable; cannot limit shared family finance; billing unspecified |
| `accounts`, `journal_entries`, `journal_postings` | Currency/tenant FKs, nonzero integer postings, status/reversal links; immutable aggregate identity/creator; required modifier/actor FKs | Balanced posted aggregate, minimum postings, account/business currency/scope matching; shared audited corrections; tombstones and atomic history |
| `monthly_budgets`, `savings_observations` | Integer amount/currency; month start, active budget uniqueness; revision/provenance | Approved category/budget and savings definitions, exact aggregation, shared read/edit semantics |
| `assets`, `metal_details`, `property_details`, `investment_details` | Tenant-safe specializations, optional amount/currency pair, positive weight, bounded purity/quantity scale | Specialization-kind match, approved precision, valuation policy and no duplicate family ownership counting |
| `asset_ownerships`, `asset_valuations` | Same-family owner/asset FK, share range, one active owner row, dated nonnegative currency value/provenance | Transactional ownership total ≤100%, intervals, valuation source/current-value rules |
| `liabilities`, `repayment_schedules`, `repayments` | Principal/components, currency/tenant/journal links, repayment uniqueness and provenance | Approved interest/EMI/rounding, currency inheritance, concurrent repayment/balance/overpayment rules |
| `stock_items`, `stock_movements`, `salary_records` | Business/tenant/journal FKs, quantity nonzero, period order and exact currency amount/provenance | Costing, negative-stock policy, accounting basis, business scope and salary settlement |
| `documents`, `document_versions` | Same-family ownership, uploader may differ; creator immutable; version/object uniqueness; digest/size/finalization checks | Family-wide visibility/shared upload, actual immutable finalized content, encryption, storage verification and authenticated read audit; no owner ACL |
| `document_key_envelopes`, `upload_reservations` | Nonempty wrapped key, version/device FK, key-version history/one active envelope; scoped uploader/version/reservation | Trusted recipient keys, family-wide historical/future key coverage, object verification, expiry/cleanup and enrollment |
| `backup_snapshots` | State/format/version/epoch/watermark bounds, actor/device FK, digest lengths/size; complete requires manifest/archive verification evidence | Actually build/authenticate/check archive, all attachments and recovery envelopes; freeze complete artifact and attest producer evidence |
| `backup_destinations` | Local/google_drive kinds; same-family configuring identity | Proposed admin configuration policy and actual Drive account authorization/custody; no tokens/local URIs in cloud catalog |
| `backup_copy_attempts` | Separate target/retry; complete-snapshot FK, observed hash/size equality; consistent acknowledgement/verification/completion required for verified state | Genuine target acknowledgement/readback, transitions/retries, independent results, durability and quota failure |
| v1 outbox/checkpoints/conflicts | Existing uniqueness, revision, JSON, acknowledgement and FK checks unchanged | Full sync worker/domain atomicity, conflict baseline and actual server receipts remain unimplemented |
| Future `local_backup_bindings` and projections | STRICT monetary tables, UUID/date/bool checks, device-local locator/reference FKs, audit/provenance guards; server-only tables excluded | Encrypted account-scoped stores, projection filters, secure-store credentials and reviewed Drift migration/version bump |

Creator/family/ID guards cover provenance-bearing rows. They do not make every
financial fact immutable, create audit events, authorize members, enforce soft
deletion, freeze finalized documents or perform provider calls. Those remain
trusted server requirements. Aggregate children inherit root provenance; device
bindings/administrative catalogs use their trusted server audit paths.

## Authorization review outcome

- Ordinary family predicates use active family membership and enrolled authenticated
  session/device, without `created_by = caller` or document `owner = caller` clauses.
  Both roles can add/edit shared finance and read/upload shared documents.
- Membership/role/device approval, key recovery/rotation and destructive shared
  operations require administrator control endpoints. Submitting an enrollment
  request never approves that device.
- Domain DML and anonymous access stay denied in the SQL proposal. There are no
  allow policies or working mutation RPCs; the app is disconnected. Real Supabase
  RLS/Storage/gateway tests must pass before shared access is claimed.
- Keys are per recipient device, not owner-only grants. New enrollment requires
  historical backfill. Revocation cannot erase copied plaintext/keys or instantly
  reach an offline cache.
- Direct Storage reads can bypass app-specific read audit even with RLS. The
  proposed gateway denies that alternate path and client URL signing; a signed
  bearer URL alone cannot identify/authenticate the actual recipient.
- Backups cannot restore old authorization as current truth. Current Auth identity,
  membership and enrollment are independently checked before live sync. Offline
  disaster recovery requires isolation and a reviewed trust bootstrap.

## Automated design validation and limits

`bash tool/check_proposals.sh` creates a UTF-8 PostgreSQL cluster with a private
Unix socket/no TCP listener, checks every table has forced RLS and verifies an
unprivileged SELECT cannot see a synthetic family row. No production DB is used.
`tool/check_design_constraints.py` probes both DDLs with synthetic fixtures,
checks expected PostgreSQL SQLSTATE/SQLite extended constraint codes and rolls
back every case. An unrelated guard rejecting the test is not counted as the
intended constraint passing.

Cases include INR/Unicode/scale defaults, distinct creator/modifier, creator and
tenant immutability, cross-family links, invalid enrollment/session pairs, audit
immutability, document/key uniqueness, 64-bit bounds, SQLite REAL/date rejection,
archive/copy completeness, verification evidence and independent destination status.
These are **metadata/DDL probes**, not formatter tests, RLS allow-policy tests,
encrypted archive verification, real provider acknowledgements or restore drills.
See the [testing strategy](testing-strategy.md) for remaining acceptance tests.
