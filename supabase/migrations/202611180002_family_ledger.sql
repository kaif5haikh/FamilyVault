-- Shared double-entry ledger and durable, ordered operation receipts.
BEGIN;
SET LOCAL ROLE familyvault_executor;
SET LOCAL search_path = '';

CREATE TABLE fv_data.ledger_accounts (
  id uuid NOT NULL,
  family_id uuid NOT NULL REFERENCES fv_data.families(id),
  revision bigint NOT NULL CHECK (revision > 0),
  created_by uuid NOT NULL,
  updated_by uuid NOT NULL,
  created_at_us bigint NOT NULL CHECK (created_at_us >= 0),
  updated_at_us bigint NOT NULL CHECK (updated_at_us >= created_at_us),
  deleted_at_us bigint CHECK (deleted_at_us >= created_at_us),
  name text NOT NULL CHECK (length(btrim(name)) BETWEEN 1 AND 120),
  kind text NOT NULL CHECK (kind IN ('asset','liability','equity','income','expense')),
  subtype text NOT NULL CHECK (length(btrim(subtype)) BETWEEN 1 AND 40),
  currency text NOT NULL CHECK (currency = 'INR'),
  system_account boolean NOT NULL,
  PRIMARY KEY (family_id, id),
  FOREIGN KEY (family_id, created_by) REFERENCES fv_data.members(family_id, id),
  FOREIGN KEY (family_id, updated_by) REFERENCES fv_data.members(family_id, id),
  CHECK (NOT system_account OR deleted_at_us IS NULL)
);
CREATE UNIQUE INDEX fv_chart_code ON fv_data.ledger_accounts(family_id, subtype) WHERE system_account;

CREATE TABLE fv_data.ledger_journals (
  id uuid NOT NULL,
  family_id uuid NOT NULL REFERENCES fv_data.families(id),
  revision bigint NOT NULL CHECK (revision > 0),
  created_by uuid NOT NULL,
  updated_by uuid NOT NULL,
  created_at_us bigint NOT NULL CHECK (created_at_us >= 0),
  updated_at_us bigint NOT NULL CHECK (updated_at_us >= created_at_us),
  deleted_at_us bigint CHECK (deleted_at_us >= created_at_us),
  kind text NOT NULL CHECK (kind IN ('income','expense','transfer','opening','adjustment','reversal','repayment','business')),
  occurred_on date NOT NULL CHECK (occurred_on BETWEEN DATE '1900-01-01' AND DATE '2200-12-31'),
  description text NOT NULL CHECK (length(btrim(description)) BETWEEN 1 AND 500),
  currency text NOT NULL CHECK (currency = 'INR'),
  status text NOT NULL CHECK (status IN ('draft','posted')),
  reverses_id uuid,
  business_id uuid,
  related_entity_id uuid,
  PRIMARY KEY (family_id, id),
  FOREIGN KEY (family_id, created_by) REFERENCES fv_data.members(family_id, id),
  FOREIGN KEY (family_id, updated_by) REFERENCES fv_data.members(family_id, id),
  FOREIGN KEY (family_id, reverses_id) REFERENCES fv_data.ledger_journals(family_id, id),
  UNIQUE (family_id, reverses_id),
  CHECK ((reverses_id IS NOT NULL) = (kind = 'reversal')),
  CHECK (reverses_id IS NULL OR reverses_id <> id)
);
CREATE INDEX fv_journals_by_date ON fv_data.ledger_journals(family_id, occurred_on, id);

CREATE TABLE fv_data.ledger_postings (
  id uuid NOT NULL,
  family_id uuid NOT NULL,
  journal_id uuid NOT NULL,
  account_id uuid NOT NULL,
  position integer NOT NULL CHECK (position BETWEEN 0 AND 99),
  amount_minor bigint NOT NULL CHECK (amount_minor <> 0),
  PRIMARY KEY (family_id, id),
  UNIQUE (family_id, journal_id, position),
  FOREIGN KEY (family_id, journal_id) REFERENCES fv_data.ledger_journals(family_id, id),
  FOREIGN KEY (family_id, account_id) REFERENCES fv_data.ledger_accounts(family_id, id)
);
CREATE INDEX fv_postings_by_account ON fv_data.ledger_postings(family_id, account_id);

CREATE TABLE fv_data.sync_clocks (
  family_id uuid PRIMARY KEY REFERENCES fv_data.families(id),
  last_sequence bigint NOT NULL DEFAULT 0 CHECK (last_sequence >= 0)
);

