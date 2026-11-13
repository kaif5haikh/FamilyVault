-- PROPOSAL ONLY. Do not deploy as an application migration.
-- Empty, isolated review schema; no auth identities or family data are inserted.
-- Revised by ADR 0003. Cross-row rules/RPCs/read policies remain review-gated.
BEGIN;
CREATE SCHEMA familyvault_proposal;
REVOKE ALL ON SCHEMA familyvault_proposal FROM PUBLIC;
SET LOCAL search_path = familyvault_proposal, pg_catalog;

CREATE TABLE currencies (
    code text PRIMARY KEY CHECK (code ~ '^[A-Z]{3}$'),
    minor_unit_scale smallint NOT NULL CHECK (minor_unit_scale BETWEEN 0 AND 6),
    display_symbol text NOT NULL,
    default_locale text NOT NULL,
    CHECK (code <> 'INR' OR (minor_unit_scale = 2 AND display_symbol = '₹' AND default_locale = 'en_IN'))
);
-- Public reference metadata, not family/financial data. Future catalogs may add currencies.
INSERT INTO currencies VALUES ('INR', 2, '₹', 'en_IN');

CREATE TABLE families (
    id uuid PRIMARY KEY,
    display_name text NOT NULL,
    default_currency text NOT NULL DEFAULT 'INR' REFERENCES currencies(code),
    revision bigint NOT NULL CHECK (revision > 0),
    created_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL,
    deleted_at timestamptz,
    CHECK (updated_at >= created_at),
    CHECK (deleted_at IS NULL OR deleted_at >= created_at)
);

CREATE TABLE family_members (
    id uuid PRIMARY KEY,
    family_id uuid NOT NULL REFERENCES families(id),
    user_id uuid NOT NULL, -- Map to auth.users in the reviewed deployment migration.
    role text NOT NULL CHECK (role IN ('administrator', 'member')),
    active boolean NOT NULL DEFAULT false,
    revision bigint NOT NULL CHECK (revision > 0),
    created_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL,
    deleted_at timestamptz,
    UNIQUE (family_id, id),
    UNIQUE (family_id, user_id),
    CHECK (updated_at >= created_at),
    CHECK (deleted_at IS NULL OR deleted_at >= created_at),
    CHECK (deleted_at IS NULL OR NOT active)
);

CREATE TABLE devices (
    id uuid PRIMARY KEY,
    family_id uuid NOT NULL REFERENCES families(id),
    user_id uuid NOT NULL,
    public_key_envelope bytea, -- Authenticated public key bundle; never a private key.
    enrollment_state text NOT NULL DEFAULT 'pending'
        CHECK (enrollment_state IN ('pending', 'enrolled', 'revoked')),
    approved_by uuid,
    approved_at timestamptz,
    revoked_at timestamptz,
    created_at timestamptz NOT NULL,
    UNIQUE (family_id, id),
    UNIQUE (family_id, id, user_id),
    FOREIGN KEY (family_id, approved_by) REFERENCES family_members(family_id, user_id),
    CHECK ((approved_by IS NULL) = (approved_at IS NULL)),
    CHECK (approved_at IS NULL OR approved_at >= created_at),
    CHECK (revoked_at IS NULL OR revoked_at >= created_at),
    CHECK (
        (enrollment_state = 'pending' AND approved_at IS NULL AND revoked_at IS NULL)
        OR (enrollment_state = 'enrolled' AND approved_at IS NOT NULL
            AND public_key_envelope IS NOT NULL AND octet_length(public_key_envelope) > 0 AND revoked_at IS NULL)
        OR (enrollment_state = 'revoked' AND revoked_at IS NOT NULL)
    ),
    FOREIGN KEY (family_id, user_id) REFERENCES family_members(family_id, user_id)
);

CREATE TABLE device_sessions (
    family_id uuid NOT NULL,
    session_id uuid NOT NULL, -- Verified Auth JWT session_id, bound by trusted enrollment RPC.
    user_id uuid NOT NULL,
    device_id uuid NOT NULL,
    created_at timestamptz NOT NULL,
    expires_at timestamptz NOT NULL CHECK (expires_at > created_at),
    revoked_at timestamptz CHECK (revoked_at IS NULL OR revoked_at >= created_at),
    PRIMARY KEY (family_id, session_id),
    FOREIGN KEY (family_id, device_id, user_id) REFERENCES devices(family_id, id, user_id)
); -- Presence of this row alone is not current authorization; check membership/device/revocation.

