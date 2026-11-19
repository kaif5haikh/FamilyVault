-- Shared worker records and exact salary payments with linked reversals.
BEGIN;
SET LOCAL ROLE familyvault_executor;
SET LOCAL search_path = '';

CREATE TABLE fv_data.workers (
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
  monthly_salary_minor bigint CHECK (monthly_salary_minor>=0),
  notes text NOT NULL CHECK (length(notes)<=4000),
  PRIMARY KEY (family_id,id),
  UNIQUE (family_id,id,business_id),
  FOREIGN KEY (family_id,business_id) REFERENCES fv_data.businesses(family_id,id),
  FOREIGN KEY (family_id,created_by) REFERENCES fv_data.members(family_id,id),
  FOREIGN KEY (family_id,updated_by) REFERENCES fv_data.members(family_id,id)
);
CREATE INDEX fv_workers_by_business ON fv_data.workers(family_id,business_id);

CREATE TABLE fv_data.salary_payments (
  id uuid NOT NULL,
  family_id uuid NOT NULL,
  created_by uuid NOT NULL,
  device_id uuid NOT NULL,
  created_at_us bigint NOT NULL CHECK (created_at_us>=0),
  business_id uuid NOT NULL,
  worker_id uuid NOT NULL,
  journal_id uuid NOT NULL,
  period text NOT NULL CHECK (period ~ '^[0-9]{4}-(0[1-9]|1[0-2])$' AND period BETWEEN '1900-01' AND '2200-12'),
  paid_on date NOT NULL CHECK (paid_on BETWEEN DATE '1900-01-01' AND DATE '2200-12-31'),
  amount_minor bigint NOT NULL CHECK (amount_minor>0),
  notes text NOT NULL CHECK (length(notes)<=4000),
  PRIMARY KEY (family_id,id),
  UNIQUE (family_id,journal_id),
  FOREIGN KEY (family_id,device_id,created_by) REFERENCES fv_data.devices(family_id,id,member_id),
  FOREIGN KEY (family_id,worker_id,business_id) REFERENCES fv_data.workers(family_id,id,business_id),
  FOREIGN KEY (family_id,journal_id) REFERENCES fv_data.ledger_journals(family_id,id)
);
CREATE INDEX fv_salary_by_worker ON fv_data.salary_payments(family_id,worker_id,paid_on);
ALTER TABLE fv_data.workers ENABLE ROW LEVEL SECURITY;
ALTER TABLE fv_data.workers FORCE ROW LEVEL SECURITY;
CREATE POLICY internal_executor ON fv_data.workers TO familyvault_executor USING (true) WITH CHECK (true);
ALTER TABLE fv_data.salary_payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE fv_data.salary_payments FORCE ROW LEVEL SECURITY;
CREATE POLICY internal_executor ON fv_data.salary_payments TO familyvault_executor USING (true) WITH CHECK (true);
REVOKE ALL ON fv_data.workers,fv_data.salary_payments FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER fv_worker_retain BEFORE DELETE OR TRUNCATE ON fv_data.workers
  FOR EACH STATEMENT EXECUTE FUNCTION fv_internal.forbid_audit_change();
CREATE TRIGGER fv_salary_immutable BEFORE UPDATE OR DELETE OR TRUNCATE ON fv_data.salary_payments
  FOR EACH STATEMENT EXECUTE FUNCTION fv_internal.forbid_audit_change();

CREATE FUNCTION fv_internal.checked_salary(actor fv_internal.device_context, worker fv_data.workers,
  business fv_data.businesses, journal jsonb, raw jsonb) RETURNS fv_data.salary_payments
LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE payment fv_data.salary_payments;
DECLARE cash uuid;
BEGIN
  SELECT * INTO payment FROM jsonb_populate_record(NULL::fv_data.salary_payments,raw);
  IF to_jsonb(payment) IS DISTINCT FROM raw OR
    (payment.family_id,payment.business_id,payment.worker_id,payment.journal_id,payment.created_by,payment.device_id,payment.paid_on::text)
      IS DISTINCT FROM (actor.family_id,business.id,worker.id,fv_internal.input_id(journal,'id'),
        actor.member_id,actor.device_id,journal->>'occurred_on')
    OR journal->>'kind' IS DISTINCT FROM 'business' OR worker.deleted_at_us IS NOT NULL THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Salary must match its active worker, business and payment date';
  END IF;
  SELECT fv_internal.input_id(p,'account_id') INTO cash FROM jsonb_array_elements(journal->'postings') p
    WHERE fv_internal.liquid_ledger_account(actor.family_id,fv_internal.input_id(p,'account_id')) LIMIT 1;
  IF cash IS NULL THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Salary needs an active cash or bank account';
  END IF;
  PERFORM fv_internal.require_postings(journal,ARRAY[business.salary_account_id,cash],
    ARRAY[payment.amount_minor::numeric,-payment.amount_minor::numeric]);
  RETURN payment;
