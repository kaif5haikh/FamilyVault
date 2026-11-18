# ADR 0009: asset accounting and dated ownership

Status: implemented in the local vault. Imports of encrypted property documents
and server replication belong to the document and synchronization milestones.

An asset has a dedicated account. A recorded opening value credits equity. A
purchase recorded against a cash or bank account reduces that account by the
family's portion. Valuations change the asset and an equity reserve. This keeps
unrealized changes out of income and expense reports. Closing a holding credits
its book value, debits actual proceeds to the receiving account and posts any
difference to equity. Rental receipts and their reversals appear in income.

Valuations apply on a calendar date. A later entry for an earlier date appends
the change and a compensating posting as needed to preserve the first known
valuation after it. Closure-date valuations calculate the book value before
disposal, then maintain a zero holding balance after disposal. Undoing closure
appends exact reversals. Changing the family share uses a current dated quote.
An earlier quote still uses the share effective on its date. Individual
allocations describe ownership and remain within the total family share.

The module transaction checks the current member, device and expected revision.
It commits the root, metadata and ledger changes with a single outbox envelope
and append-only audit. Retrying the same operation on the same device returns
its result. A changed command using that operation ID conflicts. The generic
ledger service rejects direct edits to accounts and entries owned by modules.
The local SQLite service enforces this boundary. Supabase must enforce equivalent
invariants independently before accepting shared writes.
