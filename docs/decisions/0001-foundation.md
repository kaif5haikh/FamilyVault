# ADR 0001: offline-first foundation

Status: proposed for architecture review; infrastructure choices evaluated during setup.

## Decisions

1. Flutter/Dart with Riverpod and GoRouter, Android/iOS only. FL Chart is selected
   for later visualization; do not add artificial chart data to the shell.
2. Drift on native SQLite with SQLite3MultipleCiphers, a random per-vault key in
   secure platform storage, and a release-mode runtime cipher check. Upstream
   Drift now recommends the sqlite3 build-hook route rather than old
   `sqlcipher_flutter_libs` recipes. Key availability failure never falls back
   to plaintext. Keys are not the Supabase password or access token.
3. Supabase PostgreSQL/Auth/private Storage; custom transactional outbox/RPC
   protocol with optimistic revision checks. Realtime alone cannot replay a
   durable offline mutation log. Managed third-party sync services are deferred
   to avoid an unreviewed dependency/cost; revisit if protocol complexity warrants it.
4. UUIDv4 client IDs, integer minor-unit money and explicit currency, UTC event
   instants plus separate local accounting dates. No wall-clock last-write-wins.
5. Encrypted document envelopes with independent version keys, opaque object
   names and server-confirmed finalization. Cloud-at-rest encryption alone does
   not satisfy document application encryption.
6. Private GitHub repository over SSH. Use repository-local Git author identity
   based on the verified account; never modify global identity or credentials.
7. Architecture proposals live under `docs/`, outside executable migrations.
   Phase 3 implements sync metadata only. Financial implementation is gated.

## Consequences

We must build and test sync acknowledgements, conflict management, permission
epochs, key distribution/recovery and native encryption behavior explicitly.
These are planned controls, not claims of completed security. Document search
is performed locally over authorized metadata; server OCR/plaintext indexing
would break the document confidentiality boundary and is not included.

## Upstream evidence

- [Drift encryption](https://drift.simonbinder.eu/platforms/encryption/)
- [Supabase private buckets](https://supabase.com/docs/guides/storage/buckets/fundamentals)
- [Supabase RLS](https://supabase.com/docs/guides/database/postgres/row-level-security)
- [Flutter stable SDK archive](https://docs.flutter.dev/install/archive)
