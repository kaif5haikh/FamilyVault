-- Document metadata and file receipts. Object bytes are served by a private gateway.
BEGIN;
SET LOCAL ROLE familyvault_executor;
SET LOCAL search_path = '';

CREATE TABLE fv_data.documents (
  family_id uuid NOT NULL REFERENCES fv_data.families(id),
  id uuid NOT NULL,
  owner_id uuid NOT NULL,
  revision bigint NOT NULL CHECK (revision > 0),
  created_by uuid NOT NULL,
  updated_by uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  updated_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  archived_at timestamptz,
  metadata_box text NOT NULL CHECK (length(metadata_box) BETWEEN 56 AND 4096 AND metadata_box ~ '^[A-Za-z0-9+/=]+$'),
  PRIMARY KEY (family_id,id),
  FOREIGN KEY (family_id,owner_id) REFERENCES fv_data.members(family_id,id),
  FOREIGN KEY (family_id,created_by) REFERENCES fv_data.members(family_id,id),
  FOREIGN KEY (family_id,updated_by) REFERENCES fv_data.members(family_id,id)
);

CREATE TABLE fv_data.document_uploads (
  family_id uuid NOT NULL REFERENCES fv_data.families(id),
  id uuid NOT NULL,
  document_id uuid NOT NULL,
  version_id uuid NOT NULL,
  owner_id uuid NOT NULL,
  member_id uuid NOT NULL,
  device_id uuid NOT NULL,
  base_revision bigint NOT NULL CHECK (base_revision BETWEEN 0 AND 9223372036854775806),
  mime_type text NOT NULL CHECK (mime_type IN ('application/pdf','image/jpeg','image/png')),
  plaintext_bytes integer NOT NULL CHECK (plaintext_bytes BETWEEN 8 AND 25165824),
  ciphertext_bytes integer GENERATED ALWAYS AS (32 + plaintext_bytes + 16 * ((plaintext_bytes + 262143) / 262144)) STORED,
  ciphertext_digest text NOT NULL CHECK (ciphertext_digest ~ '^[0-9a-f]{64}$'),
  metadata_box text NOT NULL CHECK (length(metadata_box) BETWEEN 56 AND 4096 AND metadata_box ~ '^[A-Za-z0-9+/=]+$'),
  object_path text GENERATED ALWAYS AS (family_id::text || '/' || id::text || '.fvdoc') STORED,
  expires_at timestamptz NOT NULL DEFAULT (statement_timestamp() + interval '1 hour'),
  verified_at timestamptz,
  finalized_at timestamptz,
  PRIMARY KEY (family_id,id),
  FOREIGN KEY (family_id,owner_id) REFERENCES fv_data.members(family_id,id),
  FOREIGN KEY (family_id,device_id,member_id) REFERENCES fv_data.devices(family_id,id,member_id),
  CHECK (finalized_at IS NULL OR verified_at IS NOT NULL)
);

CREATE TABLE fv_data.document_versions (
  family_id uuid NOT NULL,
  id uuid NOT NULL,
  document_id uuid NOT NULL,
  reservation_id uuid NOT NULL,
  version integer NOT NULL CHECK (version > 0),
  PRIMARY KEY (family_id,id),
  UNIQUE (family_id,document_id,version),
  UNIQUE (family_id,reservation_id),
  FOREIGN KEY (family_id,document_id) REFERENCES fv_data.documents(family_id,id),
  FOREIGN KEY (family_id,reservation_id) REFERENCES fv_data.document_uploads(family_id,id)
);

ALTER TABLE fv_data.devices ADD CONSTRAINT fv_device_family_and_id UNIQUE (family_id,id);

CREATE TABLE fv_data.document_key_grants (
  family_id uuid NOT NULL,
  version_id uuid NOT NULL,
  recipient_id uuid NOT NULL,
  sender_id uuid NOT NULL,
  envelope jsonb NOT NULL,
  granted_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  PRIMARY KEY (family_id,version_id,recipient_id),
  FOREIGN KEY (family_id,version_id) REFERENCES fv_data.document_versions(family_id,id),
  FOREIGN KEY (family_id,recipient_id) REFERENCES fv_data.devices(family_id,id),
  FOREIGN KEY (family_id,sender_id) REFERENCES fv_data.devices(family_id,id)
);

