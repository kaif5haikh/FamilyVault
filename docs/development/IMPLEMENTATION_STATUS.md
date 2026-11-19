# Implementation status

Current task: **Shared asset document links and business accounting**. Two enrolled devices passed shared holdings and loan corrections against local Supabase.
Baseline: b9a2705. Goal active; no financial features existed at baseline.

| Area | Actual baseline | Current result |
| --- | --- | --- |
| App | Locked welcome/access/about, theme, Riverpod/GoRouter | Device-authenticated local setup/unlock, encrypted overview and automatic privacy/locking wired/tested |
| Persistence | Encrypted Drift v1 outbox, checkpoints and conflicts | Drift v6 retains the document transfer queue and indexes pending edits. Populated v1 through v5 fixtures passed migration and earlier snapshots are retained. |
| Finance/wealth/debt/business | Architecture only | Local ledger + functional account/income/expense/transfer/correction/budget/reconciliation/report UI tested; v3 schema and exact calculations; asset, property, metal, rent, ownership and valuation screens tested with posted history; loans and repayment history; business revenue, operating costs, stock purchases, issues, wages and profit tested |
| Auth/backend/sync | Secure storage adapters and proposal SQL | Approved devices sync ordinary finance, budgets, statement checks, holdings and loans. Local Supabase tested scoped journals, replay of value and repayment history, exact principal corrections and concurrent edit detection. Shared business commands are pending. |
| Documents | Design only | Local import, search, versions, in-app expiry, links, preview and export are tested. Real local Supabase tested shared versions, metadata, archive, restore, transaction links, retry of a saved conflicting version, Storage verification and historical keys. Shared asset links, scheduled reminders and physical camera validation are pending. |
| Backup/Drive | Design only | Encrypted snapshot, Files delivery and clean restore passed. The Drive fixture tested transfer recovery, receipts and clean app restore. Daily and weekly scheduling ran while unlocked and retried a pending Drive copy for its selected account. Hosted consent and physical Files validation remain pending. |
| Tests | 9 Flutter host tests and design probes | 123 Flutter tests and five Deno gateway tests passed. The two opt-in Dart provider tests passed separately. Android emulator startup is blocked by a host crash. |
| Release | Prior Android debug APK | Android debug build compiled the native Files and Google integrations. Release APK/AAB and complete UI remain pending. iOS validation needs macOS/Xcode. |

External constraints: no Supabase/Google OAuth/deployment credentials supplied;
Linux host cannot validate iOS binaries. Implement local/mocked equivalents and
provider setup documentation while continuing all independent work. No secrets
are requested in chat. This table must be updated as each unit is verified.

M01 implemented: Money uses integer paise/BigInt intermediates, strict Indian decimal parsing, exact/compact formatting and overflow detection; safe typed failures/config and English/Hindi string foundation. Analyzer clean; all 14 current tests pass. M03/M04 now wire the local UI and vault lifecycle.
