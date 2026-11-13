# Product requirements — proposal for review

## Purpose and users

Private Android/iOS family financial and document management, for father, mother,
sister and the administrator. These are requested relationship labels, not seeded
identities or automatic permission assignments. Invitation-only membership; each
person uses a separate Supabase Auth identity. One initial family is expected;
family scoping in every protected table prevents cross-family leakage.

## Requested modules

| Module | Required capabilities | Acceptance basis for later implementation |
| --- | --- | --- |
| Family finance | Income, daily expenses, monthly budgets, savings, bank/cash accounts, transfers, monthly/yearly reports | Offline entry persists across restart; transfers update both accounts atomically without increasing income/expense; reports reconcile to authorized ledger entries |
| Wealth | Gold/silver purity, weight, purchase cost/making charges, historical/current valuations; Mumbai/Ballia properties and land; ownership, cost/estimated value; vehicles, valuables, investments | Exact measured units, dated/source-attributed valuations, explicit ownership; no fabricated prices, automatic market feeds or property records |
| Liabilities | Borrowed/lent money, bank loans, EMI, interest, repayments and balances | Principal and interest separate; rounding, day-count, rate type and schedules explicitly approved; concurrent repayments never silently overwrite |
| Business | Father's tyre business: daily revenue, purchases, operating expenses, salaries, inventory and P&L | Separate business scope/permissions; stock movement history; accounting basis approved before P&L calculations |
| Documents | PDF/JPG/PNG, camera scanning, private storage, categories/search, expiry reminders, versions, secure download/sharing, ownership/grants | Encrypt before upload; metadata and object receipt confirmed before sync; unauthorized user cannot list/read/decrypt; immutable version history; no public bucket |
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

Default currency and additional currencies; family time zone/month boundaries;
member role assignments and private-vs-shared records; accounting basis and chart
of accounts; interest/rounding/EMI rules; valuation sources and ownership precision;
net-worth/savings-rate definitions and zero-income behavior; document-sharing
scope; offline unlock duration; backup cadence/retention/recovery custodians;
reminder behavior/time zone; distribution identities and mobile OS support.

No acceptance threshold for scale, RPO/RTO, availability or retention has been
invented. These values must be agreed before production acceptance.
