# ADR 0013 Shared ledger and operation receipts

Status: implemented for ordinary ledger commands and checked with local
PostgreSQL and the Supabase Data API on 2026-11-18.

The enrolled database session supplies the family, member and device for every
write. The envelope must match all three. `fv_sync_push` limits and validates
the original JSON before decoding typed records. Integers must fit a signed
64-bit value, including values above JavaScript's safe integer range. The
mobile caller sends the envelope as text. This preserves the exact bytes when
transport and database wrappers deserialize the request.

Each family serializes writes under its own database row lock. A successful
transaction records both the financial facts and the next sequence number. An
account and its optional opening entry arrive together. A correction inserts
the exact reversal, closes the original entry and posts its replacement in
one transaction. The operation UUID and SHA-256 of its original JSON identify
a receipt. Replaying the same authorized operation returns its previous
receipt. Reusing the UUID with different content fails.

A stale revision returns HTTP 409 (`PT409`). This is a FamilyVault conflict
code. PostgreSQL's `40001` is reserved for retryable serialization failures.
The PostgREST integration confirmed that using `40001` for a stale version
made the API keep replaying the rejected operation. [PostgREST errors](https://docs.postgrest.org/en/stable/references/errors.html)

`fv_sync_pull` returns a family watermark and an ordered page with exact
`payload_json` text. The client can verify each digest before applying its
record. Limits cap individual envelopes at 512 KiB and returned raw payload
bytes at 1 MiB per page. The shared chart uses canonical UUIDs derived from
the family and category code, returned by `fv_sync_chart`. Existing offline
vaults retain their chart IDs and outboxes.

The ordinary endpoint reserves managed accounts and module journals for their
typed domain commands. The planning migration adds one active budget per
category and month, with preserved tombstones. A statement check compares the
recorded ledger total with the accepted total at its statement date. If the
total changed offline, the server refuses the check. An explicitly requested
adjustment posts in the same transaction and must exactly match the difference.

Typed wealth, loan and business aggregates need their own validation. A separate
encrypted cloud cache and mobile delivery, replay and user conflict handling
remain implementation work. Server tests exercise real receipts and competing
edits but do not establish mobile replication.