CREATE TABLE sync_clocks (
    family_id uuid PRIMARY KEY REFERENCES families(id),
    last_sequence bigint NOT NULL DEFAULT 0 CHECK (last_sequence >= 0),
    authorization_epoch bigint NOT NULL DEFAULT 0 CHECK (authorization_epoch >= 0)
);

CREATE TABLE operation_receipts (
    family_id uuid NOT NULL REFERENCES families(id),
    actor_id uuid NOT NULL,
    operation_id uuid NOT NULL,
    device_id uuid NOT NULL,
    payload_digest bytea NOT NULL CHECK (octet_length(payload_digest) = 32),
    entity_type text NOT NULL,
    entity_id uuid NOT NULL,
    accepted_revision bigint NOT NULL CHECK (accepted_revision > 0),
    committed_sequence bigint NOT NULL CHECK (committed_sequence > 0),
    committed_at timestamptz NOT NULL,
    PRIMARY KEY (family_id, actor_id, operation_id),
    FOREIGN KEY (family_id, device_id, actor_id) REFERENCES devices(family_id, id, user_id)
);

CREATE TABLE change_events (
    family_id uuid NOT NULL REFERENCES families(id),
    sequence bigint NOT NULL CHECK (sequence > 0),
    entity_type text NOT NULL,
    entity_id uuid NOT NULL,
    revision bigint NOT NULL CHECK (revision > 0),
    is_deleted boolean NOT NULL,
    payload_schema_version integer NOT NULL CHECK (payload_schema_version > 0),
    snapshot_json jsonb NOT NULL CHECK (jsonb_typeof(snapshot_json) = 'object'),
    committed_at timestamptz NOT NULL,
    PRIMARY KEY (family_id, sequence)
); -- Immutable revision snapshots. Pull RPC applies current ACL/recipient filtering.
-- Never expose this feed directly or include file bytes/plaintext document keys.

CREATE TABLE audit_events (
    id uuid PRIMARY KEY,
    family_id uuid NOT NULL REFERENCES families(id),
    actor_id uuid NOT NULL,
    device_id uuid NOT NULL,
    operation_id uuid NOT NULL,
    action text NOT NULL,
    entity_type text NOT NULL,
    entity_id uuid NOT NULL,
    revision bigint NOT NULL CHECK (revision > 0),
    occurred_at timestamptz NOT NULL,
    FOREIGN KEY (family_id, device_id, actor_id) REFERENCES devices(family_id, id, user_id)
); -- Append-only privileges and retention in reviewed migration. No payload logging.

CREATE TABLE businesses (
    id uuid PRIMARY KEY,
    family_id uuid NOT NULL REFERENCES families(id),
    name text NOT NULL,
    revision bigint NOT NULL CHECK (revision > 0),
    created_by uuid NOT NULL,
    updated_by uuid NOT NULL,
    created_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL,
    deleted_at timestamptz,
    UNIQUE (family_id, id),
    FOREIGN KEY (family_id, created_by) REFERENCES family_members(family_id, user_id),
    FOREIGN KEY (family_id, updated_by) REFERENCES family_members(family_id, user_id),
    CHECK (updated_at >= created_at),
    CHECK (deleted_at IS NULL OR deleted_at >= created_at)
);

CREATE TABLE business_grants (
    family_id uuid NOT NULL,
    business_id uuid NOT NULL,
    user_id uuid NOT NULL,
    permission text NOT NULL CHECK (permission IN ('read', 'write', 'manage')),
    revoked_at timestamptz,
    PRIMARY KEY (family_id, business_id, user_id),
    FOREIGN KEY (family_id, business_id) REFERENCES businesses(family_id, id),
    FOREIGN KEY (family_id, user_id) REFERENCES family_members(family_id, user_id)
);

CREATE TABLE accounts (
    id uuid PRIMARY KEY,
    family_id uuid NOT NULL REFERENCES families(id),
    business_id uuid,
    name text NOT NULL,
    kind text NOT NULL CHECK (kind IN ('bank', 'cash', 'asset', 'income', 'expense', 'liability', 'equity')),
    currency text NOT NULL DEFAULT 'INR' REFERENCES currencies(code),
    revision bigint NOT NULL CHECK (revision > 0),
    created_by uuid NOT NULL,
    updated_by uuid NOT NULL,
    created_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL,
    deleted_at timestamptz,
    UNIQUE (family_id, id),
    FOREIGN KEY (family_id, business_id) REFERENCES businesses(family_id, id),
    FOREIGN KEY (family_id, created_by) REFERENCES family_members(family_id, user_id),
    FOREIGN KEY (family_id, updated_by) REFERENCES family_members(family_id, user_id),
    CHECK (updated_at >= created_at),
    CHECK (deleted_at IS NULL OR deleted_at >= created_at)
);

