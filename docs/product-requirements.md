# Product requirements — confirmed decisions, architecture pending review

The owner's confirmed currency, sharing and backup requirements are authoritative;
[ADR 0003](decisions/0003-confirmed-product-architecture.md) consolidates their
consequences. Financial implementation still waits for revised architecture review.

## Purpose and users

Private Android/iOS family financial and document management, for father, mother,
sister and the administrator. These are requested relationship labels, not seeded
identities or automatic permission assignments. Invitation-only membership; each
person uses a separate Supabase Auth identity. One initial family is expected;
family scoping in every protected table prevents cross-family leakage.

## Confirmed cross-cutting requirements

- INR is the default, displayed as ₹. Store INR amounts as integer paise, with
  currency/scale metadata extensible to international currencies. All financial
  calculations, parsing and exact formatting avoid floating point. Use Indian
  grouping (`en_IN`) and lakh/crore notation with exact values still available.
- All active, authorized family members, including the administrator, view/add/edit
  shared income/expenses and view shared assets, properties, metals, liabilities,
  dashboards and reports. An ordinary member can edit another member's shared
  record; independent accounts preserve creator/modifier identity and audit.
- Every financial deletion is a soft tombstone. Historical facts/audit are immutable;
  corrections to posted accounting history remain possible through linked events.
- The shared family document vault is visible to all authorized members. Individual
  ownership is descriptive metadata, not an access restriction. Ordinary viewing,
  authenticated downloading, uploading and versioning do not need admin approval.
  Require encrypted cloud ciphertext, integrity verification, secure device
  enrollment and audited access/changes.
- Membership and sensitive administration stay administrator-only. Enforce all
  family boundaries server-side; never share authentication credentials.
- Both encrypted local backup/export and Google Drive backup upload/download/history
  are required. Manual/scheduled local backups run where platforms permit; report
  skipped/deferred/failed work honestly. Each destination verifies complete bytes
  and has independent status. Test a complete restore on a clean device from each.
  Keep recovery keys independently; Drive never becomes the live sync database.

## Requested modules

| Module | Required capabilities | Acceptance basis for later implementation |
| --- | --- | --- |
| Family finance | Income, daily expenses, monthly budgets, savings, bank/cash accounts, transfers, monthly/yearly reports | Offline entry persists across restart; transfers update both accounts atomically without increasing income/expense; reports reconcile to authorized ledger entries |
| Wealth | Gold/silver purity, weight, purchase cost/making charges, historical/current valuations; Mumbai/Ballia properties and land; ownership, cost/estimated value; vehicles, valuables, investments | Exact measured units, dated/source-attributed valuations, explicit ownership; no fabricated prices, automatic market feeds or property records |
| Liabilities | Borrowed/lent money, bank loans, EMI, interest, repayments and balances | Principal and interest separate; rounding, day-count, rate type and schedules explicitly approved; concurrent repayments never silently overwrite |
| Business | Father's tyre business: daily revenue, purchases, operating expenses, salaries, inventory and P&L | Separate business scope/permissions; stock movement history; accounting basis approved before P&L calculations |
| Documents | PDF/JPG/PNG, scanning, private encrypted storage, categories/search, expiry reminders, versions, shared family visibility, individual ownership and audited authenticated downloads | Every authorized member can access/upload; outsider/revoked device cannot list/read/decrypt; object/version confirmation precedes sync; no owner-only ACL or public bucket |
| Dashboard | Assets, liabilities, net worth, income/expense, savings rate, business profitability, allocation/trends | Permission-filtered aggregation, clear valuation dates and missing-data states; savings/net-worth formulas approved before coding |

Restricted billing is a future separate module. Do not create invoices, tax/GST,
customers, invoice numbering, billing permissions or billing workflows yet.

## Nonfunctional acceptance

- Offline writes and a durable outbox commit together. UI reads encrypted local
  data and exposes pending/conflicted/rejected states accurately.
- Retried mutations do not duplicate entries. Two devices modifying the same
  revision produce an explicit conflict with both versions recoverable.
- Restart, delayed responses, replay, revoked access, disk-full and corrupt backup
  scenarios have deterministic, non-destructive behavior.
- Deletions synchronize using tombstones. Migrations preserve existing data.
- Audit actor, device, operation, server revision and time without financial
  payloads in operational logs. Business audit content has restricted access.
- Accessibility: semantic navigation, readable contrast, text scaling, touch
  targets and system light/dark themes; no color-only sync status.
- No implied background-execution guarantee on Android/iOS; reconnect, foreground,
  manual retry and permitted background jobs all drive the same durable engine.

## Decisions requiring owner review

Family time zone/month boundaries; accounting basis and chart of accounts;
interest/rounding/EMI rules; valuation sources and ownership precision;
net-worth/savings-rate definitions and zero-income behavior; offline unlock
duration; backup cadence/retention/operator policy/recovery custodians;
reminder behavior/time zone; distribution identities and mobile OS support.

INR, shared family record editing, shared document visibility and both backup
destinations are confirmed, not unresolved choices. No actual family identities,
amounts, documents or account credentials are added by confirming these decisions.

No acceptance threshold for scale, RPO/RTO, availability or retention has been
invented. These values must be agreed before production acceptance.
