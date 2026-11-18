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
  - [x] M06d Scoped encrypted cloud cache and live device session lifecycle.
    - [x] M06d1 Verified directory and chart import into isolated encrypted caches.
    - [x] M06d2 Connected app lifecycle, bounded offline unlock and revocation.
- [ ] M07 Durable multi-client sync, receipts/conflicts/retries/recovery and realistic fault simulations.
  - [x] M07a Durable worker, ordered ledger replay and two-cache fault simulations.
  - [x] M07b Real Dart provider round trip and foreground sync status.
  - [ ] M07c User-directed conflict recovery with prior device history retained.
- [ ] M08 Encrypted document/key engine, versions/import/camera scan/preview/search/reminders and audited gateway.
- [ ] M09 Authenticated archive/local backup/export/restore, independent Drive adapter and complete clean-environment recovery tests.
- [ ] M10 Integrated UI/security/accessibility regression, Android emulator/device-independent integration and dependency/secret review.
- [ ] M11 Release APK/AAB/signing setup, iOS configuration, installation/user/migration/recovery guides and release notes.

For each unit: implement → relevant tests/fixes → evidence/status/journal → logical
commit → verified SSH push → next available unit. Restricted billing remains an
unimplemented extension point. No milestone is complete from a schema probe alone.
