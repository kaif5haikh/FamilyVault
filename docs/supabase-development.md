# Supabase development setup

Use a dedicated local test environment and sample records. The default Flutter
build uses the local vault and does not contact Supabase.

## Database tests

With `psql`, `initdb` and `pg_ctl` available, run `bash tool/check_backend.sh`.
The script starts its own PostgreSQL cluster on a private Unix socket and uses
an Auth fixture. It checks the same application SQL used by Supabase. The test
runs no migrations against any existing database.

For the provider integration, install rootless Podman and pull the Supabase
PostgreSQL, GoTrue and PostgREST images listed in `tool/check_supabase.py` into
the project-local Podman store. The reviewed versions are PostgreSQL 17.6.1.136,
GoTrue v2.197.0 and PostgREST v14.18, with image digests pinned in the script.
Run `source tool/env.sh` followed by `python3 -B tool/check_supabase.py`. It uses
its own pod, publishes to localhost ports chosen by Podman, generates only
synthetic credentials and removes the test pod on exit. The commands and image
versions come from the [Supabase self-hosted stack](https://github.com/supabase/supabase/blob/master/docker/docker-compose.yml).

The provider check drives an ordinary ledger opening and concurrent edits
with two signed-in, approved devices. It verifies the exact paise amount in
the feed and confirms that the losing edit gets HTTP 409. It also checks that
the previous member token loses access after Auth sign-out.

## Provision a development family

1. Use a dedicated development project and apply `supabase/migrations/` in
   order as its database migration role. Leave `fv_data`, `fv_internal` and
   `fv_auth_bridge` outside the Data API's exposed schemas.
2. Disable public sign-up. In Supabase Auth, provision each test member's own
   email account and confirm it. The app's family invitation grants membership
   to a verified Auth account. It does not send email or share login details.
3. As the database operator, call `fv_internal.bootstrap_family` with the
   verified administrator's Auth user ID, a test family name and display name.
   Retain the resulting family ID in the development setup.
4. Sign in from the test device and request registration. Compare the displayed
   device ID and fingerprint directly with that device, then call
   `fv_internal.approve_first_device` with those two values. Complete device
   approval before allowing the connected workspace to open.
5. Verify the administrator's TOTP code before inviting others and approving
   their phones. Never paste passwords, proof secrets or keys in tickets or Git.

The app build accepts `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` using
`--dart-define-from-file` from an ignored file. Release builds require HTTPS.
Debug builds may use explicit loopback development configuration with
`FAMILYVAULT_LOCAL_HTTP=true`. Keep the privileged installation key server-side.
Configure session storage and revoke the corresponding session on sign-out.
Use short-lived Auth tokens and review the account recovery process before real
use. [Supabase Auth sessions](https://supabase.com/docs/guides/auth/sessions)

Current synchronization and document readiness is recorded in the
[implementation status](development/IMPLEMENTATION_STATUS.md).
