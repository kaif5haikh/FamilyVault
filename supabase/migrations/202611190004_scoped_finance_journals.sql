-- Internal journal primitives for typed family finance aggregates.
BEGIN;
SET LOCAL ROLE familyvault_executor;
SET LOCAL search_path = '';

CREATE TABLE fv_data.aggregate_journal_links (
  journal_id uuid NOT NULL,
  family_id uuid NOT NULL,
  aggregate_type text NOT NULL CHECK (aggregate_type IN ('asset','asset_rent','debt','business','stock','salary')),
  aggregate_id uuid NOT NULL,
  operation_id uuid NOT NULL,
  purpose text NOT NULL CHECK (length(btrim(purpose)) BETWEEN 1 AND 40),
  PRIMARY KEY (family_id, journal_id),
  FOREIGN KEY (family_id, journal_id) REFERENCES fv_data.ledger_journals(family_id,id),
  FOREIGN KEY (family_id, operation_id) REFERENCES fv_data.sync_changes(family_id,operation_id)
    DEFERRABLE INITIALLY DEFERRED
);
CREATE INDEX fv_aggregate_journals ON fv_data.aggregate_journal_links(family_id,aggregate_type,aggregate_id,purpose);
ALTER TABLE fv_data.aggregate_journal_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE fv_data.aggregate_journal_links FORCE ROW LEVEL SECURITY;
CREATE POLICY internal_executor ON fv_data.aggregate_journal_links TO familyvault_executor USING (true) WITH CHECK (true);
REVOKE ALL ON fv_data.aggregate_journal_links FROM PUBLIC, anon, authenticated, service_role;
CREATE TRIGGER fv_aggregate_links_immutable BEFORE UPDATE OR DELETE OR TRUNCATE ON fv_data.aggregate_journal_links
  FOR EACH STATEMENT EXECUTE FUNCTION fv_internal.forbid_audit_change();

CREATE FUNCTION fv_internal.check_record_revision(actor fv_internal.device_context, incoming jsonb, stored jsonb,
  base bigint, mutable text[]) RETURNS void
LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  IF coalesce((stored->>'revision')::bigint,0) <> base THEN
    RAISE EXCEPTION USING ERRCODE = 'PT409', MESSAGE = 'The family record revision changed';
  END IF;
  IF fv_internal.input_id(incoming,'family_id') IS DISTINCT FROM actor.family_id OR
     fv_internal.input_id(incoming,'updated_by') IS DISTINCT FROM actor.member_id OR
     fv_internal.input_int(incoming,'revision') <> base + 1 OR
     (base = 0 AND (fv_internal.input_id(incoming,'created_by') IS DISTINCT FROM actor.member_id OR
       incoming->>'deleted_at_us' IS NOT NULL)) OR
     (base > 0 AND incoming - mutable - ARRAY['updated_at_us','updated_by','revision']
                      IS DISTINCT FROM stored - mutable - ARRAY['updated_at_us','updated_by','revision']) THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'Record identity, creator and member scope must be retained';
  END IF;
END;
$$;

CREATE FUNCTION fv_internal.apply_managed_account(actor fv_internal.device_context, record jsonb,
  account_id uuid, expected_kind text, expected_subtype text, expected_name text, creating boolean) RETURNS void
LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE incoming fv_data.ledger_accounts;
DECLARE stored fv_data.ledger_accounts;
BEGIN
  SELECT * INTO incoming FROM jsonb_populate_record(NULL::fv_data.ledger_accounts,record);
  IF to_jsonb(incoming) IS DISTINCT FROM record OR
     (incoming.id,incoming.kind,incoming.subtype,incoming.name,incoming.system_account,incoming.deleted_at_us)
     IS DISTINCT FROM (account_id,expected_kind,expected_subtype,expected_name,false,NULL::bigint) THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'The managed ledger account must match its module record';
  END IF;
  SELECT * INTO stored FROM fv_data.ledger_accounts WHERE (family_id,id)=(actor.family_id,account_id);
  IF creating <> (stored.id IS NULL) THEN
    RAISE EXCEPTION USING ERRCODE = 'PT409', MESSAGE = 'The managed account changed before synchronization';
  END IF;
  PERFORM fv_internal.check_record_revision(actor, record,
    CASE WHEN stored.id IS NULL THEN NULL ELSE to_jsonb(stored) END,
    coalesce(stored.revision,0), ARRAY['name']);
  IF creating THEN
    INSERT INTO fv_data.ledger_accounts SELECT (incoming).*;
  ELSE
    UPDATE fv_data.ledger_accounts SET name=incoming.name, revision=incoming.revision,
      updated_at_us=incoming.updated_at_us,updated_by=incoming.updated_by
      WHERE (family_id,id)=(actor.family_id,account_id);
  END IF;
