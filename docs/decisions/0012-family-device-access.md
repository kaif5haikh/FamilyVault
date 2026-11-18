# ADR 0012: family membership and device access

Status: executable local Supabase migration and verification. Mobile enrollment
and protected finance replication are tracked separately.

Every person signs in with a separate verified Supabase Auth account. A family
administrator invites the verified email, and the matching account accepts it.
Membership is a server record. An invitation expires after seven days and yields
an ordinary member role. The database operator provisions the first administrator
and approves their first device after comparing the displayed fingerprint.

Each installation generates independent keys and an installation ID. The app
stores a dedicated derived device proof with its protected keys. The server
stores a digest of that proof with the Ed25519 and X25519 public keys, binds the
current Auth session to the approved installation and verifies possession on
protected requests. The stable proof is a device secret carried over TLS. It is
not device attestation. Document encryption will use the public keys separately.

Administrative calls need an enrolled administrator device and a recent verified
TOTP step. A role in client state or a session claim alone gives no access. The
access layer checks current membership, device status, bound session and the
provider's live Auth session. Approvals, revocations and bindings retain an
append-only audit with record IDs and server timestamps.

The public Data API exposes invoker RPC wrappers. Their private implementations
validate requests and operate through a dedicated no-login role. Access tables
have forced RLS and deny direct client access. A small provider-owned bridge
checks Auth without granting the application role general access to Auth tables.
PostgreSQL's quoted role grant avoids the reserved-role hook issue observed in
the local Supabase database. API logs must redact request secrets.

Native PostgreSQL tests use a local Auth fixture to exercise four accounts, two
families, denial cases and immutable audit. A separate real local Podman test
uses Supabase PostgreSQL, GoTrue and PostgREST for password login, TOTP,
invitation, device approval and stale-token denial after Auth sign-out.
