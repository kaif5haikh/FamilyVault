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

## M06c2 — 2026-11-18 budgeting and statement checks

- `flutter test --no-pub test/features/ledger_test.dart` passed 14 tests.
  The statement adjustment test retries one operation, checks one outbox
  bundle, and confirms that balances include only one adjustment.
- `bash tool/check_backend.sh` passed. It checks budget uniqueness across
  tombstones, stale statement totals, atomic rollback for an unrelated posting
  and an exact adjustment. Transcript `.cache/checks/m06c-planning-pg-20261118-a.txt`.
- The real provider check passed a two-device budget and reconciliation flow.
  It verified a one-paise adjustment to an opening beyond JavaScript's safe
  integer range. Transcript `.cache/checks/m06c-planning-rest-20261118-a.txt`.

## M06d and M07a-b — 2026-11-18 connected finance

- `bash tool/check.sh` passed 96 Flutter tests, analyzer, dependency audit,
  schema probes and executable PostgreSQL checks. The test using the provider
  pod was skipped by the default host suite and passed separately.
  Transcript `.cache/checks/m07-live-full-20261118-b.txt`.
- The cache tests cover account isolation, server chart validation, missing
  initialized files, lock on account switch, offline expiry, clock rollback,
  changed Auth session and revocation. Two encrypted clients simulate airplane
  mode, recovery from a lost receipt, restart, concurrent edits and atomic
  page rollback. Physical airplane-mode testing remains pending.
- `python3 -B tool/check_supabase.py --mobile` passed with genuine Auth sessions,
  the Dart Supabase adapter and two encrypted SQLite caches. The test creates a
  paise value above the JavaScript safe integer range, retrieves it on another
  account, edits it there and verifies creator and editor on the first device.
  Transcript `.cache/checks/m07-real-mobile-20261118-a.txt`.
- `flutter build apk --debug --no-pub` built the Android APK in 15.1 seconds.
  Transcript `.cache/checks/m07-live-android-20261118-a.txt`.

## M07c — 2026-11-18 conflict recovery

- Eleven cache and sync tests passed with `flutter test --no-pub`
  against `test/features/cloud_cache_test.dart` and
  `test/features/shared_ledger_sync_test.dart`. An interrupted rebuild keeps
  the original active cache. A valid replay activates a separate encrypted file,
  exposes the pending device edit for review and preserves the accepted balance.
  Transcript `.cache/checks/m07-recovery-tests-20261118-a.txt`.
- Targeted analyzer passed on the recovery path and its UI.
  Transcript `.cache/checks/m07-recovery-analyze-20261118-b.txt`.
- The cache, sync, enrollment and application widget suites passed 15 tests
  together. Transcript `.cache/checks/m07-recovery-app-20261118-a.txt`.

## M08a — 2026-11-18 encrypted document repository

- `bash tool/check.sh` passed with 103 tests and one opt-in provider test
  skipped. Analysis, the advisory query, proposal checks and real PostgreSQL
  migration tests also passed. Transcript `.cache/checks/m08-doc-engine-full-20261118-b.txt`.
- The 11 targeted tests verified encrypted metadata and content, actor and
  version audit, authentication with the wrong key or context, tampered and
  truncated files, concurrent version saves, archive/restore and journal links.
  The upgraded test fixtures start with populated encrypted v1, v2 and v3.
  Transcript `.cache/checks/m08-doc-engine-tests-20261118-a.txt`.
- Android emulator 37.2.13 exited 139 before boot with KVM and without it.
  The checksummed official 36.6.11 archive also exited 139. The SDK and AVD
  are project-local. Android installation and physical device checks remain
  pending. Transcripts `.cache/checks/android-avd-boot-20261118-b.txt` through
  `.cache/checks/android-avd-boot-20261118-d.txt`.

## M08b — 2026-11-18 local document screens

