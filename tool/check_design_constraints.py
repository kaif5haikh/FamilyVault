#!/usr/bin/env python3
"""Probe design DDL on isolated databases with synthetic metadata only.

This is not a financial implementation, RLS allow-policy test, encryption test,
provider integration or restore drill. No real documents, accounts or data load.
"""

import argparse
from dataclasses import dataclass
import hashlib
from pathlib import Path
import sqlite3
import subprocess


@dataclass(frozen=True)
class Time:
    seconds: int


@dataclass(frozen=True)
class Raw:
    sql: str


def uid(number):
    return f"00000000-0000-4000-8000-{number:012x}"


def literal(value, engine):
    if value is None:
        return "NULL"
    if isinstance(value, Raw):
        return value.sql
    if isinstance(value, Time):
        return f"'2026-01-01T00:00:{value.seconds:02d}Z'" if engine == "pg" else str(value.seconds * 1000000)
    if isinstance(value, bytes):
        return f"decode('{value.hex()}', 'hex')" if engine == "pg" else f"X'{value.hex()}'"
    if isinstance(value, bool):
        return ("TRUE" if value else "FALSE") if engine == "pg" else str(int(value))
    if isinstance(value, int):
        return str(value)
    if not isinstance(value, str):
        raise TypeError("Unsupported fixture type; no floating point")
    return "'" + value.replace("'", "''") + "'"


def insert(table, values, engine):
    return f"INSERT INTO {table} ({', '.join(values)}) VALUES ({', '.join(literal(v, engine) for v in values.values())});"


def update(table, values, key, engine):
    return f"UPDATE {table} SET " + ", ".join(f"{k} = {literal(v, engine)}" for k, v in values.items()) + f" WHERE {key};"


