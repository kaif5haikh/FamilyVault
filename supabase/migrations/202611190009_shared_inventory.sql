-- Shared stock movements and a derived exact-cost position per item.
BEGIN;
SET LOCAL ROLE familyvault_executor;
SET LOCAL search_path = '';

CREATE TABLE fv_data.stock_items (
  id uuid NOT NULL,
  family_id uuid NOT NULL,
  revision bigint NOT NULL CHECK (revision>0),
  created_by uuid NOT NULL,
  updated_by uuid NOT NULL,
  created_at_us bigint NOT NULL CHECK (created_at_us>=0),
  updated_at_us bigint NOT NULL CHECK (updated_at_us>=created_at_us),
  deleted_at_us bigint CHECK (deleted_at_us>=created_at_us),
  business_id uuid NOT NULL,
  name text NOT NULL CHECK (length(btrim(name)) BETWEEN 1 AND 120),
  sku text CHECK (length(btrim(sku)) BETWEEN 1 AND 80),
  unit text NOT NULL CHECK (unit='piece'),
  PRIMARY KEY (family_id,id),
  UNIQUE (family_id,id,business_id),
  FOREIGN KEY (family_id,business_id) REFERENCES fv_data.businesses(family_id,id),
  FOREIGN KEY (family_id,created_by) REFERENCES fv_data.members(family_id,id),
  FOREIGN KEY (family_id,updated_by) REFERENCES fv_data.members(family_id,id)
);
CREATE UNIQUE INDEX fv_shared_stock_sku ON fv_data.stock_items(family_id,business_id,
  translate(sku,'ABCDEFGHIJKLMNOPQRSTUVWXYZ','abcdefghijklmnopqrstuvwxyz'))
  WHERE sku IS NOT NULL AND deleted_at_us IS NULL;

CREATE TABLE fv_data.stock_positions (
  stock_item_id uuid NOT NULL,
  family_id uuid NOT NULL,
  quantity bigint NOT NULL DEFAULT 0 CHECK (quantity>=0),
  cost_pool_minor bigint NOT NULL DEFAULT 0 CHECK (cost_pool_minor>=0),
  PRIMARY KEY (family_id,stock_item_id),
  FOREIGN KEY (family_id,stock_item_id) REFERENCES fv_data.stock_items(family_id,id),
  CHECK (quantity<>0 OR cost_pool_minor=0)
);

CREATE TABLE fv_data.stock_movements (
  id uuid NOT NULL,
  family_id uuid NOT NULL,
  created_by uuid NOT NULL,
  device_id uuid NOT NULL,
  created_at_us bigint NOT NULL CHECK (created_at_us>=0),
  business_id uuid NOT NULL,
  stock_item_id uuid NOT NULL,
  item_revision bigint NOT NULL CHECK (item_revision>0),
  event_index integer NOT NULL CHECK (event_index BETWEEN 0 AND 1),
  reverses_id uuid,
  journal_id uuid,
  occurred_on date NOT NULL CHECK (occurred_on BETWEEN DATE '1900-01-01' AND DATE '2200-12-31'),
  kind text NOT NULL CHECK (kind IN ('purchase','opening','stock_out','adjustment','reversal')),
  quantity_delta bigint NOT NULL CHECK (quantity_delta<>0),
  value_delta_minor bigint NOT NULL,
  notes text NOT NULL CHECK (length(notes)<=4000),
  PRIMARY KEY (family_id,id),
  UNIQUE (family_id,stock_item_id,item_revision,event_index),
  UNIQUE (family_id,reverses_id),
  UNIQUE (family_id,journal_id),
  FOREIGN KEY (family_id,device_id,created_by) REFERENCES fv_data.devices(family_id,id,member_id),
  FOREIGN KEY (family_id,stock_item_id,business_id) REFERENCES fv_data.stock_items(family_id,id,business_id),
  FOREIGN KEY (family_id,reverses_id) REFERENCES fv_data.stock_movements(family_id,id),
  FOREIGN KEY (family_id,journal_id) REFERENCES fv_data.ledger_journals(family_id,id),
  CHECK ((value_delta_minor=0) = (journal_id IS NULL)),
  CHECK ((quantity_delta>0 AND value_delta_minor>=0) OR (quantity_delta<0 AND value_delta_minor<=0)),
  CHECK ((kind='reversal') = (reverses_id IS NOT NULL))
);
CREATE TRIGGER fv_stock_events_immutable BEFORE UPDATE OR DELETE OR TRUNCATE ON fv_data.stock_movements
  FOR EACH STATEMENT EXECUTE FUNCTION fv_internal.forbid_audit_change();
