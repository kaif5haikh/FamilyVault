# FamilyVault

Private Android and iOS application for a family's finances, assets, liabilities,
business records and encrypted documents. This is an independent project.

**Status: architecture proposal and infrastructure foundation.** No real family
records, financial features, working cloud synchronization or production backend
are included. Architecture and database review is required before financial
implementation. No Supabase project or paid service is provisioned.

## Scope

- Family finance: income, expenses, budgets, savings, bank/cash accounts, transfers and reports.
- Wealth: precious metals, properties/land, vehicles, valuables and investments.
- Liabilities: borrowed/lent money, loans, EMIs and repayment history.
- Business: tyre business revenue, purchases, expenses, salaries, stock and P&L.
- Documents: encrypted private storage, scanning, categorization, search, versions,
  expiry reminders and authorized sharing.
- Dashboard: permission-filtered assets, liabilities, net worth and trends.

The separate restricted billing module is deliberately unspecified and deferred.
No identities, balances, property details or financial assumptions are seeded.

## Design and development

Start with the [documentation index](docs/README.md),
[product requirements](docs/product-requirements.md),
[architecture](docs/architecture.md) and [review gate](docs/review-gate.md).
Read [CONTRIBUTING.md](CONTRIBUTING.md) and [SECURITY.md](SECURITY.md) before changes.

The owner has confirmed INR/₹ with exact integer paise and Indian formatting,
shared family financial editing, shared family documents with individual ownership,
and both local/Google Drive encrypted backups. The consolidated
[ADR 0003](docs/decisions/0003-confirmed-product-architecture.md) records these
requirements, consequences, risks and remaining review/implementation. The app
remains a locked foundation; confirming requirements does not implement finance,
document sharing, Google Drive or backup/restore.

Required stack: Flutter/Dart, Riverpod, GoRouter, FL Chart, Drift/SQLite,
Supabase PostgreSQL/Auth/private Storage. SQLite is encrypted using the reviewed
native cipher build; sensitive document encryption happens before uploading.

Toolchain setup, verified checks and known limitations are recorded in
[development setup](docs/development.md) and the
[initialization record](docs/operations/2026-11-13-initialization.md).

The initial Flutter shell includes a Material 3 theme, GoRouter navigation,
Riverpod access boundary, secure session/PKCE storage adapters and an encrypted
Drift database for sync metadata. The shell stays disconnected and locked;
full authentication, document crypto, synchronization and financial features
are later milestones. See [the foundation decision](docs/decisions/0002-mobile-foundation.md).

```bash
source tool/env.sh
flutter pub get --enforce-lockfile
flutter analyze --no-pub
flutter test --no-pub
```

## Security baseline

Keep credentials, personal documents, database files, exports and backups outside
Git. Supabase service-role/secret keys never belong in the mobile app. Private
repository visibility is not a data-security boundary. Use synthetic test inputs
only. Google Drive is a required encrypted backup destination alongside local backup, never the live
sync database. A successful upload alone never means synchronization succeeded.