- `bash tool/check.sh` passed with 105 Flutter tests and one opt-in provider
  check skipped. The widget test simulates the native picker pausing the app,
  verifies device unlock resumes the same vault's pending import, and checks
  an image preview, explicit export and both audit events. The resolved PDFium
  library rendered a generated sample from memory. Transcript
  `.cache/checks/m08-ui-full-20261118-a.txt`.
- The resolved package audit returned zero Pub advisory matches across 177
  packages. Android debug built with all three document plugins in 119.7
  seconds. Transcripts `.cache/checks/m08-document-advisories-20261118-a.txt`
  and `.cache/checks/m08-ui-android-20261118-a.txt`. The updated build with
  linked-document screens passed in 18.6 seconds.
  Transcript `.cache/checks/m08-ui-android-20261118-b.txt`.
- The first host test run failed because the PDF build hook could not find
  clang. The existing Android NDK clang compiled the host gate. The lifecycle
  test also needed Android's intermediate hidden and inactive transitions.
  Both corrections are reflected in the passing full check.

## M08c1 — 2026-11-19 shared document receipts and gateway

- `bash tool/check.sh` passed 106 Flutter tests, the PostgreSQL migrations,
  the private Storage catalog contract, and four Deno gateway tests. One Dart
  provider test was opt-in. Transcript `.cache/checks/m08-cloud-fundamentals-full-20261119-a.txt`.
- The document key test verifies independent device keys, rejection on wrong
  recipient, family or version, and signature and signing-key tampering.
- PostgreSQL verified finalize only after the worker receipt, exactly one
  key grant per enrolled recipient, owner and creator attribution and denial
  after revocation. The Deno gateway rejected truncated, altered and oversized
  fixture objects and streamed a permitted ciphertext download with no caching.
- `python3 -B tool/check_supabase.py` passed with real local Auth and PostgREST.
  Its document exercise wrote a synthetic worker receipt to test the database
  role boundary. Transcript `.cache/checks/m08-cloud-provider-20261119-a.txt`.
- `python3 -B tool/check_supabase.py --storage` passed with the pinned Storage
  1.89.12 image alongside Auth, PostgreSQL, PostgREST and the Deno gateway.
  With complete recipient grants, finalization failed before upload and again
  after the signed upload. The trusted gateway read and verified the exact bytes,
  the database returned a stable finalization receipt, and a second member on
  an approved device downloaded the same ciphertext. Public and direct Storage
  reads failed. Transcript `.cache/checks/m08-storage-joined-20261119-b.txt`.
  Connected Flutter views remain pending.

## M08c2a — 2026-11-19 durable staged documents

- `dart run build_runner build` and `dart run drift_dev make-migrations`
  generated the v5 schema. Prior snapshots remained unchanged.
- The 15 targeted Flutter tests passed. Populated encrypted databases from v1
  through v4 retained their data and constraints. An audit failure rolled back
  the draft, and a valid staged upload retained its exact operation and preview
  across closing and reopening. Transcript `.cache/checks/m08-queue-tests-20261119-a.txt`.
- `bash tool/check.sh` passed 108 Flutter tests, analyzer, four Deno tests,
  proposal probes, PostgreSQL and the audit of 177 resolved packages. The
  finance recovery test retained the draft file, queue and audit in the new
  cache. Transcript `.cache/checks/m08-queue-full-20261119-a.txt`.
- `bash tool/check_backend.sh` passed expired reservation renewal using the
  original byte identity, refusal to publish without an existing addressed
  grant, and idempotent backfill with a single audit event. Transcript
  `.cache/checks/m08-backfill-db-20261119-a.txt`. The local Storage check also
  passed with the new migration. Transcript `.cache/checks/m08-backfill-storage-20261119-a.txt`.

## M08c2b — 2026-11-19 connected document delivery

- `python3 -B tool/check_supabase.py --mobile --storage` passed the Dart ledger
  and encrypted document round trips with real local Auth, PostgREST, Storage
  and the Deno gateway. Three separately keyed app sessions tested delayed
  acknowledgement after a lost finalization response, encrypted download,
  cross-member owner and creator attribution, two competing uploads and keys
  for a newly enrolled device. Transcript `.cache/checks/m08-mobile-doc-provider-20261119-c.txt`.