END;
$$;

CREATE FUNCTION fv_internal.apply_shared_worker(actor fv_internal.device_context, envelope jsonb,
  record jsonb, bundle jsonb, base bigint) RETURNS void
LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE worker fv_data.workers;
DECLARE prior fv_data.workers;
DECLARE business fv_data.businesses;
DECLARE payment fv_data.salary_payments;
DECLARE links jsonb;
DECLARE link jsonb;
DECLARE journal jsonb;
DECLARE mutable text[];
DECLARE archiving boolean := false;
DECLARE reversals integer := 0;
DECLARE payments integer := 0;
BEGIN
  PERFORM fv_internal.fields(bundle,ARRAY['salary_payments','journals','journal_links']);
  SELECT * INTO worker FROM jsonb_populate_record(NULL::fv_data.workers,record);
  IF to_jsonb(worker) IS DISTINCT FROM record THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Use canonical worker fields';
  END IF;
  SELECT * INTO prior FROM fv_data.workers WHERE (family_id,id)=(actor.family_id,worker.id);
  IF coalesce(prior.revision,0)<>base THEN
    RAISE EXCEPTION USING ERRCODE = 'PT409', MESSAGE = 'The worker revision changed';
  END IF;
  SELECT * INTO business FROM fv_data.businesses WHERE (family_id,id)=(actor.family_id,worker.business_id)
    AND deleted_at_us IS NULL;
  IF business.id IS NULL THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'Workers require an active family business';
  END IF;
  links := fv_internal.checked_journal_links(bundle);
  IF jsonb_array_length(links)>0 THEN
    mutable := ARRAY[]::text[];
    IF base=0 OR jsonb_array_length(links)>2 THEN
      RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Pay or correct one existing worker at a time';
    END IF;
  ELSIF prior.deleted_at_us IS NOT NULL OR worker.deleted_at_us IS NOT NULL THEN
    mutable := ARRAY['deleted_at_us'];
    archiving := worker.deleted_at_us IS NOT NULL;
    IF (prior.deleted_at_us IS NULL)=(worker.deleted_at_us IS NULL) THEN
      RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Restore the worker before editing their details';
    END IF;
  ELSE
    mutable := ARRAY['name','monthly_salary_minor','notes'];
  END IF;
  PERFORM fv_internal.check_record_revision(actor,record,
    CASE WHEN prior.id IS NULL THEN NULL ELSE to_jsonb(prior) END,base,mutable);
  IF (envelope->>'mutation_kind'='delete')<>archiving THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'The worker change must match its archive action';
  END IF;
  IF base=0 THEN
    INSERT INTO fv_data.workers SELECT (worker).*;
  ELSE
    UPDATE fv_data.workers SET revision=worker.revision,updated_by=worker.updated_by,updated_at_us=worker.updated_at_us,
      deleted_at_us=worker.deleted_at_us,name=worker.name,monthly_salary_minor=worker.monthly_salary_minor,notes=worker.notes
      WHERE (family_id,id)=(actor.family_id,worker.id);
  END IF;
  FOR link IN SELECT * FROM jsonb_array_elements(links) LOOP
    journal := fv_internal.bundle_journal(bundle,fv_internal.input_id(link,'journal_id'));
    CASE link->>'purpose'
      WHEN 'reversal' THEN
        reversals := reversals+1;
        IF reversals<>1 OR payments<>0 OR NOT EXISTS (
          SELECT 1 FROM fv_data.salary_payments p WHERE (p.family_id,p.worker_id,p.business_id,p.journal_id)=
            (actor.family_id,worker.id,business.id,fv_internal.input_id(journal,'reverses_id'))) THEN
          RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'Original salary journal does not belong to this worker';
        END IF;
      WHEN 'salary' THEN
        payments := payments+1;
        IF payments<>1 OR jsonb_typeof(bundle->'salary_payments') IS DISTINCT FROM 'array'
          OR jsonb_array_length(bundle->'salary_payments')<>1 THEN
          RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Salary journal needs its payment record';
        END IF;
        payment := fv_internal.checked_salary(actor,worker,business,journal,bundle->'salary_payments'->0);
      ELSE
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Unsupported salary journal purpose';
    END CASE;
    PERFORM fv_internal.apply_linked_journal(actor,envelope,bundle,link,'salary',worker.id,business.id,
      ARRAY[business.salary_account_id]);
    IF link->>'purpose'='salary' THEN INSERT INTO fv_data.salary_payments SELECT (payment).*; END IF;
  END LOOP;
  IF (bundle ? 'salary_payments')<>(payments=1) THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Every salary record needs its exact journal';
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
    WHEN 'worker' THEN
      PERFORM fv_internal.apply_shared_worker(actor,envelope,record,bundle,p_base);
    ELSE
      RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'This record type is unavailable for synchronization';
  END CASE;
END;
$$;

COMMIT;