DO $$
DECLARE table_name text;
BEGIN
  FOREACH table_name IN ARRAY ARRAY['stock_items','stock_positions','stock_movements'] LOOP
    EXECUTE format('ALTER TABLE fv_data.%I ENABLE ROW LEVEL SECURITY',table_name);
    EXECUTE format('ALTER TABLE fv_data.%I FORCE ROW LEVEL SECURITY',table_name);
    EXECUTE format('CREATE POLICY internal_executor ON fv_data.%I TO familyvault_executor USING (true) WITH CHECK (true)',table_name);
    EXECUTE format('REVOKE ALL ON TABLE fv_data.%I FROM PUBLIC,anon,authenticated,service_role',table_name);
    IF table_name<>'stock_movements' THEN
      EXECUTE format('CREATE TRIGGER fv_stock_retain BEFORE DELETE OR TRUNCATE ON fv_data.%I FOR EACH STATEMENT EXECUTE FUNCTION fv_internal.forbid_audit_change()',table_name);
    END IF;
  END LOOP;
END;
$$;

CREATE FUNCTION fv_internal.apply_stock_event(actor fv_internal.device_context, envelope jsonb, item fv_data.stock_items,
  business fv_data.businesses, bundle jsonb, links jsonb, raw jsonb, event_index integer) RETURNS uuid
LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE movement fv_data.stock_movements;
DECLARE latest fv_data.stock_movements;
DECLARE position fv_data.stock_positions;
DECLARE link jsonb;
DECLARE journal jsonb;
DECLARE contra uuid;
DECLARE units numeric;
DECLARE cost numeric;
BEGIN
  SELECT * INTO movement FROM jsonb_populate_record(NULL::fv_data.stock_movements,raw);
  IF to_jsonb(movement) IS DISTINCT FROM raw OR
    (movement.family_id,movement.created_by,movement.device_id,movement.stock_item_id,movement.business_id,movement.item_revision,movement.event_index)
      IS DISTINCT FROM (actor.family_id,actor.member_id,actor.device_id,item.id,business.id,item.revision,event_index) THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'Stock event must match its item, revision and creator';
  END IF;
  SELECT * INTO position FROM fv_data.stock_positions WHERE (family_id,stock_item_id)=(actor.family_id,item.id);
  SELECT m.* INTO latest FROM fv_data.stock_movements m
    WHERE (m.family_id,m.stock_item_id)=(actor.family_id,item.id) AND m.reverses_id IS NULL AND NOT EXISTS (
      SELECT 1 FROM fv_data.stock_movements r WHERE (r.family_id,r.reverses_id)=(m.family_id,m.id))
    ORDER BY m.item_revision DESC,m.event_index DESC LIMIT 1;
  IF movement.journal_id IS NOT NULL THEN
    SELECT r INTO link FROM jsonb_array_elements(links) r WHERE r->>'journal_id'=movement.journal_id::text;
    journal := fv_internal.bundle_journal(bundle,movement.journal_id);
    IF link IS NULL OR journal IS NULL OR journal->>'occurred_on' IS DISTINCT FROM movement.occurred_on::text THEN
      RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'The stock journal must match the movement date';
    END IF;
  END IF;

  IF movement.kind='reversal' THEN
    IF event_index<>0 OR latest.id IS NULL OR
      (movement.reverses_id,movement.occurred_on,movement.quantity_delta::numeric,movement.value_delta_minor::numeric)
      IS DISTINCT FROM (latest.id,latest.occurred_on,-latest.quantity_delta::numeric,-latest.value_delta_minor::numeric)
      OR ((movement.journal_id IS NULL) <> (latest.journal_id IS NULL))
      OR (movement.journal_id IS NOT NULL AND
        (link->>'purpose',journal->>'reverses_id') IS DISTINCT FROM ('reversal'::text,latest.journal_id::text)) THEN
      RAISE EXCEPTION USING ERRCODE = 'PT409', MESSAGE = 'Only the latest active stock movement can be reversed exactly';
    END IF;
  ELSE
    IF movement.occurred_on<latest.occurred_on OR (movement.kind='opening' AND latest.id IS NOT NULL) THEN
      RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Stock movement dates must follow active inventory history';
    END IF;
    IF movement.kind IN ('purchase','opening') THEN
      IF movement.quantity_delta<=0 OR movement.value_delta_minor<0 THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Stock receipt needs positive units and a nonnegative cost';
      END IF;
      IF movement.kind='opening' THEN
        contra := fv_internal.chart_id(business.family_id,'opening');
      ELSIF movement.journal_id IS NOT NULL THEN
        SELECT fv_internal.input_id(p,'account_id') INTO contra FROM jsonb_array_elements(journal->'postings') p
          WHERE p->>'account_id'<>business.inventory_account_id::text LIMIT 1;
        IF NOT fv_internal.liquid_ledger_account(actor.family_id,contra) THEN
          RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Stock purchase needs an active family cash or bank account';
        END IF;
      END IF;
    ELSE
      units := -movement.quantity_delta::numeric;
      IF movement.kind NOT IN ('stock_out','adjustment') OR units<=0 OR units>position.quantity THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'There is insufficient stock for this issue';
      END IF;
      cost := div(2*position.cost_pool_minor::numeric*units+position.quantity,2*position.quantity::numeric);
      IF movement.value_delta_minor IS DISTINCT FROM -cost THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Stock issue must use its exact weighted cost pool';
      END IF;
      contra := business.cost_of_goods_account_id;
    END IF;
    IF movement.journal_id IS NOT NULL THEN
      IF (link->>'purpose',journal->>'kind') IS DISTINCT FROM ('stock'::text,'business'::text) THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Invalid stock journal purpose';
      END IF;
      PERFORM fv_internal.require_postings(journal,ARRAY[business.inventory_account_id,contra],
        ARRAY[movement.value_delta_minor::numeric,-movement.value_delta_minor::numeric]);
    END IF;
  END IF;
  IF movement.journal_id IS NOT NULL THEN
    PERFORM fv_internal.apply_linked_journal(actor,envelope,bundle,link,'stock',item.id,business.id,
      ARRAY[business.inventory_account_id,business.cost_of_goods_account_id]);
  END IF;
  INSERT INTO fv_data.stock_movements SELECT (movement).*;
  UPDATE fv_data.stock_positions SET quantity=quantity+movement.quantity_delta,cost_pool_minor=cost_pool_minor+movement.value_delta_minor
    WHERE (family_id,stock_item_id)=(actor.family_id,item.id);
  IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'The inventory position is unavailable'; END IF;
  RETURN movement.journal_id;
END;
$$;

CREATE FUNCTION fv_internal.apply_shared_stock(actor fv_internal.device_context, envelope jsonb,
  record jsonb, bundle jsonb, base bigint) RETURNS void
LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE item fv_data.stock_items;
DECLARE prior fv_data.stock_items;
DECLARE business fv_data.businesses;
DECLARE links jsonb;
DECLARE events jsonb := bundle->'stock_movements';
DECLARE event jsonb;
DECLARE used_journals integer := 0;
DECLARE event_index integer := 0;
DECLARE mutable text[];
BEGIN
  PERFORM fv_internal.fields(bundle,ARRAY['stock_movements','journals','journal_links']);
  SELECT * INTO item FROM jsonb_populate_record(NULL::fv_data.stock_items,record);
  IF to_jsonb(item) IS DISTINCT FROM record THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Use canonical stock item fields';
  END IF;
  SELECT * INTO prior FROM fv_data.stock_items WHERE (family_id,id)=(actor.family_id,item.id);
  IF coalesce(prior.revision,0)<>base THEN
    RAISE EXCEPTION USING ERRCODE = 'PT409', MESSAGE = 'The inventory item changed';
  END IF;
  SELECT * INTO business FROM fv_data.businesses WHERE (family_id,id)=(actor.family_id,item.business_id)
    AND deleted_at_us IS NULL;
  IF business.id IS NULL THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'Inventory requires an active family business';
  END IF;
  links := fv_internal.checked_journal_links(bundle);
  IF events IS NOT NULL THEN
    IF base=0 OR prior.deleted_at_us IS NOT NULL OR jsonb_typeof(events) IS DISTINCT FROM 'array'
      OR jsonb_array_length(events) NOT BETWEEN 1 AND 2 OR
      (jsonb_array_length(events)=2 AND events->0->>'kind' IS DISTINCT FROM 'reversal') THEN
      RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Use one active movement or one correction on an active item';
    END IF;
    mutable := ARRAY[]::text[];
  ELSIF prior.deleted_at_us IS NOT NULL OR item.deleted_at_us IS NOT NULL THEN
    mutable := ARRAY['deleted_at_us'];
    IF (prior.deleted_at_us IS NULL)=(item.deleted_at_us IS NULL) OR NOT EXISTS (
      SELECT 1 FROM fv_data.stock_positions p WHERE (p.family_id,p.stock_item_id,p.quantity)=(actor.family_id,item.id,0)) THEN
      RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Empty the item before changing its archive state';
    END IF;
  ELSE
    mutable := ARRAY['name','sku'];
  END IF;
  PERFORM fv_internal.check_record_revision(actor,record,
    CASE WHEN prior.id IS NULL THEN NULL ELSE to_jsonb(prior) END,base,mutable);
  IF (envelope->>'mutation_kind'='delete')<>(item.deleted_at_us IS NOT NULL) THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'The stock change must match its archive state';
  END IF;
  IF base=0 THEN
    INSERT INTO fv_data.stock_items SELECT (item).*;
    INSERT INTO fv_data.stock_positions(family_id,stock_item_id) VALUES(actor.family_id,item.id);
  ELSE
    UPDATE fv_data.stock_items SET revision=item.revision,updated_by=item.updated_by,updated_at_us=item.updated_at_us,
      deleted_at_us=item.deleted_at_us,name=item.name,sku=item.sku WHERE (family_id,id)=(actor.family_id,item.id);
  END IF;
  FOR event IN SELECT * FROM jsonb_array_elements(events) LOOP
    IF fv_internal.apply_stock_event(actor,envelope,item,business,bundle,links,event,event_index) IS NOT NULL THEN
      used_journals := used_journals+1;
    END IF;
    event_index := event_index+1;
  END LOOP;
  IF used_journals<>jsonb_array_length(links) THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Every inventory journal needs its stock movement';
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
    WHEN 'debt' THEN
      PERFORM fv_internal.apply_shared_debt(actor,envelope,record,bundle,p_base);
    WHEN 'business' THEN
      PERFORM fv_internal.apply_shared_business(actor,envelope,record,bundle,p_base);
    WHEN 'stock' THEN
      PERFORM fv_internal.apply_shared_stock(actor,envelope,record,bundle,p_base);
    ELSE
      RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'This record type is unavailable for synchronization';
  END CASE;
END;
$$;

COMMIT;