CREATE TABLE fv_data.document_access_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id uuid NOT NULL,
  version_id uuid NOT NULL,
  actor_id uuid NOT NULL,
  device_id uuid NOT NULL,
  action text NOT NULL CHECK (action IN ('finalize','download_authorized','metadata','archive','restore','key_grant')),
  occurred_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  FOREIGN KEY (family_id,version_id) REFERENCES fv_data.document_versions(family_id,id),
  FOREIGN KEY (family_id,device_id,actor_id) REFERENCES fv_data.devices(family_id,id,member_id)
);

DO $$
DECLARE name text;
BEGIN
  FOREACH name IN ARRAY ARRAY['documents','document_uploads','document_versions','document_key_grants','document_access_events'] LOOP
    EXECUTE format('ALTER TABLE fv_data.%I ENABLE ROW LEVEL SECURITY',name);
    EXECUTE format('ALTER TABLE fv_data.%I FORCE ROW LEVEL SECURITY',name);
    EXECUTE format('CREATE POLICY internal_executor ON fv_data.%I TO familyvault_executor USING (true) WITH CHECK (true)',name);
    EXECUTE format('REVOKE ALL ON TABLE fv_data.%I FROM PUBLIC, anon, authenticated, service_role',name);
  END LOOP;
END;
$$;

CREATE TRIGGER fv_document_version_immutable BEFORE UPDATE OR DELETE OR TRUNCATE ON fv_data.document_versions
  FOR EACH STATEMENT EXECUTE FUNCTION fv_internal.forbid_audit_change();
CREATE TRIGGER fv_document_grant_immutable BEFORE UPDATE OR DELETE OR TRUNCATE ON fv_data.document_key_grants
  FOR EACH STATEMENT EXECUTE FUNCTION fv_internal.forbid_audit_change();
CREATE TRIGGER fv_document_access_immutable BEFORE UPDATE OR DELETE OR TRUNCATE ON fv_data.document_access_events
  FOR EACH STATEMENT EXECUTE FUNCTION fv_internal.forbid_audit_change();

CREATE FUNCTION fv_internal.document_actor(p_device uuid,p_proof text,p_writing boolean DEFAULT false) RETURNS fv_internal.device_context
LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE actor fv_internal.device_context := fv_internal.require_device(p_device,p_proof);
BEGIN
  IF p_writing THEN PERFORM fv_internal.lock_document_writes(actor.family_id); END IF;
  PERFORM 1 FROM fv_data.members m JOIN fv_data.devices d ON (d.family_id,d.member_id)=(m.family_id,m.id)
    JOIN fv_data.session_bindings b ON (b.family_id,b.device_id,b.member_id)=(d.family_id,d.id,d.member_id)
    WHERE m.active AND d.state='enrolled' AND b.revoked_at IS NULL AND b.session_id=actor.session_id FOR SHARE OF m,d,b;
  IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501', MESSAGE='Document access changed'; END IF;
  PERFORM fv_internal.current_auth();
  RETURN actor;
END;
$$;

CREATE FUNCTION fv_internal.lock_document_writes(p_family uuid) RETURNS void
LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  INSERT INTO fv_data.sync_clocks(family_id) VALUES (p_family) ON CONFLICT DO NOTHING;
  PERFORM 1 FROM fv_data.sync_clocks WHERE family_id=p_family FOR UPDATE;
END;
$$;

CREATE FUNCTION fv_internal.document_reserve(p_device uuid,p_proof text,p_operation uuid,p_document uuid,p_version uuid,
  p_owner uuid,p_base bigint,p_mime text,p_bytes integer,p_digest text,p_metadata text) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE actor fv_internal.device_context := fv_internal.document_actor(p_device,p_proof,true);
