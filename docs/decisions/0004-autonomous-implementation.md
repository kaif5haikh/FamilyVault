# ADR 0004: autonomous implementation and additive migration

Date: 2026-11-13. Status: implementation authority granted by the owner's explicit
autonomous end-to-end mission. This supersedes the earlier requirement to stop
for a human review before financial implementation. It does not claim a human
architecture review, production security approval or production deployment consent.

Confirmed product decisions in ADR 0003 remain binding. Execute small tested
milestones continuously, maintain `docs/development/`, preserve history and use
no real family data or paid services. Unknown credentials/hardware are documented
limits while local/mock and independent work continue.

Drift v1 and its snapshot remain immutable historical baselines. Add financial
tables/indexes in a versioned v2 upgrade transaction; never drop/reset old tables.
Future versions use explicit forward migrations and prior-version fixtures.
Review-only SQL is not automatically adopted as a production migration.

Accounting uses signed integer paise, single-currency balanced journal aggregates,
asset/expense debit-positive and liability/equity/income credit-negative. Posted
facts are immutable; corrections append reversals/replacements. Defaults, financial
terms and later engineering decisions are recorded in the implementation journal.

An offline vault is a functional private local workspace with its own identity and
device-protected keys. It does not claim cloud family membership or shared sync.
Configured Supabase authentication opens a separately scoped authorized cache;
moving data between workspaces requires explicit validated import/recovery rather
than silently rebinding historical actors. No credentials are embedded in builds.

Completion requires behavior/integration evidence and installable artifacts,
not proposals alone. iOS binaries require macOS/Xcode; live provider validation
requires separately configured credentials. Release status must state these limits.
