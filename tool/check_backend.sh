#!/usr/bin/env bash
# Exercise migrations in a new PostgreSQL cluster with a private Unix socket.
set -euo pipefail
cd -- "$(dirname -- "$0")/.."
mkdir -p .cache
scratch=$(mktemp -d "$PWD/.cache/pg-familyvault-XXXXXXXX")
chmod 700 "$scratch"
mkdir "$scratch/socket"
initdb -D "$scratch/data" -U postgres --auth=trust --encoding=UTF8 --no-locale > "$scratch/init.log"
cleanup() {
  pg_ctl -D "$scratch/data" -m fast -w stop > "$scratch/stop.log" 2>&1 || true
}
trap cleanup EXIT
pg_ctl -D "$scratch/data" -l "$scratch/server.log" \
  -o "-h '' -k '$scratch/socket' -p 15443 -c log_parameter_max_length_on_error=0" \
  -w start > "$scratch/start.log"
psql_args=(-X -v ON_ERROR_STOP=1 -h "$scratch/socket" -U postgres -p 15443 -d postgres)
psql "${psql_args[@]}" -f supabase/tests/auth_fixture.sql > "$scratch/setup.log"
for migration in supabase/migrations/*.sql; do
  psql "${psql_args[@]}" -f "$migration" >> "$scratch/setup.log"
done
psql "${psql_args[@]}" -f supabase/tests/storage_fixture.sql >> "$scratch/setup.log"
psql "${psql_args[@]}" -f supabase/storage/document_bucket.sql >> "$scratch/setup.log"
for probe in supabase/tests/*_test.sql; do
  psql "${psql_args[@]}" -f "$probe"
done
printf '%s\n' 'FamilyVault PostgreSQL migration and access tests passed with a local Auth adapter.'
