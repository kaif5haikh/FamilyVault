# Implementation decisions

See ADR 0004 for execution authority and migration strategy. Confirmed product
choices in ADR 0003 remain binding: INR integer paise, shared family records and
documents, independent identities, local plus encrypted Drive backups.

- Select conservative, explicitly documented accounting/rounding defaults where
  engineering requires a choice; preserve data and expose terms rather than
  silently guessing loan/valuation facts. No real family records are seeded.
- Use additive relational Drift migrations; never execute the review-only SQL as
  a migration. Keep posted ledger facts immutable and correct via linked reversals.
- Offline vaults are explicitly local; do not pretend local identities have cloud
  membership. Cloud sessions authorize a separate scoped cache and live sync.
- Keep production deployment disabled without separately supplied credentials and
  explicit authorization; working local/mock integrations are labelled accurately.

## M02 — executable local ledger

- Drift v2 adds structured family/device metadata, accounts, journal aggregates,
  postings, budgets, reconciliation records, preferences and append-only audit.
  v1 outbox/checkpoint/conflict tables and historical snapshot are preserved.
- Debit-positive asset/expense and credit-negative liability/equity/income postings
  balance exactly. Validate with BigInt, cap each journal's total debits/credits to
  signed 64-bit, and accumulate reports with BigInt to avoid SQLite SUM overflow.
- Posted journals/postings are immutable SQL-guarded facts. Cancellation appends an
  exact mirrored reversal on the original accounting date, then marks the original
  display record deleted. Audit timestamps retain the actual correction time.
  Reports always include original and reversal, including tombstoned originals.
- Correction is one outbox aggregate (original tombstone, reversal, replacement),
  not two independently accepted server operations. The backend implementation
  must accept/reject the complete aggregate transactionally.
- Chart defaults are categories/system accounts only, with deterministic family
  UUIDv5 identifiers. There are no sample balances, people or transactions.
- Renaming shared accounts preserves their creator; all writes retain modifier,
  revision, immutable audit and pending mutation in the same local transaction.
  Local enrollment checks do not substitute for the later server authorization.
