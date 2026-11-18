BEGIN;
SET LOCAL plpgsql.check_asserts = on;

CREATE FUNCTION pg_temp.ledger_actor(p_user uuid, p_session uuid) RETURNS void LANGUAGE sql AS $$
  SELECT set_config('request.jwt.claims',
    jsonb_build_object('sub',p_user,'session_id',p_session,'role','authenticated', 'aal','aal2',
      'amr',jsonb_build_array(jsonb_build_object('method','totp','timestamp',extract(epoch FROM statement_timestamp())::bigint)))::text,true)
$$;

CREATE FUNCTION pg_temp.change_for(p_family uuid, p_actor uuid, p_device uuid, p_operation uuid,
  p_entity text, p_revision bigint, p_record jsonb, p_bundle jsonb DEFAULT NULL) RETURNS jsonb LANGUAGE sql AS $$
  SELECT jsonb_build_object('protocol_version',1,'family_id',p_family,'actor_id',p_actor,'device_id',p_device,
    'operation_id',p_operation,'entity_type',p_entity,'base_revision',p_revision,'entity_id',p_record->>'id',
    'mutation_kind','upsert','record',p_record) || CASE WHEN p_bundle IS NULL THEN '{}'::jsonb ELSE jsonb_build_object('bundle',p_bundle) END
$$;

DO $$
DECLARE
  owner_user uuid := gen_random_uuid();
  writer_user uuid := gen_random_uuid();
  owner_session uuid := gen_random_uuid();
  writer_session uuid := gen_random_uuid();
  owner_device uuid := gen_random_uuid();
  writer_device uuid := gen_random_uuid();
  owner_proof text := repeat('a',64);
  writer_proof text := repeat('b',64);
  family uuid;
  owner_member uuid;
  writer_member uuid;
  invitation uuid;
  cash uuid := gen_random_uuid();
  revenue uuid;
  journal uuid := gen_random_uuid();
  reversal uuid := gen_random_uuid();
  replacement uuid := gen_random_uuid();
  debit_id uuid := gen_random_uuid();
  credit_id uuid := gen_random_uuid();
  amount bigint := 9223372036854775807;
  account jsonb;
  posting_row jsonb;
  reversal_row jsonb;
  replacement_row jsonb;
  original_after jsonb;
  operation jsonb;
  receipt jsonb;
  page jsonb;
