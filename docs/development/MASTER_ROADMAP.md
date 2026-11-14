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
- [ ] M05 Wealth/property/metals/valuations, liabilities/interest/repayments and business accounting/inventory.
  - [x] M05a Additive v3 schema, guarded histories, exact valuation/interest/stock math.
  - [ ] M05b Atomic module writer and wealth/property/metals services/screens.
  - [ ] M05c Contracts, actual repayments, interest estimates and native workflows.
  - [ ] M05d Business revenue/expenses, stock, workers/salaries and profit reporting.
- [ ] M06 Executable PostgreSQL/Supabase migrations, membership/enrollment/session/RLS/RPC and security integration tests.
- [ ] M07 Durable multi-client sync, receipts/conflicts/retries/recovery and realistic fault simulations.
- [ ] M08 Encrypted document/key engine, versions/import/camera scan/preview/search/reminders and audited gateway.
- [ ] M09 Authenticated archive/local backup/export/restore, independent Drive adapter and complete clean-environment recovery tests.
- [ ] M10 Integrated UI/security/accessibility regression, Android emulator/device-independent integration and dependency/secret review.
- [ ] M11 Release APK/AAB/signing setup, iOS configuration, installation/user/migration/recovery guides and release notes.

For each unit: implement → relevant tests/fixes → evidence/status/journal → logical
commit → private SSH push → next available unit. Restricted billing remains an
unimplemented extension point. No milestone is complete from a schema probe alone.
