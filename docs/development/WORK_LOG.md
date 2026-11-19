# Work log

## 2026-11-13 — mission start

- Inspected clean main at b9a2705, prior commits and private SSH origin.
- Read actual shell, encrypted v1 database, security/storage adapters, confirmed
  architecture/sync/recovery designs and tests. Main product modules are absent.
- Owner's latest mission authorizes implementation and routine engineering choices;
  prior per-phase approval gate is superseded, not marked human-reviewed.
- Created persistent roadmap/status/decision/test journal. Next: exact INR core and
  additive ledger migration, followed immediately by secure vault and usable UI.
- Toolchains remain project-local. About 51 GiB disk free; native PostgreSQL and
  Podman available; no production/cloud credential connection performed.

## M01 complete

Implemented/tested exact INR Money, safe failure/config boundaries and localization strings. All 14 tests/analyzer pass. Reviewed candidate dependency SDKs, archive hashes, licences and OSV versions before later adoption (no matches returned for the ten new candidates; native review still required). Next M02: structured finance tables, additive v1 upgrade, immutable posted ledger and atomic audit/outbox.

## M02 complete

- Implemented additive encrypted Drift v2 and exact double-entry accounting,
  immutable postings/reversals, idempotent commands, shared provenance, atomic
  audit/outbox, budgets and reconciliation. No real records or sample balances.
- `bash tool/check.sh` passed: generator, formatting, analyzer, 27 Flutter tests,
  OSV (145 hosted packages), SQLite integrity and proposal probes (50 SQLite /
  51 PostgreSQL; these remain design probes, not actual cloud sync).
- Generated v2 schema snapshot and encrypted generated-v1 migration tests. No v1
  schema/history overwrite. SQL trigger tampering and outbox-failure rollback tested.
- Next M03: secure local vault creation/unlock, lifecycle locking and app wiring;
  then immediately functional finance screens and reporting.

## M03 in verification

- Implemented OS-authenticated local vault setup/unlock, independent random keys
  in OS secure storage, interrupted-setup recovery and fail-closed missing-file/
  catalog handling. Seven lifecycle tests pass; no real data used.
- Connected Riverpod/GoRouter to active sessions, encrypted overview and private
  routes. Added background/idle locking, key lifetime cleanup, curated error logs,
  Android screenshot protection and iOS app-switcher privacy cover.
- Three widget tests pass, including independent locked access, 320px/2x text and
  background masking/locking. Fixed the trust-label overflow found by large text.
- Android native build and full project checks are running; iOS remains unbuilt on
  this Linux host. Next: finance entry/account/planning/report screens (M04).

## M03 complete

Full checks passed (36 tests/analyzer/generator/dependency/proposal checks).
Android debug build succeeded in 142.2s. Documented native-device and iOS limits in
ADR 0006; production/cloud credentials remain unused. Verified private-origin push
of M02 (61e3574). M03 is being committed; continue directly to M04 finance UI.

## M04 in progress

- Verified M03 private push: cd5c275. Implemented finance navigation, account /
  category forms and balances, dated opening entries, transactions, corrections,
  reversal/audit detail, reconciliation, monthly budgets and reports/charts.
- Added soft account archive/restore and revision-checked budget edit/removal.
  Corrections retain their bundle in immutable audit, independent of outbox pruning.
- Added persisted light/dark/system appearance and English/Hindi navigation choice.
- Analyzer was clean before the final test harness additions. Existing ledger and
  app tests plus three new accounting/report cases pass (16 targeted cases).
- New end-to-end widget tests exercise encrypted persistence through the real
  forms, exact totals, navigation, layouts and theme settings. Investigating the
  harness's fake-clock/real-SQLite scheduling before accepting this milestone;
  no tests weakened and no integration success claimed yet.
- M05 next: additive wealth/property/metal, debt and business tables, exact
  valuation/interest/inventory math, atomic ledger-linked operations and native UI.
  Restricted billing stays unspecified/unimplemented.

## 2026-11-14 — M04 final verification