CREATE TABLE fv_data.sync_changes (
  family_id uuid NOT NULL REFERENCES fv_data.families(id),
  sequence bigint NOT NULL CHECK (sequence > 0),
  operation_id uuid NOT NULL,
  actor_id uuid NOT NULL,
  device_id uuid NOT NULL,
  payload_digest text NOT NULL CHECK (payload_digest ~ '^[0-9a-f]{64}$'),
  accepted_at_us bigint NOT NULL,
  payload_json text NOT NULL CHECK (octet_length(payload_json) <= 524288 AND json_typeof(payload_json::json) = 'object'),
  PRIMARY KEY (family_id, sequence),
  UNIQUE (family_id, operation_id),
  FOREIGN KEY (family_id, device_id, actor_id) REFERENCES fv_data.devices(family_id, id, member_id)
);

DO $$
DECLARE name text;
BEGIN
  FOREACH name IN ARRAY ARRAY['ledger_accounts','ledger_journals','ledger_postings','sync_clocks','sync_changes'] LOOP
    EXECUTE format('ALTER TABLE fv_data.%I ENABLE ROW LEVEL SECURITY', name);
    EXECUTE format('ALTER TABLE fv_data.%I FORCE ROW LEVEL SECURITY', name);
    EXECUTE format('CREATE POLICY internal_executor ON fv_data.%I TO familyvault_executor USING (true) WITH CHECK (true)', name);
    EXECUTE format('REVOKE ALL ON TABLE fv_data.%I FROM PUBLIC, anon, authenticated, service_role', name);
  END LOOP;
END;
$$;

CREATE TRIGGER fv_postings_immutable BEFORE UPDATE OR DELETE OR TRUNCATE ON fv_data.ledger_postings
  FOR EACH STATEMENT EXECUTE FUNCTION fv_internal.forbid_audit_change();
CREATE TRIGGER fv_receipts_immutable BEFORE UPDATE OR DELETE OR TRUNCATE ON fv_data.sync_changes
  FOR EACH STATEMENT EXECUTE FUNCTION fv_internal.forbid_audit_change();
CREATE TRIGGER fv_journals_retain BEFORE DELETE OR TRUNCATE ON fv_data.ledger_journals
  FOR EACH STATEMENT EXECUTE FUNCTION fv_internal.forbid_audit_change();
CREATE TRIGGER fv_accounts_retain BEFORE DELETE OR TRUNCATE ON fv_data.ledger_accounts
  FOR EACH STATEMENT EXECUTE FUNCTION fv_internal.forbid_audit_change();

CREATE FUNCTION fv_internal.guard_posting_insert() RETURNS trigger
LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM fv_data.ledger_journals WHERE (family_id, id) = (NEW.family_id, NEW.journal_id) AND status = 'draft')
      OR NOT EXISTS (SELECT 1 FROM fv_data.ledger_accounts WHERE (family_id, id) = (NEW.family_id, NEW.account_id) AND deleted_at_us IS NULL) THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'The posting needs a draft journal and active family account';
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER fv_posting_scope BEFORE INSERT ON fv_data.ledger_postings
  FOR EACH ROW EXECUTE FUNCTION fv_internal.guard_posting_insert();

