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

## M03 — local vault lifecycle

See ADR 0006. Offline workspace keys live in a versioned OS-secure catalog, with
an initializing/ready state so interrupted setup can resume without discarding
keys. Device authentication precedes key use. Missing ready files/catalogs are
recovery errors; no automatic reset. Background/idle locking disposes the encrypted
database and its in-memory key bundle. Android screenshot protection and iOS
snapshot masking supplement the Flutter privacy cover. Key zeroization is best
effort, not a VM/hardware guarantee. Framework/platform error logs are constant,
curated messages. The working offline overview is labelled "On this device".

## M04 — finance UI and reporting

- Overview balances stop at today's accounting date; monthly/yearly reports clearly
  identify their period end. Yearly means January–December calendar year, not an
  implied Indian tax return or fiscal-year computation.
- Charts consume dimensionless ratios only. Labels, tooltips, totals, budgets and
  percentages are calculated with integer/BigInt arithmetic. Exact figures remain
  available alongside charts; no floating-point financial arithmetic is adopted.
- Archive/restore retains account history; nonzero balance accounts must be
  reconciled/transferred before archival. Budget edits check the displayed revision
  and removal creates a tombstone. No financial rows are physically deleted.
- Audited correction bundles are retained in append-only local audit JSON, preserving
  original/reversal/replacement association if acknowledged outbox rows are pruned.
- Appearance is a private device preference in the encrypted database. The Hindi
  setting currently labels navigation; it does not claim full Hindi translation.

## 2026-11-15 — wealth, debt and business foundation

ADR 0008 specifies additive v3, exact ownership/metal calculations, explicitly
labelled loan estimates and weighted-average stock. Root revision/event indexes
and immutable journal-purpose links support atomic domain changes; module services
remain the next unit. No actual family holdings, rates or loan terms are seeded.

## 2026-11-18 — asset accounting

ADR 0009 records acquisition funding, separate equity reserve, family share and
backdated valuation behavior. Generic finance cannot alter domain-owned entries.
The asset module writes the complete command and its facts within one transaction.

## 2026-11-18 — loans and repayments

ADR 0010 specifies borrowed and lent principal, paid interest and immutable
corrections. Estimate screens use recorded terms without posting accruals.

## 2026-11-18 — business accounts

ADR 0011 records cash-based revenue and operating expenses, inventory at
weighted cost, actual wage payments and reporting scope. Billing remains open.

## 2026-11-18 — server family access

ADR 0012 records verified-email invitations, device-key enrollment, live Auth
session checks and recent TOTP controls. Local provider integration confirmed
the private Auth helper and permission boundaries.

## 2026-11-18 — shared ledger receipts

ADR 0013 records the exact-byte operation envelope, family-scoped transaction
sequence, atomic opening and corrections, and revision conflict response.

## 2026-11-18 — encrypted family replicas

ADR 0014 records verified chart and directory bootstrap, isolated cache paths,
outbox leases, receipt recovery and transactional feed replay.
