BEGIN;
SET LOCAL plpgsql.check_asserts=on;

CREATE FUNCTION pg_temp.document_session(p_user uuid,p_session uuid) RETURNS void LANGUAGE sql AS $$
  SELECT set_config('request.jwt.claims',jsonb_build_object('sub',p_user,'session_id',p_session,'role','authenticated',
    'aal','aal2','amr',jsonb_build_array(jsonb_build_object('method','totp','timestamp',extract(epoch FROM statement_timestamp())::bigint)))::text,true)
$$;

DO $$
DECLARE owner_user uuid:=gen_random_uuid();
DECLARE member_user uuid:=gen_random_uuid();
DECLARE owner_session uuid:=gen_random_uuid();
DECLARE member_session uuid:=gen_random_uuid();
DECLARE dev_owner uuid:=gen_random_uuid();
DECLARE dev_member uuid:=gen_random_uuid();
DECLARE dev_later uuid:=gen_random_uuid();
DECLARE later_session uuid:=gen_random_uuid();
DECLARE proof_owner text:=repeat('d',64);
DECLARE proof_member text:=repeat('e',64);
DECLARE proof_later text:=repeat('f',64);
DECLARE family uuid;
DECLARE member_id uuid;
DECLARE owner_id uuid;
DECLARE reservation uuid:=gen_random_uuid();
DECLARE document uuid:=gen_random_uuid();
DECLARE version_id uuid:=gen_random_uuid();
DECLARE metadata_op uuid:=gen_random_uuid();
DECLARE archive_op uuid:=gen_random_uuid();
DECLARE restore_op uuid:=gen_random_uuid();
DECLARE invitation uuid;
DECLARE expected_digest text:=repeat('a',64);
DECLARE grants jsonb;
DECLARE received jsonb;
DECLARE plan jsonb;
BEGIN
  INSERT INTO auth.users VALUES(owner_user,'document-owner@example.invalid',now()),(member_user,'document-member@example.invalid',now());
  INSERT INTO auth.sessions(id,user_id) VALUES(owner_session,owner_user),(member_session,member_user),(later_session,member_user);
  family:=fv_internal.bootstrap_family(owner_user,'Synthetic document family','Synthetic administrator');
  SET LOCAL ROLE authenticated;
  PERFORM pg_temp.document_session(owner_user,owner_session);
  ASSERT public.fv_request_device(family,dev_owner,proof_owner,'Synthetic document phone',repeat('1',64),repeat('2',64))='pending';
  RESET ROLE;
  PERFORM fv_internal.approve_first_device(dev_owner,encode(sha256(decode(repeat('1',64)||repeat('2',64),'hex')),'hex'));
  SET LOCAL ROLE authenticated;
  PERFORM public.fv_bind_device(dev_owner,proof_owner);
  owner_id:=(public.fv_workspace(dev_owner,proof_owner)->>'member_id')::uuid;
  invitation:=public.fv_invite_member(dev_owner,proof_owner,'document-member@example.invalid','Synthetic document member','member');
  PERFORM pg_temp.document_session(member_user,member_session);
  ASSERT public.fv_accept_invite(invitation)=family;
  ASSERT public.fv_request_device(family,dev_member,proof_member,'Synthetic second phone',repeat('3',64),repeat('4',64))='pending';
  PERFORM pg_temp.document_session(owner_user,owner_session);
  PERFORM public.fv_approve_device(dev_owner,proof_owner,dev_member,encode(sha256(decode(repeat('3',64)||repeat('4',64),'hex')),'hex'));
  PERFORM pg_temp.document_session(member_user,member_session);
  PERFORM public.fv_bind_device(dev_member,proof_member);
  member_id:=(public.fv_workspace(dev_member,proof_member)->>'member_id')::uuid;

  -- An ordinary member can upload a document whose owner is another member.
  ASSERT public.fv_document_reserve(dev_member,proof_member,reservation,document,version_id,owner_id,0,
    'application/pdf',100,expected_digest,repeat('A',64))=reservation;
  ASSERT public.fv_document_reserve(dev_member,proof_member,reservation,document,version_id,owner_id,0,
    'application/pdf',100,expected_digest,repeat('A',64))=reservation;
  plan:=public.fv_document_upload_plan(dev_member,proof_member,reservation);
  ASSERT plan->>'ciphertext_bytes'='148' AND plan->>'verified'='false';
  ASSERT public.fv_document_list(dev_member,proof_member)='[]'::jsonb;
  BEGIN
    PERFORM public.fv_document_mark_bytes(family,reservation,148,expected_digest);
    RAISE EXCEPTION 'An ordinary member forged the storage receipt';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    PERFORM public.fv_document_finalize(dev_member,proof_member,reservation,'[]'::jsonb);
    RAISE EXCEPTION 'A document was finalized before a verified Storage receipt';
  EXCEPTION WHEN SQLSTATE 'PT409' THEN NULL;
  END;
  RESET ROLE;
  UPDATE fv_data.document_uploads SET expires_at=statement_timestamp()-interval '1 second'
    WHERE (family_id,id)=(family,reservation);
  SET LOCAL ROLE authenticated;
  BEGIN
    PERFORM public.fv_document_upload_plan(dev_member,proof_member,reservation);
    RAISE EXCEPTION 'An expired reservation issued a plan';
  EXCEPTION WHEN SQLSTATE 'PT409' THEN NULL;
  END;
  ASSERT public.fv_document_reserve(dev_member,proof_member,reservation,document,version_id,owner_id,0,
    'application/pdf',100,expected_digest,repeat('A',64))=reservation;
  ASSERT public.fv_document_upload_plan(dev_member,proof_member,reservation)->>'verified'='false';
  RESET ROLE;
  SET LOCAL ROLE service_role;
  BEGIN
    PERFORM public.fv_document_mark_bytes(family,reservation,147,expected_digest);
    RAISE EXCEPTION 'A partial stored object was accepted';
  EXCEPTION WHEN invalid_parameter_value THEN NULL;
  END;
  PERFORM public.fv_document_mark_bytes(family,reservation,148,expected_digest);
  RESET ROLE;
  SET LOCAL ROLE authenticated;
  ASSERT public.fv_document_list(dev_member,proof_member)='[]'::jsonb;
  SELECT jsonb_agg(jsonb_build_object('version',1,'sender_device_id',dev_member,'recipient_device_id',recipient,
    'ephemeral_public',repeat('5',64),'wrapped_key',repeat('A',96),'signature',repeat('6',128))) INTO grants
    FROM unnest(ARRAY[dev_owner,dev_member]) recipient;
  BEGIN
    PERFORM public.fv_document_finalize(dev_member,proof_member,reservation,jsonb_build_array(grants->0));
    RAISE EXCEPTION 'A finalized shared document lacked a device grant';
  EXCEPTION WHEN SQLSTATE 'PT409' THEN NULL;
  END;
  received:=public.fv_document_finalize(dev_member,proof_member,reservation,grants);
  ASSERT received->>'version_id'=version_id::text AND received->>'version'='1';
  ASSERT public.fv_document_finalize(dev_member,proof_member,reservation,grants)=received;
  received:=public.fv_document_list(dev_member,proof_member)->0;
  ASSERT received->>'owner_id'=owner_id::text AND received->>'created_by'=member_id::text;
  ASSERT received->'key_grant'->>'recipient_device_id'=dev_member::text;
  received:=public.fv_document_change(dev_member,proof_member,metadata_op,document,version_id,1,'metadata',member_id,repeat('C',64));
  ASSERT received->>'revision'='2';
  ASSERT public.fv_document_change(dev_member,proof_member,metadata_op,document,version_id,1,'metadata',member_id,repeat('C',64))=received;
  BEGIN
    PERFORM public.fv_document_change(dev_member,proof_member,metadata_op,document,version_id,1,'metadata',member_id,repeat('D',64));
    RAISE EXCEPTION 'A reused document operation ID accepted different bytes';
  EXCEPTION WHEN unique_violation THEN NULL;
  END;
  BEGIN
    PERFORM public.fv_document_change(dev_member,proof_member,archive_op,document,version_id,1,'archive',NULL,NULL);
    RAISE EXCEPTION 'A stale archive changed the document';
  EXCEPTION WHEN SQLSTATE 'PT409' THEN NULL;
  END;
  ASSERT public.fv_document_change(dev_member,proof_member,archive_op,document,version_id,2,'archive',NULL,NULL)->>'revision'='3';
  ASSERT public.fv_document_list(dev_member,proof_member)->0->>'archived_at' IS NOT NULL;
  BEGIN
    PERFORM public.fv_document_reserve(dev_member,proof_member,gen_random_uuid(),document,gen_random_uuid(),member_id,3,
      'application/pdf',100,expected_digest,repeat('C',64));
    RAISE EXCEPTION 'An archived document accepted a replacement file';
  EXCEPTION WHEN SQLSTATE 'PT409' THEN NULL;
  END;
  PERFORM pg_temp.document_session(owner_user,owner_session);
  ASSERT public.fv_document_change(dev_owner,proof_owner,restore_op,document,version_id,3,'restore',NULL,NULL)->>'revision'='4';
  received:=public.fv_document_list(dev_owner,proof_owner)->0;
  ASSERT received->>'archived_at' IS NULL AND received->>'metadata_box'=repeat('C',64);
  ASSERT received->>'owner_id'=member_id::text AND received->>'updated_by'=owner_id::text;
  received:=public.fv_document_versions(dev_owner,proof_owner,document)->0;
  ASSERT received->'key_grant'->>'recipient_device_id'=dev_owner::text;
  ASSERT public.fv_document_download_plan(dev_owner,proof_owner,version_id)->>'ciphertext_digest'=expected_digest;
  PERFORM pg_temp.document_session(member_user,later_session);
  ASSERT public.fv_request_device(family,dev_later,proof_later,'Synthetic later device',repeat('7',64),repeat('8',64))='pending';
  PERFORM pg_temp.document_session(owner_user,owner_session);
  ASSERT public.fv_document_missing_grants(dev_owner,proof_owner)='[]'::jsonb;
  PERFORM public.fv_approve_device(dev_owner,proof_owner,dev_later,encode(sha256(decode(repeat('7',64)||repeat('8',64),'hex')),'hex'));
  received:=public.fv_document_missing_grants(dev_owner,proof_owner)->0;
  ASSERT received->>'version_id'=version_id::text AND received->>'recipient_id'=dev_later::text;
  ASSERT received->'key_grant'->>'recipient_device_id'=dev_owner::text;
  PERFORM pg_temp.document_session(member_user,later_session);
  PERFORM public.fv_bind_device(dev_later,proof_later);
  BEGIN
    PERFORM public.fv_document_add_grant(dev_later,proof_later,version_id,grants->0);
    RAISE EXCEPTION 'An enrolled nonholder published a document grant';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  ASSERT public.fv_document_missing_grants(dev_later,proof_later)='[]'::jsonb;
  ASSERT public.fv_document_versions(dev_later,proof_later,document)->0->'key_grant'='null'::jsonb;
  BEGIN
    PERFORM public.fv_document_change(dev_later,proof_later,gen_random_uuid(),document,version_id,4,'archive',NULL,NULL);
    RAISE EXCEPTION 'A device without a version key changed document history';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM pg_temp.document_session(owner_user,owner_session);
  received:=jsonb_build_object('version',1,'sender_device_id',dev_owner,'recipient_device_id',dev_later,
    'ephemeral_public',repeat('9',64),'wrapped_key',repeat('B',96),'signature',repeat('c',128));
  PERFORM public.fv_document_add_grant(dev_owner,proof_owner,version_id,received);
  PERFORM public.fv_document_add_grant(dev_owner,proof_owner,version_id,received);
  ASSERT public.fv_document_missing_grants(dev_owner,proof_owner)='[]'::jsonb;
  PERFORM pg_temp.document_session(member_user,later_session);
  ASSERT public.fv_document_versions(dev_later,proof_later,document)->0->'key_grant'=received;
  PERFORM pg_temp.document_session(owner_user,owner_session);
  PERFORM public.fv_revoke_access(dev_owner,proof_owner,'device',dev_member);
  PERFORM pg_temp.document_session(member_user,member_session);
  BEGIN
    PERFORM public.fv_document_download_plan(dev_member,proof_member,version_id);
    RAISE EXCEPTION 'A revoked device could request sealed bytes';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  RESET ROLE;
  ASSERT (SELECT count(*) FROM fv_data.document_versions WHERE family_id=family)=1;
  ASSERT (SELECT count(*) FROM fv_data.document_changes WHERE family_id=family)=3;
  ASSERT (SELECT count(*) FROM fv_data.document_access_events WHERE family_id=family)=6;
END;
$$;
ROLLBACK;
