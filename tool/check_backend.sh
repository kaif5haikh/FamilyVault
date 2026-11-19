#!/usr/bin/env bash
# Exercise migrations in a new PostgreSQL cluster with a private Unix socket.
set -euo pipefail
cd -- "$(dirname -- "$0")/.."
mkdir -p .cache
scratch=$(mktemp -d "$PWD/.cache/pg-familyvault-XXXXXXXX")
cleanup() {
  local status=$?
  if [[ -s "$scratch/data/postmaster.pid" ]] &&
    ! pg_ctl -D "$scratch/data" -m fast -w stop > "$scratch/stop.log" 2>&1; then
    printf 'Could not stop the test cluster at %s\n' "$scratch" >&2
    exit 1
  fi
  rm -r -- "$scratch" || exit 1
  exit "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
mkdir "$scratch/socket"
initdb -D "$scratch/data" -U postgres --auth=trust --encoding=UTF8 --no-locale > "$scratch/init.log"
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
