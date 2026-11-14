# FamilyVault

Private Android and iOS application for a family's finances, assets, liabilities,
business records and encrypted documents. This is an independent project.

**Status: active implementation.** The encrypted offline finance workspace now
supports accounts, income, expenses, transfers, corrections, budgets,
reconciliation, dashboards and reports. Device-authenticated unlock and automatic
locking are connected. Wealth, loans, business, cloud membership/sync, documents
and backup/recovery are the next milestones. No production backend or paid service
has been provisioned. See the [verified implementation status](docs/development/IMPLEMENTATION_STATUS.md).

## Product

- INR/₹ by default, exact integer paise, Indian grouping and lakh/crore presentation.
- Independent family accounts with shared family editing and creator/modifier audit.
- Immutable posted accounting, linked corrections/reversals and financial tombstones.
- Shared document visibility; ownership is metadata, never a private document ACL.
- Encrypted local **and** Google Drive backups; Drive is not the live sync database.
- Native Flutter, Riverpod, GoRouter, FL Chart, encrypted Drift/SQLite and Supabase.

The separate restricted billing module is unspecified and deliberately deferred.
No identities, balances, property details or family documents are seeded.

## Develop

Read [AGENTS.md](AGENTS.md), [CONTRIBUTING.md](CONTRIBUTING.md),
[SECURITY.md](SECURITY.md) and the [development setup](docs/development.md).
The project-local toolchains and caches are configured by `tool/env.sh`.

```bash
source tool/env.sh
bash tool/check.sh
flutter build apk --debug --no-pub
```

The Android debug artifact is `build/app/outputs/flutter-apk/app-debug.apk`.
A device screen lock/biometric setup is required to create and unlock a vault.
Start with an empty local workspace; it works without cloud credentials.
A local save is explicitly reported as local, never as confirmed synchronization.
Release APK/AAB preparation and physical-device validation remain separate
acceptance items. iOS builds require macOS/Xcode; this Linux host cannot validate them.

## Engineering evidence

- [Roadmap](docs/development/MASTER_ROADMAP.md) and [implementation status](docs/development/IMPLEMENTATION_STATUS.md).
- [Test results](docs/development/TEST_RESULTS.md) and [operation journal](docs/development/WORK_LOG.md).
- [Documentation index](docs/README.md), [requirements](docs/product-requirements.md),
  [architecture](docs/architecture.md), [database](docs/database.md).
- Confirmed product decisions: [ADR 0003](docs/decisions/0003-confirmed-product-architecture.md).
- Autonomous execution/migration authority: [ADR 0004](docs/decisions/0004-autonomous-implementation.md).
- Implemented ledger: [ADR 0005](docs/decisions/0005-local-ledger.md).
- Device vault: [ADR 0006](docs/decisions/0006-device-vault-lifecycle.md).

The owner's autonomous mission supersedes the historic per-phase stop gate. It
is not a claim of completed human security review or production deployment approval.
SQL proposals elsewhere in the documentation are labelled separately from
executable migrations and tested application behavior.

## Security baseline

Keep credentials, personal documents, databases, exports and backups out of Git.
Supabase service-role/secret keys never belong in Flutter. Private repository
visibility is not a data-security boundary. Development and tests use synthetic
inputs only. App logs must not contain financial data, documents, keys or tokens.