CREATE TABLE journal_entries (
    id uuid PRIMARY KEY,
    family_id uuid NOT NULL REFERENCES families(id),
    business_id uuid,
    accounting_date date NOT NULL,
    status text NOT NULL CHECK (status IN ('draft', 'posted')),
    reversal_of uuid,
    description_ciphertext bytea,
    revision bigint NOT NULL CHECK (revision > 0),
    created_by uuid NOT NULL,
    updated_by uuid NOT NULL,
    created_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL,
    deleted_at timestamptz,
    UNIQUE (family_id, id),
    FOREIGN KEY (family_id, business_id) REFERENCES businesses(family_id, id),
    FOREIGN KEY (family_id, reversal_of) REFERENCES journal_entries(family_id, id),
    FOREIGN KEY (family_id, created_by) REFERENCES family_members(family_id, user_id),
    FOREIGN KEY (family_id, updated_by) REFERENCES family_members(family_id, user_id),
    CHECK (updated_at >= created_at),
    CHECK (deleted_at IS NULL OR deleted_at >= created_at)
);

CREATE TABLE journal_postings (
    id uuid PRIMARY KEY,
    family_id uuid NOT NULL,
    journal_id uuid NOT NULL,
    account_id uuid NOT NULL,
    currency text NOT NULL DEFAULT 'INR' REFERENCES currencies(code),
    amount_minor bigint NOT NULL CHECK (amount_minor <> 0),
    UNIQUE (family_id, id),
    FOREIGN KEY (family_id, journal_id) REFERENCES journal_entries(family_id, id),
    FOREIGN KEY (family_id, account_id) REFERENCES accounts(family_id, id)
); -- Deferred balance/scope/currency/immutability enforcement required before use.

CREATE TABLE monthly_budgets (
    id uuid PRIMARY KEY,
    family_id uuid NOT NULL,
    account_id uuid NOT NULL,
    month_start date NOT NULL CHECK (extract(day FROM month_start) = 1),
    currency text NOT NULL DEFAULT 'INR' REFERENCES currencies(code),
    amount_minor bigint NOT NULL CHECK (amount_minor >= 0),
    revision bigint NOT NULL CHECK (revision > 0),
    created_by uuid NOT NULL,
    updated_by uuid NOT NULL,
    created_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL,
    deleted_at timestamptz,
    UNIQUE (family_id, id),
    FOREIGN KEY (family_id, account_id) REFERENCES accounts(family_id, id),
    FOREIGN KEY (family_id, created_by) REFERENCES family_members(family_id, user_id),
    FOREIGN KEY (family_id, updated_by) REFERENCES family_members(family_id, user_id),
    CHECK (updated_at >= created_at),
    CHECK (deleted_at IS NULL OR deleted_at >= created_at)
);
CREATE UNIQUE INDEX one_active_monthly_budget ON monthly_budgets(family_id, account_id, month_start, currency) WHERE deleted_at IS NULL;

CREATE TABLE savings_observations (
    id uuid PRIMARY KEY,
    family_id uuid NOT NULL REFERENCES families(id),
    observed_on date NOT NULL,
    currency text NOT NULL DEFAULT 'INR' REFERENCES currencies(code),
    amount_minor bigint NOT NULL,
    source_ciphertext bytea,
    revision bigint NOT NULL CHECK (revision > 0),
    created_by uuid NOT NULL,
    updated_by uuid NOT NULL,
    created_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL,
    deleted_at timestamptz,
    UNIQUE (family_id, id),
    FOREIGN KEY (family_id, created_by) REFERENCES family_members(family_id, user_id),
    FOREIGN KEY (family_id, updated_by) REFERENCES family_members(family_id, user_id),
    CHECK (updated_at >= created_at),
    CHECK (deleted_at IS NULL OR deleted_at >= created_at)
);

