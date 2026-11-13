# Verified test results

No new mission tests run yet. Prior baseline evidence: 9 Flutter host tests,
51 PostgreSQL/50 future-SQLite design probes and Android debug build. Those do not
establish working auth, finance, sync, documents, backups or production readiness.
Record exact command, date, outcome and material platform/provider limits below.

## M01 — 2026-11-13

- `flutter analyze --no-pub`: no issues.
- `flutter test --no-pub --reporter expanded`: 14 tests passed.
- New money tests include 1,000 deterministic arithmetic/format round trips, boundaries, invalid fractional/nonintegral inputs and safe config rejection.
- Corrected an initial boundary golden and negative-symbol parsing; all original tests remain.

## M02 — encrypted local accounting

- `flutter test --no-pub`: **27 passed** (prior 14 plus 13 new ledger/migration cases).
- `flutter analyze --no-pub`: no issues.
- `dart run build_runner build`: succeeded; `dart run drift_dev make-migrations`
  emitted v2 snapshot/helpers. Historical v1 snapshot remains unchanged. Generated
  migration template was adapted to exercise encrypted production connections and
  populated v1 fixtures rather than adding a plaintext application constructor.
- Checks include exact balanced income/expense/transfers, aggregate overflow,
  canonical digest/duplicate retry, shared creator/modifier, revoked local device,
  cross-family denial, immutable SQL guards, budget/reconciliation, correction
  aggregate, and full rollback when the outbox insert fails.
- `python3 tool/audit_dependencies.py`: 145 hosted Pub resolutions; no matches.
- This proves host/local behavior only. Server sync, live credentials and native
  mobile secure storage are not established by these results.
