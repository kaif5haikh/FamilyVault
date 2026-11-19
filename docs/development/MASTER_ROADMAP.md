# FamilyVault master roadmap

Authority: owner's autonomous end-to-end mission, 2026-11-13. Work continues across
milestones; unavailable external credentials/hardware do not block local work.
No production deployment, real family data, paid services or destructive history.

## Ordered implementation queue

- [x] M00 Inspect actual code/history/architecture and record execution authority.
- [x] M01 Exact INR model/formatting, typed failures, localization/config foundation.
- [x] M02 Additive Drift v1→v2 migration, relational ledger/accounts/audit/outbox and financial invariants.
- [x] M03 Secure vault creation/unlock/lifecycle, independent identity/session adapters and offline app composition.
- [x] M04 Native responsive dashboard, income/expense/transfer/accounts/budgets/reports and transaction corrections/reconciliation.
- [x] M05 Wealth/property/metals/valuations, liabilities/interest/repayments and business accounting/inventory.
  - [x] M05a Additive v3 schema, guarded histories, exact valuation/interest/stock math.
  - [x] M05b Atomic module writer and wealth/property/metals services/screens.
  - [x] M05c Contracts, actual repayments, interest estimates and native workflows.
  - [x] M05d Business revenue/expenses, stock, workers/salaries and profit reporting.
- [ ] M06 Executable PostgreSQL/Supabase migrations, membership/enrollment/session/RLS/RPC and security integration tests.
  - [x] M06a Membership, enrollment, TOTP and revocation migration verified with PostgreSQL, Auth and PostgREST.
  - [x] M06b Mobile family sign-in, device approval and administrator controls.
  - [ ] M06c Typed finance mutations, shared ledger validation and ordered receipts.
    - [x] M06c1 Ordinary accounts and balanced journal commands with atomic receipts.
    - [x] M06c2 Budgets and reconciliation bundles.
    - [ ] M06c3 Typed wealth, loan and business commands.
      - [x] M06c3a Scoped journal rules, shared holdings, ownership, valuation, rent and disposal.
      - [x] M06c3b Shared loans, principal changes, repayments and archive.
      - [ ] M06c3c Shared businesses, revenue and expenses, inventory and wages.
  - [x] M06d Scoped encrypted cloud cache and live device session lifecycle.
    - [x] M06d1 Verified directory and chart import into isolated encrypted caches.
    - [x] M06d2 Connected app lifecycle, bounded offline unlock and revocation.
- [x] M07 Durable multi-client sync, receipts/conflicts/retries/recovery and realistic fault simulations for connected ordinary finance.
  - [x] M07a Durable worker, ordered ledger replay and two-cache fault simulations.
  - [x] M07b Real Dart provider round trip and foreground sync status.
  - [x] M07c User-directed conflict recovery with prior device history retained.
- [ ] M08 Encrypted document/key engine, versions/import/camera scan/preview/search/reminders and audited gateway.
  - [x] M08a Additive v4 migration, encrypted version files, metadata, links and local audit.
  - [ ] M08b Document screens, native file and camera input, preview, expiry and export.
    - [x] Local document screens, Files and camera adapters, PDF and image preview, export and links.
    - [x] In-app expiry reminders.
    - [ ] Scheduled OS reminders and physical camera validation.
  - [ ] M08c Shared device keys, confirmed private Storage delivery and access audit.
    - [x] M08c1 Reservation, verified-byte receipts, private object gateway and key grant codec.
    - [x] Joined Storage, gateway and PostgreSQL transfer validation.
    - [x] M08c2 Mobile queue, encrypted metadata with shared versions, ciphertext and historical key backfill.
      - [x] Drift v5 staged uploads, offline preview and finance recovery retention.
      - [x] Backend reservation renewal and restricted historical key grants.
      - [x] Signed mobile transfer, receipt verification, receiving views and backfill.
    - [ ] M08c3 Shared metadata edits, archive and record links with conflict recovery.
      - [x] Durable metadata edits, archive and restore with independent revision and file history.
      - [x] Shared transaction links and user-directed retry of a preserved draft.
      - [ ] Shared asset links after the typed wealth backend is available.
- [ ] M09 Authenticated archive/local backup/export/restore, independent Drive adapter and complete clean-environment recovery tests.
  - [x] M09a Consistent rekeyed snapshot, authenticated envelope and verified local artifact.
  - [x] M09b Clean-install activation, recovery UI and verified Files destination adapters.
    - [ ] Native Files validation on supported devices.
  - [ ] M09c Drive copy/versioning/restore and permitted scheduling.
    - [x] M09c1 Resumable Drive transport, independent receipt and clean recovery in a local provider fixture.
    - [x] M09c2 Native Google consent configuration, backup history, export and restore screens with a local fixture.
    - [ ] Hosted Google consent and physical clean-device recovery drill.
    - [x] M09c3 Scheduled capture and optional Drive delivery during authorized device sessions.
- [ ] M10 Integrated UI/security/accessibility regression, Android emulator/device-independent integration and dependency/secret review.
- [ ] M11 Release APK/AAB/signing setup, iOS configuration, installation/user/migration/recovery guides and release notes.

For each unit: implement → relevant tests/fixes → evidence/status/journal → logical
commit → verified SSH push → next available unit. Restricted billing remains an
unimplemented extension point. No milestone is complete from a schema probe alone.
