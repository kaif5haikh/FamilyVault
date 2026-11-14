# ADR 0008: exact wealth, debt and business history foundation

Date: 2026-11-15. Status: implemented local schema and calculation foundation;
module services/UI and backend replication are subsequent work. Execution authority
is ADR 0004; no human architecture review or production deployment is claimed.

Drift v3 adds 15 tables to the existing 13, preserving populated v1/v2 and their
committed snapshots. Creation/upgrade and the schema-version stamp are one SQLite
transaction. A failed DDL upgrade preserves both the prior data and version; there
is no reset fallback. Generated schema, migration helpers and Dart are committed.

Assets have a dedicated ledger account, whole-holding observations and family
ownership in basis points. The family portion is rounded once, half away from
zero, using BigInt intermediates. Owner allocations cannot exceed the family
portion; they never control document or financial access. Unknown price/purity is
NULL, distinct from a recorded zero. Property area retains its recorded unit;
no implicit Mumbai/Ballia area conversion is assumed. Metal mass is milligrams;
purity is parts per million. Nominal 18/22/24 karat conversion is explicitly
labelled nominal, distinct from an assayed value. Investment units retain scale.
Dated immutable valuation events reference their aggregate revision and event
index. Carry-forward events permit a later service to compensate a backdated
quote without changing a previously known later observation. Closure has a
separate accounting date, distinct from when the tombstone was recorded.

Debt principal and actual paid interest remain separate. Rates use integer basis
points; unknown rate/method is not silently interest-free. Calculator methods are
explicit ACT/365 simple interest, flat monthly and reducing monthly estimates.
Monthly nominal APR/12, half-away paise rounding and anchored/clamped month ends
are documented calculation choices, not a claim about a particular bank contract.
Estimates never post interest automatically. Terms are bounded to 600 months;
actual dated repayments and ledger balances determine outstanding principal.

Business stock uses whole pieces and perpetual weighted-average cost. Each issue
rounds its proportional cost; the final unit takes the remainder. Event triggers
maintain the quantity/cost projection and reject negative or overflowing stock.
Corrections reverse the latest active movement and its exact journal; prior events
remain intact. Business stock, cost-of-goods and salary accounts are separate.
Revenue and expenses remain ordinary shared family accounting; the future
restricted billing module has no invented workflow, grants or tables here.

Immutable aggregate/journal links record purpose. Module services must commit
metadata, linked postings, events, audit and one durable outbox envelope atomically.
Generic finance commands must refuse managed module accounts/journals. This
service-level enforcement is the next implementation unit, not established merely
by these schema checks. Backend typed operations must independently enforce the
same tenant, role, balance, revision, chronology and idempotency requirements.

Tests exercise exact decimal parsing, independently calculated EMI examples,
principal conservation, leap-day ACT/365, metal values, weighted stock conservation,
family/account scope, immutable facts, rollback, ownership limits and repeated
stock reversal. Encrypted populated v2 migration and interrupted-DDL tests preserve
history. SQL proposal probes remain separate from this executable local schema.
No cloud sync, real enrollment, vault documents or backups are claimed by this ADR.