def probes(engine):
    f1, f2, admin, member, outsider, device = uid(1), uid(2), uid(11), uid(12), uid(21), uid(31)
    digest = hashlib.sha256(b"synthetic archive ciphertext").digest()
    other_digest = hashlib.sha256(b"different synthetic bytes").digest()
    meta = dict(revision=1, created_by=admin, updated_by=admin, created_at=Time(0), updated_at=Time(0))
    rows = []

    def row(table, **values):
        rows.append(insert(table, values, engine))

    for fid in [f1, f2]:
        row("families", id=fid, display_name="synthetic isolation probe", revision=1, created_at=Time(0), updated_at=Time(0))
    for user, family, role in [(uid(11), f1, "administrator"), (uid(12), f1, "member"), (uid(13), f1, "member"), (uid(14), f1, "member"), (outsider, f2, "administrator")]:
        row("family_members", id=uid(1000 + int(user[-12:], 16)), family_id=family, user_id=user, role=role, active=True, revision=1, created_at=Time(0), updated_at=Time(0))
    for dev, user, family, approver in [(device, admin, f1, admin), (uid(32), member, f1, admin), (uid(41), outsider, f2, outsider)]:
        row("devices", id=dev, family_id=family, user_id=user, public_key_envelope=b"synthetic public bundle", enrollment_state="enrolled", approved_by=approver, approved_at=Time(1), created_at=Time(0))
    row("devices", id=uid(35), family_id=f1, user_id=uid(13), created_at=Time(0))
    if engine == "pg":
        row("device_sessions", family_id=f1, session_id=uid(301), user_id=admin, device_id=device, created_at=Time(1), expires_at=Time(9))
    row("accounts", id=uid(51), family_id=f1, name="synthetic account", kind="bank", **meta)
    other_meta = dict(meta, created_by=outsider, updated_by=outsider)
    row("accounts", id=uid(52), family_id=f2, name="synthetic isolation account", kind="cash", **other_meta)
    row("journal_entries", id=uid(61), family_id=f1, accounting_date="2026-01-01", status="draft", **meta)
    row("journal_postings", id=uid(71), family_id=f1, journal_id=uid(61), account_id=uid(51), amount_minor=123456789)
    row("documents", id=uid(81), family_id=f1, owner_user_id=member, category="synthetic", metadata_ciphertext=b"synthetic metadata", **meta)
    version = dict(id=uid(91), family_id=f1, document_id=uid(81), version_number=1, object_path="synthetic-opaque-object", ciphertext_sha256=digest, ciphertext_size=7, envelope_version=1, created_by=admin, created_at=Time(0), finalized_at=Time(1))
    row("document_versions", **version)
    envelope = dict(family_id=f1, version_id=uid(91), recipient_device_id=device, wrapped_key=b"synthetic wrapped key", key_version=1)
    row("document_key_envelopes", **envelope)
    row("audit_events", id=uid(101), family_id=f1, actor_id=admin, device_id=device, operation_id=uid(121), action="synthetic_probe", entity_type="metadata", entity_id=uid(81), revision=1, occurred_at=Time(1))
    access = dict(id=uid(111), family_id=f1, version_id=uid(91), request_id=uid(181), actor_id=admin, device_id=device, event_kind="authorized", source="gateway", occurred_at=Time(1))
    row("document_access_events", **access)
    snapshot = dict(id=uid(201), family_id=f1, created_by=admin, creator_device_id=device, state="complete", archive_format_version=1, database_schema_version=1, server_watermark=0, authorization_epoch=0, includes_pending_operations=False, archive_sha256=digest, archive_size=7, manifest_sha256=other_digest, created_at=Time(0), archive_verified_at=Time(1))
    row("backup_snapshots", **snapshot)
    row("backup_snapshots", **dict(snapshot, id=uid(202), state="building", archive_sha256=None, archive_size=None, manifest_sha256=None, archive_verified_at=None))
    for target, family, kind, actor in [(uid(211), f1, "local", admin), (uid(212), f1, "google_drive", admin), (uid(221), f2, "local", outsider)]:
        row("backup_destinations", id=target, family_id=family, kind=kind, configured_by=actor, created_at=Time(0))
    attempt = dict(id=uid(231), family_id=f1, snapshot_id=uid(201), destination_id=uid(211), created_by=admin, writer_device_id=device, created_at=Time(2))
    row("backup_copy_attempts", **attempt)
    row("backup_copy_attempts", **dict(attempt, id=uid(232), destination_id=uid(212), state="failed"))
    cases = []

    def reject(name, table, changes, key="id = " + literal(uid(231), engine), state="23514"):
        cases.append((name, update(table, changes, key, engine), state, None))

    def key(number):
        return "id = " + literal(uid(number), engine)

    reject("INR scale is fixed at two", "currencies", {"minor_unit_scale": 3}, "code = 'INR'")
    reject("INR symbol is fixed", "currencies", {"display_symbol": "invalid"}, "code = 'INR'")
    reject("INR locale is fixed", "currencies", {"default_locale": "invalid"}, "code = 'INR'")
    reject("unknown currency FK", "accounts", {"currency": "ZZZ"}, key(51), "23503")
    reject("viewer role is outside scope", "family_members", {"role": "viewer"}, "user_id = " + literal(member, engine))
    reject("deleted member cannot remain active", "family_members", {"deleted_at": Time(2)}, "user_id = " + literal(member, engine))
    reject("future modifier must belong to family", "accounts", {"updated_by": outsider}, key(51), "23503")
    cases.append(("creator must belong to family", insert("accounts", dict(id=uid(53), family_id=f1, name="synthetic rejected creator", kind="bank", **dict(meta, created_by=outsider)), engine), "23503", None))
    reject("creator identity cannot be reassigned", "accounts", {"created_by": member}, key(51), "55000")
    reject("record family cannot be reassigned", "accounts", {"family_id": f2}, key(51), "55000")
    reject("modifier identity is required", "accounts", {"updated_by": None}, key(51), "23502")
    reject("cross-family account link", "journal_postings", {"account_id": uid(52)}, key(71), "23503")
    reject("money exceeds signed 64-bit", "journal_postings", {"amount_minor": Raw("9223372036854775808")}, key(71), "22003")
    reject("device approval required", "devices", {"enrollment_state": "enrolled"}, key(35))
    reject("device approver must belong to family", "devices", {"approved_by": outsider}, key(31), "23503")
    reject("revoked device requires revocation time", "devices", {"enrollment_state": "revoked"}, key(31))
    reject("document owner must belong to family", "documents", {"owner_user_id": outsider}, key(81), "23503")
    cases.append(("access actor must match device owner", insert("document_access_events", dict(access, id=uid(112), request_id=uid(182), actor_id=member), engine), "23503", None))
    cases.append(("cached view cannot masquerade as gateway event", insert("document_access_events", dict(access, id=uid(112), request_id=uid(182), event_kind="cached_open_reported"), engine), "23514", None))
    reject("invalid ciphertext digest length", "document_versions", {"ciphertext_sha256": b"short"}, key(91))
    reject("empty wrapped key", "document_key_envelopes", {"wrapped_key": b""}, "version_id = " + literal(uid(91), engine))
    for table, identity in [("audit_events", 101), ("document_access_events", 111)]:
        cases.append((f"{table} update is immutable", f"UPDATE {table} SET id = {literal(uid(999), engine)} WHERE {key(identity)};", "55000", None))
        cases.append((f"{table} delete is immutable", f"DELETE FROM {table} WHERE {key(identity)};", "55000", None))
    cases.append(("duplicate document version", insert("document_versions", dict(version, id=uid(92), object_path="different synthetic object"), engine), "23505", None))
    cases.append(("duplicate active key envelope", insert("document_key_envelopes", dict(envelope, key_version=2), engine), "23505", None))
    reject("complete archive requires manifest", "backup_snapshots", {"manifest_sha256": None}, key(201))
    reject("complete archive requires producer verification", "backup_snapshots", {"archive_verified_at": None}, key(201))
    reject("copy requires complete snapshot", "backup_copy_attempts", {"snapshot_id": uid(202)}, state="23503")
    reject("cross-family backup destination", "backup_copy_attempts", {"destination_id": uid(221)}, state="23503")
    reject("unknown backup destination kind", "backup_destinations", {"kind": "live_sync"}, key(211))
    reject("upload alone is not verified", "backup_copy_attempts", {"state": "verified", "provider_ack_at": Time(3)})
    reject("verification cannot precede provider acknowledgement", "backup_copy_attempts", {"verified_at": Time(4)})
    reject("queued copy cannot claim completion", "backup_copy_attempts", {"provider_ack_at": Time(3), "verified_at": Time(4), "completed_at": Time(5)})
    reject("observed digest must match snapshot", "backup_copy_attempts", {"observed_sha256": other_digest, "observed_size": 7}, state="23503")
    reject("observed length must match snapshot", "backup_copy_attempts", {"observed_sha256": digest, "observed_size": 8}, state="23503")
    cases.append(("copy actor must match device", insert("backup_copy_attempts", dict(attempt, id=uid(233), created_by=member), engine), "23503", None))
    verified = dict(state="verified", observed_sha256=digest, observed_size=7, receipt_ciphertext=b"synthetic receipt", provider_ack_at=Time(3), verified_at=Time(4), completed_at=Time(5))
    for field in ["provider_ack_at", "verified_at", "completed_at", "receipt_ciphertext"]:
        reject(f"verified copy requires {field}", "backup_copy_attempts", dict(verified, **{field: None}))
    cases.append(("shared edit preserves creator with distinct modifier", update("accounts", {"updated_by": member, "updated_at": Time(2)}, key(51), engine), None, f"(SELECT created_by = {literal(admin, engine)} AND updated_by = {literal(member, engine)} FROM accounts WHERE {key(51)})"))
    cases.append(("document ownership differs from uploader", "", None, f"(SELECT owner_user_id <> created_by FROM documents WHERE {key(81)})"))
    cases.append(("financial tombstone retains the row", update("accounts", {"deleted_at": Time(2), "updated_at": Time(2), "updated_by": member}, key(51), engine), None, f"(SELECT deleted_at IS NOT NULL FROM accounts WHERE {key(51)})"))
    cases.append(("exact paise and default INR", "", None, f"(SELECT amount_minor = 123456789 AND currency = 'INR' FROM journal_postings WHERE {key(71)})"))
    cases.append(("INR Unicode symbol and metadata", "", None, "(SELECT display_symbol = '₹' AND length(display_symbol) = 1 AND minor_unit_scale = 2 AND default_locale = 'en_IN' FROM currencies WHERE code = 'INR')"))
    cases.append(("local verification cannot hide Drive failure", update("backup_copy_attempts", verified, key(231), engine), None, f"(SELECT state = 'verified' FROM backup_copy_attempts WHERE {key(231)}) AND (SELECT state = 'failed' FROM backup_copy_attempts WHERE {key(232)})"))
    if engine == "pg":
        reject("session user must match enrolled device", "device_sessions", {"user_id": member}, "session_id = " + literal(uid(301), engine), "23503")
        for table in ["audit_events", "document_access_events"]:
            cases.append((f"{table} truncate is immutable", f"TRUNCATE {table};", "55000", None))
    else:
        reject("REAL paise rejected by STRICT storage", "journal_postings", {"amount_minor": Raw("123.45")}, key(71), "22003")
        reject("malformed date rejected", "journal_entries", {"accounting_date": "2026-02-31"}, key(61))
    return rows, cases


