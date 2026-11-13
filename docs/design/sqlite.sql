-- Phase 3 local metadata proposal, version 1. No financial tables or seed data.
-- Drift definitions in lib/core/database/app_database.dart are authoritative.
-- Production connections must use the encrypted native library and vault key.
PRAGMA foreign_keys = ON;
BEGIN;
CREATE TABLE pending_mutations (
    operation_id TEXT NOT NULL PRIMARY KEY,
    family_id TEXT NOT NULL,
    device_id TEXT NOT NULL,
    entity_type TEXT NOT NULL,
    entity_id TEXT NOT NULL,
    mutation_kind TEXT NOT NULL CHECK (mutation_kind IN ('upsert', 'delete')),
    base_revision INTEGER NOT NULL CHECK (base_revision >= 0),
    payload_json TEXT NOT NULL CHECK (json_valid(payload_json)),
    payload_digest TEXT NOT NULL CHECK (length(payload_digest) = 64),
    protocol_version INTEGER NOT NULL CHECK (protocol_version > 0),
    state TEXT NOT NULL DEFAULT 'pending'
        CHECK (state IN ('pending', 'in_flight', 'conflicted', 'rejected', 'acknowledged')),
    attempts INTEGER NOT NULL DEFAULT 0 CHECK (attempts >= 0),
    created_at_us INTEGER NOT NULL,
    next_attempt_at_us INTEGER,
    lease_expires_at_us INTEGER,
    accepted_revision INTEGER CHECK (accepted_revision IS NULL OR accepted_revision > 0),
    CHECK (state <> 'acknowledged' OR accepted_revision IS NOT NULL)
);
CREATE INDEX pending_mutations_retry ON pending_mutations(state, next_attempt_at_us);
CREATE TABLE sync_checkpoints (
    family_id TEXT NOT NULL PRIMARY KEY,
    last_sequence INTEGER NOT NULL DEFAULT 0 CHECK (last_sequence >= 0),
    authorization_epoch INTEGER NOT NULL DEFAULT 0 CHECK (authorization_epoch >= 0),
    updated_at_us INTEGER NOT NULL
);
CREATE TABLE sync_conflicts (
    id TEXT NOT NULL PRIMARY KEY,
    operation_id TEXT NOT NULL UNIQUE REFERENCES pending_mutations(operation_id),
    server_revision INTEGER NOT NULL CHECK (server_revision > 0),
    server_snapshot_json TEXT NOT NULL CHECK (json_valid(server_snapshot_json)),
    detected_at_us INTEGER NOT NULL,
    resolved_at_us INTEGER
);
PRAGMA user_version = 1;
COMMIT;
