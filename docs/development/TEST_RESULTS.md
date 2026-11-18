# Verified test results

Historical baseline evidence: 9 Flutter host tests,
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

## M03 — device-protected vault and app composition

- `bash tool/check.sh`: passed; **36 Flutter tests**, clean analysis/formatting,
  code generation, 145-package OSV graph (no matches) and prior SQL design probes.
- Seven lifecycle tests cover device denial, independent keys/persistence/close,
  storage failure, interrupted setup, lock/open race and missing/corrupt catalog/
  database preservation. Three app widget tests cover locked access, 320px/2x text
  and background privacy/locking. Report formatting also covers >int64 totals.
- A widget test exposed a label overflow at large text size; fixed with flexible
  layout. All widget cases then passed without reducing text scale/assertions.
- `flutter build apk --debug --no-pub`: succeeded, 142.2 seconds, Android debug APK
  at `build/app/outputs/flutter-apk/app-debug.apk`. This proves Android compilation
  of FragmentActivity/local_auth/secure-storage/privacy changes, not physical
  biometric/key-store security or distribution signing. No physical device used.
- iOS scene masking/Face ID configuration added; **not compiled on Linux**.

## M04 — 2026-11-14 native finance workflows

- `bash tool/check.sh`: **passed, 41 tests**, clean analyzer/formatter/generator,
  145 resolved Pub advisory queries (no matches), 50 SQLite/51 PostgreSQL design
  probes. Final isolated transcript: `.cache/checks/m04-final-check-20261114-a.txt`.
- New encrypted database tests cover soft archive/restore, stale budget rejection /
  removal preservation and exact month/calendar-year reports excluding transfers.
- UI workflow uses real encrypted Drift: account/opening → expense → correction →
  budget; asserts exact persisted amounts, four retained journal facts and budget
  remaining value. Native authentication is replaced by an explicit test gate only.
- Responsive UI test covers main screens **and** financial forms at 320px/1200px
  with 2x text, then checks persisted dark theme and locked route denial. Fixed
  dropdown/ink/navigator issues; no accessibility scale/assertions were removed.
- `flutter build apk --debug --no-pub`: **passed, 34.8s**. Transcript:
  `.cache/checks/m04-android-20261114-a.txt`. Still a debug artifact, not distribution
  signing or physical hardware validation. iOS remains uncompiled on Linux.
- Synthetic dashboard image rendered with SDK fonts and visually inspected in the
  ignored screenshot cache. No family records/documents or credentials used.

## M05a — 2026-11-15 schema and exact calculations

- `bash tool/check.sh`: passed, **55 tests**, clean analysis, formatting and
  generation; 145-package advisory graph had no matches. Existing SQL design
  probes still pass (50 SQLite/51 PostgreSQL); these are not live backend tests.
- New cases cover fixed decimal/overflow, independent high-precision EMI oracles,
  exact principal conservation and leap-day interest; metal purity/valuation and
  1,000 mixed weighted-average stock conservation operations.
- Encrypted schema tests cover cross-family/business/account constraints,
  ownership limits, valuation/posting consistency, append-only facts, negative/
  overflowing stock rollback and latest-active movement reversals.
- Populated encrypted v1 and v2 upgrade to v3 with history intact. An intentional
  mid-upgrade table collision rolls back DDL and user_version, retaining the old
  checkpoint and existing user table. Historical v1/v2 fixtures/snapshots unchanged.
- Final transcript: `.cache/checks/m05a-final-history-check-20261115-a.txt`.
  Services/UI for these modules are still next; no sync claim follows from DDL.
- `flutter build apk --debug --no-pub`: passed, 18.8s; final transcript
  `.cache/checks/m05a-final-history-android-20261115-a.txt`. Android compilation
  only; physical security, release signing and iOS remain unvalidated.

## M05b — 2026-11-18 assets and atomic module changes

- `bash tool/check.sh` passed with 67 tests and clean generation, formatting and
  analysis. The 145-package OSV query returned no matches. Existing proposal SQL
  probes passed. Transcript `.cache/checks/m05b-full-20261118-b.txt`.
- Encrypted repository tests cover ownership rounding and history, funded and
  opening acquisitions, exact metal estimates, past-date and same-day valuation
  corrections, rent reversals, shared edits, stale commands, duplicate retries,
  managed account denial and rollback on outbox failure.
- The closure test found a doubled book value on undo after a past-date quote.
  The fix values the holding before active disposal entries. The regression
  verifies both a zero closed balance and the original value after undo.
- The property widget test uses the live encrypted Drift repository. It saves
  and revalues a synthetic holding and checks audit, related entry navigation
  and layout of each asset route at 320px and 1200px with doubled text.
