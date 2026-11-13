-- PROPOSAL ONLY. Do not deploy as an application migration.
-- Empty, isolated review schema; no auth identities or family data are inserted.
-- Cross-row rules/RPCs/usable read policies remain review-gated (docs/database.md).
BEGIN;
CREATE SCHEMA familyvault_proposal;
REVOKE ALL ON SCHEMA familyvault_proposal FROM PUBLIC;
SET LOCAL search_path = familyvault_proposal, pg_catalog;

CREATE TABLE currencies (
    code text PRIMARY KEY CHECK (code ~ '^[A-Z]{3}$'),
    minor_unit_scale smallint NOT NULL CHECK (minor_unit_scale BETWEEN 0 AND 6)
);

CREATE TABLE families (
    id uuid PRIMARY KEY,
    display_name text NOT NULL,
    revision bigint NOT NULL CHECK (revision > 0),
    created_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL,
    deleted_at timestamptz
);

CREATE TABLE family_members (
    id uuid PRIMARY KEY,
    family_id uuid NOT NULL REFERENCES families(id),
    user_id uuid NOT NULL, -- Map to auth.users in the reviewed deployment migration.
    role text NOT NULL CHECK (role IN ('administrator', 'member', 'viewer')),
    active boolean NOT NULL DEFAULT false,
    revision bigint NOT NULL CHECK (revision > 0),
    created_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL,
    deleted_at timestamptz,
    UNIQUE (family_id, id),
    UNIQUE (family_id, user_id)
);

CREATE TABLE devices (
    id uuid PRIMARY KEY,
    family_id uuid NOT NULL REFERENCES families(id),
    user_id uuid NOT NULL,
    public_key_envelope bytea, -- Enrollment/key authenticity protocol remains open.
    revoked_at timestamptz,
    created_at timestamptz NOT NULL,
    UNIQUE (family_id, id),
    FOREIGN KEY (family_id, user_id) REFERENCES family_members(family_id, user_id)
);

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
    FOREIGN KEY (family_id, device_id) REFERENCES devices(family_id, id)
);

CREATE TABLE change_events (
    family_id uuid NOT NULL REFERENCES families(id),
    sequence bigint NOT NULL CHECK (sequence > 0),
    entity_type text NOT NULL,
    entity_id uuid NOT NULL,
    revision bigint NOT NULL CHECK (revision > 0),
    is_deleted boolean NOT NULL,
    committed_at timestamptz NOT NULL,
    PRIMARY KEY (family_id, sequence)
); -- Pull RPC resolves authorized current snapshots; never expose this feed directly.

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
    FOREIGN KEY (family_id, device_id) REFERENCES devices(family_id, id)
); -- Append-only privileges and retention in reviewed migration. No payload logging.

CREATE TABLE businesses (
    id uuid PRIMARY KEY,
    family_id uuid NOT NULL REFERENCES families(id),
    name text NOT NULL,
    revision bigint NOT NULL CHECK (revision > 0),
    created_by uuid NOT NULL,
    created_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL,
    deleted_at timestamptz,
    UNIQUE (family_id, id)
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
    currency text NOT NULL REFERENCES currencies(code),
    revision bigint NOT NULL CHECK (revision > 0),
    created_by uuid NOT NULL,
    created_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL,
    deleted_at timestamptz,
    UNIQUE (family_id, id),
    FOREIGN KEY (family_id, business_id) REFERENCES businesses(family_id, id)
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
    created_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL,
    deleted_at timestamptz,
    UNIQUE (family_id, id),
    FOREIGN KEY (family_id, business_id) REFERENCES businesses(family_id, id),
    FOREIGN KEY (family_id, reversal_of) REFERENCES journal_entries(family_id, id)
);

CREATE TABLE journal_postings (
    id uuid PRIMARY KEY,
    family_id uuid NOT NULL,
    journal_id uuid NOT NULL,
    account_id uuid NOT NULL,
    currency text NOT NULL REFERENCES currencies(code),
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
    currency text NOT NULL REFERENCES currencies(code),
    amount_minor bigint NOT NULL CHECK (amount_minor >= 0),
    revision bigint NOT NULL CHECK (revision > 0),
    created_by uuid NOT NULL,
    created_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL,
    deleted_at timestamptz,
    UNIQUE (family_id, id),
    FOREIGN KEY (family_id, account_id) REFERENCES accounts(family_id, id)
);
CREATE UNIQUE INDEX one_active_monthly_budget ON monthly_budgets(family_id, account_id, month_start, currency) WHERE deleted_at IS NULL;

CREATE TABLE savings_observations (
    id uuid PRIMARY KEY,
    family_id uuid NOT NULL REFERENCES families(id),
    observed_on date NOT NULL,
    currency text NOT NULL REFERENCES currencies(code),
    amount_minor bigint NOT NULL,
    source_ciphertext bytea,
    revision bigint NOT NULL CHECK (revision > 0),
    created_by uuid NOT NULL,
    created_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL,
    deleted_at timestamptz,
    UNIQUE (family_id, id)
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
    created_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL,
    deleted_at timestamptz,
    UNIQUE (family_id, id),
    CHECK ((purchase_amount_minor IS NULL) = (purchase_currency IS NULL))
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
    created_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL,
    deleted_at timestamptz,
    UNIQUE (family_id, id),
    FOREIGN KEY (family_id, asset_id) REFERENCES assets(family_id, id),
    FOREIGN KEY (family_id, owner_user_id) REFERENCES family_members(family_id, user_id)
);
CREATE UNIQUE INDEX one_active_asset_owner ON asset_ownerships(family_id, asset_id, owner_user_id) WHERE deleted_at IS NULL;
CREATE TABLE asset_valuations (
    id uuid PRIMARY KEY,
    family_id uuid NOT NULL,
    asset_id uuid NOT NULL,
    valued_at timestamptz NOT NULL,
    amount_minor bigint NOT NULL CHECK (amount_minor >= 0),
    currency text NOT NULL REFERENCES currencies(code),
    source_ciphertext bytea NOT NULL,
    revision bigint NOT NULL CHECK (revision > 0),
    created_by uuid NOT NULL,
    created_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL,
    deleted_at timestamptz,
    UNIQUE (family_id, id),
    FOREIGN KEY (family_id, asset_id) REFERENCES assets(family_id, id)
);