DECLARE existing fv_data.document_uploads;
DECLARE doc fv_data.documents;
BEGIN
  IF p_operation IS NULL OR p_document IS NULL OR p_version IS NULL OR p_owner IS NULL THEN
    RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='Document identifiers are required';
  END IF;
  SELECT * INTO existing FROM fv_data.document_uploads WHERE (family_id,id)=(actor.family_id,p_operation);
  IF existing.id IS NOT NULL THEN
    IF (existing.device_id,existing.member_id,existing.document_id,existing.version_id,existing.owner_id,existing.base_revision,
        existing.mime_type,existing.plaintext_bytes,existing.ciphertext_digest,existing.metadata_box) IS DISTINCT FROM
        (actor.device_id,actor.member_id,p_document,p_version,p_owner,p_base,p_mime,p_bytes,p_digest,p_metadata) THEN
      RAISE EXCEPTION USING ERRCODE='23505', MESSAGE='This document operation ID is already in use';
    END IF;
    RETURN existing.id;
  END IF;
  SELECT * INTO doc FROM fv_data.documents WHERE (family_id,id)=(actor.family_id,p_document);
  IF coalesce(doc.revision,0) IS DISTINCT FROM p_base OR doc.archived_at IS NOT NULL THEN
    RAISE EXCEPTION USING ERRCODE='PT409', MESSAGE='The document changed before upload';
  END IF;
  INSERT INTO fv_data.document_uploads(family_id,id,document_id,version_id,owner_id,member_id,device_id,
    base_revision,mime_type,plaintext_bytes,ciphertext_digest,metadata_box)
    VALUES(actor.family_id,p_operation,p_document,p_version,p_owner,actor.member_id,actor.device_id,p_base,p_mime,p_bytes,p_digest,p_metadata);
  RETURN p_operation;
END;
$$;

