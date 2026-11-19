-- Typed family asset records, ownership and immutable valuation history.
BEGIN;
SET LOCAL ROLE familyvault_executor;
SET LOCAL search_path = '';

CREATE TABLE fv_data.wealth_assets (
  id uuid NOT NULL,
  family_id uuid NOT NULL REFERENCES fv_data.families(id),
  revision bigint NOT NULL CHECK (revision > 0),
  created_by uuid NOT NULL,
  updated_by uuid NOT NULL,
  created_at_us bigint NOT NULL CHECK (created_at_us >= 0),
  updated_at_us bigint NOT NULL CHECK (updated_at_us >= created_at_us),
  deleted_at_us bigint CHECK (deleted_at_us >= created_at_us),
  name text NOT NULL CHECK (length(btrim(name)) BETWEEN 1 AND 120),
  kind text NOT NULL CHECK (kind IN ('property','land','gold','silver','jewellery','vehicle','deposit','investment','other')),
  account_id uuid NOT NULL,
  family_ownership_bps integer NOT NULL CHECK (family_ownership_bps BETWEEN 1 AND 10000),
  valuation_state text NOT NULL CHECK (valuation_state IN ('unrecorded','recorded','closed')),
  closed_on date CHECK (closed_on BETWEEN DATE '1900-01-01' AND DATE '2200-12-31'),
  purchase_total_minor bigint CHECK (purchase_total_minor >= 0),
  purchase_ownership_bps integer NOT NULL CHECK (purchase_ownership_bps BETWEEN 1 AND 10000),
  purchased_on date CHECK (purchased_on BETWEEN DATE '1900-01-01' AND DATE '2200-12-31'),
  currency text NOT NULL CHECK (currency = 'INR'),
  notes text NOT NULL CHECK (length(notes) <= 4000),
  PRIMARY KEY (family_id,id),
  UNIQUE (family_id,account_id),
  FOREIGN KEY (family_id,created_by) REFERENCES fv_data.members(family_id,id),
  FOREIGN KEY (family_id,updated_by) REFERENCES fv_data.members(family_id,id),
  FOREIGN KEY (family_id,account_id) REFERENCES fv_data.ledger_accounts(family_id,id),
  CHECK ((valuation_state='closed') = (deleted_at_us IS NOT NULL)),
  CHECK ((valuation_state='closed') = (closed_on IS NOT NULL)),
  CHECK (closed_on >= purchased_on),
  CHECK (purchase_total_minor IS NULL OR purchased_on IS NOT NULL)
);

CREATE TABLE fv_data.property_details (
  asset_id uuid NOT NULL,
  family_id uuid NOT NULL,
  city text NOT NULL CHECK (length(btrim(city)) BETWEEN 1 AND 120),
  location text NOT NULL CHECK (length(location) <= 500),
  record_reference text CHECK (length(record_reference) <= 200),
  area_milli bigint CHECK (area_milli > 0),
  area_unit text CHECK (length(btrim(area_unit)) BETWEEN 1 AND 24),
  PRIMARY KEY (family_id,asset_id),
  FOREIGN KEY (family_id,asset_id) REFERENCES fv_data.wealth_assets(family_id,id),
  CHECK ((area_milli IS NULL) = (area_unit IS NULL))
);

CREATE TABLE fv_data.metal_details (
  asset_id uuid NOT NULL,
  family_id uuid NOT NULL,
  weight_mg bigint NOT NULL CHECK (weight_mg > 0),
  metal text NOT NULL CHECK (metal IN ('gold','silver')),
  purity_ppm integer CHECK (purity_ppm BETWEEN 1 AND 1000000),
  purity_kind text NOT NULL CHECK (purity_kind IN ('unrecorded','nominal','assayed')),
  karat integer CHECK (karat IN (18,22,24)),
  purchase_rate_minor_per_gram bigint CHECK (purchase_rate_minor_per_gram >= 0),
  making_charges_minor bigint CHECK (making_charges_minor >= 0),
  PRIMARY KEY (family_id,asset_id),
  FOREIGN KEY (family_id,asset_id) REFERENCES fv_data.wealth_assets(family_id,id),
  CHECK ((purity_kind='unrecorded') = (purity_ppm IS NULL)),
  CHECK (purity_kind<>'nominal' OR (karat IS NOT NULL AND purity_ppm=(karat*1000000+12)/24)),
  CHECK (metal<>'silver' OR karat IS NULL)
);

