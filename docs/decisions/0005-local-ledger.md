# ADR 0005: exact atomic local accounting

Date: 2026-11-13. Status: implemented and host-tested locally (M02).

Use immutable posted double-entry journal aggregates in encrypted Drift v2.
Signed integer paise, family-scoped composite foreign keys, strict tables, SQL
seal/reversal/immutability triggers and repository validation reinforce each other.
Reports aggregate with BigInt. Transfers affect asset accounts only; they do not
inflate income or expenses. Opening balances have an equity contra posting.
Reconciliation compares a recorded statement to the ledger; an adjustment requires
an explicit caller decision and appends a separate journal.

Cancellation mirrors each original posting and retains both records. Corrections
are a single durable sync aggregate containing the old tombstone, reversal and
replacement. This is a requirement for the server RPC, not a claim that remote
sync exists. Duplicate command IDs return the existing result only when the
canonical command digest matches. Changed retries are explicit conflicts.

The transaction boundary includes domain facts, immutable local audit and outbox.
A failure in any of these rolls back all changes. Ownership does not restrict
shared editing. Independent member/device identity is validated on local writes;
cloud membership/RLS remains a separate milestone.

Evidence: encrypted historical v1 fixture migration (including conflict/checkpoint
rows), snapshot verification, balance/reversal/idempotency/shared-member/overflow/
rollback/adversarial SQL tests. These tests do not prove native mobile key storage,
Supabase enforcement or synchronization. See development test results.