def sqlite_checks():
    db = sqlite3.connect(":memory:")
    db.executescript(Path("docs/design/sqlite.sql").read_text())
    db.executescript(Path("docs/design/sqlite-next.sql").read_text())
    assert db.execute("PRAGMA user_version").fetchone()[0] == 1, "Design must not bump implemented v1"
    rows, cases = probes("sqlite")
    for sql in rows:
        db.execute(sql)
    db.commit()
    for name, sql, reject, condition in cases:
        db.execute("SAVEPOINT probe")
        try:
            for statement in sql.split(";"):
                if statement.strip():
                    db.execute(statement)
            if reject:
                raise AssertionError(f"SQLite accepted invalid design case: {name}")
            if condition:
                assert db.execute("SELECT " + condition).fetchone()[0] == 1, name
        except sqlite3.IntegrityError as error:
            if not reject:
                raise AssertionError(f"SQLite rejected valid design case: {name}") from None
            expected = {
                "23514": {275},  # SQLITE_CONSTRAINT_CHECK
                "23503": {787},  # SQLITE_CONSTRAINT_FOREIGNKEY
                "23502": {1299},  # SQLITE_CONSTRAINT_NOTNULL
                "23505": {2067, 1555},  # UNIQUE / PRIMARYKEY
                "22003": {3091},  # DATATYPE (some Python bindings report its name as unknown)
                "55000": {1811},  # TRIGGER
            }[reject]
            assert error.sqlite_errorcode in expected, f"Wrong SQLite rejection for {name}: {error.sqlite_errorcode}"
        finally:
            db.execute("ROLLBACK TO probe")
            db.execute("RELEASE probe")
    assert not db.execute("PRAGMA foreign_key_check").fetchall()
    assert db.execute("PRAGMA integrity_check").fetchone()[0] == "ok"
    assert not db.execute("SELECT 1 FROM sqlite_schema WHERE name = 'document_grants'").fetchone()
    assert not db.execute("SELECT 1 FROM sqlite_schema WHERE name IN ('device_sessions','operation_receipts','sync_clocks','change_events','upload_reservations')").fetchone()
    count = db.execute("SELECT count(*) FROM sqlite_schema WHERE type = 'table'").fetchone()[0]
    db.close()
    print(f"SQLite future proposal: {len(cases)} behavioral probes passed; {count} tables including unchanged v1")