CREATE TABLE assets (
    id uuid PRIMARY KEY,
    family_id uuid NOT NULL REFERENCES families(id),
    kind text NOT NULL CHECK (kind IN ('gold', 'silver', 'property', 'land', 'vehicle', 'investment', 'other')),
    label_ciphertext bytea NOT NULL,
    acquired_on date,
    purchase_amount_minor bigint CHECK (purchase_amount_minor >= 0),
    purchase_currency text REFERENCES currencies(code),
    revision bigint NOT NULL CHECK (revision > 0),
    created_by uuid NOT NULL,
    updated_by uuid NOT NULL,
    created_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL,
    deleted_at timestamptz,
    UNIQUE (family_id, id),
    CHECK ((purchase_amount_minor IS NULL) = (purchase_currency IS NULL)),
    FOREIGN KEY (family_id, created_by) REFERENCES family_members(family_id, user_id),
    FOREIGN KEY (family_id, updated_by) REFERENCES family_members(family_id, user_id),
    CHECK (updated_at >= created_at),
    CHECK (deleted_at IS NULL OR deleted_at >= created_at)
);
CREATE TABLE metal_details (
    family_id uuid NOT NULL,
    asset_id uuid NOT NULL,
    weight_mg bigint NOT NULL CHECK (weight_mg > 0),
    purity_ppm integer NOT NULL CHECK (purity_ppm BETWEEN 1 AND 1000000),
    making_charges_minor bigint CHECK (making_charges_minor >= 0),
    currency text REFERENCES currencies(code),
    PRIMARY KEY (family_id, asset_id),
    FOREIGN KEY (family_id, asset_id) REFERENCES assets(family_id, id),
    CHECK ((making_charges_minor IS NULL) = (currency IS NULL))
);
CREATE TABLE property_details (
    family_id uuid NOT NULL,
    asset_id uuid NOT NULL,
    location_ciphertext bytea NOT NULL,
    record_reference_ciphertext bytea,
    PRIMARY KEY (family_id, asset_id),
    FOREIGN KEY (family_id, asset_id) REFERENCES assets(family_id, id)
);
CREATE TABLE investment_details (
    family_id uuid NOT NULL,
    asset_id uuid NOT NULL,
    instrument_ciphertext bytea NOT NULL,
    quantity_scaled bigint NOT NULL CHECK (quantity_scaled > 0),
    quantity_scale smallint NOT NULL CHECK (quantity_scale BETWEEN 0 AND 9),
    PRIMARY KEY (family_id, asset_id),
    FOREIGN KEY (family_id, asset_id) REFERENCES assets(family_id, id)
);
CREATE TABLE asset_ownerships (
    id uuid PRIMARY KEY,
    family_id uuid NOT NULL,
    asset_id uuid NOT NULL,
    owner_user_id uuid NOT NULL,
    share_basis_points integer NOT NULL CHECK (share_basis_points BETWEEN 1 AND 10000),
    revision bigint NOT NULL CHECK (revision > 0),
    created_by uuid NOT NULL,
    updated_by uuid NOT NULL,
    created_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL,
    deleted_at timestamptz,
    UNIQUE (family_id, id),
    FOREIGN KEY (family_id, asset_id) REFERENCES assets(family_id, id),
    FOREIGN KEY (family_id, owner_user_id) REFERENCES family_members(family_id, user_id),
    FOREIGN KEY (family_id, created_by) REFERENCES family_members(family_id, user_id),
    FOREIGN KEY (family_id, updated_by) REFERENCES family_members(family_id, user_id),
    CHECK (updated_at >= created_at),
    CHECK (deleted_at IS NULL OR deleted_at >= created_at)
);
CREATE UNIQUE INDEX one_active_asset_owner ON asset_ownerships(family_id, asset_id, owner_user_id) WHERE deleted_at IS NULL;
CREATE TABLE asset_valuations (
    id uuid PRIMARY KEY,
    family_id uuid NOT NULL,
    asset_id uuid NOT NULL,
    valued_at timestamptz NOT NULL,
    amount_minor bigint NOT NULL CHECK (amount_minor >= 0),
    currency text NOT NULL DEFAULT 'INR' REFERENCES currencies(code),
    source_ciphertext bytea NOT NULL,
    revision bigint NOT NULL CHECK (revision > 0),
    created_by uuid NOT NULL,
    updated_by uuid NOT NULL,
    created_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL,
    deleted_at timestamptz,
    UNIQUE (family_id, id),
    FOREIGN KEY (family_id, asset_id) REFERENCES assets(family_id, id),
    FOREIGN KEY (family_id, created_by) REFERENCES family_members(family_id, user_id),
    FOREIGN KEY (family_id, updated_by) REFERENCES family_members(family_id, user_id),
    CHECK (updated_at >= created_at),
    CHECK (deleted_at IS NULL OR deleted_at >= created_at)
);

