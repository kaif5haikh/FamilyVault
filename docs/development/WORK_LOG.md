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