CREATE FUNCTION fv_internal.guard_journal() RETURNS trigger
LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE debit numeric;
DECLARE credit numeric;
DECLARE posting_count integer;
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.status <> 'draft' OR NEW.revision <> 1 OR NEW.deleted_at_us IS NOT NULL THEN
      RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Start with a new draft journal';
    END IF;
    RETURN NEW;
  END IF;
  IF (to_jsonb(NEW) - ARRAY['status','deleted_at_us','updated_at_us','updated_by','revision'])
      IS DISTINCT FROM (to_jsonb(OLD) - ARRAY['status','deleted_at_us','updated_at_us','updated_by','revision']) THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Journal facts are immutable';
  END IF;
  IF OLD.status = 'posted' THEN
    IF NEW.status <> 'posted' OR OLD.deleted_at_us IS NOT NULL OR NEW.deleted_at_us IS NULL
        OR NEW.revision <> OLD.revision + 1 OR NOT EXISTS (
          SELECT 1 FROM fv_data.ledger_journals r WHERE r.family_id = OLD.family_id
            AND r.reverses_id = OLD.id AND r.status = 'posted') THEN
      RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'A posted journal needs an exact reversal to be closed';
    END IF;
    RETURN NEW;
  END IF;
  IF NEW.status = 'posted' THEN
    SELECT count(*), sum(amount_minor) FILTER (WHERE amount_minor > 0),
        -sum(amount_minor) FILTER (WHERE amount_minor < 0)
      INTO posting_count, debit, credit FROM fv_data.ledger_postings WHERE family_id=NEW.family_id AND journal_id = NEW.id;
    IF posting_count NOT BETWEEN 2 AND 100 OR debit IS NULL OR credit IS NULL OR debit <> credit
        OR debit > 9223372036854775807 THEN
      RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Debits and credits must balance within the supported limit';
    END IF;
    IF NEW.reverses_id IS NOT NULL THEN
      IF NOT EXISTS (SELECT 1 FROM fv_data.ledger_journals o WHERE (o.family_id, o.id) = (NEW.family_id, NEW.reverses_id)
          AND o.status = 'posted' AND o.deleted_at_us IS NULL AND o.kind <> 'reversal'
          AND (o.occurred_on, o.currency, o.business_id, o.related_entity_id)
            IS NOT DISTINCT FROM (NEW.occurred_on, NEW.currency, NEW.business_id, NEW.related_entity_id))
        OR EXISTS (SELECT 1 FROM
          (SELECT position, account_id, amount_minor FROM fv_data.ledger_postings WHERE family_id=NEW.family_id AND journal_id = NEW.id) r
          FULL JOIN (SELECT position, account_id, amount_minor FROM fv_data.ledger_postings WHERE family_id=NEW.family_id AND journal_id = NEW.reverses_id) o
          USING (position) WHERE r.account_id IS DISTINCT FROM o.account_id
            OR r.amount_minor::numeric IS DISTINCT FROM -o.amount_minor::numeric) THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Reversals must mirror the original posted entry';
      END IF;
    END IF;
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER fv_journal_seal BEFORE INSERT OR UPDATE ON fv_data.ledger_journals
  FOR EACH ROW EXECUTE FUNCTION fv_internal.guard_journal();

-- Preserve exact 64-bit input. Check the original JSON tokens before conversion
-- to jsonb can normalize equivalent number spellings or discard duplicate keys.
CREATE FUNCTION fv_internal.validate_integer_json(value json, depth integer DEFAULT 0) RETURNS void
LANGUAGE plpgsql IMMUTABLE SET search_path = '' AS $$
DECLARE child json;
BEGIN
  IF depth > 18 THEN RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Change payload is too deeply nested'; END IF;
  CASE json_typeof(value)
    WHEN 'number' THEN
      IF value::text !~ '^-?(0|[1-9][0-9]{0,18})$' OR value::text::numeric NOT BETWEEN -9223372036854775808 AND 9223372036854775807 THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Use exact signed integer amounts';
      END IF;
    WHEN 'object' THEN
      IF EXISTS (SELECT 1 FROM json_each(value) GROUP BY key HAVING count(*) > 1) THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Change fields must be unique';
      END IF;
      FOR child IN SELECT node.value FROM json_each(value) node LOOP
        PERFORM fv_internal.validate_integer_json(child, depth + 1);
      END LOOP;
    WHEN 'array' THEN
      FOR child IN SELECT * FROM json_array_elements(value) LOOP
        PERFORM fv_internal.validate_integer_json(child, depth + 1);
      END LOOP;
    ELSE NULL;
  END CASE;
END;
$$;

CREATE FUNCTION fv_internal.input_int(value jsonb, key text) RETURNS bigint
LANGUAGE plpgsql IMMUTABLE SET search_path = '' AS $$
BEGIN
  IF jsonb_typeof(value->key) IS DISTINCT FROM 'number' OR (value->>key) !~ '^-?(0|[1-9][0-9]{0,18})$' THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Integer change field required';
  END IF;
  RETURN (value->>key)::bigint;
END;
$$;

CREATE FUNCTION fv_internal.fields(value jsonb, allowed text[]) RETURNS void
LANGUAGE plpgsql IMMUTABLE SET search_path = '' AS $$
BEGIN
  IF jsonb_typeof(value) IS DISTINCT FROM 'object' OR value - allowed <> '{}'::jsonb THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Unsupported change fields';
  END IF;
END;
$$;

CREATE FUNCTION fv_internal.input_id(value jsonb, key text) RETURNS uuid
LANGUAGE plpgsql IMMUTABLE SET search_path = '' AS $$
BEGIN
  IF jsonb_typeof(value->key) IS DISTINCT FROM 'string'
      OR (value->>key) !~ '^[0-9a-f]{8}(-[0-9a-f]{4}){3}-[0-9a-f]{12}$' THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Canonical UUID change field required';
  END IF;
  RETURN (value->>key)::uuid;