CREATE TABLE liabilities (
    id uuid PRIMARY KEY,
    family_id uuid NOT NULL REFERENCES families(id),
    direction text NOT NULL CHECK (direction IN ('borrowed', 'lent')),
    kind text NOT NULL CHECK (kind IN ('personal', 'bank_loan', 'other')),
    counterparty_ciphertext bytea NOT NULL,
    principal_minor bigint NOT NULL CHECK (principal_minor > 0),
    currency text NOT NULL DEFAULT 'INR' REFERENCES currencies(code),
    terms_ciphertext bytea NOT NULL, -- Versioned, approved interest rules, not arbitrary calculations.
    opened_on date NOT NULL,
    revision bigint NOT NULL CHECK (revision > 0),
    created_by uuid NOT NULL,
    updated_by uuid NOT NULL,
    created_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL,
    deleted_at timestamptz,
    UNIQUE (family_id, id),
    FOREIGN KEY (family_id, created_by) REFERENCES family_members(family_id, user_id),
    FOREIGN KEY (family_id, updated_by) REFERENCES family_members(family_id, user_id),
    CHECK (updated_at >= created_at),
    CHECK (deleted_at IS NULL OR deleted_at >= created_at)
);
CREATE TABLE repayment_schedules (
    id uuid PRIMARY KEY,
    family_id uuid NOT NULL,
    liability_id uuid NOT NULL,
    due_on date NOT NULL,
    principal_minor bigint NOT NULL CHECK (principal_minor >= 0),
    interest_minor bigint NOT NULL CHECK (interest_minor >= 0),
    revision bigint NOT NULL CHECK (revision > 0),
    created_by uuid NOT NULL,
    updated_by uuid NOT NULL,
    created_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL,
    deleted_at timestamptz,
    UNIQUE (family_id, id),
    FOREIGN KEY (family_id, liability_id) REFERENCES liabilities(family_id, id),
    FOREIGN KEY (family_id, created_by) REFERENCES family_members(family_id, user_id),
    FOREIGN KEY (family_id, updated_by) REFERENCES family_members(family_id, user_id),
    CHECK (updated_at >= created_at),
    CHECK (deleted_at IS NULL OR deleted_at >= created_at)
);
CREATE TABLE repayments (
    id uuid PRIMARY KEY,
    family_id uuid NOT NULL,
    liability_id uuid NOT NULL,
    journal_id uuid NOT NULL,
    paid_on date NOT NULL,
    principal_minor bigint NOT NULL CHECK (principal_minor >= 0),
    interest_minor bigint NOT NULL CHECK (interest_minor >= 0),
    revision bigint NOT NULL CHECK (revision > 0),
    created_by uuid NOT NULL,
    updated_by uuid NOT NULL,
    created_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL,
    deleted_at timestamptz,
    UNIQUE (family_id, id),
    UNIQUE (family_id, liability_id, journal_id),
    CHECK (principal_minor > 0 OR interest_minor > 0),
    FOREIGN KEY (family_id, liability_id) REFERENCES liabilities(family_id, id),
    FOREIGN KEY (family_id, journal_id) REFERENCES journal_entries(family_id, id),
    FOREIGN KEY (family_id, created_by) REFERENCES family_members(family_id, user_id),
    FOREIGN KEY (family_id, updated_by) REFERENCES family_members(family_id, user_id),
    CHECK (updated_at >= created_at),
    CHECK (deleted_at IS NULL OR deleted_at >= created_at)
);

