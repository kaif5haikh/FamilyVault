-- Replicate monthly budgets and statement checks as typed commands.
BEGIN;
SET LOCAL ROLE familyvault_executor;
SET LOCAL search_path = '';

CREATE TABLE fv_data.monthly_budgets (
  id uuid NOT NULL,
  family_id uuid NOT NULL REFERENCES fv_data.families(id),
  revision bigint NOT NULL CHECK (revision > 0),
  created_by uuid NOT NULL,
  updated_by uuid NOT NULL,
  created_at_us bigint NOT NULL CHECK (created_at_us >= 0),
  updated_at_us bigint NOT NULL CHECK (updated_at_us >= created_at_us),
  deleted_at_us bigint CHECK (deleted_at_us >= created_at_us),
  account_id uuid NOT NULL,
  month text NOT NULL CHECK (month ~ '^[0-9]{4}-(0[1-9]|1[0-2])$' AND month BETWEEN '1900-01' AND '2200-12'),
  amount_minor bigint NOT NULL CHECK (amount_minor >= 0),
  PRIMARY KEY (family_id, id),
  FOREIGN KEY (family_id, created_by) REFERENCES fv_data.members(family_id, id),
  FOREIGN KEY (family_id, updated_by) REFERENCES fv_data.members(family_id, id),
  FOREIGN KEY (family_id, account_id) REFERENCES fv_data.ledger_accounts(family_id, id)
);
CREATE UNIQUE INDEX fv_active_monthly_budget ON fv_data.monthly_budgets(family_id, account_id, month)
  WHERE deleted_at_us IS NULL;

CREATE TABLE fv_data.reconciliation_checks (
  id uuid NOT NULL,
  family_id uuid NOT NULL REFERENCES fv_data.families(id),
  revision bigint NOT NULL CHECK (revision = 1),
  created_by uuid NOT NULL,
  updated_by uuid NOT NULL CHECK (updated_by = created_by),
  created_at_us bigint NOT NULL CHECK (created_at_us >= 0),
  updated_at_us bigint NOT NULL CHECK (updated_at_us = created_at_us),
  deleted_at_us bigint CHECK (deleted_at_us IS NULL),
  account_id uuid NOT NULL,
  statement_date date NOT NULL CHECK (statement_date BETWEEN DATE '1900-01-01' AND DATE '2200-12-31'),
  statement_minor bigint NOT NULL,
  ledger_minor bigint NOT NULL,
  notes text NOT NULL CHECK (length(btrim(notes)) BETWEEN 1 AND 500),
  PRIMARY KEY (family_id, id),
  FOREIGN KEY (family_id, created_by) REFERENCES fv_data.members(family_id, id),
  FOREIGN KEY (family_id, account_id) REFERENCES fv_data.ledger_accounts(family_id, id)
);

DO $$
DECLARE name text;
BEGIN
  FOREACH name IN ARRAY ARRAY['monthly_budgets','reconciliation_checks'] LOOP
    EXECUTE format('ALTER TABLE fv_data.%I ENABLE ROW LEVEL SECURITY', name);
    EXECUTE format('ALTER TABLE fv_data.%I FORCE ROW LEVEL SECURITY', name);
    EXECUTE format('CREATE POLICY internal_executor ON fv_data.%I TO familyvault_executor USING (true) WITH CHECK (true)', name);
    EXECUTE format('REVOKE ALL ON TABLE fv_data.%I FROM PUBLIC, anon, authenticated, service_role', name);
  END LOOP;
END;
$$;

CREATE TRIGGER fv_budgets_retain BEFORE DELETE OR TRUNCATE ON fv_data.monthly_budgets
  FOR EACH STATEMENT EXECUTE FUNCTION fv_internal.forbid_audit_change();
CREATE TRIGGER fv_reconciliations_immutable BEFORE UPDATE OR DELETE OR TRUNCATE ON fv_data.reconciliation_checks
  FOR EACH STATEMENT EXECUTE FUNCTION fv_internal.forbid_audit_change();