- `bash tool/check.sh` passed 108 Flutter tests, five Deno tests, analyzer,
  PostgreSQL, proposal checks and the package advisory query. Two provider
  tests were opt-in. The Deno test rejects a truncated or longer object stream
  using the authorized length. Transcript `.cache/checks/m08-mobile-doc-full-20261119-a.txt`.

## M08c3a — 2026-11-19 shared edits, archive and restore

- `bash tool/check.sh` passed 109 Flutter tests, analyzer, PostgreSQL,
  dependency and proposal checks and five Deno tests. The two provider tests
  were opt-in. Transcript `.cache/checks/m08-change-full-20261119-b.txt`.
- The 27 targeted tests cover v1 through v6 migration, preserved v5 upload
  rows, independent document revision and version guards, offline device cache
  and existing native input flows. Transcript `.cache/checks/m08-change-targeted-20261119-a.txt`.
- `python3 -B tool/check_supabase.py --mobile --storage` passed on the three
  synthetic devices. A metadata edit from one device preserved creator
  attribution, rejected a competing stale archive, and retained both file
  versions through archive, backfill and restore. Transcript
  `.cache/checks/m08-change-provider-20261119-a.txt`.
- The prior connected document Android debug build passed in 23.9 seconds.
  Transcript `.cache/checks/m08-shared-doc-android-20261119-a.txt`.

## M08c3b — 2026-11-19 transaction links and draft retry

- `bash tool/check_backend.sh` passed same-family link constraints and refused
  an unavailable journal reference. Transcript `.cache/checks/m08-link-sql-20261119-b.txt`.
- `python3 -B tool/check_supabase.py --mobile --storage` passed. The Flutter
  fixture queued both the new transaction and its document link, received the
  link on a second device, retained the tombstone through removal and reattachment,
  and submitted a preserved conflicting file as a new version. The original
  draft remained readable and the opening balance stayed at 4,123 paise.
  Transcript `.cache/checks/m08-link-provider-20261119-b.txt`.
- `bash tool/check.sh` passed 109 Flutter tests, five Deno tests, analyzer,
  package audit and both SQL gates. The two provider checks ran separately.
  Transcript `.cache/checks/m08-link-full-20261119-a.txt`.

## M09a — 2026-11-19 encrypted archive

- A SQLite3MC experiment used a pinned WAL read while the source committed
  another record. The separate encrypted copy had the original view, passed
  SQLite checks and refused the source key. Transcript
  `.cache/checks/sqlite-encrypted-backup-20261119-a.txt`.
- The 14 snapshot and migration tests passed. The new snapshot tests protected
  an existing destination and removed a partial copy after failure. Transcript
  `.cache/checks/m09-snapshot-tests-20261119-b.txt`.
- The targeted archive and encrypted document suite passed 15 tests. The
  recovery key alone reopened the archive in a clean directory after source
  lock and decrypted an older version. A wrong key, short archive, changed
  ciphertext and missing source document all failed. Transcript
  `.cache/checks/m09-archive-tests-20261119-a.txt`.
- `bash tool/check.sh` passed 113 Flutter tests, five Deno tests, analyzer,
  both SQL gates and the advisory review. Two provider tests were opt-in.
  Transcript `.cache/checks/m09-archive-full-20261119-a.txt`.

## M09b — 2026-11-19 local Files and app recovery

- `bash tool/check.sh` passed 116 Flutter tests, five Deno tests, analyzer,
  both SQL gates and the package advisory check. The Flutter tests exercised the
  encrypted backup picker, activation through device verification, interrupted
  catalog writes, destination readback, wrong key and invalid input handling.
  Transcript `.cache/checks/m09-restore-full-20261119-c.txt`.
- `python3 -B tool/check_supabase.py --mobile --storage` passed. The recovery
  extension restores a connected device snapshot in a separate clean app
  directory, keeps the shared chart IDs, exact 4,123 paise and the saved draft,
  and opens with a fresh local identity. Transcript
  `.cache/checks/m09-cloud-restore-provider-20261119-a.txt`.
