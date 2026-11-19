# Implementation status

The local development release is built and verified on Linux. Hosted services
and physical-device acceptance remain in the external validation checklist.
The implementation baseline was `b9a2705`.

| Area | Actual baseline | Current result |
| --- | --- | --- |
| App | Locked welcome/access/about, theme, Riverpod/GoRouter | Device-authenticated local setup/unlock, encrypted overview and automatic privacy/locking wired/tested |
| Persistence | Encrypted Drift v1 outbox, checkpoints and conflicts | Drift v6 retains the document transfer queue and indexes pending edits. Populated v1 through v5 fixtures passed migration and earlier snapshots are retained. |
| Finance/wealth/debt/business | Architecture only | Local ledger + functional account/income/expense/transfer/correction/budget/reconciliation/report UI tested; v3 schema and exact calculations; asset, property, metal, rent, ownership and valuation screens tested with posted history; loans and repayment history; business revenue, operating costs, stock purchases, issues, wages and profit tested |
| Auth/backend/sync | Secure storage adapters and proposal SQL | Approved devices sync ordinary finance, budgets, statement checks, holdings, loans, business cash journals, stock and wages. Local Supabase tested exact profit after cross-device corrections and worker restoration. Hosted validation requires a configured deployment. |
| Documents | Design only | Local import, search, versions, expiry, links, preview and export are tested. Local Supabase tested encrypted delivery and shared document workflows. Opt-in expiry scheduling passed host tests and Android compilation. Physical camera and notification delivery remain unverified. |
| Backup/Drive | Design only | Encrypted snapshot, Files delivery and clean restore passed. The Drive fixture tested transfer recovery, receipts and clean app restore. Daily and weekly scheduling ran while unlocked and retried a pending Drive copy for its selected account. Hosted consent and physical Files validation remain pending. |
| Tests | 9 Flutter host tests and design probes | 125 Flutter tests and five Deno gateway tests passed. Two opt-in Dart provider tests passed separately with Auth, PostgreSQL and Storage. Android emulator startup was blocked by a host crash. |
| Release | Prior Android debug APK | Signed Android 0.1.0 APK and App Bundle verified with the same local development certificate. Bundletool produced a universal APK that passed signature verification. The included iOS project needs macOS and Xcode for validation. |

Hosted Supabase and Google OAuth require approved credentials and setup.
Android physical camera, Files, notifications, installation and offline
reconnection remain to be exercised. iOS compilation and runtime validation
need a macOS host. [Release notes](../release-notes.md). [External validation](MASTER_ROADMAP.md#external-validation).