CREATE TABLE stock_items (
    id uuid PRIMARY KEY,
    family_id uuid NOT NULL,
    business_id uuid NOT NULL,
    label_ciphertext bytea NOT NULL,
    quantity_scale smallint NOT NULL CHECK (quantity_scale BETWEEN 0 AND 9),
    revision bigint NOT NULL CHECK (revision > 0),
    created_by uuid NOT NULL,
    updated_by uuid NOT NULL,
    created_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL,
    deleted_at timestamptz,
    UNIQUE (family_id, id),
    FOREIGN KEY (family_id, business_id) REFERENCES businesses(family_id, id),
    FOREIGN KEY (family_id, created_by) REFERENCES family_members(family_id, user_id),
    FOREIGN KEY (family_id, updated_by) REFERENCES family_members(family_id, user_id),
    CHECK (updated_at >= created_at),
    CHECK (deleted_at IS NULL OR deleted_at >= created_at)
);
CREATE TABLE stock_movements (
    id uuid PRIMARY KEY,
    family_id uuid NOT NULL,
    stock_item_id uuid NOT NULL,
    quantity_delta_scaled bigint NOT NULL CHECK (quantity_delta_scaled <> 0),
    journal_id uuid,
    moved_at timestamptz NOT NULL,
    revision bigint NOT NULL CHECK (revision > 0),
    created_by uuid NOT NULL,
    updated_by uuid NOT NULL,
    created_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL,
    deleted_at timestamptz,
    UNIQUE (family_id, id),
    FOREIGN KEY (family_id, stock_item_id) REFERENCES stock_items(family_id, id),
    FOREIGN KEY (family_id, journal_id) REFERENCES journal_entries(family_id, id),
    FOREIGN KEY (family_id, created_by) REFERENCES family_members(family_id, user_id),
    FOREIGN KEY (family_id, updated_by) REFERENCES family_members(family_id, user_id),
    CHECK (updated_at >= created_at),
    CHECK (deleted_at IS NULL OR deleted_at >= created_at)
);
CREATE TABLE salary_records (
    id uuid PRIMARY KEY,
    family_id uuid NOT NULL,
    business_id uuid NOT NULL,
    worker_reference_ciphertext bytea NOT NULL,
    period_start date NOT NULL,
    period_end date NOT NULL CHECK (period_end >= period_start),
    amount_minor bigint NOT NULL CHECK (amount_minor >= 0),
    currency text NOT NULL DEFAULT 'INR' REFERENCES currencies(code),
    settlement_journal_id uuid,
    revision bigint NOT NULL CHECK (revision > 0),
    created_by uuid NOT NULL,
    updated_by uuid NOT NULL,
    created_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL,
    deleted_at timestamptz,
    UNIQUE (family_id, id),
    FOREIGN KEY (family_id, business_id) REFERENCES businesses(family_id, id),
    FOREIGN KEY (family_id, settlement_journal_id) REFERENCES journal_entries(family_id, id),
    FOREIGN KEY (family_id, created_by) REFERENCES family_members(family_id, user_id),
    FOREIGN KEY (family_id, updated_by) REFERENCES family_members(family_id, user_id),
    CHECK (updated_at >= created_at),
    CHECK (deleted_at IS NULL OR deleted_at >= created_at)
);

CREATE TABLE documents (
    id uuid PRIMARY KEY,
    family_id uuid NOT NULL REFERENCES families(id),
    owner_user_id uuid NOT NULL,
    category text NOT NULL, -- Neutral category only; no identity number fields.
    metadata_ciphertext bytea NOT NULL, -- Title, optional expiry/reminders, private search metadata.
    revision bigint NOT NULL CHECK (revision > 0),
    created_by uuid NOT NULL,
    updated_by uuid NOT NULL,
    created_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL,
    deleted_at timestamptz,
    UNIQUE (family_id, id),
    FOREIGN KEY (family_id, owner_user_id) REFERENCES family_members(family_id, user_id),
    FOREIGN KEY (family_id, created_by) REFERENCES family_members(family_id, user_id),
    FOREIGN KEY (family_id, updated_by) REFERENCES family_members(family_id, user_id),
    CHECK (updated_at >= created_at),
    CHECK (deleted_at IS NULL OR deleted_at >= created_at)
);
-- Shared family visibility: ownership is provenance, never an ACL. No per-document grants.
CREATE TABLE document_versions (
    id uuid PRIMARY KEY,
    family_id uuid NOT NULL,
    document_id uuid NOT NULL,
    version_number integer NOT NULL CHECK (version_number > 0),
    object_path text NOT NULL UNIQUE, -- Opaque immutable path, not a personal filename.
    ciphertext_sha256 bytea NOT NULL CHECK (octet_length(ciphertext_sha256) = 32),
    ciphertext_size bigint NOT NULL CHECK (ciphertext_size > 0),
    envelope_version integer NOT NULL CHECK (envelope_version > 0),
    created_by uuid NOT NULL,
    created_at timestamptz NOT NULL,
    finalized_at timestamptz, -- NULL remains incomplete and cannot count as synchronized.
    CHECK (finalized_at IS NULL OR finalized_at >= created_at),
    UNIQUE (family_id, id),
    UNIQUE (family_id, document_id, version_number),
    FOREIGN KEY (family_id, document_id) REFERENCES documents(family_id, id),
    FOREIGN KEY (family_id, created_by) REFERENCES family_members(family_id, user_id)
);
CREATE TABLE document_key_envelopes (
    family_id uuid NOT NULL,
    version_id uuid NOT NULL,
    recipient_device_id uuid NOT NULL,
    wrapped_key bytea NOT NULL CHECK (octet_length(wrapped_key) > 0),
    key_version integer NOT NULL CHECK (key_version > 0),
    revoked_at timestamptz,
    PRIMARY KEY (family_id, version_id, recipient_device_id, key_version),
    FOREIGN KEY (family_id, version_id) REFERENCES document_versions(family_id, id),
    FOREIGN KEY (family_id, recipient_device_id) REFERENCES devices(family_id, id)
);
CREATE TABLE upload_reservations (
    family_id uuid NOT NULL,
    version_id uuid NOT NULL,
    operation_id uuid NOT NULL,
    uploader_user_id uuid NOT NULL,
    status text NOT NULL CHECK (status IN ('reserved', 'uploaded', 'verified', 'finalized', 'abandoned')),
    expires_at timestamptz NOT NULL,
    PRIMARY KEY (family_id, version_id),
    UNIQUE (family_id, operation_id),
    FOREIGN KEY (family_id, version_id) REFERENCES document_versions(family_id, id),
    FOREIGN KEY (family_id, uploader_user_id) REFERENCES family_members(family_id, user_id)
);

