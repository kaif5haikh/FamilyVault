-- PROPOSAL ONLY: future authorized projections, not a Drift migration.
-- Apply only to a scratch DB after sqlite.sql. Existing implemented v1 is unchanged.
-- Server-only clocks/sessions/receipts/feed/reservations are not replicated.
-- INTEGER times are Unix microseconds; monetary INTEGER columns are minor units.
-- STRICT tables prevent REAL monetary storage. RPC input validation is still required.
PRAGMA foreign_keys = ON;
BEGIN;

CREATE TABLE currencies (
    code TEXT PRIMARY KEY CHECK (length(code) = 3 AND code GLOB '[A-Z][A-Z][A-Z]'),
    minor_unit_scale INTEGER NOT NULL CHECK (minor_unit_scale BETWEEN 0 AND 6),
    display_symbol TEXT NOT NULL,
    default_locale TEXT NOT NULL,
    CHECK (code <> 'INR' OR (minor_unit_scale = 2 AND display_symbol = '₹' AND default_locale = 'en_IN'))
) STRICT;

CREATE TABLE families (
    id TEXT CHECK (length(id) = 36 AND substr(id, 9, 1) = '-' AND substr(id, 14, 1) = '-' AND substr(id, 19, 1) = '-' AND substr(id, 24, 1) = '-' AND length(replace(id, '-', '')) = 32 AND replace(id, '-', '') NOT GLOB '*[^0-9a-f]*') PRIMARY KEY,
    display_name TEXT NOT NULL,
    default_currency TEXT NOT NULL DEFAULT 'INR' REFERENCES currencies(code),
    revision INTEGER NOT NULL CHECK (revision > 0),
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    deleted_at INTEGER,
    CHECK (updated_at >= created_at),
    CHECK (deleted_at IS NULL OR deleted_at >= created_at)
) STRICT;

