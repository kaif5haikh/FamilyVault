# ADR 0007: native finance workflows and exact reporting

Date: 2026-11-14. Status: implemented; final milestone checks recorded in the test
journal. This is local functionality, not a claim of cloud authorization or sync.

Connect the encrypted ledger to real forms, account/category history, corrections,
budgets, reconciliation and read-only financial reports. Forms retain a stable
operation ID across retries. Saving a correction appends a reversal/replacement;
its association remains in append-only audit after outbox pruning. Account
archive/restore is soft and revision checked; nonzero balance accounts must be
reconciled/transferred first. Budget edits/removal likewise preserve history and
reject stale revisions. Opening entries have an explicit date.

The overview stops balances at today's accounting date. Monthly reports use the
selected month; yearly reports use January–December and explicitly say calendar
year. These are not tax-return or implied fiscal-year calculations. Monetary
aggregation, budgets, percentages and labels stay in integer/BigInt arithmetic.
FL Chart consumes dimensionless ratios for drawing, including negative flow bars;
exact values appear in the report and tooltips. Positive asset allocation is labelled
separately from net worth, which still includes overdrafts.

A single root GoRouter navigator and a shared responsive frame serve top-level
screens. Forms/details are pushed on top and replacements retain the return stack.
The common frame uses immediate tab transitions; this avoids reparenting a shared
nested navigator during rapid route/viewport changes. Device authentication and
backend authorization remain independent of route visibility.

The privacy boundary puts an opaque unlock screen above an offstage router as soon
as an existing vault locks. Cached route transition images cannot remain visible
while redirects finish. Background masking and native platform protections from
ADR 0006 still apply. Appearance preferences persist in the encrypted device
workspace. Hindi currently localizes navigation labels; no full translation is claimed.

Tests exercise real encrypted SQLite through the account/expense/correction/budget
forms, exact persisted totals and preserved history. Responsive checks cover main
screens and financial forms at 320px/1200px with 2x text, plus saved appearance and
locked-route denial. Provider, credential and physical hardware limits remain in
the implementation status, not hidden by these host tests.
