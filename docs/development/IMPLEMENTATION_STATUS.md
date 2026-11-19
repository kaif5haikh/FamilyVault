# Implementation status

Current task: **M08 documents**. Connected document versions passed a Flutter round trip through local Supabase. Shared metadata changes, archive, record links and scheduled reminders remain pending.
Baseline: b9a2705. Goal active; no financial features existed at baseline.

| Area | Actual baseline | Current result |
| --- | --- | --- |
| App | Locked welcome/access/about, theme, Riverpod/GoRouter | Device-authenticated local setup/unlock, encrypted overview and automatic privacy/locking wired/tested |
| Persistence | Encrypted Drift v1 outbox, checkpoints and conflicts | Drift v5 adds an encrypted document transfer queue. Populated v1 through v4 fixtures passed migration and earlier schema snapshots are retained. |
| Finance/wealth/debt/business | Architecture only | Local ledger + functional account/income/expense/transfer/correction/budget/reconciliation/report UI tested; v3 schema and exact calculations; asset, property, metal, rent, ownership and valuation screens tested with posted history; loans and repayment history; business revenue, operating costs, stock purchases, issues, wages and profit tested |
| Auth/backend/sync | Secure storage adapters and proposal SQL | Approved devices can open isolated encrypted family caches and sync ordinary finance, budgets and statement checks. Two Dart clients passed a live local Supabase round trip. Offline leases and recovery that retains pending device changes passed host tests. Shared wealth, loans and business commands are pending. |
| Documents | Design only | Local import, search, versions, in-app expiry, links, preview and export are tested. Shared versions, pending draft preview, Storage verification, conflict retention and historical key delivery passed with real local Supabase. Shared metadata changes, archive and links, scheduled reminders and physical camera validation are pending. |
| Backup/Drive | Design only | Encrypted archive, restore, and both destinations remain pending. |
| Tests | 9 Flutter host tests and design probes | 108 Flutter tests and five Deno gateway tests passed. The two opt-in Dart provider tests passed separately. Android emulator startup is blocked by a host crash. |
| Release | Prior Android debug APK | M07b Android debug build passed. Release APK/AAB and complete UI remain pending. iOS validation needs macOS/Xcode. |

External constraints: no Supabase/Google OAuth/deployment credentials supplied;
Linux host cannot validate iOS binaries. Implement local/mocked equivalents and
provider setup documentation while continuing all independent work. No secrets
are requested in chat. This table must be updated as each unit is verified.

M01 implemented: Money uses integer paise/BigInt intermediates, strict Indian decimal parsing, exact/compact formatting and overflow detection; safe typed failures/config and English/Hindi string foundation. Analyzer clean; all 14 current tests pass. M03/M04 now wire the local UI and vault lifecycle.