CREATE TABLE liabilities (
    id uuid PRIMARY KEY,
    family_id uuid NOT NULL REFERENCES families(id),
    direction text NOT NULL CHECK (direction IN ('borrowed', 'lent')),
    kind text NOT NULL CHECK (kind IN ('personal', 'bank_loan', 'other')),
    counterparty_ciphertext bytea NOT NULL,
    principal_minor bigint NOT NULL CHECK (principal_minor > 0),
    currency text NOT NULL REFERENCES currencies(code),
    terms_ciphertext bytea NOT NULL, -- Versioned, approved interest rules, not arbitrary calculations.
    opened_on date NOT NULL,
    revision bigint NOT NULL CHECK (revision > 0),
    created_by uuid NOT NULL,
    created_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL,
    deleted_at timestamptz,
    UNIQUE (family_id, id)
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
    created_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL,
    deleted_at timestamptz,
    UNIQUE (family_id, id),
    FOREIGN KEY (family_id, liability_id) REFERENCES liabilities(family_id, id)
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
    created_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL,
    deleted_at timestamptz,
    UNIQUE (family_id, id),
    UNIQUE (family_id, liability_id, journal_id),
    CHECK (principal_minor > 0 OR interest_minor > 0),
    FOREIGN KEY (family_id, liability_id) REFERENCES liabilities(family_id, id),
    FOREIGN KEY (family_id, journal_id) REFERENCES journal_entries(family_id, id)
);

CREATE TABLE stock_items (
    id uuid PRIMARY KEY,
    family_id uuid NOT NULL,
    business_id uuid NOT NULL,
    label_ciphertext bytea NOT NULL,
    quantity_scale smallint NOT NULL CHECK (quantity_scale BETWEEN 0 AND 9),
    revision bigint NOT NULL CHECK (revision > 0),
    created_by uuid NOT NULL,
    created_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL,
    deleted_at timestamptz,
    UNIQUE (family_id, id),
    FOREIGN KEY (family_id, business_id) REFERENCES businesses(family_id, id)
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
    created_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL,
    deleted_at timestamptz,
    UNIQUE (family_id, id),
    FOREIGN KEY (family_id, stock_item_id) REFERENCES stock_items(family_id, id),
    FOREIGN KEY (family_id, journal_id) REFERENCES journal_entries(family_id, id)
);
CREATE TABLE salary_records (
    id uuid PRIMARY KEY,
    family_id uuid NOT NULL,
    business_id uuid NOT NULL,
    worker_reference_ciphertext bytea NOT NULL,
    period_start date NOT NULL,
    period_end date NOT NULL CHECK (period_end >= period_start),
    amount_minor bigint NOT NULL CHECK (amount_minor >= 0),
    currency text NOT NULL REFERENCES currencies(code),
    settlement_journal_id uuid,
    revision bigint NOT NULL CHECK (revision > 0),
    created_by uuid NOT NULL,
    created_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL,
    deleted_at timestamptz,
    UNIQUE (family_id, id),
    FOREIGN KEY (family_id, business_id) REFERENCES businesses(family_id, id),
    FOREIGN KEY (family_id, settlement_journal_id) REFERENCES journal_entries(family_id, id)
);

CREATE TABLE documents (
    id uuid PRIMARY KEY,
    family_id uuid NOT NULL REFERENCES families(id),
    owner_user_id uuid NOT NULL,
    category text NOT NULL, -- Neutral category only; no identity number fields.
    metadata_ciphertext bytea NOT NULL, -- Title, optional expiry/reminders, private search metadata.
    revision bigint NOT NULL CHECK (revision > 0),
    created_by uuid NOT NULL,
    created_at timestamptz NOT NULL,
    updated_at timestamptz NOT NULL,
    deleted_at timestamptz,
    UNIQUE (family_id, id),
    FOREIGN KEY (family_id, owner_user_id) REFERENCES family_members(family_id, user_id)
);
CREATE TABLE document_grants (
    family_id uuid NOT NULL,
    document_id uuid NOT NULL,
    user_id uuid NOT NULL,
    permission text NOT NULL CHECK (permission IN ('read', 'write', 'manage')),
    expires_at timestamptz,
    revoked_at timestamptz,
    PRIMARY KEY (family_id, document_id, user_id),
    FOREIGN KEY (family_id, document_id) REFERENCES documents(family_id, id),
    FOREIGN KEY (family_id, user_id) REFERENCES family_members(family_id, user_id)
);
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
    UNIQUE (family_id, id),
    UNIQUE (family_id, document_id, version_number),
    FOREIGN KEY (family_id, document_id) REFERENCES documents(family_id, id)
);
CREATE TABLE document_key_envelopes (
    family_id uuid NOT NULL,
    version_id uuid NOT NULL,
    recipient_device_id uuid NOT NULL,
    wrapped_key bytea NOT NULL,
    key_version integer NOT NULL CHECK (key_version > 0),
    revoked_at timestamptz,
    PRIMARY KEY (family_id, version_id, recipient_device_id),
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