CREATE FUNCTION fv_internal.apply_budget(actor fv_internal.device_context, record jsonb, p_base bigint, p_kind text)
RETURNS void LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE incoming fv_data.monthly_budgets;
DECLARE stored fv_data.monthly_budgets;
BEGIN
  SELECT * INTO incoming FROM jsonb_populate_record(NULL::fv_data.monthly_budgets, record);
  IF to_jsonb(incoming) IS DISTINCT FROM record OR incoming.revision IS DISTINCT FROM p_base + 1
      OR (p_kind = 'delete') <> (incoming.deleted_at_us IS NOT NULL) THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Use a complete canonical budget record';
  END IF;
  IF (incoming.family_id,incoming.updated_by) IS DISTINCT FROM (actor.family_id,actor.member_id) THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'The budget must belong to this family';
  END IF;
  SELECT * INTO stored FROM fv_data.monthly_budgets WHERE (family_id,id)=(actor.family_id,incoming.id);
  IF coalesce(stored.revision,0) <> p_base OR stored.deleted_at_us IS NOT NULL THEN
    RAISE EXCEPTION USING ERRCODE = 'PT409', MESSAGE = 'The budget revision changed';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM fv_data.ledger_accounts WHERE (family_id,id)=(actor.family_id,incoming.account_id)
      AND kind='expense' AND (deleted_at_us IS NULL OR p_kind = 'delete')
      AND subtype NOT LIKE 'managed\_%' ESCAPE '\') THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Choose an available expense category';
  END IF;
  IF stored.id IS NULL THEN
    IF incoming.created_by IS DISTINCT FROM actor.member_id OR incoming.deleted_at_us IS NOT NULL THEN
      RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'Only an active budget can be created';
    END IF;
    IF EXISTS (SELECT 1 FROM fv_data.monthly_budgets WHERE family_id=actor.family_id AND account_id=incoming.account_id
        AND month=incoming.month AND deleted_at_us IS NULL) THEN
      RAISE EXCEPTION USING ERRCODE = 'PT409', MESSAGE = 'An active budget already covers this month';
    END IF;
    INSERT INTO fv_data.monthly_budgets SELECT (incoming).*;
  ELSE
    IF (incoming.created_by,incoming.created_at_us,incoming.account_id,incoming.month)
        IS DISTINCT FROM (stored.created_by,stored.created_at_us,stored.account_id,stored.month)
        OR (incoming.deleted_at_us IS NOT NULL AND incoming.amount_minor IS DISTINCT FROM stored.amount_minor) THEN
      RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Budget identity and deleted amounts are retained';
    END IF;
    UPDATE fv_data.monthly_budgets SET revision=incoming.revision, updated_by=incoming.updated_by,
      updated_at_us=incoming.updated_at_us, deleted_at_us=incoming.deleted_at_us, amount_minor=incoming.amount_minor
      WHERE (family_id,id)=(actor.family_id,stored.id);
  END IF;
END;
$$;

CREATE FUNCTION fv_internal.apply_reconciliation(actor fv_internal.device_context, record jsonb, bundle jsonb)
RETURNS void LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE incoming fv_data.reconciliation_checks;
DECLARE adjustment jsonb;
DECLARE actual_balance numeric;
DECLARE difference numeric;
DECLARE matching_postings integer;
BEGIN
  SELECT * INTO incoming FROM jsonb_populate_record(NULL::fv_data.reconciliation_checks, record);
  IF to_jsonb(incoming) IS DISTINCT FROM record THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Use a complete canonical statement check';
  END IF;
  IF (incoming.family_id,incoming.created_by,incoming.updated_by) IS DISTINCT FROM (actor.family_id,actor.member_id,actor.member_id) THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'The statement check must belong to this family';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM fv_data.ledger_accounts WHERE (family_id,id)=(actor.family_id,incoming.account_id)
      AND kind='asset' AND subtype IN ('cash','bank') AND deleted_at_us IS NULL) THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Choose an available cash or bank account';
  END IF;
  SELECT coalesce(sum(p.amount_minor),0) INTO actual_balance FROM fv_data.ledger_postings p
    JOIN fv_data.ledger_journals j ON (p.family_id,p.journal_id)=(j.family_id,j.id)
    WHERE p.family_id=actor.family_id AND p.account_id=incoming.account_id AND j.status='posted'
      AND j.occurred_on <= incoming.statement_date;
  IF incoming.ledger_minor IS DISTINCT FROM actual_balance THEN
    RAISE EXCEPTION USING ERRCODE = 'PT409', MESSAGE = 'The ledger balance for this statement changed';
  END IF;

  INSERT INTO fv_data.reconciliation_checks SELECT (incoming).*;
  IF bundle IS NULL THEN RETURN; END IF;
  PERFORM fv_internal.fields(bundle, ARRAY['adjustment']);
  adjustment := bundle->'adjustment';
  difference := incoming.statement_minor::numeric - actual_balance;
  IF difference = 0 OR adjustment->>'kind' IS DISTINCT FROM 'adjustment'
      OR adjustment->>'related_entity_id' IS DISTINCT FROM incoming.id::text
      OR adjustment->>'occurred_on' IS DISTINCT FROM incoming.statement_date::text
      OR jsonb_typeof(adjustment->'postings') IS DISTINCT FROM 'array'
      OR jsonb_array_length(adjustment->'postings') <> 2 THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'The adjustment must match the statement check';
  END IF;
  SELECT count(*) INTO matching_postings FROM jsonb_array_elements(adjustment->'postings') posting
    WHERE (fv_internal.input_id(posting,'account_id'),fv_internal.input_int(posting,'amount_minor')::numeric) IN (
      (incoming.account_id, difference), (fv_internal.chart_id(actor.family_id,'reconciliation'), -difference));
  IF matching_postings <> 2 THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'The adjustment must account for the exact difference';
  END IF;
  PERFORM fv_internal.insert_journal(actor, adjustment, false);
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
      PERFORM fv_internal.apply_budget(actor, record, p_base, envelope->>'mutation_kind');
    WHEN 'reconciliation' THEN
      IF p_base <> 0 OR envelope->>'mutation_kind' <> 'upsert' THEN
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Statement checks are append-only';
      END IF;
      PERFORM fv_internal.apply_reconciliation(actor, record, bundle);
    ELSE
      RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'This record type is unavailable for synchronization';
  END CASE;
END;
$$;
COMMIT;