END;
$$;

CREATE FUNCTION fv_internal.chart_id(p_family uuid, p_code text) RETURNS uuid
LANGUAGE sql IMMUTABLE STRICT SET search_path = '' AS $$
  WITH digest AS (SELECT encode(sha256(convert_to(p_family::text || '/chart/' || p_code, 'UTF8')), 'hex') AS h)
  SELECT (substr(h,1,8) || '-' || substr(h,9,4) || '-8' || substr(h,14,3) || '-8' || substr(h,18,3) || '-' || substr(h,21,12))::uuid FROM digest
$$;

CREATE FUNCTION fv_internal.seed_chart(p_family uuid) RETURNS void
LANGUAGE sql SET search_path = '' AS $$
  INSERT INTO fv_data.ledger_accounts(id, family_id, revision, created_by, updated_by,
    created_at_us, updated_at_us, name, kind, subtype, currency, system_account)
  SELECT fv_internal.chart_id(p_family, def.code), p_family, 1, m.id, m.id,
    (extract(epoch FROM f.created_at)*1000000)::bigint, (extract(epoch FROM f.created_at)*1000000)::bigint,
    def.name, def.kind, def.code, 'INR', true
  FROM fv_data.families f JOIN fv_data.members m ON m.family_id = f.id AND m.role = 'administrator' AND m.active
  CROSS JOIN (VALUES ('Opening balances','equity','opening'), ('Reconciliation adjustments','equity','reconciliation'),
    ('Salary','income','salary'), ('Business income','income','business_income'), ('Rental income','income','rental'),
    ('Other income','income','other_income'), ('Household','expense','household'), ('Groceries','expense','groceries'),
    ('Utilities','expense','utilities'), ('Transport','expense','transport'), ('Shopping','expense','shopping'),
    ('Medical','expense','medical'), ('Education','expense','education'), ('Business expenses','expense','business_expense'),
    ('Other expenses','expense','other_expense'), ('Asset valuation reserve','equity','asset_revaluation'),
    ('Capital disposal reserve','equity','capital_disposals'), ('Interest paid','expense','interest_paid'),
    ('Interest received','income','interest_received')) AS def(name, kind, code)
  WHERE f.id = p_family ON CONFLICT (family_id, id) DO NOTHING
$$;

CREATE FUNCTION fv_internal.apply_account(actor fv_internal.device_context, record jsonb, p_base bigint)
RETURNS void LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE incoming fv_data.ledger_accounts;
DECLARE stored fv_data.ledger_accounts;
BEGIN
  PERFORM fv_internal.fields(record, ARRAY['id','family_id','revision','created_by','updated_by','created_at_us','updated_at_us',
    'deleted_at_us','name','kind','subtype','currency','system_account']);
  IF jsonb_typeof(record->'system_account') IS DISTINCT FROM 'boolean' THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Account record required';
  END IF;
  PERFORM fv_internal.input_int(record, 'created_at_us');
  PERFORM fv_internal.input_int(record, 'updated_at_us');
  IF record->>'deleted_at_us' IS NOT NULL THEN PERFORM fv_internal.input_int(record, 'deleted_at_us'); END IF;
  SELECT * INTO incoming FROM jsonb_populate_record(NULL::fv_data.ledger_accounts, record);
  IF to_jsonb(incoming) IS DISTINCT FROM record THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Use canonical account values';
  END IF;
  IF incoming.family_id IS DISTINCT FROM actor.family_id OR incoming.updated_by IS DISTINCT FROM actor.member_id
      OR fv_internal.input_int(record, 'revision') <> p_base + 1 OR incoming.system_account OR incoming.kind = 'equity'
      OR incoming.subtype LIKE 'managed\_%' ESCAPE '\' THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'This account change is outside the permitted scope';
  END IF;
  SELECT * INTO stored FROM fv_data.ledger_accounts WHERE id = incoming.id AND family_id = actor.family_id;
  IF coalesce(stored.revision, 0) <> p_base THEN
    RAISE EXCEPTION USING ERRCODE = 'PT409', MESSAGE = 'The account revision changed';
  END IF;
  IF stored.id IS NULL THEN
    IF incoming.created_by IS DISTINCT FROM actor.member_id OR incoming.deleted_at_us IS NOT NULL THEN
      RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'The creator must be the current member';
    END IF;
    INSERT INTO fv_data.ledger_accounts SELECT (incoming).*;
  ELSE
    IF stored.system_account OR stored.subtype LIKE 'managed\_%' ESCAPE '\'
      OR (incoming.created_by, incoming.created_at_us, incoming.currency, incoming.kind, incoming.subtype)
         IS DISTINCT FROM (stored.created_by, stored.created_at_us, stored.currency, stored.kind, stored.subtype) THEN
      RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'Account identity and provenance are immutable';
    END IF;
    IF incoming.deleted_at_us IS NOT NULL AND incoming.deleted_at_us IS DISTINCT FROM stored.deleted_at_us
        AND stored.kind IN ('asset','liability') AND (SELECT coalesce(sum(amount_minor), 0) FROM fv_data.ledger_postings p
          JOIN fv_data.ledger_journals j ON (j.family_id,j.id)=(p.family_id,p.journal_id)
          WHERE p.family_id=actor.family_id AND p.account_id=stored.id AND j.status='posted') <> 0 THEN
      RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'An account with a balance cannot be archived';
    END IF;
    UPDATE fv_data.ledger_accounts SET name = incoming.name, revision = incoming.revision, updated_by = incoming.updated_by,
      updated_at_us = incoming.updated_at_us, deleted_at_us = incoming.deleted_at_us WHERE family_id=actor.family_id AND id = stored.id;
  END IF;
