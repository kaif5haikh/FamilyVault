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