- Full form workflow now passes against encrypted SQLite: create account/opening,
  expense, immutable correction and monthly budget, with exact remaining balance.
- Broad responsive tests cover main screens plus account/transaction/budget/
  reconciliation forms at 320px and 1200px, with 2x text. Fixed a settings dropdown
  overflow and Material ink background issue without reducing accessibility checks.
- Switched the new shared frame to a single root navigator after rapid route/size
  tests exposed nested-navigator key reuse. Five targeted app/flow cases passed
  against the final flat router. Added opaque lock gate over offstage route content.
- Earlier overwritten scratch test transcripts had overlapping stale writers after
  interrupted experiments; they are not final verification evidence. Confirmed no
  project test processes remained, then started a uniquely named full-check/build
  run: `.cache/checks/m04-final-check-20261114-a.txt` and Android counterpart.
- Synthetic dashboard render inspected; only ignored cache images were written.
  No real data or credentials used. Next: complete milestone commit and M05.

## M04 complete

The isolated full check passed: 41 tests, clean static/generation checks, advisory
scan and existing design probes. Android debug rebuild passed in 34.8s. README and
ADR 0007 now describe actual local finance functionality and remaining cloud/
document/backup work. Next M05 is split into tested units: additive schema/exact
math; wealth/valuation; debt/repayment; business/inventory/salary and their UI.

## 2026-11-15 — M05a exact domain and schema foundation

- Inspected current repository/architecture/history; preserved the private SSH
  origin and prior commits. Reviewed v3 as an unreleased draft before freezing its
  committed snapshot. Preserved each intermediate snapshot in ignored cache;
  committed v1/v2 artifacts were never changed.
- Added 15 family-scoped strict tables, immutable event/journal-purpose links,
  ownership/account guards, weighted stock projection and reversal consistency.
  New asset closure/valuation event-index fields support dated correction history.
- Added exact fixed quantities, nominal/assayed metal valuation, explicit loan
  estimates and inventory math. No real data, prices or business billing invented.
- `dart run build_runner build` and `dart run drift_dev make-migrations` succeeded.
  `bash tool/check.sh` passed: 55 tests plus static/advisory/design SQL checks.
  Final evidence paths are recorded in TEST_RESULTS; older draft runs are not
  substituted for the final unique transcript. Migration failures preserve data.
- ADR 0008 records engineering choices and the boundary between tested local
  schema/calculations and unfinished services, cloud sync, documents and backups.
  Next: atomic module writer, native wealth/debt/business functionality.
- Android debug rebuild passed in 18.8s. Indexed-content/policy/redacted secret
  checks precede the milestone commit and the private-origin push hook verifies
  repository identity/privacy. No production infrastructure is touched.

## 2026-11-18 — assets and aggregate accounting

- Confirmed the previous `f940ac1` commit on the designated private SSH origin.
  Resumed the paused worktree. Added the atomic module writer and completed asset
  creation, edits, date-based valuation history, nominal and assayed metal details,
  family ownership changes, rental receipts, closure and undo.
- Targeted repo and widget checks found and corrected the sale undo accounting
  issue and an ambiguous widget test selector. The full `tool/check.sh` run then
  passed with 67 tests. See TEST_RESULTS for the exact transcript.
- Loan contract and repayment repository work started separately. Next verify
  independent server-relevant invariants and finish native loan workflows.

## 2026-11-18 — public source repository and README

The owner requested public visibility for the existing GitHub repository and a
simpler README. Checked all nine reachable commits and 195 distinct tracked
paths. Redacted Gitleaks reported no leaks. The history scan found no private
file types and all author and committer email addresses use GitHub noreply.
GitHub showed one main branch and zero pull requests, issues, forks, releases,
deployments, action runs, artifacts and repository action secrets.

Rewrote the README in plain English and checked it contains no em dashes.
The push hook checks the same SSH destination, owner and expected visibility
throughout the transition. Application data and sensitive local files remain
excluded from the source repository. No history rewrite or repository replacement.