CREATE TABLE fv_data.investment_details (
  asset_id uuid NOT NULL,
  family_id uuid NOT NULL,
  instrument text NOT NULL CHECK (length(btrim(instrument)) BETWEEN 1 AND 120),
  symbol text CHECK (length(symbol) <= 80),
  quantity_scaled bigint CHECK (quantity_scaled > 0),
  quantity_scale integer CHECK (quantity_scale BETWEEN 0 AND 9),
  PRIMARY KEY (family_id,asset_id),
  FOREIGN KEY (family_id,asset_id) REFERENCES fv_data.wealth_assets(family_id,id),
  CHECK ((quantity_scaled IS NULL) = (quantity_scale IS NULL))
);

CREATE TABLE fv_data.asset_ownerships (
  id uuid NOT NULL,
  family_id uuid NOT NULL,
  revision bigint NOT NULL CHECK (revision > 0),
  created_by uuid NOT NULL,
  updated_by uuid NOT NULL,
  created_at_us bigint NOT NULL CHECK (created_at_us >= 0),
  updated_at_us bigint NOT NULL CHECK (updated_at_us >= created_at_us),
  deleted_at_us bigint CHECK (deleted_at_us >= created_at_us),
  asset_id uuid NOT NULL,
  member_id uuid,
  owner_label text NOT NULL CHECK (length(btrim(owner_label)) BETWEEN 1 AND 120),
  share_bps integer NOT NULL CHECK (share_bps BETWEEN 1 AND 10000),
  PRIMARY KEY (family_id,id),
  FOREIGN KEY (family_id,asset_id) REFERENCES fv_data.wealth_assets(family_id,id),
  FOREIGN KEY (family_id,member_id) REFERENCES fv_data.members(family_id,id),
  FOREIGN KEY (family_id,created_by) REFERENCES fv_data.members(family_id,id),
  FOREIGN KEY (family_id,updated_by) REFERENCES fv_data.members(family_id,id)
);
CREATE UNIQUE INDEX fv_active_asset_owner ON fv_data.asset_ownerships(family_id,asset_id,member_id)
  WHERE member_id IS NOT NULL AND deleted_at_us IS NULL;
CREATE INDEX fv_asset_owners ON fv_data.asset_ownerships(family_id,asset_id) WHERE deleted_at_us IS NULL;

CREATE TABLE fv_data.asset_valuations (
  id uuid NOT NULL,
  family_id uuid NOT NULL,
  created_by uuid NOT NULL,
  device_id uuid NOT NULL,
  created_at_us bigint NOT NULL CHECK (created_at_us >= 0),
  asset_id uuid NOT NULL,
  asset_revision bigint NOT NULL CHECK (asset_revision > 0),
  event_index integer NOT NULL CHECK (event_index BETWEEN 0 AND 1),
  journal_id uuid,
  valued_on date NOT NULL CHECK (valued_on BETWEEN DATE '1900-01-01' AND DATE '2200-12-31'),
  total_value_minor bigint NOT NULL CHECK (total_value_minor >= 0),
  family_value_minor bigint NOT NULL CHECK (family_value_minor >= 0),
  previous_family_value_minor bigint NOT NULL,
  ownership_bps integer NOT NULL CHECK (ownership_bps BETWEEN 1 AND 10000),
  source text NOT NULL CHECK (source IN ('purchase','manual','metal_rate','carry_forward')),
  notes text NOT NULL CHECK (length(btrim(notes)) BETWEEN 1 AND 1000),
  basis_json text NOT NULL CHECK (jsonb_typeof(basis_json::jsonb)='object'),
  currency text NOT NULL CHECK (currency='INR'),
  PRIMARY KEY (family_id,id),
  UNIQUE (family_id,asset_id,asset_revision,event_index),
  UNIQUE (family_id,journal_id),
  FOREIGN KEY (family_id,asset_id) REFERENCES fv_data.wealth_assets(family_id,id),
  FOREIGN KEY (family_id,journal_id) REFERENCES fv_data.ledger_journals(family_id,id),
  FOREIGN KEY (family_id,device_id,created_by) REFERENCES fv_data.devices(family_id,id,member_id),
  CHECK ((family_value_minor=previous_family_value_minor) = (journal_id IS NULL)),
  CHECK (family_value_minor=div(total_value_minor::numeric*ownership_bps+5000,10000))
);
CREATE INDEX fv_asset_quote_dates ON fv_data.asset_valuations(family_id,asset_id,valued_on,asset_revision,event_index);
CREATE TRIGGER fv_asset_valuations_immutable BEFORE UPDATE OR DELETE OR TRUNCATE ON fv_data.asset_valuations
  FOR EACH STATEMENT EXECUTE FUNCTION fv_internal.forbid_audit_change();
