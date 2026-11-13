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
