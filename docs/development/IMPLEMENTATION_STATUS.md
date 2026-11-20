# Implementation status

The signed Android 0.1.0 development release was physically exercised on a
Motorola Moto G34 5G. See the device report for the build-by-build results.
The implementation baseline was `b9a2705`.

Five tabs give access to Home, Money, Documents, Family and More. The app
has direct received, spent and move forms, an optional remembered tour and
16 offline help topics. English is the default and Hindi is available in
Devanagari. The language picker appears during first use and in Settings.
The exact signed 0.1.0+4 APK was verified on the Moto G34, including an
offline restart with a known synthetic record. Signed build 5 completes the
Hindi copy and passed host tests. Its physical retest is pending because
the phone stopped appearing in USB discovery after the offline test.
[Usability checklist](../UIUX/implementation-checklist.md).
[Hindi copy audit](../UIUX/hindi-copy-audit.md).

| Area | Actual baseline | Current result |
| --- | --- | --- |
| App | Locked welcome/access/about, theme, Riverpod/GoRouter | Device-authenticated local setup/unlock, encrypted overview and automatic privacy/locking wired/tested |
| Persistence | Encrypted Drift v1 outbox, checkpoints and conflicts | Drift v6 retains the document transfer queue and indexes pending edits. Populated v1 through v5 fixtures passed migration and earlier snapshots are retained. |
| Finance/wealth/debt/business | Architecture only | Local ledger + functional account/income/expense/transfer/correction/budget/reconciliation/report UI tested; v3 schema and exact calculations; asset, property, metal, rent, ownership and valuation screens tested with posted history; loans and repayment history; business revenue, operating costs, stock purchases, issues, wages and profit tested |
| Auth/backend/sync | Secure storage adapters and proposal SQL | Approved devices sync ordinary finance, budgets, statement checks, holdings, loans, business cash journals, stock and wages. Local Supabase tested exact profit after cross-device corrections and worker restoration. Hosted validation requires a configured deployment. |
| Documents | Design only | The signed Android app imported, previewed and exported a synthetic PDF. On the same handset, an isolated app verified streamed PNG and JPEG intake with zero additional picker cache copies, versions and archive restoration. Local Supabase verified encrypted delivery. Full camera capture and scheduled notification delivery remain open. |
| Backup/Drive | Design only | Android Files export and clean application restore passed on the Moto G34 using isolated local vaults. The host Drive fixture covered transfer recovery, verified receipts and restore. Live Google consent and transfer require OAuth configuration. |
| Tests | 9 Flutter host tests and design probes | 139 Flutter and five Deno tests passed. Both additional Flutter tests passed with local Auth, PostgreSQL and Storage. Physical tests used Android 15 on the Moto G34 5G. |
| Release | Prior Android debug APK | The Moto G34's installed APK matched signed build 4. Build 5 APK and App Bundle verify against the original local development certificate. Build 5 needs a connected Android device for its physical retest. iOS validation needs macOS and Xcode. |

Hosted Supabase and Google OAuth require approved credentials and setup.
Physical testing verified installation, device unlock, local ledger and offline
reconnection. iOS compilation and runtime validation need a macOS host.
[Physical Android validation](../testing/android-physical-device-validation.md).
[Release notes](../release-notes.md). [External validation](MASTER_ROADMAP.md#external-validation).