DO $$
DECLARE table_name text;
BEGIN
  FOREACH table_name IN ARRAY ARRAY['wealth_assets','property_details','metal_details','investment_details','asset_ownerships','asset_valuations'] LOOP
    EXECUTE format('ALTER TABLE fv_data.%I ENABLE ROW LEVEL SECURITY',table_name);
    EXECUTE format('ALTER TABLE fv_data.%I FORCE ROW LEVEL SECURITY',table_name);
    EXECUTE format('CREATE POLICY internal_executor ON fv_data.%I TO familyvault_executor USING (true) WITH CHECK (true)',table_name);
    EXECUTE format('REVOKE ALL ON TABLE fv_data.%I FROM PUBLIC, anon, authenticated, service_role',table_name);
    IF table_name <> 'asset_valuations' THEN
      EXECUTE format('CREATE TRIGGER fv_asset_history_retain BEFORE DELETE OR TRUNCATE ON fv_data.%I FOR EACH STATEMENT EXECUTE FUNCTION fv_internal.forbid_audit_change()',table_name);
    END IF;
  END LOOP;
END;
$$;

CREATE FUNCTION fv_internal.apply_asset_details(asset fv_data.wealth_assets, bundle jsonb, editing boolean) RETURNS void
LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE property fv_data.property_details;
DECLARE metal fv_data.metal_details;
DECLARE investment fv_data.investment_details;
DECLARE previous jsonb;
BEGIN
  IF (bundle ? 'property') <> (asset.kind IN ('property','land'))
    OR (bundle ? 'metal') <> (asset.kind IN ('gold','silver','jewellery'))
    OR (bundle ? 'investment') <> (asset.kind='investment') THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Asset details must match the holding type';
  END IF;
  IF editing THEN
    SELECT jsonb_build_object(
      'property', coalesce((SELECT jsonb_agg(to_jsonb(p)) FROM fv_data.property_details p
        WHERE (p.family_id,p.asset_id)=(asset.family_id,asset.id)),'[]'::jsonb),
      'metal', coalesce((SELECT jsonb_agg(to_jsonb(m)) FROM fv_data.metal_details m
        WHERE (m.family_id,m.asset_id)=(asset.family_id,asset.id)),'[]'::jsonb),
      'investment', coalesce((SELECT jsonb_agg(to_jsonb(i)) FROM fv_data.investment_details i
        WHERE (i.family_id,i.asset_id)=(asset.family_id,asset.id)),'[]'::jsonb)) INTO previous;
    IF bundle->'previous_details' IS DISTINCT FROM previous THEN
      RAISE EXCEPTION USING ERRCODE = 'PT409', MESSAGE = 'The asset details changed before synchronization';
    END IF;
  END IF;
  IF bundle ? 'property' THEN
    SELECT * INTO property FROM jsonb_populate_record(NULL::fv_data.property_details,bundle->'property');
    IF to_jsonb(property) IS DISTINCT FROM bundle->'property' OR
      (property.family_id,property.asset_id) IS DISTINCT FROM (asset.family_id,asset.id) THEN
      RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'Property fields must belong to this asset';
    END IF;
    INSERT INTO fv_data.property_details SELECT (property).* ON CONFLICT (family_id,asset_id) DO UPDATE
      SET city=excluded.city,location=excluded.location,record_reference=excluded.record_reference,
          area_milli=excluded.area_milli,area_unit=excluded.area_unit;
  ELSIF bundle ? 'metal' THEN
    SELECT * INTO metal FROM jsonb_populate_record(NULL::fv_data.metal_details,bundle->'metal');
    IF to_jsonb(metal) IS DISTINCT FROM bundle->'metal' OR
      (metal.family_id,metal.asset_id) IS DISTINCT FROM (asset.family_id,asset.id) OR
      NOT (asset.kind IN (metal.metal,'jewellery')) THEN
      RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'Metal fields must belong to this asset';
    END IF;
    INSERT INTO fv_data.metal_details SELECT (metal).* ON CONFLICT (family_id,asset_id) DO UPDATE
      SET weight_mg=excluded.weight_mg,metal=excluded.metal,purity_ppm=excluded.purity_ppm,
          purity_kind=excluded.purity_kind,karat=excluded.karat,
          purchase_rate_minor_per_gram=excluded.purchase_rate_minor_per_gram,making_charges_minor=excluded.making_charges_minor;
  ELSIF bundle ? 'investment' THEN
    SELECT * INTO investment FROM jsonb_populate_record(NULL::fv_data.investment_details,bundle->'investment');
    IF to_jsonb(investment) IS DISTINCT FROM bundle->'investment' OR
      (investment.family_id,investment.asset_id) IS DISTINCT FROM (asset.family_id,asset.id) THEN
      RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'Investment fields must belong to this asset';
    END IF;
    INSERT INTO fv_data.investment_details SELECT (investment).* ON CONFLICT (family_id,asset_id) DO UPDATE
      SET instrument=excluded.instrument,symbol=excluded.symbol,
          quantity_scaled=excluded.quantity_scaled,quantity_scale=excluded.quantity_scale;
  END IF;