END;
$$;

CREATE FUNCTION fv_internal.liquid_ledger_account(family uuid, account uuid) RETURNS boolean
LANGUAGE sql STABLE SET search_path = '' AS $$
  SELECT EXISTS (SELECT 1 FROM fv_data.ledger_accounts WHERE (family_id,id)=(family,account)
    AND kind='asset' AND subtype IN ('bank','cash') AND deleted_at_us IS NULL AND NOT system_account)
$$;

CREATE FUNCTION fv_internal.ledger_balance_through(family uuid, account uuid, through date,
  before_disposal boolean DEFAULT false) RETURNS numeric
LANGUAGE sql STABLE SET search_path = '' AS $$
  SELECT coalesce(sum(p.amount_minor),0)
  FROM fv_data.ledger_postings p JOIN fv_data.ledger_journals j ON (j.family_id,j.id)=(p.family_id,p.journal_id)
  WHERE (p.family_id,p.account_id)=(family,account) AND j.status='posted'
    AND (through IS NULL OR j.occurred_on <= through)
    AND (NOT before_disposal OR j.deleted_at_us IS NOT NULL OR NOT EXISTS (
      SELECT 1 FROM fv_data.aggregate_journal_links l WHERE (l.family_id,l.journal_id)=(j.family_id,j.id)
        AND l.purpose IN ('disposal','disposal_bridge')))
$$;

CREATE FUNCTION fv_internal.require_postings(p_journal jsonb, accounts uuid[], amounts numeric[]) RETURNS void
LANGUAGE plpgsql IMMUTABLE SET search_path = '' AS $$
DECLARE supplied jsonb;
DECLARE expected jsonb;
DECLARE supplied_count integer;
DECLARE expected_count integer;
BEGIN
  SELECT count(*),jsonb_object_agg(fv_internal.input_id(p,'account_id')::text,fv_internal.input_int(p,'amount_minor'))
    INTO supplied_count,supplied FROM jsonb_array_elements(p_journal->'postings') p;
  SELECT count(*),jsonb_object_agg(id::text,amount)
    INTO expected_count,expected FROM unnest(accounts,amounts) AS effect(id,amount) WHERE amount <> 0;
  IF supplied_count <> expected_count OR supplied IS DISTINCT FROM expected THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'The journal must post the exact module amounts to their accounts';
  END IF;
END;
$$;

CREATE FUNCTION fv_internal.insert_scoped_journal(actor fv_internal.device_context, record jsonb,
  allow_reversal boolean, scope_id uuid, scope_business uuid, managed uuid[]) RETURNS uuid
LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE incoming fv_data.ledger_journals;
DECLARE posting fv_data.ledger_postings;
DECLARE element jsonb;
BEGIN
  IF jsonb_typeof(record->'postings') IS DISTINCT FROM 'array'
      OR jsonb_array_length(record->'postings') NOT BETWEEN 2 AND 100
      OR coalesce(record->>'occurred_on','') !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Complete dated journal and postings required';
  END IF;
  PERFORM fv_internal.input_int(record,'created_at_us');
  PERFORM fv_internal.input_int(record,'updated_at_us');
  SELECT * INTO incoming FROM jsonb_populate_record(NULL::fv_data.ledger_journals,record);
  IF to_jsonb(incoming) IS DISTINCT FROM record - 'postings' THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Use canonical journal values';
  END IF;
  IF incoming.family_id IS DISTINCT FROM actor.family_id OR incoming.created_by IS DISTINCT FROM actor.member_id
      OR incoming.updated_by IS DISTINCT FROM actor.member_id OR fv_internal.input_int(record,'revision') <> 1
      OR incoming.deleted_at_us IS NOT NULL OR incoming.status IS DISTINCT FROM 'posted'
      OR (incoming.reverses_id IS NOT NULL) <> allow_reversal
      OR incoming.business_id IS DISTINCT FROM scope_business
      OR (scope_id IS NULL AND incoming.kind IN ('business','repayment'))
      OR (scope_id IS NOT NULL AND incoming.related_entity_id IS DISTINCT FROM scope_id) THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'Posting is outside the authorized ledger scope';
  END IF;
  incoming.status := 'draft';
  INSERT INTO fv_data.ledger_journals SELECT (incoming).*;
  FOR element IN SELECT * FROM jsonb_array_elements(record->'postings') LOOP
    PERFORM fv_internal.input_int(element,'amount_minor');
    PERFORM fv_internal.input_int(element,'position');
    SELECT * INTO posting FROM jsonb_populate_record(NULL::fv_data.ledger_postings,element);
    IF to_jsonb(posting) IS DISTINCT FROM element THEN
      RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Use canonical posting values';
    END IF;
    IF posting.family_id IS DISTINCT FROM actor.family_id OR posting.journal_id IS DISTINCT FROM incoming.id
      OR NOT EXISTS (SELECT 1 FROM fv_data.ledger_accounts a
        WHERE (a.family_id,a.id)=(actor.family_id,posting.account_id)
          AND (a.id=ANY(managed) OR a.subtype NOT LIKE 'managed\_%' ESCAPE '\')) THEN
      RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'Posting refers to an account outside the ledger scope';
    END IF;
    INSERT INTO fv_data.ledger_postings SELECT (posting).*;
  END LOOP;
  UPDATE fv_data.ledger_journals SET status='posted' WHERE (family_id,id)=(actor.family_id,incoming.id);
  RETURN incoming.id;
END;
$$;

CREATE OR REPLACE FUNCTION fv_internal.insert_journal(actor fv_internal.device_context, record jsonb, allow_reversal boolean)
RETURNS uuid LANGUAGE sql SET search_path = '' AS $$
  SELECT fv_internal.insert_scoped_journal(actor,record,allow_reversal,NULL,NULL,ARRAY[]::uuid[])
$$;

CREATE FUNCTION fv_internal.close_scoped_journal(actor fv_internal.device_context, record jsonb, reversal jsonb,
  base bigint, scope_id uuid, scope_type text, scope_business uuid, managed uuid[]) RETURNS void
LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE original fv_data.ledger_journals;
DECLARE changed fv_data.ledger_journals;
DECLARE link fv_data.aggregate_journal_links;
BEGIN
  SELECT * INTO changed FROM jsonb_populate_record(NULL::fv_data.ledger_journals,record);
  IF to_jsonb(changed) IS DISTINCT FROM record - 'postings' THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Use canonical correction values';
  END IF;
  SELECT * INTO original FROM fv_data.ledger_journals WHERE (family_id,id)=(actor.family_id,changed.id);
  IF original.id IS NULL OR original.revision <> base OR original.deleted_at_us IS NOT NULL THEN
    RAISE EXCEPTION USING ERRCODE = 'PT409', MESSAGE = 'The journal changed before correction';
  END IF;
  SELECT * INTO link FROM fv_data.aggregate_journal_links WHERE (family_id,journal_id)=(actor.family_id,original.id);
  IF (link.aggregate_id,link.aggregate_type) IS DISTINCT FROM (scope_id,scope_type)
     OR original.reverses_id IS NOT NULL OR original.business_id IS DISTINCT FROM scope_business THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'Correct this journal through its own accounting module';
  END IF;
  IF changed.updated_by IS DISTINCT FROM actor.member_id OR fv_internal.input_int(record,'revision') <> base + 1
    OR fv_internal.input_int(record,'deleted_at_us') IS NULL OR fv_internal.input_id(reversal,'reverses_id') IS DISTINCT FROM original.id
    OR (to_jsonb(changed) - ARRAY['revision','deleted_at_us','updated_at_us','updated_by'])
      IS DISTINCT FROM (to_jsonb(original) - ARRAY['revision','deleted_at_us','updated_at_us','updated_by'])
    OR (SELECT jsonb_agg(to_jsonb(p) ORDER BY p.position) FROM fv_data.ledger_postings p
      WHERE (p.family_id,p.journal_id)=(actor.family_id,original.id)) IS DISTINCT FROM record->'postings' THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Invalid journal correction history';
  END IF;
  PERFORM fv_internal.input_int(record,'updated_at_us');
  PERFORM fv_internal.insert_scoped_journal(actor,reversal,true,scope_id,scope_business,managed);
  UPDATE fv_data.ledger_journals SET deleted_at_us=changed.deleted_at_us,updated_at_us=changed.updated_at_us,
    updated_by=changed.updated_by,revision=changed.revision WHERE (family_id,id)=(actor.family_id,original.id);
END;
$$;

CREATE OR REPLACE FUNCTION fv_internal.close_journal(actor fv_internal.device_context, record jsonb, reversal jsonb, p_base bigint)
RETURNS void LANGUAGE sql SET search_path = '' AS $$
  SELECT fv_internal.close_scoped_journal(actor,record,reversal,p_base,NULL,NULL,NULL,ARRAY[]::uuid[])
$$;

CREATE FUNCTION fv_internal.checked_journal_links(bundle jsonb) RETURNS jsonb
LANGUAGE plpgsql IMMUTABLE SET search_path = '' AS $$
DECLARE journals jsonb := coalesce(bundle->'journals','[]'::jsonb);
DECLARE links jsonb := coalesce(bundle->'journal_links','[]'::jsonb);
DECLARE j jsonb;
DECLARE ids uuid[] := ARRAY[]::uuid[];
DECLARE expected uuid[] := ARRAY[]::uuid[];
BEGIN
  IF jsonb_typeof(journals) IS DISTINCT FROM 'array' OR jsonb_typeof(links) IS DISTINCT FROM 'array'
    OR jsonb_array_length(journals) > 100 OR jsonb_array_length(links) > 100 THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Invalid module journals';
  END IF;
  FOR j IN SELECT * FROM jsonb_array_elements(journals) LOOP
    ids := array_append(ids,fv_internal.input_id(j,'id'));
    IF j->>'reverses_id' IS NOT NULL THEN
      expected := array_append(expected,fv_internal.input_id(j,'reverses_id'));
    END IF;
  END LOOP;
  FOR j IN SELECT * FROM jsonb_array_elements(links) LOOP
    expected := array_append(expected,fv_internal.input_id(j,'journal_id'));
  END LOOP;
  IF cardinality(ids) <> cardinality(expected) OR
    cardinality(ids) <> (SELECT count(DISTINCT id) FROM unnest(ids) id) OR
    (SELECT array_agg(id ORDER BY id) FROM unnest(ids) id)
      IS DISTINCT FROM (SELECT array_agg(id ORDER BY id) FROM unnest(expected) id) THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Every module journal needs exactly one operation link or reversal';
  END IF;
  RETURN links;
END;
$$;

CREATE FUNCTION fv_internal.bundle_journal(bundle jsonb, id uuid) RETURNS jsonb
LANGUAGE sql IMMUTABLE SET search_path = '' AS $$
  SELECT j FROM jsonb_array_elements(bundle->'journals') j WHERE fv_internal.input_id(j,'id')=id
$$;

CREATE FUNCTION fv_internal.apply_linked_journal(actor fv_internal.device_context, envelope jsonb, bundle jsonb,
  raw_link jsonb, scope_type text, scope_id uuid, scope_business uuid, managed uuid[]) RETURNS void
LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE link fv_data.aggregate_journal_links;
DECLARE journal jsonb;
DECLARE original jsonb;
BEGIN
  SELECT * INTO link FROM jsonb_populate_record(NULL::fv_data.aggregate_journal_links,raw_link);
  IF to_jsonb(link) IS DISTINCT FROM raw_link OR
     (link.family_id,link.aggregate_type,link.aggregate_id,link.operation_id)
      IS DISTINCT FROM (actor.family_id,scope_type,scope_id,fv_internal.input_id(envelope,'operation_id')) THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'Journal link does not match the approved module scope';
  END IF;
  journal := fv_internal.bundle_journal(bundle,link.journal_id);
  IF journal IS NULL OR (journal->>'kind' = 'reversal') IS DISTINCT FROM (link.purpose='reversal') THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Journal purpose must match its postings';
  END IF;
  IF link.purpose='reversal' THEN
    original := fv_internal.bundle_journal(bundle,fv_internal.input_id(journal,'reverses_id'));
    PERFORM fv_internal.close_scoped_journal(actor,original,journal,fv_internal.input_int(original,'revision')-1,
      scope_id,scope_type,scope_business,managed);
  ELSE
    PERFORM fv_internal.insert_scoped_journal(actor,journal,false,scope_id,scope_business,managed);
  END IF;
  INSERT INTO fv_data.aggregate_journal_links SELECT (link).*;
END;
$$;

COMMIT;
