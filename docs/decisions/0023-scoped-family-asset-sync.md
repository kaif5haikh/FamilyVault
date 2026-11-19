# ADR 0023 Shared holdings and their ledger journals

**Status** Implemented and verified with two independent Dart caches and
local Supabase Auth and PostgreSQL on 2026-11-19.

Reuse the existing family outbox and ordered receipts for advanced finance.
Each root mutation includes the previous revision and the typed rows that its
local transaction produced. The server independently verifies the account,
journal, provenance, domain rules and postings. Only an enrolled device with
current family access can submit an operation. One family lock serializes
revision checks and receipt allocation with the domain transaction.

An asset has a managed ledger account, its own revision, optional
type-specific details and a history of valuation and ownership records.
Require exact delta postings for the acquisition, valuation and later
valuation bridge. PostgreSQL derives prior book value and share in paise with
integer or exact numeric intermediates. Verify the weight, purity and rate
for a metal-rate quote. A closed holding keeps all history and has zero book
value. Restoring it appends exact reversals of the disposal entries. Rental
income belongs to its asset and uses the shared rental category and an active
bank or cash account.

Keep module journal links and receipts append-only. The ordinary ledger
route must reject a direct reversal of a module journal, including rental
income. The separate module route validates the original linkage before
permitting a reversal. No application client receives direct table access.

Replay accepted accounts, holdings, links, journal postings and valuations in
one Drift transaction with the cursor. Write explicit nulls when replaying
cleared optional fields and removal of tombstones. Existing Drift v6 tables
suffice. Ship a client that understands asset receipts with the server
migration before enabling asset writes on a shared family workspace.