END;
$$;

CREATE FUNCTION fv_internal.apply_asset_ownerships(actor fv_internal.device_context, asset fv_data.wealth_assets, owners jsonb)
RETURNS void LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE row_input jsonb;
DECLARE incoming fv_data.asset_ownerships;
DECLARE stored fv_data.asset_ownerships;
BEGIN
  IF jsonb_typeof(owners) IS DISTINCT FROM 'array' OR jsonb_array_length(owners) > 200 THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Complete ownership replacement records required';
  END IF;
  IF EXISTS (SELECT 1 FROM fv_data.asset_ownerships o
    WHERE (o.family_id,o.asset_id)=(actor.family_id,asset.id) AND o.deleted_at_us IS NULL AND NOT EXISTS (
      SELECT 1 FROM jsonb_array_elements(owners) r WHERE r->>'id'=o.id::text AND r->>'deleted_at_us' IS NOT NULL)) THEN
    RAISE EXCEPTION USING ERRCODE = 'PT409', MESSAGE = 'Prior ownership allocations must be retained in history';
  END IF;
  FOR row_input IN SELECT r FROM jsonb_array_elements(owners) r ORDER BY (r->>'deleted_at_us' IS NULL) LOOP
    SELECT * INTO incoming FROM jsonb_populate_record(NULL::fv_data.asset_ownerships,row_input);
    IF to_jsonb(incoming) IS DISTINCT FROM row_input OR
      (incoming.family_id,incoming.asset_id) IS DISTINCT FROM (actor.family_id,asset.id) THEN
      RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'Ownership must belong to this family holding';
    END IF;
    SELECT * INTO stored FROM fv_data.asset_ownerships WHERE (family_id,id)=(actor.family_id,incoming.id);
    IF (stored.id IS NULL) <> (incoming.deleted_at_us IS NULL) OR stored.deleted_at_us IS NOT NULL THEN
      RAISE EXCEPTION USING ERRCODE = 'PT409', MESSAGE = 'Ownership changes must close prior rows and add new ones';
    END IF;
    PERFORM fv_internal.check_record_revision(actor,row_input,
      CASE WHEN stored.id IS NULL THEN NULL ELSE to_jsonb(stored) END,
      coalesce(stored.revision,0),ARRAY['deleted_at_us']);
    IF stored.id IS NULL THEN
      INSERT INTO fv_data.asset_ownerships SELECT (incoming).*;
    ELSE
      UPDATE fv_data.asset_ownerships SET deleted_at_us=incoming.deleted_at_us,updated_by=incoming.updated_by,
        updated_at_us=incoming.updated_at_us,revision=incoming.revision WHERE (family_id,id)=(actor.family_id,incoming.id);
    END IF;
  END LOOP;
  IF (SELECT count(*) FROM fv_data.asset_ownerships WHERE (family_id,asset_id)=(actor.family_id,asset.id)
      AND deleted_at_us IS NULL) > 100 THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Too many ownership allocations';
  END IF;
END;
$$;

CREATE FUNCTION fv_internal.apply_asset_valuations(actor fv_internal.device_context, envelope jsonb,
  asset fv_data.wealth_assets, prior fv_data.wealth_assets, bundle jsonb, links jsonb) RETURNS uuid[]
LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE valuations jsonb := bundle->'valuations';
DECLARE item jsonb;
DECLARE quote fv_data.asset_valuations;
DECLARE following fv_data.asset_valuations;
DECLARE share integer;
DECLARE metal fv_data.metal_details;
DECLARE basis jsonb;
DECLARE rate bigint;
DECLARE quote_purity bigint;
DECLARE numerator numeric;
DECLARE denominator numeric;
DECLARE book numeric;
DECLARE delta numeric;
DECLARE contra uuid;
DECLARE link jsonb;
DECLARE journal jsonb;
DECLARE purpose text;
DECLARE used_journals uuid[] := ARRAY[]::uuid[];
DECLARE position integer := 0;
DECLARE creating boolean := prior.id IS NULL;
DECLARE new_share boolean := NOT creating AND asset.family_ownership_bps <> prior.family_ownership_bps;
BEGIN
  IF jsonb_typeof(valuations) IS DISTINCT FROM 'array' OR jsonb_array_length(valuations) NOT BETWEEN 1 AND 2 THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Complete ordered asset quotes required';
  END IF;
  FOR item IN SELECT * FROM jsonb_array_elements(valuations) LOOP
    SELECT * INTO quote FROM jsonb_populate_record(NULL::fv_data.asset_valuations,item);
    IF to_jsonb(quote) IS DISTINCT FROM item OR
      (quote.family_id,quote.created_by,quote.device_id,quote.asset_id,quote.asset_revision,quote.event_index)
      IS DISTINCT FROM (actor.family_id,actor.member_id,actor.device_id,asset.id,asset.revision,position) THEN
      RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'Quote scope or authorship is invalid';
    END IF;
    IF quote.valued_on < asset.purchased_on OR quote.valued_on > asset.closed_on THEN
      RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Quote date is outside the holding history';
    END IF;
    basis := quote.basis_json::jsonb;
    purpose := 'valuation';
    IF creating THEN
      share := asset.purchase_ownership_bps;
      IF position=0 AND asset.purchase_total_minor IS NOT NULL THEN
        IF (quote.source,quote.total_value_minor,quote.valued_on,basis)
          IS DISTINCT FROM ('purchase'::text,asset.purchase_total_minor,asset.purchased_on,'{}'::jsonb) THEN
          RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'The acquisition quote must match the recorded purchase';
        END IF;
        purpose := 'purchase';
      ELSIF (position=1 AND asset.purchase_total_minor IS NULL)
        OR (quote.source,basis) IS DISTINCT FROM ('manual'::text,'{}'::jsonb) THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Initial quotes need the supplied manual value';
      END IF;
    ELSIF position=0 THEN
      SELECT * INTO following FROM fv_data.asset_valuations
        WHERE (family_id,asset_id)=(asset.family_id,asset.id) AND valued_on>quote.valued_on
        ORDER BY valued_on,asset_revision DESC,event_index DESC LIMIT 1;
      IF jsonb_array_length(valuations) <> (CASE WHEN following.id IS NULL THEN 1 ELSE 2 END) THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'A backdated quote must preserve the following valuation';
      END IF;
      IF new_share THEN
        share := asset.family_ownership_bps;
        IF asset.closed_on IS NOT NULL OR following.id IS NOT NULL OR
          (quote.source,basis) IS DISTINCT FROM ('manual'::text,jsonb_build_object('previous_ownership_bps',prior.family_ownership_bps)) THEN
          RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'New ownership requires a current quote and its prior share';
        END IF;
      ELSE
        SELECT ownership_bps INTO share FROM fv_data.asset_valuations
          WHERE (family_id,asset_id)=(asset.family_id,asset.id) AND valued_on<=quote.valued_on
          ORDER BY valued_on DESC,asset_revision DESC,event_index DESC LIMIT 1;
        share := coalesce(share,asset.purchase_ownership_bps);
        IF quote.source='metal_rate' THEN
          PERFORM fv_internal.fields(basis,ARRAY['weight_mg','holding_purity_ppm','rate_minor_per_gram','quote_purity_ppm']);
          SELECT * INTO metal FROM fv_data.metal_details WHERE (family_id,asset_id)=(asset.family_id,asset.id);
          rate := fv_internal.input_int(basis,'rate_minor_per_gram');
          quote_purity := fv_internal.input_int(basis,'quote_purity_ppm');
          IF (metal.weight_mg,metal.purity_ppm::bigint)
             IS DISTINCT FROM (fv_internal.input_int(basis,'weight_mg'),fv_internal.input_int(basis,'holding_purity_ppm'))
             OR rate<0 OR quote_purity NOT BETWEEN 1 AND 1000000 THEN
            RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Metal rate must use the holding weight and recorded purity';
          END IF;
          numerator := metal.weight_mg::numeric * rate * metal.purity_ppm;
          denominator := 1000 * quote_purity;
          IF quote.total_value_minor IS DISTINCT FROM div(2*numerator+denominator,2*denominator) THEN
            RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Metal valuation does not match the exact quoted rate';
          END IF;
        ELSIF (quote.source,basis) IS DISTINCT FROM ('manual'::text,'{}'::jsonb) THEN
          RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Invalid asset quote source';
        END IF;
      END IF;
    ELSE
      share := following.ownership_bps;
      purpose := 'valuation_bridge';
      IF following.id IS NULL OR (quote.valued_on,quote.total_value_minor,quote.source,basis)
        IS DISTINCT FROM (following.valued_on,following.total_value_minor,'carry_forward'::text,
          jsonb_build_object('preserves_valuation_id',following.id)) THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'The bridge must preserve the following quote';
      END IF;
    END IF;

    book := fv_internal.ledger_balance_through(asset.family_id,asset.account_id,quote.valued_on,asset.closed_on IS NOT NULL);
    IF quote.ownership_bps IS DISTINCT FROM share OR quote.previous_family_value_minor IS DISTINCT FROM book OR
      quote.family_value_minor IS DISTINCT FROM div(quote.total_value_minor::numeric*share+5000,10000) THEN
      RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'The valuation must match the recorded basis and family share';
    END IF;
    delta := quote.family_value_minor::numeric - book;
    IF delta <> 0 THEN
      SELECT r INTO link FROM jsonb_array_elements(links) r WHERE r->>'journal_id'=quote.journal_id::text;
      journal := fv_internal.bundle_journal(bundle,quote.journal_id);
      contra := fv_internal.chart_id(asset.family_id,'asset_revaluation');
      IF purpose='purchase' THEN
        purpose := link->>'purpose';
        IF purpose='opening' THEN
          contra := fv_internal.chart_id(asset.family_id,'opening');
        ELSIF purpose='acquisition' THEN
          SELECT fv_internal.input_id(p,'account_id') INTO contra FROM jsonb_array_elements(journal->'postings') p
            WHERE p->>'account_id'<>asset.account_id::text LIMIT 1;
          IF NOT fv_internal.liquid_ledger_account(asset.family_id,contra) THEN
            RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Asset funding needs a family cash or bank account';
          END IF;
        ELSE
          RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'An acquisition needs an opening or funded journal';
        END IF;
      END IF;
      IF (link->>'purpose',journal->>'occurred_on',journal->>'kind')
        IS DISTINCT FROM (purpose,quote.valued_on::text,CASE WHEN purpose='opening' THEN 'opening'::text ELSE 'adjustment'::text END) THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'A valuation journal must match its quote and purpose';
      END IF;
      PERFORM fv_internal.require_postings(journal,ARRAY[asset.account_id,contra],ARRAY[delta,-delta]);
      PERFORM fv_internal.apply_linked_journal(actor,envelope,bundle,link,'asset',asset.id,NULL,ARRAY[asset.account_id]);
      used_journals := array_append(used_journals,quote.journal_id);
    END IF;
    INSERT INTO fv_data.asset_valuations SELECT (quote).*;
    position := position+1;
  END LOOP;
  RETURN used_journals;