def pg_checks(socket):
    root = Path.cwd().resolve()
    socket = socket.resolve()
    if not socket.is_relative_to(root / ".cache") or not socket.parent.name.startswith("pg-review-") or not (socket.parent / "data/PG_VERSION").is_file():
        raise ValueError("PostgreSQL checks require this project's isolated scratch cluster")
    rows, cases = probes("pg")
    blocks = ["BEGIN; SET LOCAL search_path = familyvault_proposal, pg_catalog;", *rows]
    for index, (name, sql, state, condition) in enumerate(cases):
        blocks.append("SAVEPOINT probe;")
        if state:
            blocks.append(f"DO $probe$ BEGIN BEGIN {sql} EXCEPTION WHEN SQLSTATE '{state}' THEN RETURN; END; RAISE EXCEPTION 'Design probe {index} accepted invalid input'; END; $probe$;")
        else:
            blocks.append(sql)
            if condition:
                blocks.append(f"DO $probe$ BEGIN IF ({condition}) IS NOT TRUE THEN RAISE EXCEPTION 'Design probe {index} failed'; END IF; END; $probe$;")
        blocks.append("ROLLBACK TO probe; RELEASE probe;")
    blocks.append("ROLLBACK;")
    result = subprocess.run(["psql", "-X", "-q", "-v", "ON_ERROR_STOP=1", "-h", str(socket), "-p", "15439", "-d", "postgres"], input="\n".join(blocks), text=True, capture_output=True)
    if result.returncode:
        # Only synthetic fixtures are present, but keep payloads out of operation logs.
        (root / ".cache/checks/design-probe-error.txt").write_text(result.stderr)
        raise AssertionError("PostgreSQL design probe failed; inspect ignored .cache/checks/design-probe-error.txt")
    print(f"PostgreSQL proposal: {len(cases)} behavioral probes passed; synthetic transactions rolled back")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--pg-socket", type=Path)
    args = parser.parse_args()
    sqlite_checks()
    if args.pg_socket:
        pg_checks(args.pg_socket)