CREATE UNIQUE INDEX one_current_document_device_key
    ON document_key_envelopes(family_id, version_id, recipient_device_id)
    WHERE revoked_at IS NULL;

CREATE TABLE document_access_events (
    id uuid PRIMARY KEY,
    family_id uuid NOT NULL,
    version_id uuid NOT NULL,
    request_id uuid NOT NULL,
    actor_id uuid NOT NULL,
    device_id uuid NOT NULL,
    event_kind text NOT NULL CHECK (event_kind IN
        ('authorized', 'transfer_completed', 'transfer_failed', 'cached_open_reported')),
    source text NOT NULL CHECK (source IN ('gateway', 'device_report')),
    bytes_transferred bigint CHECK (bytes_transferred >= 0),
    occurred_at timestamptz NOT NULL, -- Trusted server ingestion/access time.
    client_occurred_at timestamptz, -- Optional untrusted offline observation.
    UNIQUE (family_id, id),
    UNIQUE (family_id, request_id, event_kind),
    FOREIGN KEY (family_id, version_id) REFERENCES document_versions(family_id, id),
    FOREIGN KEY (family_id, device_id, actor_id) REFERENCES devices(family_id, id, user_id),
    CHECK ((event_kind = 'cached_open_reported') = (source = 'device_report'))
); -- Read audit is append-only. Finalized/authorized-version and byte-count checks need gateway code.

CREATE TABLE backup_snapshots (
    id uuid PRIMARY KEY,
    family_id uuid NOT NULL REFERENCES families(id),
    created_by uuid NOT NULL,
    creator_device_id uuid NOT NULL,
    state text NOT NULL DEFAULT 'building' CHECK (state IN ('building', 'complete', 'failed')),
    archive_format_version integer NOT NULL CHECK (archive_format_version > 0),
    database_schema_version integer NOT NULL CHECK (database_schema_version > 0),
    server_watermark bigint NOT NULL CHECK (server_watermark >= 0),
    authorization_epoch bigint NOT NULL CHECK (authorization_epoch >= 0),
    includes_pending_operations boolean NOT NULL,
    archive_sha256 bytea CHECK (octet_length(archive_sha256) = 32),
    archive_size bigint CHECK (archive_size > 0),
    manifest_sha256 bytea CHECK (octet_length(manifest_sha256) = 32),
    created_at timestamptz NOT NULL,
    archive_verified_at timestamptz CHECK (archive_verified_at >= created_at),
    UNIQUE (family_id, id),
    UNIQUE (family_id, id, state),
    UNIQUE (family_id, id, archive_sha256, archive_size),
    FOREIGN KEY (family_id, creator_device_id, created_by) REFERENCES devices(family_id, id, user_id),
    CHECK ((archive_sha256 IS NULL) = (archive_size IS NULL)),
    CHECK (state <> 'complete' OR (archive_sha256 IS NOT NULL AND archive_size IS NOT NULL
        AND manifest_sha256 IS NOT NULL AND archive_verified_at IS NOT NULL))
); -- Metadata evidence is necessary, not proof of AEAD/integrity verification by itself.

