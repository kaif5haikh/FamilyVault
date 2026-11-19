-- Typed loan terms, managed principal and immutable repayment history.
BEGIN;
SET LOCAL ROLE familyvault_executor;
SET LOCAL search_path = '';

CREATE TABLE fv_data.debt_contracts (
  id uuid NOT NULL,
  family_id uuid NOT NULL REFERENCES fv_data.families(id),
  revision bigint NOT NULL CHECK (revision > 0),
  created_by uuid NOT NULL,
  updated_by uuid NOT NULL,
  created_at_us bigint NOT NULL CHECK (created_at_us >= 0),
  updated_at_us bigint NOT NULL CHECK (updated_at_us >= created_at_us),
  deleted_at_us bigint CHECK (deleted_at_us >= created_at_us),
  name text NOT NULL CHECK (length(btrim(name)) BETWEEN 1 AND 120),
  direction text NOT NULL CHECK (direction IN ('borrowed','lent','bank_loan')),
  counterparty text NOT NULL CHECK (length(btrim(counterparty)) BETWEEN 1 AND 120),
  account_id uuid NOT NULL,
  principal_minor bigint NOT NULL CHECK (principal_minor > 0),
  annual_rate_bps integer CHECK (annual_rate_bps BETWEEN 0 AND 1000000),
  interest_method text NOT NULL CHECK (interest_method IN ('unrecorded','simpleActual365','flatMonthly','reducingMonthly')),
  term_months integer CHECK (term_months BETWEEN 1 AND 600),
  emi_minor bigint CHECK (emi_minor >= 0),
  started_on date NOT NULL CHECK (started_on BETWEEN DATE '1900-01-01' AND DATE '2200-12-31'),
  first_due_on date CHECK (first_due_on BETWEEN DATE '1900-01-01' AND DATE '2200-12-31'),
  due_on date CHECK (due_on BETWEEN DATE '1900-01-01' AND DATE '2200-12-31'),
  currency text NOT NULL CHECK (currency='INR'),
  notes text NOT NULL CHECK (length(notes) <= 4000),
  PRIMARY KEY (family_id,id),
  UNIQUE (family_id,account_id),
  FOREIGN KEY (family_id,created_by) REFERENCES fv_data.members(family_id,id),
  FOREIGN KEY (family_id,updated_by) REFERENCES fv_data.members(family_id,id),
  FOREIGN KEY (family_id,account_id) REFERENCES fv_data.ledger_accounts(family_id,id),
  CHECK ((interest_method='unrecorded') = (annual_rate_bps IS NULL)),
  CHECK (first_due_on >= started_on),
  CHECK (due_on >= started_on AND due_on >= first_due_on)
);

CREATE TABLE fv_data.debt_repayments (
  id uuid NOT NULL,
  family_id uuid NOT NULL,
  created_by uuid NOT NULL,
  device_id uuid NOT NULL,
  created_at_us bigint NOT NULL CHECK (created_at_us >= 0),
  contract_id uuid NOT NULL,
  journal_id uuid NOT NULL,
  paid_on date NOT NULL CHECK (paid_on BETWEEN DATE '1900-01-01' AND DATE '2200-12-31'),
  principal_minor bigint NOT NULL CHECK (principal_minor >= 0),
  interest_minor bigint NOT NULL CHECK (interest_minor >= 0),
  notes text NOT NULL CHECK (length(notes) <= 4000),
  PRIMARY KEY (family_id,id),
  UNIQUE (family_id,journal_id),
  FOREIGN KEY (family_id,device_id,created_by) REFERENCES fv_data.devices(family_id,id,member_id),
  FOREIGN KEY (family_id,contract_id) REFERENCES fv_data.debt_contracts(family_id,id),
  FOREIGN KEY (family_id,journal_id) REFERENCES fv_data.ledger_journals(family_id,id),
  CHECK (principal_minor::numeric+interest_minor BETWEEN 1 AND 9223372036854775807)
);
CREATE INDEX fv_loan_repayments_by_date ON fv_data.debt_repayments(family_id,contract_id,paid_on);
ALTER TABLE fv_data.debt_contracts ENABLE ROW LEVEL SECURITY;
ALTER TABLE fv_data.debt_contracts FORCE ROW LEVEL SECURITY;
CREATE POLICY internal_executor ON fv_data.debt_contracts TO familyvault_executor USING (true) WITH CHECK (true);
ALTER TABLE fv_data.debt_repayments ENABLE ROW LEVEL SECURITY;
ALTER TABLE fv_data.debt_repayments FORCE ROW LEVEL SECURITY;
CREATE POLICY internal_executor ON fv_data.debt_repayments TO familyvault_executor USING (true) WITH CHECK (true);
REVOKE ALL ON fv_data.debt_contracts,fv_data.debt_repayments FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER fv_debt_contract_retain BEFORE DELETE OR TRUNCATE ON fv_data.debt_contracts
  FOR EACH STATEMENT EXECUTE FUNCTION fv_internal.forbid_audit_change();