BEGIN
  INSERT INTO auth.users VALUES (owner_user,'ledger-owner@example.invalid',now()), (writer_user,'ledger-writer@example.invalid',now());
  INSERT INTO auth.sessions(id,user_id) VALUES (owner_session,owner_user),(writer_session,writer_user);
  family := fv_internal.bootstrap_family(owner_user,'Synthetic ledger family','Synthetic ledger owner');
  SET LOCAL ROLE authenticated;
  PERFORM pg_temp.ledger_actor(owner_user,owner_session);
  ASSERT public.fv_request_device(family,owner_device,owner_proof,'Synthetic owner device',repeat('1',64),repeat('2',64)) = 'pending';
  RESET ROLE;
  PERFORM fv_internal.approve_first_device(owner_device,encode(sha256(decode(repeat('1',64)||repeat('2',64),'hex')),'hex'));
  SET LOCAL ROLE authenticated;
  PERFORM public.fv_bind_device(owner_device,owner_proof);
  owner_member := (public.fv_workspace(owner_device,owner_proof)->>'member_id')::uuid;
  ASSERT jsonb_array_length(public.fv_sync_chart(owner_device,owner_proof)) = 19;
  SELECT (row->>'id')::uuid INTO revenue FROM jsonb_array_elements(public.fv_sync_chart(owner_device,owner_proof)) row
    WHERE row->>'subtype'='salary';

  account := jsonb_build_object('id',cash,'family_id',family,'revision',1,'created_by',owner_member,'updated_by',owner_member,
    'created_at_us',1,'updated_at_us',1,'deleted_at_us',NULL,'name','Synthetic cash','kind','asset','subtype','cash',
    'currency','INR','system_account',false);
  operation := pg_temp.change_for(family,owner_member,owner_device,gen_random_uuid(),'account',0,account);
  receipt := public.fv_sync_push(owner_device,owner_proof,operation::text);
  ASSERT receipt->>'sequence' = '1';
  ASSERT receipt->>'payload_digest' = encode(sha256(convert_to(operation::text,'UTF8')),'hex');
  ASSERT public.fv_sync_push(owner_device,owner_proof,operation::text) = receipt;
  BEGIN
    PERFORM public.fv_sync_push(owner_device,owner_proof,jsonb_set(operation,'{record,name}', '"Different retry"')::text);
    RAISE EXCEPTION 'An operation ID was reused with different content';
  EXCEPTION WHEN unique_violation THEN NULL;
  END;

  posting_row := jsonb_build_object('id',journal,'family_id',family,'revision',1,'created_by',owner_member,'updated_by',owner_member,
    'created_at_us',2,'updated_at_us',2,'deleted_at_us',NULL,'kind','income','occurred_on','2026-11-01','description','Synthetic income',
    'currency','INR','status','posted','reverses_id',NULL,'business_id',NULL,'related_entity_id',NULL,
    'postings',jsonb_build_array(
      jsonb_build_object('id',debit_id,'family_id',family,'journal_id',journal,'account_id',cash,'position',0,'amount_minor',amount),
      jsonb_build_object('id',credit_id,'family_id',family,'journal_id',journal,'account_id',revenue,'position',1,'amount_minor',-amount)));
  operation := pg_temp.change_for(family,owner_member,owner_device,gen_random_uuid(),'journal',0,posting_row);
  BEGIN
    PERFORM public.fv_sync_push(owner_device,owner_proof,jsonb_set(operation,'{record,postings,0,amount_minor}', '100')::text);
    RAISE EXCEPTION 'Unbalanced journal posted';
  EXCEPTION WHEN invalid_parameter_value THEN NULL;
  END;
  BEGIN
    PERFORM public.fv_sync_push(owner_device,owner_proof,replace(operation::text,amount::text,'1e3'));
    RAISE EXCEPTION 'Exponent inputs entered the ledger';
  EXCEPTION WHEN invalid_parameter_value THEN NULL;
  END;
  BEGIN
    PERFORM public.fv_sync_push(owner_device,owner_proof,jsonb_set(operation,'{record,postings,0,amount_minor}', '"100"')::text);
    RAISE EXCEPTION 'Text amount entered the ledger';
  EXCEPTION WHEN invalid_parameter_value THEN NULL;
  END;
  BEGIN
    PERFORM public.fv_sync_push(owner_device,owner_proof,'{"protocol_version":1,' || substr(operation::text,2));
    RAISE EXCEPTION 'Duplicate JSON keys were accepted';
  EXCEPTION WHEN invalid_parameter_value THEN NULL;
  END;
  ASSERT public.fv_sync_push(owner_device,owner_proof,operation::text)->>'sequence' = '2';
  page := public.fv_sync_pull(owner_device,owner_proof,1,1);
  ASSERT page->>'watermark' = '2';
  ASSERT (page->'changes'->0->>'payload_json')::jsonb->'record'->'postings'->0->>'amount_minor' = amount::text;
  ASSERT page->'changes'->0->>'payload_json' = operation::text;
  ASSERT jsonb_array_length(page->'changes') = 1;

  invitation := public.fv_invite_member(owner_device,owner_proof,'ledger-writer@example.invalid','Synthetic editor','member');
  PERFORM pg_temp.ledger_actor(writer_user,writer_session);
  ASSERT public.fv_accept_invite(invitation)=family;
  ASSERT public.fv_request_device(family,writer_device,writer_proof,'Synthetic editor device',repeat('3',64),repeat('4',64))='pending';
  PERFORM pg_temp.ledger_actor(owner_user,owner_session);
  PERFORM public.fv_approve_device(owner_device,owner_proof,writer_device,encode(sha256(decode(repeat('3',64)||repeat('4',64),'hex')),'hex'));
  PERFORM pg_temp.ledger_actor(writer_user,writer_session);
  PERFORM public.fv_bind_device(writer_device,writer_proof);
  writer_member := (public.fv_workspace(writer_device,writer_proof)->>'member_id')::uuid;
  ASSERT jsonb_array_length(public.fv_sync_pull(writer_device,writer_proof,0)->'changes')=2;
  BEGIN
    PERFORM public.fv_sync_push(writer_device,writer_proof,jsonb_set(pg_temp.change_for(family,writer_member,writer_device,
      gen_random_uuid(),'account',1,account || jsonb_build_object('revision',2,'name','Synthetic archive',
      'deleted_at_us',3,'updated_at_us',3,'updated_by',writer_member)), '{mutation_kind}', '"delete"')::text);
    RAISE EXCEPTION 'A nonzero account was archived';
  EXCEPTION WHEN invalid_parameter_value THEN NULL;
  END;
  operation := pg_temp.change_for(family,writer_member,writer_device,gen_random_uuid(),'account',1,
    account || jsonb_build_object('revision',2,'name','Synthetic renamed cash','updated_at_us',3,'updated_by',writer_member));
  ASSERT public.fv_sync_push(writer_device,writer_proof,operation::text)->>'sequence'='3';
  PERFORM pg_temp.ledger_actor(owner_user,owner_session);
  BEGIN
    PERFORM public.fv_sync_push(owner_device,owner_proof,pg_temp.change_for(family,owner_member,owner_device,
      gen_random_uuid(),'account',1,account || jsonb_build_object('revision',2,'name','Synthetic stale update'))::text);
    RAISE EXCEPTION 'A stale offline update overwrote another member';
  EXCEPTION WHEN SQLSTATE 'PT409' THEN NULL;
  END;
  PERFORM pg_temp.ledger_actor(writer_user,writer_session);
  original_after := posting_row || jsonb_build_object('updated_by',writer_member,'updated_at_us',4,'deleted_at_us',4,'revision',2);
  reversal_row := posting_row || jsonb_build_object('id',reversal,'kind','reversal','reverses_id',journal,
    'description','Synthetic correction','created_by',writer_member,'updated_by',writer_member,'created_at_us',4,'updated_at_us',4,
    'postings',jsonb_build_array(
      jsonb_build_object('id',gen_random_uuid(),'family_id',family,'journal_id',reversal,'account_id',cash,'position',0,'amount_minor',-amount),
      jsonb_build_object('id',gen_random_uuid(),'family_id',family,'journal_id',reversal,'account_id',revenue,'position',1,'amount_minor',amount)));
  replacement_row := posting_row || jsonb_build_object('id',replacement,'created_by',writer_member,'updated_by',writer_member,
    'created_at_us',4,'updated_at_us',4, 'postings',jsonb_build_array(
      jsonb_build_object('id',gen_random_uuid(),'family_id',family,'journal_id',replacement,'account_id',cash,'position',0,'amount_minor',100),
      jsonb_build_object('id',gen_random_uuid(),'family_id',family,'journal_id',replacement,'account_id',revenue,'position',1,'amount_minor',-100)));
  BEGIN
    PERFORM public.fv_sync_push(writer_device,writer_proof,pg_temp.change_for(family,writer_member,writer_device,
      gen_random_uuid(),'journal_correction',1,jsonb_set(replacement_row,'{postings,0,amount_minor}','101'),
      jsonb_build_object('original',original_after,'reversal',reversal_row))::text);
    RAISE EXCEPTION 'Half of a failed correction committed';
  EXCEPTION WHEN invalid_parameter_value THEN NULL;
  END;
  ASSERT public.fv_sync_pull(writer_device,writer_proof,0)->>'watermark'='3';
  operation := pg_temp.change_for(family,writer_member,writer_device,gen_random_uuid(),'journal_correction',1,replacement_row,
    jsonb_build_object('original',original_after,'reversal',reversal_row));
  ASSERT public.fv_sync_push(writer_device,writer_proof,operation::text)->>'sequence'='4';
  ASSERT public.fv_sync_push(writer_device,writer_proof,operation::text)->>'sequence'='4';
  RESET ROLE;
  ASSERT (SELECT count(*) FROM fv_data.ledger_journals WHERE family_id=family)=3;
  ASSERT (SELECT sum(amount_minor) FROM fv_data.ledger_postings WHERE family_id=family AND account_id=cash)=100;
  ASSERT (SELECT created_by FROM fv_data.ledger_accounts WHERE family_id=family AND id=cash)=owner_member;
  ASSERT (SELECT updated_by FROM fv_data.ledger_accounts WHERE family_id=family AND id=cash)=writer_member;
  ASSERT (SELECT count(*) FROM fv_data.sync_changes WHERE family_id=family)=4;
END;
$$;
ROLLBACK;