END;
$$;

CREATE FUNCTION fv_internal.apply_asset_journals(actor fv_internal.device_context, envelope jsonb,
  asset fv_data.wealth_assets, mode text, bundle jsonb, links jsonb, consumed uuid[]) RETURNS void
LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE link jsonb;
DECLARE journal jsonb;
DECLARE journal_id uuid;
DECLARE purpose text;
DECLARE prior_purpose text;
DECLARE entry_date date;
DECLARE liquid uuid;
DECLARE amount numeric;
DECLARE book numeric;
DECLARE count_journals integer := 0;
DECLARE scope_type text := CASE WHEN mode='rent' THEN 'asset_rent' ELSE 'asset' END;
BEGIN
  FOR link IN SELECT * FROM jsonb_array_elements(links) LOOP
    journal_id := fv_internal.input_id(link,'journal_id');
    IF journal_id=ANY(consumed) THEN CONTINUE; END IF;
    journal := fv_internal.bundle_journal(bundle,journal_id);
    purpose := link->>'purpose';
    entry_date := (journal->>'occurred_on')::date;
    count_journals := count_journals + 1;
    CASE
      WHEN mode='dispose' AND purpose='disposal' THEN
        book := fv_internal.ledger_balance_through(asset.family_id,asset.account_id,asset.closed_on);
        SELECT fv_internal.input_id(p,'account_id'),fv_internal.input_int(p,'amount_minor')
          INTO liquid,amount FROM jsonb_array_elements(journal->'postings') p
          WHERE fv_internal.liquid_ledger_account(asset.family_id,fv_internal.input_id(p,'account_id')) LIMIT 1;
        amount := coalesce(amount,0);
        IF count_journals<>1 OR journal->>'kind' IS DISTINCT FROM 'adjustment'
          OR entry_date IS DISTINCT FROM asset.closed_on OR book<0 OR (liquid IS NOT NULL AND amount<=0) THEN
          RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Invalid disposal journal';
        END IF;
        PERFORM fv_internal.require_postings(journal,
          ARRAY[asset.account_id,liquid,fv_internal.chart_id(asset.family_id,'capital_disposals')],
          ARRAY[-book,amount,book-amount]);
      WHEN mode='quote' AND purpose='disposal_bridge' THEN
        book := fv_internal.ledger_balance_through(asset.family_id,asset.account_id,asset.closed_on);
        IF count_journals<>1 OR asset.closed_on IS NULL OR entry_date IS DISTINCT FROM asset.closed_on
          OR journal->>'kind' IS DISTINCT FROM 'adjustment' OR book=0 THEN
          RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'A disposal bridge must preserve the closed balance';
        END IF;
        PERFORM fv_internal.require_postings(journal,
          ARRAY[asset.account_id,fv_internal.chart_id(asset.family_id,'asset_revaluation')],ARRAY[-book,book]);
      WHEN mode IN ('restore','rent') AND purpose='reversal' THEN
        SELECT l.purpose INTO prior_purpose FROM fv_data.aggregate_journal_links l
          WHERE (l.family_id,l.journal_id)=(asset.family_id,fv_internal.input_id(journal,'reverses_id'));
        IF (mode='restore' AND coalesce(prior_purpose,'') NOT IN ('disposal','disposal_bridge')) OR
          (mode='rent' AND prior_purpose IS DISTINCT FROM 'rent') THEN
          RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'The original journal is outside this asset operation';
        END IF;
      WHEN mode='rent' AND purpose='rent' THEN
        SELECT fv_internal.input_id(p,'account_id'),fv_internal.input_int(p,'amount_minor')
          INTO liquid,amount FROM jsonb_array_elements(journal->'postings') p
          WHERE fv_internal.liquid_ledger_account(asset.family_id,fv_internal.input_id(p,'account_id')) LIMIT 1;
        IF liquid IS NULL OR amount<=0 OR journal->>'kind' IS DISTINCT FROM 'income'
          OR entry_date<asset.purchased_on OR entry_date>asset.closed_on THEN
          RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Rent must be dated cash or bank income for this property';
        END IF;
        PERFORM fv_internal.require_postings(journal,
          ARRAY[liquid,fv_internal.chart_id(asset.family_id,'rental')],ARRAY[amount,-amount]);
      ELSE
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Unsupported asset journal purpose';
    END CASE;
    PERFORM fv_internal.apply_linked_journal(actor,envelope,bundle,link,scope_type,asset.id,NULL,ARRAY[asset.account_id]);
  END LOOP;
  IF mode='rent' AND count_journals<>1 THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Record or reverse one rent entry at a time';
  END IF;
  IF mode='restore' AND EXISTS (
      SELECT 1 FROM fv_data.aggregate_journal_links l JOIN fv_data.ledger_journals j
        ON (j.family_id,j.id)=(l.family_id,l.journal_id)
      WHERE (l.family_id,l.aggregate_type,l.aggregate_id)=(asset.family_id,'asset',asset.id)
        AND l.purpose IN ('disposal','disposal_bridge') AND j.deleted_at_us IS NULL) THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Restoring a holding must reverse its active disposal journals';
  END IF;
  IF asset.closed_on IS NOT NULL AND fv_internal.ledger_balance_through(asset.family_id,asset.account_id,NULL)<>0 THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'A closed holding must have zero book value';
  END IF;