Pushed the README and visibility guard in `2544915`, then ran `gh repo edit`
against `kaif5haikh/FamilyVault` with public visibility. Both `gh repo view` and
an unauthenticated GitHub API request confirmed public access. The SSH origin
and commit history were preserved. The repository-local hook now expects PUBLIC.

## 2026-11-18 — borrowing and lending

Implemented loan terms, opening principal, actual split payments, correction
and reversal history, settlement archive, and interest estimate screens.
`bash tool/check.sh` passed with 74 tests. Business repository tests also passed
separately. Continue with the business UI and executable backend policies.

## 2026-11-18 — business records and inventory

- Verified the loan commit `0a61270` on the public SSH origin, with the
  74-test check and Android debug build passing.
- Built business accounting screens, worker and salary records, inventory
  movements and period profit. Reused the shared ledger and atomic outbox.
- Fixed identical Drift query keys sharing a watcher with the wrong table
  dependencies. Distinct projection queries now update the business, assets,
  loan and audit pages independently. The business form regression passed.
- The full check passed with 80 tests and the Android debug APK built. Next:
  executable backend access and mobile enrollment.

## 2026-11-18 — executable family access policies

- Verified `0ce02a9` on the public SSH origin. Added the membership, invitation,
  session/device and audit migration. Native PostgreSQL and the isolated real
  Auth/PostgREST pod passed authorized and denied access flows.
- Pulled the reviewed upstream images into the project-local Podman store and
  pinned observed digests. Corrected the provider's reserved-role and Auth
  schema permissions before accepting the result. Used synthetic accounts and
  ephemeral credentials. No hosted infrastructure was changed.
- Next: verify the mobile enrollment screens and open a separately scoped
  encrypted family cache for the durable sync protocol.

## 2026-11-18 — mobile family access

- Pushed and verified the family session/RLS migration in `c9a3ef2`. Bound the
  existing Supabase secure-storage adapter to sign-in, invitation and device
  enrollment, and added TOTP-gated administrator controls.
- The initial widget trial hung while opening a test directory under the fake
  clock. Moved that scratch I/O into the real async zone. Application behavior
  tests and the full 85-test check passed. The Android debug APK rebuilt.
- Shared workspace bootstrap and financial replication remain separate.
  Next validate its commands, atomic receipts, chart and feed against synthetic
  multi-device clients and enable the scoped encrypted cloud cache.

## 2026-11-18 — ordinary ledger receipts

- Verified `3dd3b44` on the public SSH origin. Added typed ordinary ledger
  tables and RPCs. Accounts with opening balances now emit one local bundle.
- The first real concurrent Data API check timed out on the persistent `40001`
  retries. Changed stale revisions to `PT409` and verified a single acceptance
  and a single conflict. The full check and provider integration both passed.
- Next implement and test budget and reconciliation commands, then connect
  the encrypted client cache and queued delivery to the receipt protocol.

## 2026-11-18 — shared budgets and statement checks

- Verified `1feb3dc` on the SSH origin. Implemented planning RPC validation and
  bundled each optional adjustment with its statement check. Stale totals and
  duplicate active months return a conflict before committing facts.
- The 14-test local ledger suite, executable PostgreSQL tests and two-device
  Supabase Data API test passed. Continue with a scoped cache and client
  replay for the tested finance commands. Wealth, loans and business remain
  local while their typed cloud commands are developed.

## 2026-11-18 — connected ledger on two devices

- Verified `a9ada33` on the public origin. Connected the verified chart and
  family directory to isolated encrypted caches. The app now presents pending
  receipt counts, sync feedback and safe sign-out in Settings.
- Tested account switch and denial, a twelve-hour offline grant bound to the
  same Auth session, optimistic conflicts, bounded retries and rollback on
  interrupted pull. Fixed analyzer findings before rerunning the full check.
- The full 96-test check passed. The opt-in Dart test against the disposable
  Supabase pod verified exact round-trip finance and cross-member attribution.
  Started the API 36 system image installation inside the project SDK.
- Next implement conflict recovery that preserves the outgoing encrypted cache,
  followed by the document engine and extended typed domain integration.

