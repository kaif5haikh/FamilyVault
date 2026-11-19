# Implementation status

The signed Android 0.1.0 development release was physically exercised on a
Motorola Moto G34 5G. See the device report for the build-by-build results.
The implementation baseline was `b9a2705`.

| Area | Actual baseline | Current result |
| --- | --- | --- |
| App | Locked welcome/access/about, theme, Riverpod/GoRouter | Device-authenticated local setup/unlock, encrypted overview and automatic privacy/locking wired/tested |
| Persistence | Encrypted Drift v1 outbox, checkpoints and conflicts | Drift v6 retains the document transfer queue and indexes pending edits. Populated v1 through v5 fixtures passed migration and earlier snapshots are retained. |
| Finance/wealth/debt/business | Architecture only | Local ledger + functional account/income/expense/transfer/correction/budget/reconciliation/report UI tested; v3 schema and exact calculations; asset, property, metal, rent, ownership and valuation screens tested with posted history; loans and repayment history; business revenue, operating costs, stock purchases, issues, wages and profit tested |
| Auth/backend/sync | Secure storage adapters and proposal SQL | Approved devices sync ordinary finance, budgets, statement checks, holdings, loans, business cash journals, stock and wages. Local Supabase tested exact profit after cross-device corrections and worker restoration. Hosted validation requires a configured deployment. |
| Documents | Design only | The signed Android app imported, previewed and exported a synthetic PDF. On the same handset, an isolated app verified streamed PNG and JPEG intake with zero additional picker cache copies, versions and archive restoration. Local Supabase verified encrypted delivery. Full camera capture and scheduled notification delivery remain open. |
| Backup/Drive | Design only | Android Files export and clean application restore passed on the Moto G34 using isolated local vaults. The host Drive fixture covered transfer recovery, verified receipts and restore. Live Google consent and transfer require OAuth configuration. |
| Tests | 9 Flutter host tests and design probes | 130 Flutter tests and five Deno gateway tests passed. Two additional Dart provider tests passed with local Auth, PostgreSQL and Storage. Physical tests used Android 15 on the Moto G34 5G. |
| Release | Prior Android debug APK | Signed Android 0.1.0+3 APK and App Bundle verified with the original local development certificate. The handset's installed APK matched the rebuilt digest. The included iOS project needs macOS and Xcode for validation. |

Hosted Supabase and Google OAuth require approved credentials and setup.
Physical testing verified installation, device unlock, local ledger and offline
reconnection. iOS compilation and runtime validation need a macOS host.
[Physical Android validation](../testing/android-physical-device-validation.md).
[Release notes](../release-notes.md). [External validation](MASTER_ROADMAP.md#external-validation).