CREATE TRIGGER fv_debt_repayment_immutable BEFORE UPDATE OR DELETE OR TRUNCATE ON fv_data.debt_repayments
  FOR EACH STATEMENT EXECUTE FUNCTION fv_internal.forbid_audit_change();

CREATE FUNCTION fv_internal.require_debt_opening(loan fv_data.debt_contracts, journal jsonb) RETURNS void
LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE cash uuid;
DECLARE signed_principal numeric := loan.principal_minor::numeric *
  (CASE WHEN loan.direction='lent' THEN 1 ELSE -1 END);
BEGIN
  IF journal->>'occurred_on' IS DISTINCT FROM loan.started_on::text THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Principal must use the recorded start date';
  END IF;
  IF journal->>'kind'='opening' THEN
    cash := fv_internal.chart_id(loan.family_id,'opening');
  ELSIF journal->>'kind'='adjustment' THEN
    SELECT fv_internal.input_id(p,'account_id') INTO cash FROM jsonb_array_elements(journal->'postings') p
      WHERE p->>'account_id'<>loan.account_id::text LIMIT 1;
    IF NOT fv_internal.liquid_ledger_account(loan.family_id,cash) THEN
      RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Loan funds need an active cash or bank account';
    END IF;
  ELSE
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Principal requires an opening or funds journal';
  END IF;
  PERFORM fv_internal.require_postings(journal,ARRAY[loan.account_id,cash],ARRAY[signed_principal,-signed_principal]);
END;
$$;

CREATE FUNCTION fv_internal.checked_debt_payment(actor fv_internal.device_context, loan fv_data.debt_contracts,
  journal jsonb, raw jsonb) RETURNS fv_data.debt_repayments
LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE payment fv_data.debt_repayments;
DECLARE cash uuid;
DECLARE interest uuid := fv_internal.chart_id(loan.family_id,CASE WHEN loan.direction='lent' THEN 'interest_received' ELSE 'interest_paid' END);
DECLARE direction_sign integer := CASE WHEN loan.direction='lent' THEN 1 ELSE -1 END;
DECLARE outstanding numeric := direction_sign * fv_internal.ledger_balance_through(loan.family_id,loan.account_id,NULL);
DECLARE signed_cash numeric;
BEGIN
  SELECT * INTO payment FROM jsonb_populate_record(NULL::fv_data.debt_repayments,raw);
  IF to_jsonb(payment) IS DISTINCT FROM raw OR
    (payment.family_id,payment.contract_id,payment.journal_id,payment.created_by,payment.device_id,payment.paid_on::text)
      IS DISTINCT FROM (actor.family_id,loan.id,fv_internal.input_id(journal,'id'),actor.member_id,actor.device_id,journal->>'occurred_on')
    OR journal->>'kind' IS DISTINCT FROM 'repayment'
    OR payment.paid_on<loan.started_on OR payment.principal_minor>outstanding THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Repayment must match the active loan, date and outstanding principal';
  END IF;
  SELECT fv_internal.input_id(p,'account_id') INTO cash FROM jsonb_array_elements(journal->'postings') p
    WHERE fv_internal.liquid_ledger_account(loan.family_id,fv_internal.input_id(p,'account_id')) LIMIT 1;
  IF cash IS NULL THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Repayment needs an active cash or bank account';
  END IF;
  signed_cash := direction_sign * (payment.principal_minor::numeric+payment.interest_minor);
  PERFORM fv_internal.require_postings(journal,ARRAY[cash,loan.account_id,interest],
    ARRAY[signed_cash,-direction_sign*payment.principal_minor::numeric,-direction_sign*payment.interest_minor::numeric]);
  RETURN payment;