END;
$$;

CREATE FUNCTION fv_internal.apply_shared_asset(actor fv_internal.device_context, envelope jsonb,
  record jsonb, bundle jsonb, base bigint) RETURNS void
LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE asset fv_data.wealth_assets;
DECLARE prior fv_data.wealth_assets;
DECLARE links jsonb;
DECLARE consumed uuid[] := ARRAY[]::uuid[];
DECLARE mode text;
DECLARE mutable text[];
DECLARE latest date;
DECLARE known boolean;
BEGIN
  PERFORM fv_internal.fields(bundle,ARRAY['accounts','property','metal','investment','ownerships',
    'valuations','previous_details','journals','journal_links']);
  SELECT * INTO asset FROM jsonb_populate_record(NULL::fv_data.wealth_assets,record);
  IF to_jsonb(asset) IS DISTINCT FROM record THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Use canonical holding values';
  END IF;
  SELECT * INTO prior FROM fv_data.wealth_assets WHERE (family_id,id)=(actor.family_id,asset.id);
  IF base=0 THEN
    mode := 'create';
    mutable := ARRAY[]::text[];
    IF bundle ? 'previous_details' OR (asset.purchase_total_minor IS NOT NULL AND NOT (bundle ? 'valuations'))
      OR asset.purchase_ownership_bps IS DISTINCT FROM asset.family_ownership_bps THEN
      RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'A new holding needs its original ownership and purchase basis';
    END IF;
  ELSIF prior.closed_on IS NULL AND asset.closed_on IS NOT NULL THEN
    mode := 'dispose';
    mutable := ARRAY['closed_on','deleted_at_us','valuation_state'];
    SELECT max(valued_on) INTO latest FROM fv_data.asset_valuations WHERE (family_id,asset_id)=(actor.family_id,asset.id);
    IF asset.closed_on<latest THEN
      RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'A disposal must follow the last valuation';
    END IF;
  ELSIF prior.closed_on IS NOT NULL AND asset.closed_on IS NULL THEN
    mode := 'restore';
    mutable := ARRAY['closed_on','deleted_at_us','valuation_state'];
  ELSIF bundle ? 'previous_details' THEN
    mode := 'edit';
    mutable := ARRAY['name','notes'];
    IF prior.closed_on IS NOT NULL THEN
      RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Restore this holding before editing its details';
    END IF;
  ELSIF bundle ? 'valuations' THEN
    mode := 'quote';
    mutable := ARRAY['valuation_state','family_ownership_bps'];
  ELSE
    mode := 'rent';
    mutable := ARRAY[]::text[];
    IF asset.kind NOT IN ('property','land') THEN
      RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Rent requires a property or land record';
    END IF;
  END IF;
  PERFORM fv_internal.check_record_revision(actor,record,
    CASE WHEN prior.id IS NULL THEN NULL ELSE to_jsonb(prior) END,base,mutable);
  IF (envelope->>'mutation_kind'='delete') <> (mode='dispose')
    OR (mode NOT IN ('create','edit') AND bundle ?| ARRAY['accounts','previous_details','property','metal','investment','ownerships'])
    OR (mode NOT IN ('create','quote') AND bundle ? 'valuations') THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Asset fields must match the operation';
  END IF;

  IF mode IN ('create','edit') THEN
    IF jsonb_typeof(bundle->'accounts') IS DISTINCT FROM 'array' OR jsonb_array_length(bundle->'accounts')<>1 THEN
      RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'The holding needs its managed account record';
    END IF;
    PERFORM fv_internal.apply_managed_account(actor,bundle->'accounts'->0,asset.account_id,
      'asset','managed_'||asset.kind,asset.name,mode='create');
  END IF;
  IF mode='create' THEN
    INSERT INTO fv_data.wealth_assets SELECT (asset).*;
  ELSE
    UPDATE fv_data.wealth_assets SET name=asset.name,notes=asset.notes,revision=asset.revision,
      family_ownership_bps=asset.family_ownership_bps,valuation_state=asset.valuation_state,closed_on=asset.closed_on,
      deleted_at_us=asset.deleted_at_us,updated_by=asset.updated_by,updated_at_us=asset.updated_at_us
      WHERE (family_id,id)=(actor.family_id,asset.id);
  END IF;
  IF mode IN ('create','edit') THEN
    PERFORM fv_internal.apply_asset_details(asset,bundle,mode='edit');
    PERFORM fv_internal.apply_asset_ownerships(actor,asset,bundle->'ownerships');
  END IF;
  IF (SELECT coalesce(sum(share_bps),0) FROM fv_data.asset_ownerships
      WHERE (family_id,asset_id)=(actor.family_id,asset.id) AND deleted_at_us IS NULL) > asset.family_ownership_bps THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Allocated ownership exceeds the family share';
  END IF;
  links := fv_internal.checked_journal_links(bundle);
  IF bundle ? 'valuations' THEN
    consumed := fv_internal.apply_asset_valuations(actor,envelope,asset,prior,bundle,links);
  END IF;
  PERFORM fv_internal.apply_asset_journals(actor,envelope,asset,mode,bundle,links,consumed);
  SELECT EXISTS (SELECT 1 FROM fv_data.asset_valuations WHERE (family_id,asset_id)=(actor.family_id,asset.id)) INTO known;
  IF asset.valuation_state IS DISTINCT FROM
    (CASE WHEN asset.closed_on IS NOT NULL THEN 'closed' WHEN known THEN 'recorded' ELSE 'unrecorded' END) THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Asset value status must match the retained history';
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION fv_internal.apply_module_change(actor fv_internal.device_context, envelope jsonb,
  record jsonb, bundle jsonb, p_base bigint) RETURNS void
LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  CASE envelope->>'entity_type'
    WHEN 'budget' THEN
      IF bundle IS NOT NULL THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'A budget is one record';
      END IF;
      PERFORM fv_internal.apply_budget(actor,record,p_base,envelope->>'mutation_kind');
    WHEN 'reconciliation' THEN
      IF p_base<>0 OR envelope->>'mutation_kind'<>'upsert' THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Statement checks are append-only';
      END IF;
      PERFORM fv_internal.apply_reconciliation(actor,record,bundle);
    WHEN 'asset' THEN
      PERFORM fv_internal.apply_shared_asset(actor,envelope,record,bundle,p_base);
    ELSE
      RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'This record type is unavailable for synchronization';
  END CASE;
END;
$$;

COMMIT;
