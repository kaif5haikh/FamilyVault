#!/usr/bin/env bash
# Validate design DDL on isolated, empty local databases only. Preserve scratch data.
set -euo pipefail
cd -- "$(dirname -- "$0")/.."
mkdir -p .cache/checks
python3 - <<'PY'
from pathlib import Path
import sqlite3
db = sqlite3.connect(':memory:')
db.executescript(Path('docs/design/sqlite.sql').read_text())
assert db.execute('PRAGMA foreign_keys').fetchone()[0] == 1
assert db.execute('PRAGMA user_version').fetchone()[0] == 1
assert db.execute('PRAGMA integrity_check').fetchone()[0] == 'ok'
tables = {r[0] for r in db.execute("SELECT name FROM sqlite_schema WHERE type='table'")}
assert tables == {'pending_mutations', 'sync_checkpoints', 'sync_conflicts'}, tables
try:
    db.execute("INSERT INTO sync_conflicts VALUES ('synthetic', 'absent', 1, '{}', 0, NULL)")
except sqlite3.IntegrityError:
    pass
else:
    raise AssertionError('Foreign key enforcement missing')
print('SQLite proposal: schema/integrity/foreign-key checks passed')
PY
scratch="$(mktemp -d "$PWD/.cache/pg-review-XXXXXXXX")"
chmod 700 "$scratch"
mkdir "$scratch/socket"
initdb -D "$scratch/data" -A trust --no-locale --encoding=UTF8 > "$scratch/init.log"
cleanup() {
  pg_ctl -D "$scratch/data" -m fast -w stop > "$scratch/stop.log" 2>&1 || true
}
trap cleanup EXIT
pg_ctl -D "$scratch/data" -l "$scratch/server.log" -o "-F -h '' -k '$scratch/socket' -p 15439" -w start > "$scratch/start.log"
psql_args=(-X -v ON_ERROR_STOP=1 -h "$scratch/socket" -p 15439 -d postgres)
psql "${psql_args[@]}" -f docs/design/postgresql.sql > "$scratch/schema.log"
psql "${psql_args[@]}" <<'SQL'
DO $$
DECLARE unsafe_count integer;
BEGIN
    SELECT count(*) INTO unsafe_count FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'familyvault_proposal' AND c.relkind = 'r'
      AND (NOT c.relrowsecurity OR NOT c.relforcerowsecurity);
    IF unsafe_count <> 0 THEN RAISE EXCEPTION 'Missing forced RLS'; END IF;
END;
$$;
CREATE ROLE proposal_reader NOLOGIN;
GRANT USAGE ON SCHEMA familyvault_proposal TO proposal_reader;
GRANT SELECT ON ALL TABLES IN SCHEMA familyvault_proposal TO proposal_reader;
-- Synthetic isolation probes, rolled back after verification.
BEGIN;
INSERT INTO familyvault_proposal.families VALUES
 ('00000000-0000-4000-8000-000000000001', 'synthetic isolation probe', 'INR', 1, now(), now(), NULL);
SET LOCAL ROLE proposal_reader;
DO $$
BEGIN
    IF EXISTS (SELECT FROM familyvault_proposal.families)
    THEN RAISE EXCEPTION 'Deny-all RLS leaked a row'; END IF;
END;
$$;
ROLLBACK;
SELECT count(*) AS proposal_table_count FROM pg_tables
 WHERE schemaname = 'familyvault_proposal';
SQL
python3 tool/check_design_constraints.py --pg-socket "$scratch/socket"
printf '%s\n' 'PostgreSQL proposal: DDL/forced-RLS/deny-all checks passed (not production policy validation)'