END;
$$;

CREATE FUNCTION fv_internal.apply_shared_debt(actor fv_internal.device_context, envelope jsonb,
  record jsonb, bundle jsonb, base bigint) RETURNS void
LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE loan fv_data.debt_contracts;
DECLARE prior fv_data.debt_contracts;
DECLARE payment fv_data.debt_repayments;
DECLARE mode text;
DECLARE mutable text[];
DECLARE links jsonb;
DECLARE link jsonb;
DECLARE journal jsonb;
DECLARE reverses_id uuid;
DECLARE prior_purpose text;
DECLARE outstanding numeric;
DECLARE openings integer := 0;
DECLARE reversals integer := 0;
DECLARE payments integer := 0;
BEGIN
  PERFORM fv_internal.fields(bundle,ARRAY['accounts','journals','journal_links','repayments']);
  SELECT * INTO loan FROM jsonb_populate_record(NULL::fv_data.debt_contracts,record);
  IF to_jsonb(loan) IS DISTINCT FROM record THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Use canonical debt contract values';
  END IF;
  SELECT * INTO prior FROM fv_data.debt_contracts WHERE (family_id,id)=(actor.family_id,loan.id);
  IF coalesce(prior.revision,0)<>base THEN
    RAISE EXCEPTION USING ERRCODE = 'PT409', MESSAGE = 'The loan revision changed';
  END IF;
  outstanding := fv_internal.ledger_balance_through(actor.family_id,loan.account_id,NULL) *
    (CASE WHEN loan.direction='lent' THEN 1 ELSE -1 END);
  links := fv_internal.checked_journal_links(bundle);
  IF base=0 THEN
    mode := 'create';
    mutable := ARRAY[]::text[];
  ELSIF prior.deleted_at_us IS NOT NULL OR loan.deleted_at_us IS NOT NULL THEN
    mode := 'archive';
    mutable := ARRAY['deleted_at_us'];
    IF (prior.deleted_at_us IS NULL) = (loan.deleted_at_us IS NULL) OR outstanding<>0 THEN
      RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'A loan must be settled before changing its archive state';
    END IF;
  ELSIF EXISTS (SELECT 1 FROM jsonb_array_elements(links) r WHERE r->>'purpose'='opening') THEN
    mode := 'principal';
    mutable := ARRAY['principal_minor','started_on'];
    IF loan.principal_minor<prior.principal_minor-outstanding OR EXISTS (
        SELECT 1 FROM fv_data.debt_repayments r JOIN fv_data.ledger_journals j
          ON (j.family_id,j.id)=(r.family_id,r.journal_id)
        WHERE (r.family_id,r.contract_id)=(actor.family_id,loan.id) AND j.deleted_at_us IS NULL AND r.paid_on<loan.started_on) THEN
      RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Principal and start date must cover existing repayments';
    END IF;
  ELSIF jsonb_array_length(links)>0 THEN
    mode := 'payment';
    mutable := ARRAY[]::text[];
  ELSE
    mode := 'edit';
    mutable := ARRAY['name','counterparty','annual_rate_bps','interest_method','term_months','emi_minor','first_due_on','due_on','notes'];
  END IF;
  PERFORM fv_internal.check_record_revision(actor,record,
    CASE WHEN prior.id IS NULL THEN NULL ELSE to_jsonb(prior) END,base,mutable);
  IF (envelope->>'mutation_kind'='delete') <> (loan.deleted_at_us IS NOT NULL) OR
    (mode<>'payment' AND bundle ? 'repayments') OR
    (mode='payment' AND jsonb_array_length(links)>2) OR
    (mode IN ('edit','archive') AND jsonb_array_length(links)<>0) THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Loan fields must match the operation';
  END IF;
  IF mode='create' OR loan.name IS DISTINCT FROM prior.name THEN
    IF jsonb_typeof(bundle->'accounts') IS DISTINCT FROM 'array' OR jsonb_array_length(bundle->'accounts')<>1 THEN
      RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Loan changes must carry their managed account';
    END IF;
    PERFORM fv_internal.apply_managed_account(actor,bundle->'accounts'->0,loan.account_id,
      CASE WHEN loan.direction='lent' THEN 'asset' ELSE 'liability' END,
      'managed_'||loan.direction,loan.name,mode='create');
  ELSIF bundle ? 'accounts' THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'An unchanged loan name needs no account revision';
  END IF;
  IF mode='create' THEN
    INSERT INTO fv_data.debt_contracts SELECT (loan).*;
  ELSE
    UPDATE fv_data.debt_contracts SET revision=loan.revision,updated_by=loan.updated_by,updated_at_us=loan.updated_at_us,
      deleted_at_us=loan.deleted_at_us,name=loan.name,counterparty=loan.counterparty,principal_minor=loan.principal_minor,
      annual_rate_bps=loan.annual_rate_bps,interest_method=loan.interest_method,term_months=loan.term_months,
      emi_minor=loan.emi_minor,started_on=loan.started_on,first_due_on=loan.first_due_on,due_on=loan.due_on,notes=loan.notes
      WHERE (family_id,id)=(actor.family_id,loan.id);
  END IF;
  FOR link IN SELECT * FROM jsonb_array_elements(links) LOOP
    journal := fv_internal.bundle_journal(bundle,fv_internal.input_id(link,'journal_id'));
    CASE link->>'purpose'
      WHEN 'opening' THEN
        openings := openings+1;
        IF mode NOT IN ('create','principal') OR openings<>1 OR (mode='principal' AND reversals<>1) THEN
          RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Principal correction must reverse the old opening first';
        END IF;
        PERFORM fv_internal.require_debt_opening(loan,journal);
      WHEN 'reversal' THEN
        reversals := reversals+1;
        reverses_id := fv_internal.input_id(journal,'reverses_id');
        SELECT l.purpose INTO prior_purpose FROM fv_data.aggregate_journal_links l
          WHERE (l.family_id,l.journal_id)=(actor.family_id,reverses_id);
        IF reversals<>1 OR openings<>0 OR payments<>0 OR
          NOT ((mode='principal' AND prior_purpose IS NOT DISTINCT FROM 'opening') OR
            (mode='payment' AND prior_purpose IS NOT DISTINCT FROM 'repayment' AND EXISTS (
              SELECT 1 FROM fv_data.debt_repayments r
              WHERE (r.family_id,r.contract_id,r.journal_id)=(actor.family_id,loan.id,reverses_id)))) THEN
          RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'Original journal is outside this loan correction';
        END IF;
      WHEN 'repayment' THEN
        payments := payments+1;
        IF mode<>'payment' OR payments<>1 OR jsonb_typeof(bundle->'repayments') IS DISTINCT FROM 'array'
          OR jsonb_array_length(bundle->'repayments')<>1 THEN
          RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'A repayment needs one matching record';
        END IF;
        payment := fv_internal.checked_debt_payment(actor,loan,journal,bundle->'repayments'->0);
      ELSE
        RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Unsupported loan journal purpose';
    END CASE;
    PERFORM fv_internal.apply_linked_journal(actor,envelope,bundle,link,'debt',loan.id,NULL,ARRAY[loan.account_id]);
    IF link->>'purpose'='repayment' THEN INSERT INTO fv_data.debt_repayments SELECT (payment).*; END IF;
  END LOOP;
  IF (mode IN ('create','principal') AND (openings<>1 OR
      (SELECT count(*) FROM fv_data.aggregate_journal_links l JOIN fv_data.ledger_journals j
        ON (j.family_id,j.id)=(l.family_id,l.journal_id)
        WHERE (l.family_id,l.aggregate_type,l.aggregate_id,l.purpose)=(actor.family_id,'debt',loan.id,'opening')
          AND j.deleted_at_us IS NULL)<>1)) OR
     ((bundle ? 'repayments') <> (payments=1)) THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Loan history must retain its principal and every repayment';
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
    ELSE
      RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'This record type is unavailable for synchronization';
  END CASE;
END;
$$;

COMMIT;