- `flutter build apk --debug --no-pub` passed in 252.7 seconds. Transcript
  `.cache/checks/m05b-android-20261118-a.txt`.

## M05c — 2026-11-18 loan workflows

- `bash tool/check.sh` passed with 74 tests, no analysis findings, clean
  generation, and the advisory and design SQL checks. Transcript
  `.cache/checks/m05c-full-20261118-a.txt`.
- Six new encrypted repository tests cover borrower and lender signs, opening
  funding, separate interest, partial payments, stale and concurrent commands,
  duplicate retries, correction history, date and overpayment checks, archives
  and rollback when the outbox insert fails.
- A widget test records a loan and split repayment, corrects it and verifies
  the exact cash, principal, interest and reversal in the encrypted database.
  The test waits for the prior save notice to leave before pressing the next
  form's bottom action. Targeted transcript `.cache/checks/m05c-widget-20261118-e.txt`.
- `flutter build apk --debug --no-pub` passed in 292.2 seconds. Transcript
  `.cache/checks/m05c-android-20261118-a.txt`.

## M05d — 2026-11-18 business accounts, stock and wages

- `bash tool/check.sh` passed with 80 tests, clean analysis and formatting,
  dependency advisory scan and SQL design probes. Transcript
  `.cache/checks/m05d-full-20261118-a.txt`.
- Five encrypted repository tests cover scoped profit, stock costing, zero-cost
  movements, worker payment corrections, archive/restore, idempotency,
  concurrent stock issues, and rollback when writing the outbox fails.
- A widget test records business revenue, three pieces of opening stock and a
  one-piece issue. It verifies 823 paise of remaining stock and 9,589 paise of
  profit. Fixed a Drift stream cache key collision that hid stock updates when
  the ledger and another module were both watching.
- `flutter build apk --debug --no-pub` passed in 263.1 seconds. Transcript
  `.cache/checks/m05d-android-20261118-a.txt`.

## M06a — 2026-11-18 server family access

- `bash tool/check_backend.sh` passed. The isolated native PostgreSQL 18 cluster
  covered four independent family accounts, a separate family, forced RLS,
  matching invite email, fingerprint approval, proof/session scope, stale MFA,
  member and device revocation, cross-family denial and immutable audit.
  Transcript `.cache/checks/m06a-postgres-20261118-d.txt`.
- `python3 -B tool/check_supabase.py` passed against local Supabase PostgreSQL
  17.6, GoTrue v2.197.0 and PostgREST v14.18 in a rootless Podman pod. A genuine
  Auth JWT and TOTP enabled the admin flow. Pending devices, outside accounts,
  member admin access, incorrect device proof and old JWTs after Auth sign-out
  were denied. Transcript `.cache/checks/m06a-real-supabase-20261118-h.txt`.
- The provider test found a reserved role hook issue with `CURRENT_USER` and
  a missing Auth schema grant option for the migration role. Quoting the role
  identifier and using a minimal Auth bridge fixed both under the actual images.

## M06b — 2026-11-18 mobile enrollment and administration

- `bash tool/check.sh` passed with 85 tests, clean analysis, generation,
  advisory checks and schema probes. Transcript `.cache/checks/m06b-full-20261118-b.txt`.
- Device tests cover preservation after an interrupted request, stable proof
  retries, blocking unapproved/revoked devices, identity changes during the
  OS prompt, account/family/server key isolation and key release after use.
- The widget test opens family access from the opaque vault lock screen,
  registers an approved device and verifies a synthetic TOTP step to load
  the administrator panel. The offline vault remains locked throughout.
- `flutter build apk --debug --no-pub` passed in 18.2 seconds. Transcript
  `.cache/checks/m06b-android-20261118-b.txt`. The loopback cleartext exception
  is limited to debug builds and explicit Dart development configuration.

## M06c1 — 2026-11-18 shared ordinary ledger

- `bash tool/check.sh` passed with 86 Flutter tests, clean analysis,
  dependency and schema checks, and native PostgreSQL migration tests.
  Transcript `.cache/checks/m06c-ledger-full-20261118-b.txt`.
- The local opening test checks rollback on invalid input, one outbox
  operation for account plus opening entry and idempotent retry. The
  native SQL suite checks strict integers, immutable history, exact reversal,
  stale revisions and a failed correction leaving no partial posts or gap.
- `python3 -B tool/check_supabase.py` passed with two genuine Auth sessions.
  It verified a 64-bit opening amount, the feed digest, duplicate receipts,
  two simultaneous edits returning one acceptance and one HTTP 409, and
  feed denial after Auth sign-out. Transcript
  `.cache/checks/m06c-rest-ledger-20261118-c.txt`.