CREATE TABLE backup_destinations (
    id uuid PRIMARY KEY,
    family_id uuid NOT NULL REFERENCES families(id),
    kind text NOT NULL CHECK (kind IN ('local', 'google_drive')),
    configured_by uuid NOT NULL,
    created_at timestamptz NOT NULL,
    revoked_at timestamptz CHECK (revoked_at >= created_at),
    UNIQUE (family_id, id),
    FOREIGN KEY (family_id, configured_by) REFERENCES family_members(family_id, user_id)
); -- No OAuth credentials, Drive account identity or local filesystem path in the shared catalog.

CREATE TABLE backup_copy_attempts (
    id uuid PRIMARY KEY,
    family_id uuid NOT NULL,
    snapshot_id uuid NOT NULL,
    snapshot_state text NOT NULL DEFAULT 'complete' CHECK (snapshot_state = 'complete'),
    destination_id uuid NOT NULL,
    created_by uuid NOT NULL,
    writer_device_id uuid NOT NULL,
    state text NOT NULL DEFAULT 'queued'
        CHECK (state IN ('queued', 'writing', 'verifying', 'verified', 'failed', 'cancelled')),
    observed_sha256 bytea CHECK (octet_length(observed_sha256) = 32),
    observed_size bigint CHECK (observed_size > 0),
    receipt_ciphertext bytea CHECK (octet_length(receipt_ciphertext) > 0),
    created_at timestamptz NOT NULL,
    provider_ack_at timestamptz CHECK (provider_ack_at >= created_at),
    verified_at timestamptz CHECK (verified_at >= provider_ack_at),
    completed_at timestamptz CHECK (completed_at >= verified_at),
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
); -- Independent rows per destination/retry; uploaded bytes alone cannot produce verified state.

CREATE FUNCTION reject_audit_rewrite() RETURNS trigger
LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
    RAISE EXCEPTION 'Audit history is append-only' USING ERRCODE = '55000';
END;
$$;
REVOKE ALL ON FUNCTION reject_audit_rewrite() FROM PUBLIC;
CREATE TRIGGER audit_events_immutable BEFORE UPDATE OR DELETE ON audit_events
    FOR EACH ROW EXECUTE FUNCTION reject_audit_rewrite();
CREATE TRIGGER audit_events_no_truncate BEFORE TRUNCATE ON audit_events
    FOR EACH STATEMENT EXECUTE FUNCTION reject_audit_rewrite();
CREATE TRIGGER document_access_immutable BEFORE UPDATE OR DELETE ON document_access_events
    FOR EACH ROW EXECUTE FUNCTION reject_audit_rewrite();
CREATE TRIGGER document_access_no_truncate BEFORE TRUNCATE ON document_access_events
    FOR EACH STATEMENT EXECUTE FUNCTION reject_audit_rewrite();

CREATE FUNCTION reject_provenance_rewrite() RETURNS trigger
LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
    IF NEW.id IS DISTINCT FROM OLD.id OR NEW.family_id IS DISTINCT FROM OLD.family_id
        OR NEW.created_by IS DISTINCT FROM OLD.created_by THEN
        RAISE EXCEPTION 'Record identity, family and creator are immutable' USING ERRCODE = '55000';
    END IF;
    RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION reject_provenance_rewrite() FROM PUBLIC;
DO $$
DECLARE row record;
BEGIN
    FOR row IN SELECT table_name FROM information_schema.columns
        WHERE table_schema = 'familyvault_proposal' AND column_name = 'created_by'
    LOOP
        EXECUTE format('CREATE TRIGGER immutable_provenance BEFORE UPDATE ON familyvault_proposal.%I '
            'FOR EACH ROW EXECUTE FUNCTION familyvault_proposal.reject_provenance_rewrite()', row.table_name);
    END LOOP;
END;
$$;

-- Explicitly deny all application access until reviewed policies/RPCs exist.
-- FORCE is defense in depth; superusers/service roles can still bypass RLS.
DO $$
DECLARE row record;
BEGIN
    FOR row IN SELECT tablename FROM pg_tables WHERE schemaname = 'familyvault_proposal'
    LOOP
        EXECUTE format('ALTER TABLE familyvault_proposal.%I ENABLE ROW LEVEL SECURITY', row.tablename);
        EXECUTE format('ALTER TABLE familyvault_proposal.%I FORCE ROW LEVEL SECURITY', row.tablename);
        EXECUTE format('REVOKE ALL ON familyvault_proposal.%I FROM PUBLIC', row.tablename);
    END LOOP;
END;
$$;
COMMIT;