- `flutter build apk --debug --no-pub` compiled the Android Files adapter and
  backup screens. The final incremental build took 14.1 seconds. Transcript
  `.cache/checks/m09-restore-android-20261119-b.txt`. Xcode and both platforms'
  physical Files behavior remain unverified.

## M09c1 Drive transfer and independent restore on 2026-11-19

- The three Drive fixture tests passed a 9 MiB interrupted upload, loss of the
  final reply, session expiry and a rejected foreign upload URL. Retries kept
  the allocated file ID and emitted a receipt only after the strong readback
  check. A clean app with no source catalog also restored a downloaded archive
  after rejecting corrupt media.
- `bash tool/check.sh` passed 119 Flutter tests, five Deno tests, analyzer,
  PostgreSQL, proposal checks and the advisory query for 177 resolved Pub
  packages. The two Supabase fixture tests stayed opt-in during this run.
  Transcript `.cache/checks/m09-drive-full-20261119-a.txt`.

## M09c2 Native Drive configuration on 2026-11-19

- Six targeted Flutter tests passed. The widget test opened Drive history
  after simulated consent, selected an encrypted version, verified the supplied
  key and restored the original records in a clean app. The protocol tests
  included rejection of an expired token, wrong-key rejection before staging
  and rejection of corrupt downloaded content. Transcript
  `.cache/checks/m09-drive-native-tests-20261119-b.txt`.
- `bash tool/check.sh` passed 121 Flutter tests, five Deno tests, analyzer and
  both SQL gates. OSV reported no matches for the 183 resolved Pub packages.
  A separate Maven query returned no matches for the four direct Android Google
  plugin components. Transcripts `.cache/checks/m09-drive-native-full-20261119-a.txt`
  and `.cache/checks/m09-drive-native-osv-20261119-a.json`.
- `flutter build apk --debug --no-pub` passed in 65.0 seconds. The iOS property
  list parsed with the expected local settings references. Xcode and real
  Google consent are pending. Transcript
  `.cache/checks/m09-drive-native-android-20261119-a.txt`.

## M09c3 Scheduled encrypted copies on 2026-11-19

- Eleven targeted Flutter tests passed. Schedule tests reopened a successful
  archive in a clean vault after an interrupted receipt, suppressed runs
  while locked or obscured and retried without concurrent capture in one
  scheduler. The Drive fixture withheld upload for a different account and
  completed a resumed upload of the original snapshot under the selected
  account. Transcript `.cache/checks/m09-schedule-tests-20261119-b.txt`.
- `bash tool/check.sh` passed 123 Flutter tests, five Deno tests, analyzer,
  SQL gates and the audit of 183 Pub packages. Transcript
  `.cache/checks/m09-schedule-full-20261119-a.txt`.
- `flutter build apk --debug --no-pub` passed in 15.5 seconds. Transcript
  `.cache/checks/m09-schedule-android-20261119-a.txt`.

## M06c3a Shared assets on 2026-11-19

- `bash tool/check_backend.sh` applied the scoped journal and asset migrations
  and passed the existing family authorization, documents and ledger SQL
  suite. Transcript `.cache/checks/m06-shared-assets-sql-20261119-a.txt`.
- `python3 -B tool/check_supabase.py --mobile --storage` passed on the two
  enrolled finance devices and the three enrolled document devices. The asset
  checks exercised exact large paise values, denial of a wrong valuation,
  duplicate receipt acknowledgement, clearing optional details, retained
  ownership and quote history, scoped rent reversal, disposal, restoration,
  metal pricing and concurrent changes. Transcript
  `.cache/checks/m06-asset-provider-20261119-g.txt`.
- `bash tool/check.sh` passed analyzer, 123 Flutter tests, five Deno tests,
  PostgreSQL and proposal checks and the dependency advisory query. The
  provider tests ran separately. Transcript
  `.cache/checks/m06-asset-full-20261119-a.txt`.
