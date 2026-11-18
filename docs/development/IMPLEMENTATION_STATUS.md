# Implementation status

Current task: **M06 shared family access and backend**. The local finance, assets, loans and business workflows passed.
Baseline: b9a2705. Goal active; no financial features existed at baseline.

| Area | Actual baseline | Current result |
| --- | --- | --- |
| App | Locked welcome/access/about, theme, Riverpod/GoRouter | Device-authenticated local setup/unlock, encrypted overview and automatic privacy/locking wired/tested |
| Persistence | Encrypted Drift v1: outbox/checkpoints/conflicts only | Encrypted v3 foundation implemented/tested; populated v1/v2 and immutable snapshots preserved |
| Finance/wealth/debt/business | Architecture only | Local ledger + functional account/income/expense/transfer/correction/budget/reconciliation/report UI tested; v3 schema and exact calculations; asset, property, metal, rent, ownership and valuation screens tested with posted history; loans and repayment history; business revenue, operating costs, stock purchases, issues, wages and profit tested |
| Auth/backend/sync | Secure storage adapters; proposal SQL | Membership/device control plane tested with local PostgreSQL and real Supabase Auth/PostgREST; app enrollment in progress; no hosted deployment or finance replication |
| Documents/backup/Drive | Design only | Engines/adapters/integration tests required |
| Tests | 9 Flutter host tests; design probes | 80 host tests passed, including encrypted form workflows and responsive layouts; cloud/mobile hardware still pending |
| Release | Prior Android debug APK | M05d Android debug build passed; release APK/AAB and complete UI still required; iOS needs macOS/Xcode |

External constraints: no Supabase/Google OAuth/deployment credentials supplied;
Linux host cannot validate iOS binaries. Implement local/mocked equivalents and
provider setup documentation while continuing all independent work. No secrets
are requested in chat. This table must be updated as each unit is verified.

M01 implemented: Money uses integer paise/BigInt intermediates, strict Indian decimal parsing, exact/compact formatting and overflow detection; safe typed failures/config and English/Hindi string foundation. Analyzer clean; all 14 current tests pass. M03/M04 now wire the local UI and vault lifecycle.