## 2026-11-18 — conflict recovery and Android setup

- Verified `8bece15` on the public origin. Built the Android debug APK in
  15.1 seconds. Installed the API 36 system image and created a FamilyVault AVD
  inside the project SDK. The first emulator process segfaulted during startup.
  Retrying with isolated emulator settings and a different graphics backend.
- Implemented user choice of the accepted family state, atomic secure catalog
  switch and read-only review of pending changes from the prior device file.
  Targeted analyzer and 11 encrypted sync/cache tests passed.
- Next implement the additive local document store and encrypted file engine.

## 2026-11-18 — encrypted local documents

- Verified `7480800` on the public origin. Added Drift v4, authenticated
  file chunks, document metadata and links, immutable versions and access audit.
- Drift rejected a draft v4 snapshot with dynamic constraints. Replaced the
  uncommitted draft after using SQL literals, and preserved v1 through v3.
  The eleven targeted tests and the full 103-test check passed.
- Tried software emulation and the checksummed 36.6.11 emulator from the
  official Android archive after 37.2.13 crashed. Both exited 139 before boot.
  Continue with document screens, camera and Files integration using host tests
  and Android builds. [Android Emulator downloads](https://developer.android.com/studio/emulator_archive)

## 2026-11-18 — local document screens and native adapters

- Verified `89c06f0` on the public origin. Reviewed and pinned file_picker
  13.3.3, image_picker 1.2.4 and pdfrx 2.12.1. Added an import flow that locks
  keys while a native picker is open and resumes after device verification.
- Verified document search, ownership, version history, asset and journal
  links, due dates, image preview and a deliberate save dialog. Rendered a
  synthetic PDF using the resolved native library. All 105 tests passed.
- The Android debug build passed. Native camera and OS picker hardware
  validation remain pending after the emulator crash. Next connect document
  keys and private Storage receipts, and continue encrypted recovery work.

## 2026-11-19 — shared document receipt protocol

- Verified `928e7f4` on the public origin. Added a reserved/finalized document
  protocol, opaque metadata, device-addressed key grants, restrictive bucket
  policy and an audited Deno gateway. It verifies full stored ciphertext before
  the database can publish a version.
- Installed checksummed Deno 2.9.8 inside the project. Native PostgreSQL,
  genuine Auth/PostgREST, grant crypto and socket-free gateway fixtures passed.
  The full check passed 106 Flutter and four Deno tests.
- Next verify the gateway and PostgreSQL receipt together with the real local
  Storage service, then connect the client queue, backfill and shared views.

## 2026-11-19 — joined private Storage transfer

- Verified `04a7a06` on the public origin. Added `--storage` to the disposable
  provider check and passed a signed upload, byte readback, finalization and a
  second device's authenticated download through the actual Deno gateway.
- The first run reached Storage health and failed while applying the bucket
  SQL because peer authentication mapped the container user to a different
  database role. Applying it as the Storage owner through `SET ROLE` in the
  existing local administrator session fixed the fixture. The rerun passed.
- Continue with the durable mobile document queue and receiving device cache.

## 2026-11-19 — staging and preserving pending document uploads

- Verified `ae794eb` on the public origin. Added Drift v5 for durable encrypted
  staging with one pending version per document on the device. Kept staged
  versions readable without adding them to the confirmed document history.
- Ran the generator, additive migration checks, isolated draft tests and
  `bash tool/check.sh`. The 108-test check passed. The recovery fixture verifies
  that rebuilding the finance cache retains the pending document and its audit.
- Continue with upload resumption and key backfill in PostgreSQL, the mobile
  transport and receiving device replay.

## 2026-11-19 — resuming transfers and approving historical recipients

- Verified `30ce847` on the public origin. Added an additive PostgreSQL migration
  to resume an expired reservation for the same device and exact payload while
  the document revision remains current. Added targeted key grant queries and
  writes gated on an existing device-addressed grant.
- Native PostgreSQL access tests and the joined local Storage test passed.
  Client scheduling and independent receiver verification are the next unit.

## 2026-11-19 — shared Flutter document versions

- Verified `83c618f` on the public origin. Connected the staged upload queue
  to Supabase and the gateway. Added a separate document sync status and
  authenticated receive path with metadata decryption and on-demand caching.
- The first joined Dart run found a duplicate test matcher import. Fixed it.
  The rerun and the five-gateway-test full check passed. The joined test uses
  three synthetic device profiles to verify a lost reply, a competing version,
  late key delivery and actual ciphertext download.
- Continue with shared changes to document details, archive and record links.

## 2026-11-19 — durable document edits

- Verified `cc9ebfa` on the public SSH origin and built the connected document
  Android debug APK. Added an immutable PostgreSQL receipt for metadata, archive
  and restore, and Drift v6 for queued edits and family revision replay.
- The native database probe, 27 targeted tests and the connected three-device
  test passed. The first full run stopped at analyzer during an execution
  interruption. Its process was gone on resume. The rerun passed 109 Flutter
  tests, five Deno tests and both database gates.
- Continue with shared record links and preserve access to competing drafts.

## 2026-11-19 — transaction links and version conflict recovery

- Verified `ce2a4d9` on the public SSH origin. Added same-family PostgreSQL
  transaction links, retained removal history, and client replay and link status.
  Added a deliberate retry command that keeps the original draft intact.
- Native SQL and the joined Dart provider check passed. The fixture created a
  transaction and queued its document link, replicated the link and its removal,
  attached it again and published a version from the preserved draft. Ledger
  balances and both original file versions were retained.
- Verified in a synthetic SQLite3MC experiment that the Online Backup API can
  copy a pinned read snapshot from a live WAL source to a rekeyed destination.
  Continue with the encrypted archive and clean-device restore. Shared asset
  links remain dependent on the typed shared wealth backend.

## 2026-11-19 — verified encrypted backup archive

- Verified `9768407` on the public SSH origin. Added the independently rekeyed
  SQLite snapshot, chunked archive, recovery key and complete verification before
  the verified local artifact reaches its final filename. Added ignore and indexed
  policy checks for backup and document ciphertext formats and recovery keys.
- The initial snapshot test found an obsolete SQLite API type. Changed it to the
  pinned native Database interface. The rekeyed WAL, migration and existing-file
  protection tests passed. The archive tests reopened data in a clean directory
  and rejected missing documents, wrong keys, altered data and truncation.
- Continue with clean installation of a verified archive and local delivery.

## 2026-11-19 — app recovery and a verified Files copy

- Verified `03942b2` on the public SSH origin. Wired backup and restore pages,
  restartable catalog activation, fresh device keys and independent local
  recovery of a connected cache. Android and iOS Files adapters stream an
  encrypted copy and measure the saved bytes before recording a receipt.
- Corrected the fixture assumption about the local chart size. The recovery
  widget test needed the native SQLite setup outside its simulated clock and
  then verified the local dashboard. Real local Supabase and Storage, the full
  116-test check and the Android debug build passed.
- Continue with Drive upload, verified independent copies and scheduling.

## 2026-11-19 Drive transfer and independent recovery

- Implemented Drive resumable transfer with an account-scoped attempt record
  and a stable file ID. Completion requires metadata plus SHA-256 or full
  ciphertext readback. Recovery can discover versions on a clean installation.
- `bash tool/check.sh` passed all 119 host Flutter tests and the backend,
  advisory and Deno gates. The Drive tests used synthetic archives and a
  loopback provider. Hosted Google OAuth remains unconfigured.
- `gh repo view` confirmed public visibility for `kaif5haikh/FamilyVault`.
  Continue with native consent and backup screens against the verified adapter.

## 2026-11-19 Google Drive consent and recovery screens

- Verified `53f0405` on the public SSH origin. Reviewed the Flutter Google plugin,
  adopted the locked packages, and connected the verified Drive transport to
  encrypted backup and restore screens. Configured an ignored iOS settings file
  for the matched client ID and callback scheme.
- The first fixture run used Flutter's default blocked widget-test HTTP client
  and found a callback type mismatch. Scoped loopback clients and the correct
  widget clock allowed the six targeted cases to pass. The full 121-test check,
  dependency review and Android debug build passed.
- Continue with scheduled local capture and separately authorized Drive delivery.

## 2026-11-19 Scheduled encrypted backups

- Verified `a9d8c50` on the public SSH origin. Added opt-in daily and weekly
  checks while the vault is open with independent Files and Drive results.
  Schedule secrets and attempt records use the device's secure store.
- The first fixture run found that local failure status depended on timestamps
  from two clocks. Bound the failure to the last verified snapshot instead.
  Corrected the short-upload fixture to fail before storing the final block.
  The 11 targeted tests and the full 123-test check passed.
- Continue with scoped journals and typed shared finance records.

## 2026-11-19 Shared asset accounting

- Verified `78f8a0f` on the public SSH origin. Added PostgreSQL managed journal
  scope, typed asset tables and exact-effects checks for valuation, rent and
  disposal. The receiving Dart cache applies records and receipts together.
- The first provider replay found that the generated update omitted null
  fields when restoring a closed asset. Replayed explicit nulls and checked
  removal of an optional property detail and a disposal tombstone. Two
  different family members passed all shared asset operations in the local
  provider, which also rejected an invalid value, a direct rent reversal and
  a stale concurrent edit.
- Continue with shared asset links, loan repayments and business accounting.

## 2026-11-19 Shared loan accounting

- Verified `1e78b49` on the public SSH origin. Added typed loan terms and
  immutable repayment records under the same private ledger receipt boundary.
  The server computes outstanding principal before admitting each payment.
- `python3 -B tool/check_supabase.py --mobile` passed funded bank loan and
  opening receivable cases, overpayment rejection, corrected principal and
  repayments, soft archive and restoration with two independent devices.
- Continue with asset document links and shared business accounting.

## 2026-11-19 Links from shared documents to holdings

- Verified `4c905a4` on the public SSH origin. Added an approved-device
  endpoint and family-scoped references for asset links. Kept the existing
  journal link endpoint and response shape.
- The local provider tests queued a synthetic asset and link together,
  replayed both on another device and checked reattachment, tombstone
  retention and clean backup recovery. Continue with shared business records.

## 2026-11-19 Shared business profiles and cash journals

- Verified `06a7318` on the public SSH origin. Added family-scoped business
  profiles, managed account renames and private validation for business cash
  entries and corrections.
- Local PostgreSQL and the two-device Data API fixture passed. A business
  profile and two cash entries queued together, then a second member
  corrected the expense. The first device reported the exact resulting profit.
  Continue with weighted inventory costs and wages.

## 2026-11-19 Shared inventory and cost of goods

- Verified `d8e3b0a` on the public SSH origin. Added same-family stock
  positions, immutable movements and the backend's exact weighted issue cost.
  Shared replay uses the existing Drift inventory triggers.
- Local Supabase rejected a fabricated issue cost and accepted the valid
  movement, retained correction and archival history. Both caches reached
  the same zero position and business stock cost. Continue with wages.

## 2026-11-19 Shared worker payments

- Verified `6bc34f7` on the public SSH origin. Added typed worker and salary
  rows, family and business scope, exact journals and archived-worker
  reversal checks. The receiving cache retains all posted payment rows.
- Local Supabase rejected a mismatched salary amount. It accepted the valid
  payment, correction, return of wages on an archived worker and restoration.
  The two-device profit report included the exact paid wages and stock costs.
  The joined Storage tests also passed. Continue with expiry and release.

## 2026-11-19 Document expiry notifications

- Verified `45c137e` on the public SSH origin. Added opt-in local reminders
  using only scheduled times and a generic notification. The app derives times
  from active documents while unlocked and clears alerts at sign-out and
  observed revocation.
- Targeted host tests passed and Android compiled the native adapter. The
  iOS adapter is included and needs Xcode. Continue with signed Android
  release artifacts and the installation, migration and user guides.
