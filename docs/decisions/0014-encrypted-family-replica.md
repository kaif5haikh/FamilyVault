# ADR 0014 Encrypted family cache and receipt replay

Status: connected ordinary finance and conflict recovery implemented and tested
on 2026-11-18. Shared wealth, loan and business commands remain in progress.

A device passcode or biometric prompt protects local key access. The cloud
cache first binds the enrolled device to the live account, verifies the family
directory and both public keys, and imports the server's chart. Scoped cache
paths derive from the server, account, family and device. Each enrollment has
its own keys. The original local workspace, its chart and its outbox stay in
separate files. A missing ready cache raises a recovery error. An interrupted
initialization may resume with the same keys.

An approved cache can open through the OS prompt during a transport failure
with the same Supabase account and session for up to twelve hours after a live
check. Foreground polls refresh live access every twelve seconds and persist
an updated grant at most once per five minutes. A recorded local clock rollback,
expired grant, changed session or explicit denial requires live verification.
Account changes and server denials close the vault and clear the grant. The
offline bound uses the device clock and can be affected by device compromise.

Local writes append outbox rows in the same transaction as their ledger facts.
A single coordinator sends them in insertion order and persists each delivery
lease before the network request. It uses bounded exponential retries and
jitter. An accepted receipt must match the operation and exact digest. An
interrupted delivery can also recover a receipt from its matching feed entry.
The existing Drift `accepted_revision` field holds the accepted feed sequence.

The worker checks a complete page for contiguous ordering, the family scope
and exact payload digests. The page's SQL writes, immutable audit and cursor
share a local transaction. A rejection or bad receipt cannot silently advance
confirmation. Overlapping optimistic account, budget or journal changes stop
replay and retain the competing snapshots. Settings lets the user inspect these
changes and choose the family's accepted records. A fresh encrypted cache replays
the complete feed and verifies current access and file integrity. One secure
catalog update activates it and retains the previous file. Failed rebuilds leave
the original active. Saved device changes exposes the retained pending records
for review and manual re-entry. Re-entry creates a new transaction via its module.

The simulation runs two separate encrypted caches and tests disconnected writes,
lost or invalid receipts, restart after server commit, concurrent account edits,
partial page rollback and correction history. A second test runs two Dart clients
against isolated GoTrue and PostgREST. It exercises sign-in, chart and directory
import, exact paise delivery, ordered replay and attribution across accounts.
Hosted Supabase and physical phone checks remain pending.
