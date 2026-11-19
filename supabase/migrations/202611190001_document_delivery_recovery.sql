-- Resume the same upload after delays and deliver existing keys to new devices.
BEGIN;
SET LOCAL ROLE familyvault_executor;
SET LOCAL search_path = '';

CREATE OR REPLACE FUNCTION fv_internal.document_reserve(p_device uuid,p_proof text,p_operation uuid,p_document uuid,p_version uuid,
  p_owner uuid,p_base bigint,p_mime text,p_bytes integer,p_digest text,p_metadata text) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE actor fv_internal.device_context := fv_internal.document_actor(p_device,p_proof,true);
DECLARE existing fv_data.document_uploads;
DECLARE doc fv_data.documents;
BEGIN
  IF p_operation IS NULL OR p_document IS NULL OR p_version IS NULL OR p_owner IS NULL THEN
    RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='Document identifiers are required';
  END IF;
  SELECT * INTO existing FROM fv_data.document_uploads WHERE (family_id,id)=(actor.family_id,p_operation) FOR UPDATE;
  IF existing.id IS NOT NULL THEN
    IF (existing.device_id,existing.member_id,existing.document_id,existing.version_id,existing.owner_id,existing.base_revision,
        existing.mime_type,existing.plaintext_bytes,existing.ciphertext_digest,existing.metadata_box) IS DISTINCT FROM
        (actor.device_id,actor.member_id,p_document,p_version,p_owner,p_base,p_mime,p_bytes,p_digest,p_metadata) THEN
      RAISE EXCEPTION USING ERRCODE='23505', MESSAGE='This document operation ID is already in use';
    END IF;
    -- A finalized operation always returns the original receipt. Even if the
    -- response was lost and the family document subsequently changed.
    IF existing.finalized_at IS NOT NULL THEN RETURN existing.id; END IF;
  END IF;
  SELECT * INTO doc FROM fv_data.documents WHERE (family_id,id)=(actor.family_id,p_document);
  IF coalesce(doc.revision,0) IS DISTINCT FROM p_base OR doc.archived_at IS NOT NULL THEN
    RAISE EXCEPTION USING ERRCODE='PT409', MESSAGE='The document changed before upload';
  END IF;
  IF existing.id IS NOT NULL THEN
    UPDATE fv_data.document_uploads SET expires_at=statement_timestamp()+interval '1 hour'
      WHERE (family_id,id)=(actor.family_id,existing.id) AND expires_at<=statement_timestamp();
  ELSE
    INSERT INTO fv_data.document_uploads(family_id,id,document_id,version_id,owner_id,member_id,device_id,
      base_revision,mime_type,plaintext_bytes,ciphertext_digest,metadata_box)
      VALUES(actor.family_id,p_operation,p_document,p_version,p_owner,actor.member_id,actor.device_id,p_base,p_mime,p_bytes,p_digest,p_metadata);
  END IF;
  RETURN p_operation;
END;
$$;

CREATE INDEX fv_document_key_recipient ON fv_data.document_key_grants(family_id,recipient_id,version_id);

CREATE FUNCTION fv_internal.document_missing_grants(p_device uuid,p_proof text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE actor fv_internal.device_context := fv_internal.document_actor(p_device,p_proof);
BEGIN
  RETURN coalesce((SELECT jsonb_agg(to_jsonb(needed) ORDER BY version_id,recipient_id) FROM (
    SELECT v.id AS version_id,v.document_id,d.id AS recipient_id,source.envelope AS key_grant
    FROM fv_data.document_key_grants source
    JOIN fv_data.document_versions v ON (v.family_id,v.id)=(source.family_id,source.version_id)
    JOIN fv_data.devices d ON d.family_id=v.family_id AND d.state='enrolled'
    JOIN fv_data.members m ON (m.family_id,m.id)=(d.family_id,d.member_id) AND m.active
    LEFT JOIN fv_data.document_key_grants granted ON (granted.family_id,granted.version_id,granted.recipient_id)=(v.family_id,v.id,d.id)
    WHERE (source.family_id,source.recipient_id)=(actor.family_id,actor.device_id) AND granted.version_id IS NULL
    ORDER BY v.id,d.id LIMIT 24
  ) needed),'[]'::jsonb);
END;
$$;

CREATE FUNCTION fv_internal.document_add_grant(p_device uuid,p_proof text,p_version uuid,p_grant jsonb) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE actor fv_internal.device_context := fv_internal.document_actor(p_device,p_proof,true);
DECLARE recipient uuid := fv_internal.input_id(p_grant,'recipient_device_id');
BEGIN
  IF NOT EXISTS (SELECT 1 FROM fv_data.document_key_grants
    WHERE (family_id,version_id,recipient_id)=(actor.family_id,p_version,actor.device_id)) THEN
    RAISE EXCEPTION USING ERRCODE='42501', MESSAGE='Only a holder of the version key may share it';
  END IF;
  IF EXISTS (SELECT 1 FROM fv_data.document_key_grants
    WHERE (family_id,version_id,recipient_id)=(actor.family_id,p_version,recipient)) THEN RETURN; END IF;
  PERFORM fv_internal.insert_document_grant(actor,p_version,p_grant);
  INSERT INTO fv_data.document_access_events(family_id,version_id,actor_id,device_id,action)
    VALUES(actor.family_id,p_version,actor.member_id,actor.device_id,'key_grant');
END;
$$;

GRANT EXECUTE ON FUNCTION fv_internal.document_missing_grants(uuid,text),
  fv_internal.document_add_grant(uuid,text,uuid,jsonb) TO authenticated;
RESET ROLE;

CREATE FUNCTION public.fv_document_missing_grants(p_device uuid,p_proof text) RETURNS jsonb
  LANGUAGE sql SET search_path = '' AS 'SELECT fv_internal.document_missing_grants(p_device,p_proof)';
CREATE FUNCTION public.fv_document_add_grant(p_device uuid,p_proof text,p_version uuid,p_grant jsonb) RETURNS void
  LANGUAGE sql SET search_path = '' AS 'SELECT fv_internal.document_add_grant(p_device,p_proof,p_version,p_grant)';
REVOKE ALL ON FUNCTION public.fv_document_missing_grants(uuid,text),
  public.fv_document_add_grant(uuid,text,uuid,jsonb) FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.fv_document_missing_grants(uuid,text),
  public.fv_document_add_grant(uuid,text,uuid,jsonb) TO authenticated;

COMMIT;