CREATE FUNCTION fv_internal.document_upload_plan(p_device uuid,p_proof text,p_reservation uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE actor fv_internal.device_context := fv_internal.document_actor(p_device,p_proof);
DECLARE upload fv_data.document_uploads;
BEGIN
  SELECT * INTO upload FROM fv_data.document_uploads WHERE (family_id,id,device_id,member_id)=
    (actor.family_id,p_reservation,actor.device_id,actor.member_id);
  IF upload.id IS NULL THEN RAISE EXCEPTION USING ERRCODE='42501', MESSAGE='Upload reservation unavailable'; END IF;
  IF upload.finalized_at IS NULL AND upload.expires_at <= statement_timestamp() THEN
    RAISE EXCEPTION USING ERRCODE='PT409', MESSAGE='Upload reservation expired';
  END IF;
  RETURN jsonb_build_object('family_id',upload.family_id,'reservation_id',upload.id,'object_path',upload.object_path,
    'ciphertext_bytes',upload.ciphertext_bytes,'ciphertext_digest',upload.ciphertext_digest,
    'verified',upload.verified_at IS NOT NULL,'finalized',upload.finalized_at IS NOT NULL);
END;
$$;

-- The storage worker alone records the digest of the bytes it read back.
CREATE FUNCTION fv_internal.document_mark_bytes(p_family uuid,p_reservation uuid,p_size integer,p_digest text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  UPDATE fv_data.document_uploads SET verified_at=coalesce(verified_at,statement_timestamp())
    WHERE (family_id,id,ciphertext_bytes,ciphertext_digest)=(p_family,p_reservation,p_size,p_digest)
      AND (expires_at>statement_timestamp() OR finalized_at IS NOT NULL);
  IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='Stored document bytes failed verification'; END IF;
END;
$$;

CREATE FUNCTION fv_internal.insert_document_grant(actor fv_internal.device_context,p_version uuid,grant_payload jsonb) RETURNS void
LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE recipient uuid;
BEGIN
  PERFORM fv_internal.fields(grant_payload,ARRAY['version','sender_device_id','recipient_device_id','ephemeral_public','wrapped_key','signature']);
  recipient := fv_internal.input_id(grant_payload,'recipient_device_id');
  IF fv_internal.input_int(grant_payload,'version') <> 1
    OR fv_internal.input_id(grant_payload,'sender_device_id') IS DISTINCT FROM actor.device_id
    OR coalesce(grant_payload->>'ephemeral_public','') !~ '^[0-9a-f]{64}$'
    OR coalesce(grant_payload->>'wrapped_key','') !~ '^[A-Za-z0-9+/]{96}$'
    OR coalesce(grant_payload->>'signature','') !~ '^[0-9a-f]{128}$'
    OR NOT EXISTS (SELECT 1 FROM fv_data.devices d JOIN fv_data.members m ON (d.family_id,d.member_id)=(m.family_id,m.id)
      WHERE (d.family_id,d.id)=(actor.family_id,recipient) AND d.state='enrolled' AND m.active) THEN
    RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='Invalid enrolled recipient or device envelope';
  END IF;
  INSERT INTO fv_data.document_key_grants(family_id,version_id,recipient_id,sender_id,envelope)
    VALUES(actor.family_id,p_version,recipient,actor.device_id,grant_payload) ON CONFLICT DO NOTHING;
END;
$$;

CREATE FUNCTION fv_internal.document_finalize(p_device uuid,p_proof text,p_reservation uuid,p_grants jsonb) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE actor fv_internal.device_context := fv_internal.document_actor(p_device,p_proof,true);
DECLARE upload fv_data.document_uploads;
DECLARE doc fv_data.documents;
DECLARE seq integer;
DECLARE item jsonb;
DECLARE active_devices uuid[];
BEGIN
  SELECT * INTO upload FROM fv_data.document_uploads WHERE (family_id,id,device_id,member_id)=
    (actor.family_id,p_reservation,actor.device_id,actor.member_id) FOR UPDATE;
  IF upload.id IS NULL THEN RAISE EXCEPTION USING ERRCODE='42501', MESSAGE='Upload reservation unavailable'; END IF;
  IF upload.finalized_at IS NOT NULL THEN
    SELECT version INTO seq FROM fv_data.document_versions WHERE (family_id,reservation_id)=(actor.family_id,p_reservation);
  ELSE
    IF upload.verified_at IS NULL OR upload.expires_at <= statement_timestamp() THEN
      RAISE EXCEPTION USING ERRCODE='PT409', MESSAGE='Verified stored bytes are required';
    END IF;
    SELECT * INTO doc FROM fv_data.documents WHERE (family_id,id)=(actor.family_id,upload.document_id);
    IF coalesce(doc.revision,0) <> upload.base_revision OR doc.archived_at IS NOT NULL THEN
      RAISE EXCEPTION USING ERRCODE='PT409', MESSAGE='The document changed before confirmation';
    END IF;
    SELECT array_agg(d.id ORDER BY d.id) INTO active_devices FROM fv_data.devices d
      JOIN fv_data.members m ON (d.family_id,d.member_id)=(m.family_id,m.id)
      WHERE d.family_id=actor.family_id AND d.state='enrolled' AND m.active;
    IF jsonb_typeof(p_grants) IS DISTINCT FROM 'array' OR jsonb_array_length(p_grants) > 100 OR
        active_devices IS DISTINCT FROM (SELECT array_agg(recipient ORDER BY recipient) FROM
          (SELECT fv_internal.input_id(g,'recipient_device_id') AS recipient FROM jsonb_array_elements(p_grants) g) recipients) THEN
      RAISE EXCEPTION USING ERRCODE='PT409', MESSAGE='Wrap the file key for each active family device';
    END IF;
    INSERT INTO fv_data.documents(family_id,id,owner_id,revision,created_by,updated_by,metadata_box)
      VALUES(actor.family_id,upload.document_id,upload.owner_id,1,actor.member_id,actor.member_id,upload.metadata_box)
      ON CONFLICT (family_id,id) DO UPDATE SET owner_id=excluded.owner_id,revision=documents.revision+1,
      updated_by=excluded.updated_by,updated_at=statement_timestamp(),metadata_box=excluded.metadata_box;
    SELECT coalesce(max(version),0)+1 INTO seq FROM fv_data.document_versions
      WHERE (family_id,document_id)=(actor.family_id,upload.document_id);
    INSERT INTO fv_data.document_versions VALUES(actor.family_id,upload.version_id,upload.document_id,upload.id,seq);
    FOR item IN SELECT * FROM jsonb_array_elements(p_grants) LOOP
      PERFORM fv_internal.insert_document_grant(actor,upload.version_id,item);
    END LOOP;
    UPDATE fv_data.document_uploads SET finalized_at=statement_timestamp() WHERE (family_id,id)=(actor.family_id,p_reservation);
    INSERT INTO fv_data.document_access_events(family_id,version_id,actor_id,device_id,action)
      VALUES(actor.family_id,upload.version_id,actor.member_id,actor.device_id,'finalize');
  END IF;
  RETURN jsonb_build_object('reservation_id',upload.id,'version_id',upload.version_id,'version',seq,
    'ciphertext_digest',upload.ciphertext_digest);
END;
$$;

CREATE FUNCTION fv_internal.document_list(p_device uuid,p_proof text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE actor fv_internal.device_context := fv_internal.document_actor(p_device,p_proof);
BEGIN
  RETURN coalesce((SELECT jsonb_agg(to_jsonb(rows) ORDER BY id) FROM (
    SELECT d.id,d.owner_id,d.revision,d.metadata_box,d.created_by,d.updated_by,d.created_at,d.updated_at,d.archived_at,
      v.id AS latest_version_id,g.envelope AS key_grant
    FROM fv_data.documents d
    JOIN LATERAL (SELECT id FROM fv_data.document_versions WHERE (family_id,document_id)=(d.family_id,d.id)
      ORDER BY version DESC LIMIT 1) v ON true
    LEFT JOIN fv_data.document_key_grants g ON (g.family_id,g.version_id,g.recipient_id)=(d.family_id,v.id,actor.device_id)
    WHERE d.family_id=actor.family_id
  ) rows),'[]'::jsonb);
END;
$$;

CREATE FUNCTION fv_internal.document_versions(p_device uuid,p_proof text,p_document uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE actor fv_internal.device_context := fv_internal.document_actor(p_device,p_proof);
BEGIN
  RETURN coalesce((SELECT jsonb_agg(to_jsonb(rows) ORDER BY version DESC) FROM (
    SELECT v.id,v.version,u.finalized_at,u.mime_type,u.plaintext_bytes,u.ciphertext_bytes,u.ciphertext_digest,
      u.member_id AS created_by,u.device_id,g.envelope AS key_grant
    FROM fv_data.document_versions v JOIN fv_data.document_uploads u ON (v.family_id,v.reservation_id)=(u.family_id,u.id)
    LEFT JOIN fv_data.document_key_grants g ON (v.family_id,v.id,actor.device_id)=(g.family_id,g.version_id,g.recipient_id)
    WHERE (v.family_id,v.document_id)=(actor.family_id,p_document)
  ) rows),'[]'::jsonb);
END;
$$;

CREATE FUNCTION fv_internal.document_download_plan(p_device uuid,p_proof text,p_version uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE actor fv_internal.device_context := fv_internal.document_actor(p_device,p_proof);
DECLARE planned jsonb;
BEGIN
  SELECT jsonb_build_object('object_path',u.object_path,'ciphertext_bytes',u.ciphertext_bytes,'ciphertext_digest',u.ciphertext_digest)
    INTO planned FROM fv_data.document_versions v JOIN fv_data.document_uploads u ON (v.family_id,v.reservation_id)=(u.family_id,u.id)
    JOIN fv_data.document_key_grants g ON (v.family_id,v.id,actor.device_id)=(g.family_id,g.version_id,g.recipient_id)
    WHERE (v.family_id,v.id)=(actor.family_id,p_version) AND u.finalized_at IS NOT NULL;
  IF planned IS NULL THEN RAISE EXCEPTION USING ERRCODE='42501', MESSAGE='No active device grant for this version'; END IF;
  INSERT INTO fv_data.document_access_events(family_id,version_id,actor_id,device_id,action)
    VALUES(actor.family_id,p_version,actor.member_id,actor.device_id,'download_authorized');
  RETURN planned;
END;
$$;

GRANT EXECUTE ON FUNCTION fv_internal.document_reserve(uuid,text,uuid,uuid,uuid,uuid,bigint,text,integer,text,text),
  fv_internal.document_upload_plan(uuid,text,uuid),fv_internal.document_finalize(uuid,text,uuid,jsonb),
  fv_internal.document_list(uuid,text),fv_internal.document_versions(uuid,text,uuid),fv_internal.document_download_plan(uuid,text,uuid)
  TO authenticated;
GRANT USAGE ON SCHEMA fv_internal TO service_role;
GRANT EXECUTE ON FUNCTION fv_internal.document_mark_bytes(uuid,uuid,integer,text) TO service_role;
RESET ROLE;

CREATE FUNCTION public.fv_document_reserve(p_device uuid,p_proof text,p_operation uuid,p_document uuid,p_version uuid,
  p_owner uuid,p_base bigint,p_mime text,p_bytes integer,p_digest text,p_metadata text) RETURNS uuid
LANGUAGE sql SET search_path = '' AS 'SELECT fv_internal.document_reserve(p_device,p_proof,p_operation,p_document,p_version,p_owner,p_base,p_mime,p_bytes,p_digest,p_metadata)';
CREATE FUNCTION public.fv_document_upload_plan(p_device uuid,p_proof text,p_reservation uuid) RETURNS jsonb
LANGUAGE sql SET search_path = '' AS 'SELECT fv_internal.document_upload_plan(p_device,p_proof,p_reservation)';
CREATE FUNCTION public.fv_document_mark_bytes(p_family uuid,p_reservation uuid,p_size integer,p_digest text) RETURNS void
LANGUAGE sql SET search_path = '' AS 'SELECT fv_internal.document_mark_bytes(p_family,p_reservation,p_size,p_digest)';
CREATE FUNCTION public.fv_document_finalize(p_device uuid,p_proof text,p_reservation uuid,p_grants jsonb) RETURNS jsonb
LANGUAGE sql SET search_path = '' AS 'SELECT fv_internal.document_finalize(p_device,p_proof,p_reservation,p_grants)';
CREATE FUNCTION public.fv_document_list(p_device uuid,p_proof text) RETURNS jsonb
LANGUAGE sql SET search_path = '' AS 'SELECT fv_internal.document_list(p_device,p_proof)';
CREATE FUNCTION public.fv_document_versions(p_device uuid,p_proof text,p_document uuid) RETURNS jsonb
LANGUAGE sql SET search_path = '' AS 'SELECT fv_internal.document_versions(p_device,p_proof,p_document)';
CREATE FUNCTION public.fv_document_download_plan(p_device uuid,p_proof text,p_version uuid) RETURNS jsonb
LANGUAGE sql SET search_path = '' AS 'SELECT fv_internal.document_download_plan(p_device,p_proof,p_version)';

REVOKE ALL ON FUNCTION public.fv_document_reserve(uuid,text,uuid,uuid,uuid,uuid,bigint,text,integer,text,text),
  public.fv_document_upload_plan(uuid,text,uuid),public.fv_document_finalize(uuid,text,uuid,jsonb),
  public.fv_document_list(uuid,text),public.fv_document_versions(uuid,text,uuid),public.fv_document_download_plan(uuid,text,uuid),
  public.fv_document_mark_bytes(uuid,uuid,integer,text) FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.fv_document_reserve(uuid,text,uuid,uuid,uuid,uuid,bigint,text,integer,text,text),
  public.fv_document_upload_plan(uuid,text,uuid),public.fv_document_finalize(uuid,text,uuid,jsonb),
  public.fv_document_list(uuid,text),public.fv_document_versions(uuid,text,uuid),public.fv_document_download_plan(uuid,text,uuid)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.fv_document_mark_bytes(uuid,uuid,integer,text) TO service_role;
COMMIT;
