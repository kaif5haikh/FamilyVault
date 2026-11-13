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