END;
$$;

CREATE FUNCTION fv_internal.insert_journal(actor fv_internal.device_context, record jsonb, allow_reversal boolean)
RETURNS uuid LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE incoming fv_data.ledger_journals;
DECLARE posting fv_data.ledger_postings;
DECLARE element jsonb;
BEGIN
  PERFORM fv_internal.fields(record, ARRAY['id','family_id','revision','created_by','updated_by','created_at_us','updated_at_us',
    'deleted_at_us','kind','occurred_on','description','currency','status','reverses_id','business_id','related_entity_id','postings']);
  IF jsonb_typeof(record->'postings') IS DISTINCT FROM 'array'
      OR jsonb_array_length(record->'postings') NOT BETWEEN 2 AND 100
      OR coalesce(record->>'occurred_on','') !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Complete dated journal and postings required';
  END IF;
  PERFORM fv_internal.input_int(record, 'created_at_us');
  PERFORM fv_internal.input_int(record, 'updated_at_us');
  SELECT * INTO incoming FROM jsonb_populate_record(NULL::fv_data.ledger_journals, record);
  IF to_jsonb(incoming) IS DISTINCT FROM record - 'postings' THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Use canonical journal values';
  END IF;
  IF incoming.family_id IS DISTINCT FROM actor.family_id OR incoming.created_by IS DISTINCT FROM actor.member_id
      OR incoming.updated_by IS DISTINCT FROM actor.member_id OR fv_internal.input_int(record, 'revision') <> 1
      OR incoming.deleted_at_us IS NOT NULL OR incoming.status IS DISTINCT FROM 'posted'
      OR (incoming.reverses_id IS NOT NULL) <> allow_reversal OR incoming.business_id IS NOT NULL
      OR incoming.kind IN ('business','repayment') THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'Posting is outside the ordinary ledger scope';
  END IF;
  incoming.status := 'draft';
  INSERT INTO fv_data.ledger_journals SELECT (incoming).*;
  FOR element IN SELECT * FROM jsonb_array_elements(record->'postings') LOOP
    PERFORM fv_internal.fields(element, ARRAY['id','family_id','journal_id','account_id','position','amount_minor']);
    PERFORM fv_internal.input_int(element, 'amount_minor');
    PERFORM fv_internal.input_int(element, 'position');
    SELECT * INTO posting FROM jsonb_populate_record(NULL::fv_data.ledger_postings, element);
    IF to_jsonb(posting) IS DISTINCT FROM element THEN
      RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Use canonical posting values';
    END IF;
    IF posting.family_id IS DISTINCT FROM actor.family_id OR posting.journal_id IS DISTINCT FROM incoming.id
      OR NOT EXISTS (SELECT 1 FROM fv_data.ledger_accounts a WHERE (a.family_id,a.id)=(actor.family_id,posting.account_id)
        AND a.subtype NOT LIKE 'managed\_%' ESCAPE '\') THEN
      RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'Posting refers to an account outside the ordinary ledger';
    END IF;
    INSERT INTO fv_data.ledger_postings SELECT (posting).*;
  END LOOP;
  UPDATE fv_data.ledger_journals SET status = 'posted' WHERE family_id=actor.family_id AND id = incoming.id;
  RETURN incoming.id;
END;
$$;

CREATE FUNCTION fv_internal.close_journal(actor fv_internal.device_context, record jsonb, reversal jsonb, p_base bigint)
RETURNS void LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE original fv_data.ledger_journals;
DECLARE change fv_data.ledger_journals;
BEGIN
  PERFORM fv_internal.fields(record, ARRAY['id','family_id','revision','created_by','updated_by','created_at_us','updated_at_us',
    'deleted_at_us','kind','occurred_on','description','currency','status','reverses_id','business_id','related_entity_id','postings']);
  SELECT * INTO change FROM jsonb_populate_record(NULL::fv_data.ledger_journals, record);
  IF to_jsonb(change) IS DISTINCT FROM record - 'postings' THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Use canonical correction values';
  END IF;
  SELECT * INTO original FROM fv_data.ledger_journals WHERE id=change.id AND family_id=actor.family_id;
  IF original.id IS NULL OR original.revision <> p_base OR original.deleted_at_us IS NOT NULL THEN
    RAISE EXCEPTION USING ERRCODE = 'PT409', MESSAGE = 'The journal changed before correction';
  END IF;
  IF change.updated_by IS DISTINCT FROM actor.member_id OR fv_internal.input_int(record,'revision') <> p_base + 1
    OR fv_internal.input_int(record,'deleted_at_us') IS NULL OR (reversal->>'reverses_id')::uuid IS DISTINCT FROM original.id
    OR (to_jsonb(change) - ARRAY['revision','deleted_at_us','updated_at_us','updated_by'])
      IS DISTINCT FROM (to_jsonb(original) - ARRAY['revision','deleted_at_us','updated_at_us','updated_by'])
    OR (SELECT jsonb_agg(to_jsonb(p) ORDER BY p.position) FROM fv_data.ledger_postings p WHERE p.family_id=actor.family_id AND p.journal_id=original.id)
      IS DISTINCT FROM record->'postings' THEN
      RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Invalid journal correction history';
  END IF;
  PERFORM fv_internal.input_int(record,'updated_at_us');
  PERFORM fv_internal.insert_journal(actor, reversal, true);
  UPDATE fv_data.ledger_journals SET deleted_at_us=change.deleted_at_us, updated_at_us=change.updated_at_us,
    updated_by=change.updated_by, revision=change.revision WHERE family_id=actor.family_id AND id=original.id;
END;
$$;

-- A later migration can extend typed finance commands without replacing the
-- identity, idempotency and ordering logic of sync_push.
CREATE FUNCTION fv_internal.apply_module_change(actor fv_internal.device_context, envelope jsonb,
  record jsonb, bundle jsonb, p_base bigint) RETURNS void
LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'This record type is unavailable for synchronization';
END;
$$;

CREATE FUNCTION fv_internal.sync_push(p_device uuid, p_proof text, p_envelope text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE actor fv_internal.device_context := fv_internal.require_device(p_device, p_proof);
DECLARE envelope jsonb;
DECLARE record jsonb;
DECLARE bundle jsonb;
DECLARE operation uuid;
DECLARE root_id uuid;
DECLARE entity text;
DECLARE digest text;
DECLARE base_revision bigint;
DECLARE change fv_data.sync_changes;
DECLARE next_sequence bigint;
DECLARE opening jsonb;
BEGIN
  IF p_envelope IS NULL OR octet_length(p_envelope) > 524288 THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Change envelope is missing or too large';
  END IF;
  PERFORM fv_internal.validate_integer_json(p_envelope::json);
  envelope := p_envelope::jsonb;
  PERFORM fv_internal.fields(envelope, ARRAY['protocol_version','operation_id','family_id','device_id','actor_id',
    'entity_type','entity_id','mutation_kind','base_revision','command_digest','record','bundle']);
  IF jsonb_typeof(envelope) IS DISTINCT FROM 'object' OR fv_internal.input_int(envelope, 'protocol_version') <> 1
      OR fv_internal.input_id(envelope,'family_id') IS DISTINCT FROM actor.family_id
      OR fv_internal.input_id(envelope,'actor_id') IS DISTINCT FROM actor.member_id
      OR fv_internal.input_id(envelope,'device_id') IS DISTINCT FROM actor.device_id THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'Mutation identity does not match the enrolled session';
  END IF;
  operation := fv_internal.input_id(envelope,'operation_id');
  root_id := fv_internal.input_id(envelope,'entity_id');
  entity := envelope->>'entity_type';
  record := envelope->'record';
  bundle := envelope->'bundle';
  base_revision := fv_internal.input_int(envelope,'base_revision');
  IF operation IS NULL OR root_id IS NULL OR jsonb_typeof(record) IS DISTINCT FROM 'object'
      OR fv_internal.input_id(record,'id') IS DISTINCT FROM root_id OR base_revision NOT BETWEEN 0 AND 9223372036854775806
      OR coalesce(envelope->>'mutation_kind','') NOT IN ('upsert','delete') THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Complete typed change fields required';
  END IF;
  digest := encode(sha256(convert_to(p_envelope,'UTF8')),'hex');

  -- Serialize accepted operations per family. The clock and change row share the
  -- financial transaction, so failed operations do not leave sequence gaps.
  INSERT INTO fv_data.sync_clocks(family_id) VALUES (actor.family_id) ON CONFLICT DO NOTHING;
  PERFORM 1 FROM fv_data.sync_clocks WHERE family_id=actor.family_id FOR UPDATE;
  PERFORM 1 FROM fv_data.members m JOIN fv_data.devices d ON (d.family_id,d.member_id)=(m.family_id,m.id)
    JOIN fv_data.session_bindings b ON (b.family_id,b.device_id,b.member_id)=(d.family_id,d.id,d.member_id)
    WHERE m.active AND d.state='enrolled' AND b.revoked_at IS NULL AND b.session_id=actor.session_id
    FOR SHARE OF m,d,b;
  IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'Access changed before accepting this operation'; END IF;
  PERFORM fv_internal.current_auth();
  SELECT * INTO change FROM fv_data.sync_changes WHERE family_id=actor.family_id AND operation_id=operation;
  IF change.operation_id IS NOT NULL THEN
    IF change.payload_digest <> digest OR (change.actor_id,change.device_id) IS DISTINCT FROM (actor.member_id,actor.device_id) THEN
      RAISE EXCEPTION USING ERRCODE = '23505', MESSAGE = 'Operation ID is already in use';
    END IF;
    RETURN jsonb_build_object('operation_id',operation,'payload_digest',digest,'sequence',change.sequence);
  END IF;
  PERFORM fv_internal.seed_chart(actor.family_id);
  CASE entity
    WHEN 'account' THEN
      IF (envelope->>'mutation_kind' = 'delete') <> (record->>'deleted_at_us' IS NOT NULL) THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'The action must match the account state';
      END IF;
      PERFORM fv_internal.apply_account(actor, record, base_revision);
      IF bundle IS NOT NULL AND bundle <> 'null'::jsonb THEN
        PERFORM fv_internal.fields(bundle, ARRAY['journals']);
        opening := bundle->'journals'->0;
        IF base_revision <> 0 OR record->>'kind' NOT IN ('asset','liability')
            OR jsonb_typeof(bundle->'journals') IS DISTINCT FROM 'array'
            OR jsonb_array_length(bundle->'journals') <> 1 OR opening->>'kind' IS DISTINCT FROM 'opening'
            OR jsonb_typeof(opening->'postings') IS DISTINCT FROM 'array'
            OR jsonb_array_length(opening->'postings') <> 2
            OR (SELECT array_agg(fv_internal.input_id(p,'account_id') ORDER BY fv_internal.input_id(p,'account_id'))
                FROM jsonb_array_elements(opening->'postings') p)
              IS DISTINCT FROM (SELECT array_agg(id ORDER BY id) FROM unnest(ARRAY[root_id, fv_internal.chart_id(actor.family_id,'opening')]) id) THEN
          RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Opening entry must balance this new account and opening equity';
        END IF;
        PERFORM fv_internal.insert_journal(actor, opening, false);
      END IF;
    WHEN 'journal' THEN
      IF base_revision <> 0 OR bundle IS NOT NULL OR envelope->>'mutation_kind' <> 'upsert' THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Only new journals can post directly';
      END IF;
      PERFORM fv_internal.insert_journal(actor, record, false);
    WHEN 'journal_reversal' THEN
      IF envelope->>'mutation_kind' <> 'upsert' THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'A reversal appends a new journal';
      END IF;
      PERFORM fv_internal.fields(bundle, ARRAY['original']);
      PERFORM fv_internal.close_journal(actor, bundle->'original', record, base_revision);
    WHEN 'journal_correction' THEN
      IF envelope->>'mutation_kind' <> 'upsert' THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'A correction appends a new journal';
      END IF;
      PERFORM fv_internal.fields(bundle, ARRAY['original','reversal']);
      IF (record->>'business_id',record->>'related_entity_id') IS DISTINCT FROM
          (bundle->'original'->>'business_id',bundle->'original'->>'related_entity_id') THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Correction must retain its record scope';
      END IF;
      PERFORM fv_internal.close_journal(actor, bundle->'original', bundle->'reversal', base_revision);
      PERFORM fv_internal.insert_journal(actor, record, false);
    ELSE PERFORM fv_internal.apply_module_change(actor,envelope,record,bundle,base_revision);
  END CASE;
  UPDATE fv_data.sync_clocks SET last_sequence=last_sequence+1 WHERE family_id=actor.family_id RETURNING last_sequence INTO next_sequence;
  INSERT INTO fv_data.sync_changes(family_id,sequence,operation_id,actor_id,device_id,payload_digest,accepted_at_us,payload_json)
    VALUES(actor.family_id,next_sequence,operation,actor.member_id,actor.device_id,digest,
      (extract(epoch FROM statement_timestamp()) * 1000000)::bigint,p_envelope);
  RETURN jsonb_build_object('operation_id',operation,'payload_digest',digest,'sequence',next_sequence);
END;
$$;

CREATE FUNCTION fv_internal.sync_pull(p_device uuid, p_proof text, p_after bigint, p_limit integer DEFAULT 50) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE actor fv_internal.device_context := fv_internal.require_device(p_device, p_proof);
DECLARE watermark bigint;
BEGIN
  IF p_after IS NULL OR p_after < 0 OR p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 100 THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Invalid sync page';
  END IF;
  SELECT coalesce((SELECT last_sequence FROM fv_data.sync_clocks WHERE family_id=actor.family_id),0) INTO watermark;
  IF p_after > watermark THEN RAISE EXCEPTION USING ERRCODE = 'PT409', MESSAGE = 'Sync cursor requires recovery'; END IF;
  RETURN (WITH page AS MATERIALIZED (
    SELECT sequence, operation_id, payload_digest, accepted_at_us, payload_json FROM fv_data.sync_changes
    WHERE family_id=actor.family_id AND sequence > p_after AND sequence <= watermark ORDER BY sequence LIMIT p_limit
  ), sized AS (
    SELECT page AS event, sequence, sum(octet_length(payload_json)) OVER (ORDER BY sequence) AS bytes FROM page
  ) SELECT jsonb_build_object('watermark',watermark,'changes',coalesce(jsonb_agg(event ORDER BY sequence), '[]'::jsonb))
      FROM sized WHERE bytes <= 1048576);
END;
$$;

CREATE FUNCTION fv_internal.sync_chart(p_device uuid, p_proof text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE actor fv_internal.device_context := fv_internal.require_device(p_device, p_proof);
BEGIN
  PERFORM fv_internal.seed_chart(actor.family_id);
  RETURN coalesce((SELECT jsonb_agg(to_jsonb(a) ORDER BY a.subtype) FROM fv_data.ledger_accounts a
    WHERE a.family_id=actor.family_id AND a.system_account),'[]'::jsonb);
END;
$$;

GRANT EXECUTE ON FUNCTION fv_internal.sync_push(uuid,text,text), fv_internal.sync_pull(uuid,text,bigint,integer),
  fv_internal.sync_chart(uuid,text) TO authenticated;
RESET ROLE;
CREATE FUNCTION public.fv_sync_push(p_device uuid,p_proof text,p_envelope text) RETURNS jsonb
LANGUAGE sql SET search_path = '' AS 'SELECT fv_internal.sync_push(p_device,p_proof,p_envelope)';
CREATE FUNCTION public.fv_sync_pull(p_device uuid,p_proof text,p_after bigint,p_limit integer DEFAULT 50) RETURNS jsonb
LANGUAGE sql SET search_path = '' AS 'SELECT fv_internal.sync_pull(p_device,p_proof,p_after,p_limit)';
CREATE FUNCTION public.fv_sync_chart(p_device uuid,p_proof text) RETURNS jsonb
LANGUAGE sql SET search_path = '' AS 'SELECT fv_internal.sync_chart(p_device,p_proof)';
REVOKE ALL ON FUNCTION public.fv_sync_push(uuid,text,text), public.fv_sync_pull(uuid,text,bigint,integer),
  public.fv_sync_chart(uuid,text) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fv_sync_push(uuid,text,text), public.fv_sync_pull(uuid,text,bigint,integer),
  public.fv_sync_chart(uuid,text) TO authenticated;
COMMIT;