CREATE TABLE family_members (
    id TEXT CHECK (length(id) = 36 AND substr(id, 9, 1) = '-' AND substr(id, 14, 1) = '-' AND substr(id, 19, 1) = '-' AND substr(id, 24, 1) = '-' AND length(replace(id, '-', '')) = 32 AND replace(id, '-', '') NOT GLOB '*[^0-9a-f]*') PRIMARY KEY,
    family_id TEXT CHECK (length(family_id) = 36 AND substr(family_id, 9, 1) = '-' AND substr(family_id, 14, 1) = '-' AND substr(family_id, 19, 1) = '-' AND substr(family_id, 24, 1) = '-' AND length(replace(family_id, '-', '')) = 32 AND replace(family_id, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL REFERENCES families(id),
    user_id TEXT CHECK (length(user_id) = 36 AND substr(user_id, 9, 1) = '-' AND substr(user_id, 14, 1) = '-' AND substr(user_id, 19, 1) = '-' AND substr(user_id, 24, 1) = '-' AND length(replace(user_id, '-', '')) = 32 AND replace(user_id, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    role TEXT NOT NULL CHECK (role IN ('administrator', 'member')),
    active INTEGER CHECK (active IN (0, 1)) NOT NULL DEFAULT 0,
    revision INTEGER NOT NULL CHECK (revision > 0),
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    deleted_at INTEGER,
    UNIQUE (family_id, id),
    UNIQUE (family_id, user_id),
    CHECK (updated_at >= created_at),
    CHECK (deleted_at IS NULL OR deleted_at >= created_at),
    CHECK (deleted_at IS NULL OR NOT active)
) STRICT;

CREATE TABLE devices (
    id TEXT CHECK (length(id) = 36 AND substr(id, 9, 1) = '-' AND substr(id, 14, 1) = '-' AND substr(id, 19, 1) = '-' AND substr(id, 24, 1) = '-' AND length(replace(id, '-', '')) = 32 AND replace(id, '-', '') NOT GLOB '*[^0-9a-f]*') PRIMARY KEY,
    family_id TEXT CHECK (length(family_id) = 36 AND substr(family_id, 9, 1) = '-' AND substr(family_id, 14, 1) = '-' AND substr(family_id, 19, 1) = '-' AND substr(family_id, 24, 1) = '-' AND length(replace(family_id, '-', '')) = 32 AND replace(family_id, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL REFERENCES families(id),
    user_id TEXT CHECK (length(user_id) = 36 AND substr(user_id, 9, 1) = '-' AND substr(user_id, 14, 1) = '-' AND substr(user_id, 19, 1) = '-' AND substr(user_id, 24, 1) = '-' AND length(replace(user_id, '-', '')) = 32 AND replace(user_id, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    public_key_envelope BLOB,
    enrollment_state TEXT NOT NULL DEFAULT 'pending'
        CHECK (enrollment_state IN ('pending', 'enrolled', 'revoked')),
    approved_by TEXT CHECK (length(approved_by) = 36 AND substr(approved_by, 9, 1) = '-' AND substr(approved_by, 14, 1) = '-' AND substr(approved_by, 19, 1) = '-' AND substr(approved_by, 24, 1) = '-' AND length(replace(approved_by, '-', '')) = 32 AND replace(approved_by, '-', '') NOT GLOB '*[^0-9a-f]*'),
    approved_at INTEGER,
    revoked_at INTEGER,
    created_at INTEGER NOT NULL,
    UNIQUE (family_id, id),
    UNIQUE (family_id, id, user_id),
    FOREIGN KEY (family_id, approved_by) REFERENCES family_members(family_id, user_id),
    CHECK ((approved_by IS NULL) = (approved_at IS NULL)),
    CHECK (approved_at IS NULL OR approved_at >= created_at),
    CHECK (revoked_at IS NULL OR revoked_at >= created_at),
    CHECK (
        (enrollment_state = 'pending' AND approved_at IS NULL AND revoked_at IS NULL)
        OR (enrollment_state = 'enrolled' AND approved_at IS NOT NULL
            AND public_key_envelope IS NOT NULL AND length(public_key_envelope) > 0 AND revoked_at IS NULL)
        OR (enrollment_state = 'revoked' AND revoked_at IS NOT NULL)
    ),
    FOREIGN KEY (family_id, user_id) REFERENCES family_members(family_id, user_id)
) STRICT;

CREATE TABLE audit_events (
    id TEXT CHECK (length(id) = 36 AND substr(id, 9, 1) = '-' AND substr(id, 14, 1) = '-' AND substr(id, 19, 1) = '-' AND substr(id, 24, 1) = '-' AND length(replace(id, '-', '')) = 32 AND replace(id, '-', '') NOT GLOB '*[^0-9a-f]*') PRIMARY KEY,
    family_id TEXT CHECK (length(family_id) = 36 AND substr(family_id, 9, 1) = '-' AND substr(family_id, 14, 1) = '-' AND substr(family_id, 19, 1) = '-' AND substr(family_id, 24, 1) = '-' AND length(replace(family_id, '-', '')) = 32 AND replace(family_id, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL REFERENCES families(id),
    actor_id TEXT CHECK (length(actor_id) = 36 AND substr(actor_id, 9, 1) = '-' AND substr(actor_id, 14, 1) = '-' AND substr(actor_id, 19, 1) = '-' AND substr(actor_id, 24, 1) = '-' AND length(replace(actor_id, '-', '')) = 32 AND replace(actor_id, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    device_id TEXT CHECK (length(device_id) = 36 AND substr(device_id, 9, 1) = '-' AND substr(device_id, 14, 1) = '-' AND substr(device_id, 19, 1) = '-' AND substr(device_id, 24, 1) = '-' AND length(replace(device_id, '-', '')) = 32 AND replace(device_id, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    operation_id TEXT CHECK (length(operation_id) = 36 AND substr(operation_id, 9, 1) = '-' AND substr(operation_id, 14, 1) = '-' AND substr(operation_id, 19, 1) = '-' AND substr(operation_id, 24, 1) = '-' AND length(replace(operation_id, '-', '')) = 32 AND replace(operation_id, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    action TEXT NOT NULL,
    entity_type TEXT NOT NULL,
    entity_id TEXT CHECK (length(entity_id) = 36 AND substr(entity_id, 9, 1) = '-' AND substr(entity_id, 14, 1) = '-' AND substr(entity_id, 19, 1) = '-' AND substr(entity_id, 24, 1) = '-' AND length(replace(entity_id, '-', '')) = 32 AND replace(entity_id, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    revision INTEGER NOT NULL CHECK (revision > 0),
    occurred_at INTEGER NOT NULL,
    FOREIGN KEY (family_id, device_id, actor_id) REFERENCES devices(family_id, id, user_id)
) STRICT;

CREATE TABLE businesses (
    id TEXT CHECK (length(id) = 36 AND substr(id, 9, 1) = '-' AND substr(id, 14, 1) = '-' AND substr(id, 19, 1) = '-' AND substr(id, 24, 1) = '-' AND length(replace(id, '-', '')) = 32 AND replace(id, '-', '') NOT GLOB '*[^0-9a-f]*') PRIMARY KEY,
    family_id TEXT CHECK (length(family_id) = 36 AND substr(family_id, 9, 1) = '-' AND substr(family_id, 14, 1) = '-' AND substr(family_id, 19, 1) = '-' AND substr(family_id, 24, 1) = '-' AND length(replace(family_id, '-', '')) = 32 AND replace(family_id, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL REFERENCES families(id),
    name TEXT NOT NULL,
    revision INTEGER NOT NULL CHECK (revision > 0),
    created_by TEXT CHECK (length(created_by) = 36 AND substr(created_by, 9, 1) = '-' AND substr(created_by, 14, 1) = '-' AND substr(created_by, 19, 1) = '-' AND substr(created_by, 24, 1) = '-' AND length(replace(created_by, '-', '')) = 32 AND replace(created_by, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    updated_by TEXT CHECK (length(updated_by) = 36 AND substr(updated_by, 9, 1) = '-' AND substr(updated_by, 14, 1) = '-' AND substr(updated_by, 19, 1) = '-' AND substr(updated_by, 24, 1) = '-' AND length(replace(updated_by, '-', '')) = 32 AND replace(updated_by, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    deleted_at INTEGER,
    UNIQUE (family_id, id),
    FOREIGN KEY (family_id, created_by) REFERENCES family_members(family_id, user_id),
    FOREIGN KEY (family_id, updated_by) REFERENCES family_members(family_id, user_id),
    CHECK (updated_at >= created_at),
    CHECK (deleted_at IS NULL OR deleted_at >= created_at)
) STRICT;

CREATE TABLE business_grants (
    family_id TEXT CHECK (length(family_id) = 36 AND substr(family_id, 9, 1) = '-' AND substr(family_id, 14, 1) = '-' AND substr(family_id, 19, 1) = '-' AND substr(family_id, 24, 1) = '-' AND length(replace(family_id, '-', '')) = 32 AND replace(family_id, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    business_id TEXT CHECK (length(business_id) = 36 AND substr(business_id, 9, 1) = '-' AND substr(business_id, 14, 1) = '-' AND substr(business_id, 19, 1) = '-' AND substr(business_id, 24, 1) = '-' AND length(replace(business_id, '-', '')) = 32 AND replace(business_id, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    user_id TEXT CHECK (length(user_id) = 36 AND substr(user_id, 9, 1) = '-' AND substr(user_id, 14, 1) = '-' AND substr(user_id, 19, 1) = '-' AND substr(user_id, 24, 1) = '-' AND length(replace(user_id, '-', '')) = 32 AND replace(user_id, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    permission TEXT NOT NULL CHECK (permission IN ('read', 'write', 'manage')),
    revoked_at INTEGER,
    PRIMARY KEY (family_id, business_id, user_id),
    FOREIGN KEY (family_id, business_id) REFERENCES businesses(family_id, id),
    FOREIGN KEY (family_id, user_id) REFERENCES family_members(family_id, user_id)
) STRICT;

CREATE TABLE accounts (
    id TEXT CHECK (length(id) = 36 AND substr(id, 9, 1) = '-' AND substr(id, 14, 1) = '-' AND substr(id, 19, 1) = '-' AND substr(id, 24, 1) = '-' AND length(replace(id, '-', '')) = 32 AND replace(id, '-', '') NOT GLOB '*[^0-9a-f]*') PRIMARY KEY,
    family_id TEXT CHECK (length(family_id) = 36 AND substr(family_id, 9, 1) = '-' AND substr(family_id, 14, 1) = '-' AND substr(family_id, 19, 1) = '-' AND substr(family_id, 24, 1) = '-' AND length(replace(family_id, '-', '')) = 32 AND replace(family_id, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL REFERENCES families(id),
    business_id TEXT CHECK (length(business_id) = 36 AND substr(business_id, 9, 1) = '-' AND substr(business_id, 14, 1) = '-' AND substr(business_id, 19, 1) = '-' AND substr(business_id, 24, 1) = '-' AND length(replace(business_id, '-', '')) = 32 AND replace(business_id, '-', '') NOT GLOB '*[^0-9a-f]*'),
    name TEXT NOT NULL,
    kind TEXT NOT NULL CHECK (kind IN ('bank', 'cash', 'asset', 'income', 'expense', 'liability', 'equity')),
    currency TEXT NOT NULL DEFAULT 'INR' REFERENCES currencies(code),
    revision INTEGER NOT NULL CHECK (revision > 0),
    created_by TEXT CHECK (length(created_by) = 36 AND substr(created_by, 9, 1) = '-' AND substr(created_by, 14, 1) = '-' AND substr(created_by, 19, 1) = '-' AND substr(created_by, 24, 1) = '-' AND length(replace(created_by, '-', '')) = 32 AND replace(created_by, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    updated_by TEXT CHECK (length(updated_by) = 36 AND substr(updated_by, 9, 1) = '-' AND substr(updated_by, 14, 1) = '-' AND substr(updated_by, 19, 1) = '-' AND substr(updated_by, 24, 1) = '-' AND length(replace(updated_by, '-', '')) = 32 AND replace(updated_by, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    deleted_at INTEGER,
    UNIQUE (family_id, id),
    FOREIGN KEY (family_id, business_id) REFERENCES businesses(family_id, id),
    FOREIGN KEY (family_id, created_by) REFERENCES family_members(family_id, user_id),
    FOREIGN KEY (family_id, updated_by) REFERENCES family_members(family_id, user_id),
    CHECK (updated_at >= created_at),
    CHECK (deleted_at IS NULL OR deleted_at >= created_at)
) STRICT;

CREATE TABLE journal_entries (
    id TEXT CHECK (length(id) = 36 AND substr(id, 9, 1) = '-' AND substr(id, 14, 1) = '-' AND substr(id, 19, 1) = '-' AND substr(id, 24, 1) = '-' AND length(replace(id, '-', '')) = 32 AND replace(id, '-', '') NOT GLOB '*[^0-9a-f]*') PRIMARY KEY,
    family_id TEXT CHECK (length(family_id) = 36 AND substr(family_id, 9, 1) = '-' AND substr(family_id, 14, 1) = '-' AND substr(family_id, 19, 1) = '-' AND substr(family_id, 24, 1) = '-' AND length(replace(family_id, '-', '')) = 32 AND replace(family_id, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL REFERENCES families(id),
    business_id TEXT CHECK (length(business_id) = 36 AND substr(business_id, 9, 1) = '-' AND substr(business_id, 14, 1) = '-' AND substr(business_id, 19, 1) = '-' AND substr(business_id, 24, 1) = '-' AND length(replace(business_id, '-', '')) = 32 AND replace(business_id, '-', '') NOT GLOB '*[^0-9a-f]*'),
    accounting_date TEXT CHECK (accounting_date IS NULL OR (length(accounting_date) = 10 AND date(accounting_date) IS NOT NULL AND date(accounting_date) = accounting_date)) NOT NULL,
    status TEXT NOT NULL CHECK (status IN ('draft', 'posted')),
    reversal_of TEXT CHECK (length(reversal_of) = 36 AND substr(reversal_of, 9, 1) = '-' AND substr(reversal_of, 14, 1) = '-' AND substr(reversal_of, 19, 1) = '-' AND substr(reversal_of, 24, 1) = '-' AND length(replace(reversal_of, '-', '')) = 32 AND replace(reversal_of, '-', '') NOT GLOB '*[^0-9a-f]*'),
    description_ciphertext BLOB,
    revision INTEGER NOT NULL CHECK (revision > 0),
    created_by TEXT CHECK (length(created_by) = 36 AND substr(created_by, 9, 1) = '-' AND substr(created_by, 14, 1) = '-' AND substr(created_by, 19, 1) = '-' AND substr(created_by, 24, 1) = '-' AND length(replace(created_by, '-', '')) = 32 AND replace(created_by, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    updated_by TEXT CHECK (length(updated_by) = 36 AND substr(updated_by, 9, 1) = '-' AND substr(updated_by, 14, 1) = '-' AND substr(updated_by, 19, 1) = '-' AND substr(updated_by, 24, 1) = '-' AND length(replace(updated_by, '-', '')) = 32 AND replace(updated_by, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    deleted_at INTEGER,
    UNIQUE (family_id, id),
    FOREIGN KEY (family_id, business_id) REFERENCES businesses(family_id, id),
    FOREIGN KEY (family_id, reversal_of) REFERENCES journal_entries(family_id, id),
    FOREIGN KEY (family_id, created_by) REFERENCES family_members(family_id, user_id),
    FOREIGN KEY (family_id, updated_by) REFERENCES family_members(family_id, user_id),
    CHECK (updated_at >= created_at),
    CHECK (deleted_at IS NULL OR deleted_at >= created_at)
) STRICT;

CREATE TABLE journal_postings (
    id TEXT CHECK (length(id) = 36 AND substr(id, 9, 1) = '-' AND substr(id, 14, 1) = '-' AND substr(id, 19, 1) = '-' AND substr(id, 24, 1) = '-' AND length(replace(id, '-', '')) = 32 AND replace(id, '-', '') NOT GLOB '*[^0-9a-f]*') PRIMARY KEY,
    family_id TEXT CHECK (length(family_id) = 36 AND substr(family_id, 9, 1) = '-' AND substr(family_id, 14, 1) = '-' AND substr(family_id, 19, 1) = '-' AND substr(family_id, 24, 1) = '-' AND length(replace(family_id, '-', '')) = 32 AND replace(family_id, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    journal_id TEXT CHECK (length(journal_id) = 36 AND substr(journal_id, 9, 1) = '-' AND substr(journal_id, 14, 1) = '-' AND substr(journal_id, 19, 1) = '-' AND substr(journal_id, 24, 1) = '-' AND length(replace(journal_id, '-', '')) = 32 AND replace(journal_id, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    account_id TEXT CHECK (length(account_id) = 36 AND substr(account_id, 9, 1) = '-' AND substr(account_id, 14, 1) = '-' AND substr(account_id, 19, 1) = '-' AND substr(account_id, 24, 1) = '-' AND length(replace(account_id, '-', '')) = 32 AND replace(account_id, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    currency TEXT NOT NULL DEFAULT 'INR' REFERENCES currencies(code),
    amount_minor INTEGER NOT NULL CHECK (amount_minor <> 0),
    UNIQUE (family_id, id),
    FOREIGN KEY (family_id, journal_id) REFERENCES journal_entries(family_id, id),
    FOREIGN KEY (family_id, account_id) REFERENCES accounts(family_id, id)
) STRICT;

CREATE TABLE monthly_budgets (
    id TEXT CHECK (length(id) = 36 AND substr(id, 9, 1) = '-' AND substr(id, 14, 1) = '-' AND substr(id, 19, 1) = '-' AND substr(id, 24, 1) = '-' AND length(replace(id, '-', '')) = 32 AND replace(id, '-', '') NOT GLOB '*[^0-9a-f]*') PRIMARY KEY,
    family_id TEXT CHECK (length(family_id) = 36 AND substr(family_id, 9, 1) = '-' AND substr(family_id, 14, 1) = '-' AND substr(family_id, 19, 1) = '-' AND substr(family_id, 24, 1) = '-' AND length(replace(family_id, '-', '')) = 32 AND replace(family_id, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    account_id TEXT CHECK (length(account_id) = 36 AND substr(account_id, 9, 1) = '-' AND substr(account_id, 14, 1) = '-' AND substr(account_id, 19, 1) = '-' AND substr(account_id, 24, 1) = '-' AND length(replace(account_id, '-', '')) = 32 AND replace(account_id, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    month_start TEXT CHECK (month_start IS NULL OR (length(month_start) = 10 AND date(month_start) IS NOT NULL AND date(month_start) = month_start)) NOT NULL CHECK (substr(month_start, 9, 2) = '01'),
    currency TEXT NOT NULL DEFAULT 'INR' REFERENCES currencies(code),
    amount_minor INTEGER NOT NULL CHECK (amount_minor >= 0),
    revision INTEGER NOT NULL CHECK (revision > 0),
    created_by TEXT CHECK (length(created_by) = 36 AND substr(created_by, 9, 1) = '-' AND substr(created_by, 14, 1) = '-' AND substr(created_by, 19, 1) = '-' AND substr(created_by, 24, 1) = '-' AND length(replace(created_by, '-', '')) = 32 AND replace(created_by, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    updated_by TEXT CHECK (length(updated_by) = 36 AND substr(updated_by, 9, 1) = '-' AND substr(updated_by, 14, 1) = '-' AND substr(updated_by, 19, 1) = '-' AND substr(updated_by, 24, 1) = '-' AND length(replace(updated_by, '-', '')) = 32 AND replace(updated_by, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    deleted_at INTEGER,
    UNIQUE (family_id, id),
    FOREIGN KEY (family_id, account_id) REFERENCES accounts(family_id, id),
    FOREIGN KEY (family_id, created_by) REFERENCES family_members(family_id, user_id),
    FOREIGN KEY (family_id, updated_by) REFERENCES family_members(family_id, user_id),
    CHECK (updated_at >= created_at),
    CHECK (deleted_at IS NULL OR deleted_at >= created_at)
) STRICT;

CREATE TABLE savings_observations (
    id TEXT CHECK (length(id) = 36 AND substr(id, 9, 1) = '-' AND substr(id, 14, 1) = '-' AND substr(id, 19, 1) = '-' AND substr(id, 24, 1) = '-' AND length(replace(id, '-', '')) = 32 AND replace(id, '-', '') NOT GLOB '*[^0-9a-f]*') PRIMARY KEY,
    family_id TEXT CHECK (length(family_id) = 36 AND substr(family_id, 9, 1) = '-' AND substr(family_id, 14, 1) = '-' AND substr(family_id, 19, 1) = '-' AND substr(family_id, 24, 1) = '-' AND length(replace(family_id, '-', '')) = 32 AND replace(family_id, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL REFERENCES families(id),
    observed_on TEXT CHECK (observed_on IS NULL OR (length(observed_on) = 10 AND date(observed_on) IS NOT NULL AND date(observed_on) = observed_on)) NOT NULL,
    currency TEXT NOT NULL DEFAULT 'INR' REFERENCES currencies(code),
    amount_minor INTEGER NOT NULL,
    source_ciphertext BLOB,
    revision INTEGER NOT NULL CHECK (revision > 0),
    created_by TEXT CHECK (length(created_by) = 36 AND substr(created_by, 9, 1) = '-' AND substr(created_by, 14, 1) = '-' AND substr(created_by, 19, 1) = '-' AND substr(created_by, 24, 1) = '-' AND length(replace(created_by, '-', '')) = 32 AND replace(created_by, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    updated_by TEXT CHECK (length(updated_by) = 36 AND substr(updated_by, 9, 1) = '-' AND substr(updated_by, 14, 1) = '-' AND substr(updated_by, 19, 1) = '-' AND substr(updated_by, 24, 1) = '-' AND length(replace(updated_by, '-', '')) = 32 AND replace(updated_by, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    deleted_at INTEGER,
    UNIQUE (family_id, id),
    FOREIGN KEY (family_id, created_by) REFERENCES family_members(family_id, user_id),
    FOREIGN KEY (family_id, updated_by) REFERENCES family_members(family_id, user_id),
    CHECK (updated_at >= created_at),
    CHECK (deleted_at IS NULL OR deleted_at >= created_at)
) STRICT;

CREATE TABLE assets (
    id TEXT CHECK (length(id) = 36 AND substr(id, 9, 1) = '-' AND substr(id, 14, 1) = '-' AND substr(id, 19, 1) = '-' AND substr(id, 24, 1) = '-' AND length(replace(id, '-', '')) = 32 AND replace(id, '-', '') NOT GLOB '*[^0-9a-f]*') PRIMARY KEY,
    family_id TEXT CHECK (length(family_id) = 36 AND substr(family_id, 9, 1) = '-' AND substr(family_id, 14, 1) = '-' AND substr(family_id, 19, 1) = '-' AND substr(family_id, 24, 1) = '-' AND length(replace(family_id, '-', '')) = 32 AND replace(family_id, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL REFERENCES families(id),
    kind TEXT NOT NULL CHECK (kind IN ('gold', 'silver', 'property', 'land', 'vehicle', 'investment', 'other')),
    label_ciphertext BLOB NOT NULL,
    acquired_on TEXT CHECK (acquired_on IS NULL OR (length(acquired_on) = 10 AND date(acquired_on) IS NOT NULL AND date(acquired_on) = acquired_on)),
    purchase_amount_minor INTEGER CHECK (purchase_amount_minor >= 0),
    purchase_currency TEXT REFERENCES currencies(code),
    revision INTEGER NOT NULL CHECK (revision > 0),
    created_by TEXT CHECK (length(created_by) = 36 AND substr(created_by, 9, 1) = '-' AND substr(created_by, 14, 1) = '-' AND substr(created_by, 19, 1) = '-' AND substr(created_by, 24, 1) = '-' AND length(replace(created_by, '-', '')) = 32 AND replace(created_by, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    updated_by TEXT CHECK (length(updated_by) = 36 AND substr(updated_by, 9, 1) = '-' AND substr(updated_by, 14, 1) = '-' AND substr(updated_by, 19, 1) = '-' AND substr(updated_by, 24, 1) = '-' AND length(replace(updated_by, '-', '')) = 32 AND replace(updated_by, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    deleted_at INTEGER,
    UNIQUE (family_id, id),
    CHECK ((purchase_amount_minor IS NULL) = (purchase_currency IS NULL)),
    FOREIGN KEY (family_id, created_by) REFERENCES family_members(family_id, user_id),
    FOREIGN KEY (family_id, updated_by) REFERENCES family_members(family_id, user_id),
    CHECK (updated_at >= created_at),
    CHECK (deleted_at IS NULL OR deleted_at >= created_at)
) STRICT;

CREATE TABLE metal_details (
    family_id TEXT CHECK (length(family_id) = 36 AND substr(family_id, 9, 1) = '-' AND substr(family_id, 14, 1) = '-' AND substr(family_id, 19, 1) = '-' AND substr(family_id, 24, 1) = '-' AND length(replace(family_id, '-', '')) = 32 AND replace(family_id, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    asset_id TEXT CHECK (length(asset_id) = 36 AND substr(asset_id, 9, 1) = '-' AND substr(asset_id, 14, 1) = '-' AND substr(asset_id, 19, 1) = '-' AND substr(asset_id, 24, 1) = '-' AND length(replace(asset_id, '-', '')) = 32 AND replace(asset_id, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    weight_mg INTEGER NOT NULL CHECK (weight_mg > 0),
    purity_ppm INTEGER NOT NULL CHECK (purity_ppm BETWEEN 1 AND 1000000),
    making_charges_minor INTEGER CHECK (making_charges_minor >= 0),
    currency TEXT REFERENCES currencies(code),
    PRIMARY KEY (family_id, asset_id),
    FOREIGN KEY (family_id, asset_id) REFERENCES assets(family_id, id),
    CHECK ((making_charges_minor IS NULL) = (currency IS NULL))
) STRICT;

CREATE TABLE property_details (
    family_id TEXT CHECK (length(family_id) = 36 AND substr(family_id, 9, 1) = '-' AND substr(family_id, 14, 1) = '-' AND substr(family_id, 19, 1) = '-' AND substr(family_id, 24, 1) = '-' AND length(replace(family_id, '-', '')) = 32 AND replace(family_id, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    asset_id TEXT CHECK (length(asset_id) = 36 AND substr(asset_id, 9, 1) = '-' AND substr(asset_id, 14, 1) = '-' AND substr(asset_id, 19, 1) = '-' AND substr(asset_id, 24, 1) = '-' AND length(replace(asset_id, '-', '')) = 32 AND replace(asset_id, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    location_ciphertext BLOB NOT NULL,
    record_reference_ciphertext BLOB,
    PRIMARY KEY (family_id, asset_id),
    FOREIGN KEY (family_id, asset_id) REFERENCES assets(family_id, id)
) STRICT;

CREATE TABLE investment_details (
    family_id TEXT CHECK (length(family_id) = 36 AND substr(family_id, 9, 1) = '-' AND substr(family_id, 14, 1) = '-' AND substr(family_id, 19, 1) = '-' AND substr(family_id, 24, 1) = '-' AND length(replace(family_id, '-', '')) = 32 AND replace(family_id, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    asset_id TEXT CHECK (length(asset_id) = 36 AND substr(asset_id, 9, 1) = '-' AND substr(asset_id, 14, 1) = '-' AND substr(asset_id, 19, 1) = '-' AND substr(asset_id, 24, 1) = '-' AND length(replace(asset_id, '-', '')) = 32 AND replace(asset_id, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    instrument_ciphertext BLOB NOT NULL,
    quantity_scaled INTEGER NOT NULL CHECK (quantity_scaled > 0),
    quantity_scale INTEGER NOT NULL CHECK (quantity_scale BETWEEN 0 AND 9),
    PRIMARY KEY (family_id, asset_id),
    FOREIGN KEY (family_id, asset_id) REFERENCES assets(family_id, id)
) STRICT;

CREATE TABLE asset_ownerships (
    id TEXT CHECK (length(id) = 36 AND substr(id, 9, 1) = '-' AND substr(id, 14, 1) = '-' AND substr(id, 19, 1) = '-' AND substr(id, 24, 1) = '-' AND length(replace(id, '-', '')) = 32 AND replace(id, '-', '') NOT GLOB '*[^0-9a-f]*') PRIMARY KEY,
    family_id TEXT CHECK (length(family_id) = 36 AND substr(family_id, 9, 1) = '-' AND substr(family_id, 14, 1) = '-' AND substr(family_id, 19, 1) = '-' AND substr(family_id, 24, 1) = '-' AND length(replace(family_id, '-', '')) = 32 AND replace(family_id, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    asset_id TEXT CHECK (length(asset_id) = 36 AND substr(asset_id, 9, 1) = '-' AND substr(asset_id, 14, 1) = '-' AND substr(asset_id, 19, 1) = '-' AND substr(asset_id, 24, 1) = '-' AND length(replace(asset_id, '-', '')) = 32 AND replace(asset_id, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    owner_user_id TEXT CHECK (length(owner_user_id) = 36 AND substr(owner_user_id, 9, 1) = '-' AND substr(owner_user_id, 14, 1) = '-' AND substr(owner_user_id, 19, 1) = '-' AND substr(owner_user_id, 24, 1) = '-' AND length(replace(owner_user_id, '-', '')) = 32 AND replace(owner_user_id, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    share_basis_points INTEGER NOT NULL CHECK (share_basis_points BETWEEN 1 AND 10000),
    revision INTEGER NOT NULL CHECK (revision > 0),
    created_by TEXT CHECK (length(created_by) = 36 AND substr(created_by, 9, 1) = '-' AND substr(created_by, 14, 1) = '-' AND substr(created_by, 19, 1) = '-' AND substr(created_by, 24, 1) = '-' AND length(replace(created_by, '-', '')) = 32 AND replace(created_by, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    updated_by TEXT CHECK (length(updated_by) = 36 AND substr(updated_by, 9, 1) = '-' AND substr(updated_by, 14, 1) = '-' AND substr(updated_by, 19, 1) = '-' AND substr(updated_by, 24, 1) = '-' AND length(replace(updated_by, '-', '')) = 32 AND replace(updated_by, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    deleted_at INTEGER,
    UNIQUE (family_id, id),
    FOREIGN KEY (family_id, asset_id) REFERENCES assets(family_id, id),
    FOREIGN KEY (family_id, owner_user_id) REFERENCES family_members(family_id, user_id),
    FOREIGN KEY (family_id, created_by) REFERENCES family_members(family_id, user_id),
    FOREIGN KEY (family_id, updated_by) REFERENCES family_members(family_id, user_id),
    CHECK (updated_at >= created_at),
    CHECK (deleted_at IS NULL OR deleted_at >= created_at)
) STRICT;

CREATE TABLE asset_valuations (
    id TEXT CHECK (length(id) = 36 AND substr(id, 9, 1) = '-' AND substr(id, 14, 1) = '-' AND substr(id, 19, 1) = '-' AND substr(id, 24, 1) = '-' AND length(replace(id, '-', '')) = 32 AND replace(id, '-', '') NOT GLOB '*[^0-9a-f]*') PRIMARY KEY,
    family_id TEXT CHECK (length(family_id) = 36 AND substr(family_id, 9, 1) = '-' AND substr(family_id, 14, 1) = '-' AND substr(family_id, 19, 1) = '-' AND substr(family_id, 24, 1) = '-' AND length(replace(family_id, '-', '')) = 32 AND replace(family_id, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    asset_id TEXT CHECK (length(asset_id) = 36 AND substr(asset_id, 9, 1) = '-' AND substr(asset_id, 14, 1) = '-' AND substr(asset_id, 19, 1) = '-' AND substr(asset_id, 24, 1) = '-' AND length(replace(asset_id, '-', '')) = 32 AND replace(asset_id, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    valued_at INTEGER NOT NULL,
    amount_minor INTEGER NOT NULL CHECK (amount_minor >= 0),
    currency TEXT NOT NULL DEFAULT 'INR' REFERENCES currencies(code),
    source_ciphertext BLOB NOT NULL,
    revision INTEGER NOT NULL CHECK (revision > 0),
    created_by TEXT CHECK (length(created_by) = 36 AND substr(created_by, 9, 1) = '-' AND substr(created_by, 14, 1) = '-' AND substr(created_by, 19, 1) = '-' AND substr(created_by, 24, 1) = '-' AND length(replace(created_by, '-', '')) = 32 AND replace(created_by, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    updated_by TEXT CHECK (length(updated_by) = 36 AND substr(updated_by, 9, 1) = '-' AND substr(updated_by, 14, 1) = '-' AND substr(updated_by, 19, 1) = '-' AND substr(updated_by, 24, 1) = '-' AND length(replace(updated_by, '-', '')) = 32 AND replace(updated_by, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    deleted_at INTEGER,
    UNIQUE (family_id, id),
    FOREIGN KEY (family_id, asset_id) REFERENCES assets(family_id, id),
    FOREIGN KEY (family_id, created_by) REFERENCES family_members(family_id, user_id),
    FOREIGN KEY (family_id, updated_by) REFERENCES family_members(family_id, user_id),
    CHECK (updated_at >= created_at),
    CHECK (deleted_at IS NULL OR deleted_at >= created_at)
) STRICT;

CREATE TABLE liabilities (
    id TEXT CHECK (length(id) = 36 AND substr(id, 9, 1) = '-' AND substr(id, 14, 1) = '-' AND substr(id, 19, 1) = '-' AND substr(id, 24, 1) = '-' AND length(replace(id, '-', '')) = 32 AND replace(id, '-', '') NOT GLOB '*[^0-9a-f]*') PRIMARY KEY,
    family_id TEXT CHECK (length(family_id) = 36 AND substr(family_id, 9, 1) = '-' AND substr(family_id, 14, 1) = '-' AND substr(family_id, 19, 1) = '-' AND substr(family_id, 24, 1) = '-' AND length(replace(family_id, '-', '')) = 32 AND replace(family_id, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL REFERENCES families(id),
    direction TEXT NOT NULL CHECK (direction IN ('borrowed', 'lent')),
    kind TEXT NOT NULL CHECK (kind IN ('personal', 'bank_loan', 'other')),
    counterparty_ciphertext BLOB NOT NULL,
    principal_minor INTEGER NOT NULL CHECK (principal_minor > 0),
    currency TEXT NOT NULL DEFAULT 'INR' REFERENCES currencies(code),
    terms_ciphertext BLOB NOT NULL,
    opened_on TEXT CHECK (opened_on IS NULL OR (length(opened_on) = 10 AND date(opened_on) IS NOT NULL AND date(opened_on) = opened_on)) NOT NULL,
    revision INTEGER NOT NULL CHECK (revision > 0),
    created_by TEXT CHECK (length(created_by) = 36 AND substr(created_by, 9, 1) = '-' AND substr(created_by, 14, 1) = '-' AND substr(created_by, 19, 1) = '-' AND substr(created_by, 24, 1) = '-' AND length(replace(created_by, '-', '')) = 32 AND replace(created_by, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    updated_by TEXT CHECK (length(updated_by) = 36 AND substr(updated_by, 9, 1) = '-' AND substr(updated_by, 14, 1) = '-' AND substr(updated_by, 19, 1) = '-' AND substr(updated_by, 24, 1) = '-' AND length(replace(updated_by, '-', '')) = 32 AND replace(updated_by, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    deleted_at INTEGER,
    UNIQUE (family_id, id),
    FOREIGN KEY (family_id, created_by) REFERENCES family_members(family_id, user_id),
    FOREIGN KEY (family_id, updated_by) REFERENCES family_members(family_id, user_id),
    CHECK (updated_at >= created_at),
    CHECK (deleted_at IS NULL OR deleted_at >= created_at)
) STRICT;

CREATE TABLE repayment_schedules (
    id TEXT CHECK (length(id) = 36 AND substr(id, 9, 1) = '-' AND substr(id, 14, 1) = '-' AND substr(id, 19, 1) = '-' AND substr(id, 24, 1) = '-' AND length(replace(id, '-', '')) = 32 AND replace(id, '-', '') NOT GLOB '*[^0-9a-f]*') PRIMARY KEY,
    family_id TEXT CHECK (length(family_id) = 36 AND substr(family_id, 9, 1) = '-' AND substr(family_id, 14, 1) = '-' AND substr(family_id, 19, 1) = '-' AND substr(family_id, 24, 1) = '-' AND length(replace(family_id, '-', '')) = 32 AND replace(family_id, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    liability_id TEXT CHECK (length(liability_id) = 36 AND substr(liability_id, 9, 1) = '-' AND substr(liability_id, 14, 1) = '-' AND substr(liability_id, 19, 1) = '-' AND substr(liability_id, 24, 1) = '-' AND length(replace(liability_id, '-', '')) = 32 AND replace(liability_id, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    due_on TEXT CHECK (due_on IS NULL OR (length(due_on) = 10 AND date(due_on) IS NOT NULL AND date(due_on) = due_on)) NOT NULL,
    principal_minor INTEGER NOT NULL CHECK (principal_minor >= 0),
    interest_minor INTEGER NOT NULL CHECK (interest_minor >= 0),
    revision INTEGER NOT NULL CHECK (revision > 0),
    created_by TEXT CHECK (length(created_by) = 36 AND substr(created_by, 9, 1) = '-' AND substr(created_by, 14, 1) = '-' AND substr(created_by, 19, 1) = '-' AND substr(created_by, 24, 1) = '-' AND length(replace(created_by, '-', '')) = 32 AND replace(created_by, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    updated_by TEXT CHECK (length(updated_by) = 36 AND substr(updated_by, 9, 1) = '-' AND substr(updated_by, 14, 1) = '-' AND substr(updated_by, 19, 1) = '-' AND substr(updated_by, 24, 1) = '-' AND length(replace(updated_by, '-', '')) = 32 AND replace(updated_by, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    deleted_at INTEGER,
    UNIQUE (family_id, id),
    FOREIGN KEY (family_id, liability_id) REFERENCES liabilities(family_id, id),
    FOREIGN KEY (family_id, created_by) REFERENCES family_members(family_id, user_id),
    FOREIGN KEY (family_id, updated_by) REFERENCES family_members(family_id, user_id),
    CHECK (updated_at >= created_at),
    CHECK (deleted_at IS NULL OR deleted_at >= created_at)
) STRICT;

CREATE TABLE repayments (
    id TEXT CHECK (length(id) = 36 AND substr(id, 9, 1) = '-' AND substr(id, 14, 1) = '-' AND substr(id, 19, 1) = '-' AND substr(id, 24, 1) = '-' AND length(replace(id, '-', '')) = 32 AND replace(id, '-', '') NOT GLOB '*[^0-9a-f]*') PRIMARY KEY,
    family_id TEXT CHECK (length(family_id) = 36 AND substr(family_id, 9, 1) = '-' AND substr(family_id, 14, 1) = '-' AND substr(family_id, 19, 1) = '-' AND substr(family_id, 24, 1) = '-' AND length(replace(family_id, '-', '')) = 32 AND replace(family_id, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    liability_id TEXT CHECK (length(liability_id) = 36 AND substr(liability_id, 9, 1) = '-' AND substr(liability_id, 14, 1) = '-' AND substr(liability_id, 19, 1) = '-' AND substr(liability_id, 24, 1) = '-' AND length(replace(liability_id, '-', '')) = 32 AND replace(liability_id, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    journal_id TEXT CHECK (length(journal_id) = 36 AND substr(journal_id, 9, 1) = '-' AND substr(journal_id, 14, 1) = '-' AND substr(journal_id, 19, 1) = '-' AND substr(journal_id, 24, 1) = '-' AND length(replace(journal_id, '-', '')) = 32 AND replace(journal_id, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    paid_on TEXT CHECK (paid_on IS NULL OR (length(paid_on) = 10 AND date(paid_on) IS NOT NULL AND date(paid_on) = paid_on)) NOT NULL,
    principal_minor INTEGER NOT NULL CHECK (principal_minor >= 0),
    interest_minor INTEGER NOT NULL CHECK (interest_minor >= 0),
    revision INTEGER NOT NULL CHECK (revision > 0),
    created_by TEXT CHECK (length(created_by) = 36 AND substr(created_by, 9, 1) = '-' AND substr(created_by, 14, 1) = '-' AND substr(created_by, 19, 1) = '-' AND substr(created_by, 24, 1) = '-' AND length(replace(created_by, '-', '')) = 32 AND replace(created_by, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    updated_by TEXT CHECK (length(updated_by) = 36 AND substr(updated_by, 9, 1) = '-' AND substr(updated_by, 14, 1) = '-' AND substr(updated_by, 19, 1) = '-' AND substr(updated_by, 24, 1) = '-' AND length(replace(updated_by, '-', '')) = 32 AND replace(updated_by, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    deleted_at INTEGER,
    UNIQUE (family_id, id),
    UNIQUE (family_id, liability_id, journal_id),
    CHECK (principal_minor > 0 OR interest_minor > 0),
    FOREIGN KEY (family_id, liability_id) REFERENCES liabilities(family_id, id),
    FOREIGN KEY (family_id, journal_id) REFERENCES journal_entries(family_id, id),
    FOREIGN KEY (family_id, created_by) REFERENCES family_members(family_id, user_id),
    FOREIGN KEY (family_id, updated_by) REFERENCES family_members(family_id, user_id),
    CHECK (updated_at >= created_at),
    CHECK (deleted_at IS NULL OR deleted_at >= created_at)
) STRICT;

CREATE TABLE stock_items (
    id TEXT CHECK (length(id) = 36 AND substr(id, 9, 1) = '-' AND substr(id, 14, 1) = '-' AND substr(id, 19, 1) = '-' AND substr(id, 24, 1) = '-' AND length(replace(id, '-', '')) = 32 AND replace(id, '-', '') NOT GLOB '*[^0-9a-f]*') PRIMARY KEY,
    family_id TEXT CHECK (length(family_id) = 36 AND substr(family_id, 9, 1) = '-' AND substr(family_id, 14, 1) = '-' AND substr(family_id, 19, 1) = '-' AND substr(family_id, 24, 1) = '-' AND length(replace(family_id, '-', '')) = 32 AND replace(family_id, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    business_id TEXT CHECK (length(business_id) = 36 AND substr(business_id, 9, 1) = '-' AND substr(business_id, 14, 1) = '-' AND substr(business_id, 19, 1) = '-' AND substr(business_id, 24, 1) = '-' AND length(replace(business_id, '-', '')) = 32 AND replace(business_id, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    label_ciphertext BLOB NOT NULL,
    quantity_scale INTEGER NOT NULL CHECK (quantity_scale BETWEEN 0 AND 9),
    revision INTEGER NOT NULL CHECK (revision > 0),
    created_by TEXT CHECK (length(created_by) = 36 AND substr(created_by, 9, 1) = '-' AND substr(created_by, 14, 1) = '-' AND substr(created_by, 19, 1) = '-' AND substr(created_by, 24, 1) = '-' AND length(replace(created_by, '-', '')) = 32 AND replace(created_by, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    updated_by TEXT CHECK (length(updated_by) = 36 AND substr(updated_by, 9, 1) = '-' AND substr(updated_by, 14, 1) = '-' AND substr(updated_by, 19, 1) = '-' AND substr(updated_by, 24, 1) = '-' AND length(replace(updated_by, '-', '')) = 32 AND replace(updated_by, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    deleted_at INTEGER,
    UNIQUE (family_id, id),
    FOREIGN KEY (family_id, business_id) REFERENCES businesses(family_id, id),
    FOREIGN KEY (family_id, created_by) REFERENCES family_members(family_id, user_id),
    FOREIGN KEY (family_id, updated_by) REFERENCES family_members(family_id, user_id),
    CHECK (updated_at >= created_at),
    CHECK (deleted_at IS NULL OR deleted_at >= created_at)
) STRICT;

CREATE TABLE stock_movements (
    id TEXT CHECK (length(id) = 36 AND substr(id, 9, 1) = '-' AND substr(id, 14, 1) = '-' AND substr(id, 19, 1) = '-' AND substr(id, 24, 1) = '-' AND length(replace(id, '-', '')) = 32 AND replace(id, '-', '') NOT GLOB '*[^0-9a-f]*') PRIMARY KEY,
    family_id TEXT CHECK (length(family_id) = 36 AND substr(family_id, 9, 1) = '-' AND substr(family_id, 14, 1) = '-' AND substr(family_id, 19, 1) = '-' AND substr(family_id, 24, 1) = '-' AND length(replace(family_id, '-', '')) = 32 AND replace(family_id, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    stock_item_id TEXT CHECK (length(stock_item_id) = 36 AND substr(stock_item_id, 9, 1) = '-' AND substr(stock_item_id, 14, 1) = '-' AND substr(stock_item_id, 19, 1) = '-' AND substr(stock_item_id, 24, 1) = '-' AND length(replace(stock_item_id, '-', '')) = 32 AND replace(stock_item_id, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    quantity_delta_scaled INTEGER NOT NULL CHECK (quantity_delta_scaled <> 0),
    journal_id TEXT CHECK (length(journal_id) = 36 AND substr(journal_id, 9, 1) = '-' AND substr(journal_id, 14, 1) = '-' AND substr(journal_id, 19, 1) = '-' AND substr(journal_id, 24, 1) = '-' AND length(replace(journal_id, '-', '')) = 32 AND replace(journal_id, '-', '') NOT GLOB '*[^0-9a-f]*'),
    moved_at INTEGER NOT NULL,
    revision INTEGER NOT NULL CHECK (revision > 0),
    created_by TEXT CHECK (length(created_by) = 36 AND substr(created_by, 9, 1) = '-' AND substr(created_by, 14, 1) = '-' AND substr(created_by, 19, 1) = '-' AND substr(created_by, 24, 1) = '-' AND length(replace(created_by, '-', '')) = 32 AND replace(created_by, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    updated_by TEXT CHECK (length(updated_by) = 36 AND substr(updated_by, 9, 1) = '-' AND substr(updated_by, 14, 1) = '-' AND substr(updated_by, 19, 1) = '-' AND substr(updated_by, 24, 1) = '-' AND length(replace(updated_by, '-', '')) = 32 AND replace(updated_by, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    deleted_at INTEGER,
    UNIQUE (family_id, id),
    FOREIGN KEY (family_id, stock_item_id) REFERENCES stock_items(family_id, id),
    FOREIGN KEY (family_id, journal_id) REFERENCES journal_entries(family_id, id),
    FOREIGN KEY (family_id, created_by) REFERENCES family_members(family_id, user_id),
    FOREIGN KEY (family_id, updated_by) REFERENCES family_members(family_id, user_id),
    CHECK (updated_at >= created_at),
    CHECK (deleted_at IS NULL OR deleted_at >= created_at)
) STRICT;

CREATE TABLE salary_records (
    id TEXT CHECK (length(id) = 36 AND substr(id, 9, 1) = '-' AND substr(id, 14, 1) = '-' AND substr(id, 19, 1) = '-' AND substr(id, 24, 1) = '-' AND length(replace(id, '-', '')) = 32 AND replace(id, '-', '') NOT GLOB '*[^0-9a-f]*') PRIMARY KEY,
    family_id TEXT CHECK (length(family_id) = 36 AND substr(family_id, 9, 1) = '-' AND substr(family_id, 14, 1) = '-' AND substr(family_id, 19, 1) = '-' AND substr(family_id, 24, 1) = '-' AND length(replace(family_id, '-', '')) = 32 AND replace(family_id, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    business_id TEXT CHECK (length(business_id) = 36 AND substr(business_id, 9, 1) = '-' AND substr(business_id, 14, 1) = '-' AND substr(business_id, 19, 1) = '-' AND substr(business_id, 24, 1) = '-' AND length(replace(business_id, '-', '')) = 32 AND replace(business_id, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    worker_reference_ciphertext BLOB NOT NULL,
    period_start TEXT CHECK (period_start IS NULL OR (length(period_start) = 10 AND date(period_start) IS NOT NULL AND date(period_start) = period_start)) NOT NULL,
    period_end TEXT CHECK (period_end IS NULL OR (length(period_end) = 10 AND date(period_end) IS NOT NULL AND date(period_end) = period_end)) NOT NULL CHECK (period_end >= period_start),
    amount_minor INTEGER NOT NULL CHECK (amount_minor >= 0),
    currency TEXT NOT NULL DEFAULT 'INR' REFERENCES currencies(code),
    settlement_journal_id TEXT CHECK (length(settlement_journal_id) = 36 AND substr(settlement_journal_id, 9, 1) = '-' AND substr(settlement_journal_id, 14, 1) = '-' AND substr(settlement_journal_id, 19, 1) = '-' AND substr(settlement_journal_id, 24, 1) = '-' AND length(replace(settlement_journal_id, '-', '')) = 32 AND replace(settlement_journal_id, '-', '') NOT GLOB '*[^0-9a-f]*'),
    revision INTEGER NOT NULL CHECK (revision > 0),
    created_by TEXT CHECK (length(created_by) = 36 AND substr(created_by, 9, 1) = '-' AND substr(created_by, 14, 1) = '-' AND substr(created_by, 19, 1) = '-' AND substr(created_by, 24, 1) = '-' AND length(replace(created_by, '-', '')) = 32 AND replace(created_by, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    updated_by TEXT CHECK (length(updated_by) = 36 AND substr(updated_by, 9, 1) = '-' AND substr(updated_by, 14, 1) = '-' AND substr(updated_by, 19, 1) = '-' AND substr(updated_by, 24, 1) = '-' AND length(replace(updated_by, '-', '')) = 32 AND replace(updated_by, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    deleted_at INTEGER,
    UNIQUE (family_id, id),
    FOREIGN KEY (family_id, business_id) REFERENCES businesses(family_id, id),
    FOREIGN KEY (family_id, settlement_journal_id) REFERENCES journal_entries(family_id, id),
    FOREIGN KEY (family_id, created_by) REFERENCES family_members(family_id, user_id),
    FOREIGN KEY (family_id, updated_by) REFERENCES family_members(family_id, user_id),
    CHECK (updated_at >= created_at),
    CHECK (deleted_at IS NULL OR deleted_at >= created_at)
) STRICT;

CREATE TABLE documents (
    id TEXT CHECK (length(id) = 36 AND substr(id, 9, 1) = '-' AND substr(id, 14, 1) = '-' AND substr(id, 19, 1) = '-' AND substr(id, 24, 1) = '-' AND length(replace(id, '-', '')) = 32 AND replace(id, '-', '') NOT GLOB '*[^0-9a-f]*') PRIMARY KEY,
    family_id TEXT CHECK (length(family_id) = 36 AND substr(family_id, 9, 1) = '-' AND substr(family_id, 14, 1) = '-' AND substr(family_id, 19, 1) = '-' AND substr(family_id, 24, 1) = '-' AND length(replace(family_id, '-', '')) = 32 AND replace(family_id, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL REFERENCES families(id),
    owner_user_id TEXT CHECK (length(owner_user_id) = 36 AND substr(owner_user_id, 9, 1) = '-' AND substr(owner_user_id, 14, 1) = '-' AND substr(owner_user_id, 19, 1) = '-' AND substr(owner_user_id, 24, 1) = '-' AND length(replace(owner_user_id, '-', '')) = 32 AND replace(owner_user_id, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    category TEXT NOT NULL,
    metadata_ciphertext BLOB NOT NULL,
    revision INTEGER NOT NULL CHECK (revision > 0),
    created_by TEXT CHECK (length(created_by) = 36 AND substr(created_by, 9, 1) = '-' AND substr(created_by, 14, 1) = '-' AND substr(created_by, 19, 1) = '-' AND substr(created_by, 24, 1) = '-' AND length(replace(created_by, '-', '')) = 32 AND replace(created_by, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    updated_by TEXT CHECK (length(updated_by) = 36 AND substr(updated_by, 9, 1) = '-' AND substr(updated_by, 14, 1) = '-' AND substr(updated_by, 19, 1) = '-' AND substr(updated_by, 24, 1) = '-' AND length(replace(updated_by, '-', '')) = 32 AND replace(updated_by, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL,
    deleted_at INTEGER,
    UNIQUE (family_id, id),
    FOREIGN KEY (family_id, owner_user_id) REFERENCES family_members(family_id, user_id),
    FOREIGN KEY (family_id, created_by) REFERENCES family_members(family_id, user_id),
    FOREIGN KEY (family_id, updated_by) REFERENCES family_members(family_id, user_id),
    CHECK (updated_at >= created_at),
    CHECK (deleted_at IS NULL OR deleted_at >= created_at)
) STRICT;

CREATE TABLE document_versions (
    id TEXT CHECK (length(id) = 36 AND substr(id, 9, 1) = '-' AND substr(id, 14, 1) = '-' AND substr(id, 19, 1) = '-' AND substr(id, 24, 1) = '-' AND length(replace(id, '-', '')) = 32 AND replace(id, '-', '') NOT GLOB '*[^0-9a-f]*') PRIMARY KEY,
    family_id TEXT CHECK (length(family_id) = 36 AND substr(family_id, 9, 1) = '-' AND substr(family_id, 14, 1) = '-' AND substr(family_id, 19, 1) = '-' AND substr(family_id, 24, 1) = '-' AND length(replace(family_id, '-', '')) = 32 AND replace(family_id, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    document_id TEXT CHECK (length(document_id) = 36 AND substr(document_id, 9, 1) = '-' AND substr(document_id, 14, 1) = '-' AND substr(document_id, 19, 1) = '-' AND substr(document_id, 24, 1) = '-' AND length(replace(document_id, '-', '')) = 32 AND replace(document_id, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    version_number INTEGER NOT NULL CHECK (version_number > 0),
    object_path TEXT NOT NULL UNIQUE,
    ciphertext_sha256 BLOB NOT NULL CHECK (length(ciphertext_sha256) = 32),
    ciphertext_size INTEGER NOT NULL CHECK (ciphertext_size > 0),
    envelope_version INTEGER NOT NULL CHECK (envelope_version > 0),
    created_by TEXT CHECK (length(created_by) = 36 AND substr(created_by, 9, 1) = '-' AND substr(created_by, 14, 1) = '-' AND substr(created_by, 19, 1) = '-' AND substr(created_by, 24, 1) = '-' AND length(replace(created_by, '-', '')) = 32 AND replace(created_by, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    created_at INTEGER NOT NULL,
    finalized_at INTEGER,
    CHECK (finalized_at IS NULL OR finalized_at >= created_at),
    UNIQUE (family_id, id),
    UNIQUE (family_id, document_id, version_number),
    FOREIGN KEY (family_id, document_id) REFERENCES documents(family_id, id),
    FOREIGN KEY (family_id, created_by) REFERENCES family_members(family_id, user_id)
) STRICT;

CREATE TABLE document_key_envelopes (
    family_id TEXT CHECK (length(family_id) = 36 AND substr(family_id, 9, 1) = '-' AND substr(family_id, 14, 1) = '-' AND substr(family_id, 19, 1) = '-' AND substr(family_id, 24, 1) = '-' AND length(replace(family_id, '-', '')) = 32 AND replace(family_id, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    version_id TEXT CHECK (length(version_id) = 36 AND substr(version_id, 9, 1) = '-' AND substr(version_id, 14, 1) = '-' AND substr(version_id, 19, 1) = '-' AND substr(version_id, 24, 1) = '-' AND length(replace(version_id, '-', '')) = 32 AND replace(version_id, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    recipient_device_id TEXT CHECK (length(recipient_device_id) = 36 AND substr(recipient_device_id, 9, 1) = '-' AND substr(recipient_device_id, 14, 1) = '-' AND substr(recipient_device_id, 19, 1) = '-' AND substr(recipient_device_id, 24, 1) = '-' AND length(replace(recipient_device_id, '-', '')) = 32 AND replace(recipient_device_id, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    wrapped_key BLOB NOT NULL CHECK (length(wrapped_key) > 0),
    key_version INTEGER NOT NULL CHECK (key_version > 0),
    revoked_at INTEGER,
    PRIMARY KEY (family_id, version_id, recipient_device_id, key_version),
    FOREIGN KEY (family_id, version_id) REFERENCES document_versions(family_id, id),
    FOREIGN KEY (family_id, recipient_device_id) REFERENCES devices(family_id, id)
) STRICT;

CREATE TABLE document_access_events (
    id TEXT CHECK (length(id) = 36 AND substr(id, 9, 1) = '-' AND substr(id, 14, 1) = '-' AND substr(id, 19, 1) = '-' AND substr(id, 24, 1) = '-' AND length(replace(id, '-', '')) = 32 AND replace(id, '-', '') NOT GLOB '*[^0-9a-f]*') PRIMARY KEY,
    family_id TEXT CHECK (length(family_id) = 36 AND substr(family_id, 9, 1) = '-' AND substr(family_id, 14, 1) = '-' AND substr(family_id, 19, 1) = '-' AND substr(family_id, 24, 1) = '-' AND length(replace(family_id, '-', '')) = 32 AND replace(family_id, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    version_id TEXT CHECK (length(version_id) = 36 AND substr(version_id, 9, 1) = '-' AND substr(version_id, 14, 1) = '-' AND substr(version_id, 19, 1) = '-' AND substr(version_id, 24, 1) = '-' AND length(replace(version_id, '-', '')) = 32 AND replace(version_id, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    request_id TEXT CHECK (length(request_id) = 36 AND substr(request_id, 9, 1) = '-' AND substr(request_id, 14, 1) = '-' AND substr(request_id, 19, 1) = '-' AND substr(request_id, 24, 1) = '-' AND length(replace(request_id, '-', '')) = 32 AND replace(request_id, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    actor_id TEXT CHECK (length(actor_id) = 36 AND substr(actor_id, 9, 1) = '-' AND substr(actor_id, 14, 1) = '-' AND substr(actor_id, 19, 1) = '-' AND substr(actor_id, 24, 1) = '-' AND length(replace(actor_id, '-', '')) = 32 AND replace(actor_id, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    device_id TEXT CHECK (length(device_id) = 36 AND substr(device_id, 9, 1) = '-' AND substr(device_id, 14, 1) = '-' AND substr(device_id, 19, 1) = '-' AND substr(device_id, 24, 1) = '-' AND length(replace(device_id, '-', '')) = 32 AND replace(device_id, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    event_kind TEXT NOT NULL CHECK (event_kind IN
        ('authorized', 'transfer_completed', 'transfer_failed', 'cached_open_reported')),
    source TEXT NOT NULL CHECK (source IN ('gateway', 'device_report')),
    bytes_transferred INTEGER CHECK (bytes_transferred >= 0),
    occurred_at INTEGER NOT NULL,
    client_occurred_at INTEGER,
    UNIQUE (family_id, id),
    UNIQUE (family_id, request_id, event_kind),
    FOREIGN KEY (family_id, version_id) REFERENCES document_versions(family_id, id),
    FOREIGN KEY (family_id, device_id, actor_id) REFERENCES devices(family_id, id, user_id),
    CHECK ((event_kind = 'cached_open_reported') = (source = 'device_report'))
) STRICT;

CREATE TABLE backup_snapshots (
    id TEXT CHECK (length(id) = 36 AND substr(id, 9, 1) = '-' AND substr(id, 14, 1) = '-' AND substr(id, 19, 1) = '-' AND substr(id, 24, 1) = '-' AND length(replace(id, '-', '')) = 32 AND replace(id, '-', '') NOT GLOB '*[^0-9a-f]*') PRIMARY KEY,
    family_id TEXT CHECK (length(family_id) = 36 AND substr(family_id, 9, 1) = '-' AND substr(family_id, 14, 1) = '-' AND substr(family_id, 19, 1) = '-' AND substr(family_id, 24, 1) = '-' AND length(replace(family_id, '-', '')) = 32 AND replace(family_id, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL REFERENCES families(id),
    created_by TEXT CHECK (length(created_by) = 36 AND substr(created_by, 9, 1) = '-' AND substr(created_by, 14, 1) = '-' AND substr(created_by, 19, 1) = '-' AND substr(created_by, 24, 1) = '-' AND length(replace(created_by, '-', '')) = 32 AND replace(created_by, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    creator_device_id TEXT CHECK (length(creator_device_id) = 36 AND substr(creator_device_id, 9, 1) = '-' AND substr(creator_device_id, 14, 1) = '-' AND substr(creator_device_id, 19, 1) = '-' AND substr(creator_device_id, 24, 1) = '-' AND length(replace(creator_device_id, '-', '')) = 32 AND replace(creator_device_id, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    state TEXT NOT NULL DEFAULT 'building' CHECK (state IN ('building', 'complete', 'failed')),
    archive_format_version INTEGER NOT NULL CHECK (archive_format_version > 0),
    database_schema_version INTEGER NOT NULL CHECK (database_schema_version > 0),
    server_watermark INTEGER NOT NULL CHECK (server_watermark >= 0),
    authorization_epoch INTEGER NOT NULL CHECK (authorization_epoch >= 0),
    includes_pending_operations INTEGER CHECK (includes_pending_operations IN (0, 1)) NOT NULL,
    archive_sha256 BLOB CHECK (length(archive_sha256) = 32),
    archive_size INTEGER CHECK (archive_size > 0),
    manifest_sha256 BLOB CHECK (length(manifest_sha256) = 32),
    created_at INTEGER NOT NULL,
    archive_verified_at INTEGER CHECK (archive_verified_at >= created_at),
    UNIQUE (family_id, id),
    UNIQUE (family_id, id, state),
    UNIQUE (family_id, id, archive_sha256, archive_size),
    FOREIGN KEY (family_id, creator_device_id, created_by) REFERENCES devices(family_id, id, user_id),
    CHECK ((archive_sha256 IS NULL) = (archive_size IS NULL)),
    CHECK (state <> 'complete' OR (archive_sha256 IS NOT NULL AND archive_size IS NOT NULL
        AND manifest_sha256 IS NOT NULL AND archive_verified_at IS NOT NULL))
) STRICT;

CREATE TABLE backup_destinations (
    id TEXT CHECK (length(id) = 36 AND substr(id, 9, 1) = '-' AND substr(id, 14, 1) = '-' AND substr(id, 19, 1) = '-' AND substr(id, 24, 1) = '-' AND length(replace(id, '-', '')) = 32 AND replace(id, '-', '') NOT GLOB '*[^0-9a-f]*') PRIMARY KEY,
    family_id TEXT CHECK (length(family_id) = 36 AND substr(family_id, 9, 1) = '-' AND substr(family_id, 14, 1) = '-' AND substr(family_id, 19, 1) = '-' AND substr(family_id, 24, 1) = '-' AND length(replace(family_id, '-', '')) = 32 AND replace(family_id, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL REFERENCES families(id),
    kind TEXT NOT NULL CHECK (kind IN ('local', 'google_drive')),
    configured_by TEXT CHECK (length(configured_by) = 36 AND substr(configured_by, 9, 1) = '-' AND substr(configured_by, 14, 1) = '-' AND substr(configured_by, 19, 1) = '-' AND substr(configured_by, 24, 1) = '-' AND length(replace(configured_by, '-', '')) = 32 AND replace(configured_by, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    created_at INTEGER NOT NULL,
    revoked_at INTEGER CHECK (revoked_at >= created_at),
    UNIQUE (family_id, id),
    FOREIGN KEY (family_id, configured_by) REFERENCES family_members(family_id, user_id)
) STRICT;

CREATE TABLE backup_copy_attempts (
    id TEXT CHECK (length(id) = 36 AND substr(id, 9, 1) = '-' AND substr(id, 14, 1) = '-' AND substr(id, 19, 1) = '-' AND substr(id, 24, 1) = '-' AND length(replace(id, '-', '')) = 32 AND replace(id, '-', '') NOT GLOB '*[^0-9a-f]*') PRIMARY KEY,
    family_id TEXT CHECK (length(family_id) = 36 AND substr(family_id, 9, 1) = '-' AND substr(family_id, 14, 1) = '-' AND substr(family_id, 19, 1) = '-' AND substr(family_id, 24, 1) = '-' AND length(replace(family_id, '-', '')) = 32 AND replace(family_id, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    snapshot_id TEXT CHECK (length(snapshot_id) = 36 AND substr(snapshot_id, 9, 1) = '-' AND substr(snapshot_id, 14, 1) = '-' AND substr(snapshot_id, 19, 1) = '-' AND substr(snapshot_id, 24, 1) = '-' AND length(replace(snapshot_id, '-', '')) = 32 AND replace(snapshot_id, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    snapshot_state TEXT NOT NULL DEFAULT 'complete' CHECK (snapshot_state = 'complete'),
    destination_id TEXT CHECK (length(destination_id) = 36 AND substr(destination_id, 9, 1) = '-' AND substr(destination_id, 14, 1) = '-' AND substr(destination_id, 19, 1) = '-' AND substr(destination_id, 24, 1) = '-' AND length(replace(destination_id, '-', '')) = 32 AND replace(destination_id, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    created_by TEXT CHECK (length(created_by) = 36 AND substr(created_by, 9, 1) = '-' AND substr(created_by, 14, 1) = '-' AND substr(created_by, 19, 1) = '-' AND substr(created_by, 24, 1) = '-' AND length(replace(created_by, '-', '')) = 32 AND replace(created_by, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    writer_device_id TEXT CHECK (length(writer_device_id) = 36 AND substr(writer_device_id, 9, 1) = '-' AND substr(writer_device_id, 14, 1) = '-' AND substr(writer_device_id, 19, 1) = '-' AND substr(writer_device_id, 24, 1) = '-' AND length(replace(writer_device_id, '-', '')) = 32 AND replace(writer_device_id, '-', '') NOT GLOB '*[^0-9a-f]*') NOT NULL,
    state TEXT NOT NULL DEFAULT 'queued'
        CHECK (state IN ('queued', 'writing', 'verifying', 'verified', 'failed', 'cancelled')),
    observed_sha256 BLOB CHECK (length(observed_sha256) = 32),
    observed_size INTEGER CHECK (observed_size > 0),
    receipt_ciphertext BLOB CHECK (length(receipt_ciphertext) > 0),
    created_at INTEGER NOT NULL,
    provider_ack_at INTEGER CHECK (provider_ack_at >= created_at),
    verified_at INTEGER CHECK (verified_at >= provider_ack_at),
    completed_at INTEGER CHECK (completed_at >= verified_at),
    UNIQUE (family_id, id),
    FOREIGN KEY (family_id, snapshot_id, snapshot_state) REFERENCES backup_snapshots(family_id, id, state),
    FOREIGN KEY (family_id, snapshot_id, observed_sha256, observed_size)
        REFERENCES backup_snapshots(family_id, id, archive_sha256, archive_size),
    FOREIGN KEY (family_id, destination_id) REFERENCES backup_destinations(family_id, id),
    FOREIGN KEY (family_id, writer_device_id, created_by) REFERENCES devices(family_id, id, user_id),
    CHECK ((observed_sha256 IS NULL) = (observed_size IS NULL)),
    CHECK (verified_at IS NULL OR provider_ack_at IS NOT NULL),
    CHECK (completed_at IS NULL OR verified_at IS NOT NULL),
    CHECK (state = 'verified' OR completed_at IS NULL),
    CHECK (state <> 'verified' OR (observed_sha256 IS NOT NULL AND observed_size IS NOT NULL
        AND receipt_ciphertext IS NOT NULL AND provider_ack_at IS NOT NULL
        AND verified_at IS NOT NULL AND completed_at IS NOT NULL))
) STRICT;

CREATE UNIQUE INDEX one_active_monthly_budget ON monthly_budgets(family_id, account_id, month_start, currency) WHERE deleted_at IS NULL;

CREATE UNIQUE INDEX one_active_asset_owner ON asset_ownerships(family_id, asset_id, owner_user_id) WHERE deleted_at IS NULL;

CREATE UNIQUE INDEX one_current_document_device_key
    ON document_key_envelopes(family_id, version_id, recipient_device_id)
    WHERE revoked_at IS NULL;

INSERT INTO currencies VALUES ('INR', 2, '₹', 'en_IN');

-- Local-only binding: no locator/OAuth key-reference in the cloud schema.
CREATE TABLE local_backup_bindings (
    family_id TEXT NOT NULL,
    destination_id TEXT NOT NULL,
    device_id TEXT NOT NULL,
    user_id TEXT NOT NULL,
    locator_ciphertext BLOB NOT NULL CHECK (length(locator_ciphertext) > 0),
    credential_store_reference TEXT,
    PRIMARY KEY (family_id, destination_id, device_id),
    FOREIGN KEY (family_id, destination_id) REFERENCES backup_destinations(family_id, id),
    FOREIGN KEY (family_id, device_id, user_id) REFERENCES devices(family_id, id, user_id)
) STRICT;

CREATE TRIGGER audit_events_no_update BEFORE UPDATE ON audit_events
BEGIN SELECT RAISE(ABORT, 'Audit history is append-only'); END;

CREATE TRIGGER audit_events_no_delete BEFORE DELETE ON audit_events
BEGIN SELECT RAISE(ABORT, 'Audit history is append-only'); END;

CREATE TRIGGER document_access_events_no_update BEFORE UPDATE ON document_access_events
BEGIN SELECT RAISE(ABORT, 'Audit history is append-only'); END;

CREATE TRIGGER document_access_events_no_delete BEFORE DELETE ON document_access_events
BEGIN SELECT RAISE(ABORT, 'Audit history is append-only'); END;

CREATE TRIGGER businesses_immutable_provenance BEFORE UPDATE ON businesses
WHEN NEW.id IS NOT OLD.id OR NEW.family_id IS NOT OLD.family_id OR NEW.created_by IS NOT OLD.created_by
BEGIN SELECT RAISE(ABORT, 'Record identity, family and creator are immutable'); END;

CREATE TRIGGER accounts_immutable_provenance BEFORE UPDATE ON accounts
WHEN NEW.id IS NOT OLD.id OR NEW.family_id IS NOT OLD.family_id OR NEW.created_by IS NOT OLD.created_by
BEGIN SELECT RAISE(ABORT, 'Record identity, family and creator are immutable'); END;

CREATE TRIGGER journal_entries_immutable_provenance BEFORE UPDATE ON journal_entries
WHEN NEW.id IS NOT OLD.id OR NEW.family_id IS NOT OLD.family_id OR NEW.created_by IS NOT OLD.created_by
BEGIN SELECT RAISE(ABORT, 'Record identity, family and creator are immutable'); END;

CREATE TRIGGER monthly_budgets_immutable_provenance BEFORE UPDATE ON monthly_budgets
WHEN NEW.id IS NOT OLD.id OR NEW.family_id IS NOT OLD.family_id OR NEW.created_by IS NOT OLD.created_by
BEGIN SELECT RAISE(ABORT, 'Record identity, family and creator are immutable'); END;

CREATE TRIGGER savings_observations_immutable_provenance BEFORE UPDATE ON savings_observations
WHEN NEW.id IS NOT OLD.id OR NEW.family_id IS NOT OLD.family_id OR NEW.created_by IS NOT OLD.created_by
BEGIN SELECT RAISE(ABORT, 'Record identity, family and creator are immutable'); END;

CREATE TRIGGER assets_immutable_provenance BEFORE UPDATE ON assets
WHEN NEW.id IS NOT OLD.id OR NEW.family_id IS NOT OLD.family_id OR NEW.created_by IS NOT OLD.created_by
BEGIN SELECT RAISE(ABORT, 'Record identity, family and creator are immutable'); END;

CREATE TRIGGER asset_ownerships_immutable_provenance BEFORE UPDATE ON asset_ownerships
WHEN NEW.id IS NOT OLD.id OR NEW.family_id IS NOT OLD.family_id OR NEW.created_by IS NOT OLD.created_by
BEGIN SELECT RAISE(ABORT, 'Record identity, family and creator are immutable'); END;

CREATE TRIGGER asset_valuations_immutable_provenance BEFORE UPDATE ON asset_valuations
WHEN NEW.id IS NOT OLD.id OR NEW.family_id IS NOT OLD.family_id OR NEW.created_by IS NOT OLD.created_by
BEGIN SELECT RAISE(ABORT, 'Record identity, family and creator are immutable'); END;

CREATE TRIGGER liabilities_immutable_provenance BEFORE UPDATE ON liabilities
WHEN NEW.id IS NOT OLD.id OR NEW.family_id IS NOT OLD.family_id OR NEW.created_by IS NOT OLD.created_by
BEGIN SELECT RAISE(ABORT, 'Record identity, family and creator are immutable'); END;

CREATE TRIGGER repayment_schedules_immutable_provenance BEFORE UPDATE ON repayment_schedules
WHEN NEW.id IS NOT OLD.id OR NEW.family_id IS NOT OLD.family_id OR NEW.created_by IS NOT OLD.created_by
BEGIN SELECT RAISE(ABORT, 'Record identity, family and creator are immutable'); END;

CREATE TRIGGER repayments_immutable_provenance BEFORE UPDATE ON repayments
WHEN NEW.id IS NOT OLD.id OR NEW.family_id IS NOT OLD.family_id OR NEW.created_by IS NOT OLD.created_by
BEGIN SELECT RAISE(ABORT, 'Record identity, family and creator are immutable'); END;

CREATE TRIGGER stock_items_immutable_provenance BEFORE UPDATE ON stock_items
WHEN NEW.id IS NOT OLD.id OR NEW.family_id IS NOT OLD.family_id OR NEW.created_by IS NOT OLD.created_by
BEGIN SELECT RAISE(ABORT, 'Record identity, family and creator are immutable'); END;

CREATE TRIGGER stock_movements_immutable_provenance BEFORE UPDATE ON stock_movements
WHEN NEW.id IS NOT OLD.id OR NEW.family_id IS NOT OLD.family_id OR NEW.created_by IS NOT OLD.created_by
BEGIN SELECT RAISE(ABORT, 'Record identity, family and creator are immutable'); END;

CREATE TRIGGER salary_records_immutable_provenance BEFORE UPDATE ON salary_records
WHEN NEW.id IS NOT OLD.id OR NEW.family_id IS NOT OLD.family_id OR NEW.created_by IS NOT OLD.created_by
BEGIN SELECT RAISE(ABORT, 'Record identity, family and creator are immutable'); END;

CREATE TRIGGER documents_immutable_provenance BEFORE UPDATE ON documents
WHEN NEW.id IS NOT OLD.id OR NEW.family_id IS NOT OLD.family_id OR NEW.created_by IS NOT OLD.created_by
BEGIN SELECT RAISE(ABORT, 'Record identity, family and creator are immutable'); END;

CREATE TRIGGER document_versions_immutable_provenance BEFORE UPDATE ON document_versions
WHEN NEW.id IS NOT OLD.id OR NEW.family_id IS NOT OLD.family_id OR NEW.created_by IS NOT OLD.created_by
BEGIN SELECT RAISE(ABORT, 'Record identity, family and creator are immutable'); END;

CREATE TRIGGER backup_snapshots_immutable_provenance BEFORE UPDATE ON backup_snapshots
WHEN NEW.id IS NOT OLD.id OR NEW.family_id IS NOT OLD.family_id OR NEW.created_by IS NOT OLD.created_by
BEGIN SELECT RAISE(ABORT, 'Record identity, family and creator are immutable'); END;

CREATE TRIGGER backup_copy_attempts_immutable_provenance BEFORE UPDATE ON backup_copy_attempts
WHEN NEW.id IS NOT OLD.id OR NEW.family_id IS NOT OLD.family_id OR NEW.created_by IS NOT OLD.created_by
BEGIN SELECT RAISE(ABORT, 'Record identity, family and creator are immutable'); END;

-- No PRAGMA user_version assignment: this is not an app version/migration.
COMMIT;
