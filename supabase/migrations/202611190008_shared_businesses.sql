-- Family business profiles and their scoped cash journals.
BEGIN;
SET LOCAL ROLE familyvault_executor;
SET LOCAL search_path = '';

CREATE TABLE fv_data.businesses (
  id uuid NOT NULL,
  family_id uuid NOT NULL REFERENCES fv_data.families(id),
  revision bigint NOT NULL CHECK (revision > 0),
  created_by uuid NOT NULL,
  updated_by uuid NOT NULL,
  created_at_us bigint NOT NULL CHECK (created_at_us >= 0),
  updated_at_us bigint NOT NULL CHECK (updated_at_us >= created_at_us),
  deleted_at_us bigint CHECK (deleted_at_us >= created_at_us),
  name text NOT NULL CHECK (length(btrim(name)) BETWEEN 1 AND 96),
  notes text NOT NULL CHECK (length(notes) <= 4000),
  inventory_account_id uuid NOT NULL,
  cost_of_goods_account_id uuid NOT NULL,
  salary_account_id uuid NOT NULL,
  currency text NOT NULL CHECK (currency='INR'),
  PRIMARY KEY (family_id,id),
  UNIQUE (family_id,inventory_account_id),
  UNIQUE (family_id,cost_of_goods_account_id),
  UNIQUE (family_id,salary_account_id),
  FOREIGN KEY (family_id,created_by) REFERENCES fv_data.members(family_id,id),
  FOREIGN KEY (family_id,updated_by) REFERENCES fv_data.members(family_id,id),
  FOREIGN KEY (family_id,inventory_account_id) REFERENCES fv_data.ledger_accounts(family_id,id),
  FOREIGN KEY (family_id,cost_of_goods_account_id) REFERENCES fv_data.ledger_accounts(family_id,id),
  FOREIGN KEY (family_id,salary_account_id) REFERENCES fv_data.ledger_accounts(family_id,id),
  CHECK (inventory_account_id<>cost_of_goods_account_id AND inventory_account_id<>salary_account_id
    AND cost_of_goods_account_id<>salary_account_id)
);
ALTER TABLE fv_data.businesses ENABLE ROW LEVEL SECURITY;
ALTER TABLE fv_data.businesses FORCE ROW LEVEL SECURITY;
CREATE POLICY internal_executor ON fv_data.businesses TO familyvault_executor USING (true) WITH CHECK (true);
REVOKE ALL ON fv_data.businesses FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER fv_business_profile_retain BEFORE DELETE OR TRUNCATE ON fv_data.businesses
  FOR EACH STATEMENT EXECUTE FUNCTION fv_internal.forbid_audit_change();
ALTER TABLE fv_data.ledger_journals ADD FOREIGN KEY (family_id,business_id) REFERENCES fv_data.businesses(family_id,id);

CREATE FUNCTION fv_internal.apply_shared_business(actor fv_internal.device_context, envelope jsonb,
  record jsonb, bundle jsonb, base bigint) RETURNS void
LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE business fv_data.businesses;
DECLARE prior fv_data.businesses;
DECLARE accounts jsonb := bundle->'accounts';
BEGIN
  PERFORM fv_internal.fields(bundle,ARRAY['accounts']);
  SELECT * INTO business FROM jsonb_populate_record(NULL::fv_data.businesses,record);
  IF to_jsonb(business) IS DISTINCT FROM record OR business.deleted_at_us IS NOT NULL OR
    envelope->>'mutation_kind'<>'upsert' THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Use canonical active business values';
  END IF;
  SELECT * INTO prior FROM fv_data.businesses WHERE (family_id,id)=(actor.family_id,business.id);
  PERFORM fv_internal.check_record_revision(actor,record,
    CASE WHEN prior.id IS NULL THEN NULL ELSE to_jsonb(prior) END,base,ARRAY['name','notes']);
  IF base=0 OR business.name IS DISTINCT FROM prior.name THEN
    IF jsonb_typeof(accounts) IS DISTINCT FROM 'array' OR jsonb_array_length(accounts)<>3 THEN
      RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Business profile requires its three managed accounts';
    END IF;
    PERFORM fv_internal.apply_managed_account(actor,accounts->0,business.inventory_account_id,
      'asset','managed_inventory',business.name||' · Inventory',base=0);
    PERFORM fv_internal.apply_managed_account(actor,accounts->1,business.cost_of_goods_account_id,
      'expense','managed_stock_cost',business.name||' · Stock cost',base=0);
    PERFORM fv_internal.apply_managed_account(actor,accounts->2,business.salary_account_id,
      'expense','managed_salary',business.name||' · Wages',base=0);
  ELSIF accounts IS NOT NULL THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'An unchanged business name needs no account revisions';
  END IF;
  IF base=0 THEN
    INSERT INTO fv_data.businesses SELECT (business).*;
  ELSE
    UPDATE fv_data.businesses SET name=business.name,notes=business.notes,revision=business.revision,
      updated_by=business.updated_by,updated_at_us=business.updated_at_us
      WHERE (family_id,id)=(actor.family_id,business.id);
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION fv_internal.insert_journal(actor fv_internal.device_context, record jsonb, allow_reversal boolean)
RETURNS uuid LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE business uuid;
DECLARE entry_kind text;
DECLARE debit_kind text;
DECLARE credit_kind text;
DECLARE count_matches integer;
BEGIN
  IF record->>'business_id' IS NOT NULL THEN
    business := fv_internal.input_id(record,'business_id');
    entry_kind := record->>'kind';
    IF record->>'related_entity_id' IS NOT NULL OR allow_reversal OR
      coalesce(entry_kind,'') NOT IN ('income','expense','transfer') OR NOT EXISTS (
        SELECT 1 FROM fv_data.businesses WHERE (family_id,id)=(actor.family_id,business) AND deleted_at_us IS NULL) THEN
      RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'Cash entry needs an active business in this family';
    END IF;
    IF jsonb_typeof(record->'postings') IS DISTINCT FROM 'array' OR jsonb_array_length(record->'postings')<>2 THEN
      RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Business cash entry requires a balanced pair of ordinary accounts';
    END IF;
    debit_kind := CASE WHEN entry_kind='expense' THEN 'expense' ELSE 'asset' END;
    credit_kind := CASE WHEN entry_kind='income' THEN 'income' ELSE 'asset' END;
    SELECT count(*) INTO count_matches FROM jsonb_array_elements(record->'postings') p
      JOIN fv_data.ledger_accounts a ON (a.family_id,a.id)=(actor.family_id,fv_internal.input_id(p,'account_id'))
      WHERE a.deleted_at_us IS NULL AND a.kind=CASE WHEN fv_internal.input_int(p,'amount_minor')>0
        THEN debit_kind ELSE credit_kind END;
    IF count_matches<>2 THEN
      RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Business posting accounts must match the transaction kind';
    END IF;
  END IF;
  RETURN fv_internal.insert_scoped_journal(actor,record,allow_reversal,NULL,business,ARRAY[]::uuid[]);
END;
$$;

CREATE OR REPLACE FUNCTION fv_internal.close_journal(actor fv_internal.device_context, record jsonb, reversal jsonb, p_base bigint)
RETURNS void LANGUAGE sql SET search_path = '' AS $$
  SELECT fv_internal.close_scoped_journal(actor,record,reversal,p_base,NULL,NULL,
    CASE WHEN record->>'business_id' IS NULL THEN NULL ELSE fv_internal.input_id(record,'business_id') END,ARRAY[]::uuid[])
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
    ELSE
      RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'This record type is unavailable for synchronization';
  END CASE;
END;
$$;

COMMIT;
