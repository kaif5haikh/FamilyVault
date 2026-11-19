# Implementation status

Current task: **M09 Scheduled backups**. The Drive restore screen passed with a fixture and the Android integration compiled. Live consent requires approved OAuth configuration.
Baseline: b9a2705. Goal active; no financial features existed at baseline.

| Area | Actual baseline | Current result |
| --- | --- | --- |
| App | Locked welcome/access/about, theme, Riverpod/GoRouter | Device-authenticated local setup/unlock, encrypted overview and automatic privacy/locking wired/tested |
| Persistence | Encrypted Drift v1 outbox, checkpoints and conflicts | Drift v6 retains the document transfer queue and indexes pending edits. Populated v1 through v5 fixtures passed migration and earlier snapshots are retained. |
| Finance/wealth/debt/business | Architecture only | Local ledger + functional account/income/expense/transfer/correction/budget/reconciliation/report UI tested; v3 schema and exact calculations; asset, property, metal, rent, ownership and valuation screens tested with posted history; loans and repayment history; business revenue, operating costs, stock purchases, issues, wages and profit tested |
| Auth/backend/sync | Secure storage adapters and proposal SQL | Approved devices can open isolated encrypted family caches and sync ordinary finance, budgets and statement checks. Two Dart clients passed a live local Supabase round trip. Offline leases and recovery that retains pending device changes passed host tests. Shared wealth, loans and business commands are pending. |
| Documents | Design only | Local import, search, versions, in-app expiry, links, preview and export are tested. Real local Supabase tested shared versions, metadata, archive, restore, transaction links, retry of a saved conflicting version, Storage verification and historical keys. Shared asset links, scheduled reminders and physical camera validation are pending. |
| Backup/Drive | Design only | Encrypted snapshot, Files delivery and clean restore passed. The local Drive fixture tested interrupted uploads, independent receipts, version discovery, wrong-key rejection and restore from the app screen. Android compiled the Google plugin. Scheduling, hosted consent and physical Files validation remain pending. |
| Tests | 9 Flutter host tests and design probes | 121 Flutter tests and five Deno gateway tests passed. The two opt-in Dart provider tests passed separately. Android emulator startup is blocked by a host crash. |
| Release | Prior Android debug APK | Android debug build compiled the native Files and Google integrations. Release APK/AAB and complete UI remain pending. iOS validation needs macOS/Xcode. |

External constraints: no Supabase/Google OAuth/deployment credentials supplied;
Linux host cannot validate iOS binaries. Implement local/mocked equivalents and
provider setup documentation while continuing all independent work. No secrets
are requested in chat. This table must be updated as each unit is verified.

M01 implemented: Money uses integer paise/BigInt intermediates, strict Indian decimal parsing, exact/compact formatting and overflow detection; safe typed failures/config and English/Hindi string foundation. Analyzer clean; all 14 current tests pass. M03/M04 now wire the local UI and vault lifecycle.
