-- Metadata and archive changes advance the document revision without replacing files.
BEGIN;
SET LOCAL ROLE familyvault_executor;
SET LOCAL search_path = '';

CREATE TABLE fv_data.document_changes (
  family_id uuid NOT NULL,
  id uuid NOT NULL,
  document_id uuid NOT NULL,
  version_id uuid NOT NULL,
  member_id uuid NOT NULL,
  device_id uuid NOT NULL,
  base_revision bigint NOT NULL CHECK (base_revision BETWEEN 1 AND 9223372036854775806),
  action text NOT NULL CHECK (action IN ('metadata','archive','restore')),
  owner_id uuid,
  metadata_box text CHECK (length(metadata_box) BETWEEN 56 AND 4096 AND metadata_box ~ '^[A-Za-z0-9+/=]+$'),
  occurred_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  PRIMARY KEY (family_id,id),
  UNIQUE (family_id,document_id,base_revision),
  FOREIGN KEY (family_id,document_id) REFERENCES fv_data.documents(family_id,id),
  FOREIGN KEY (family_id,version_id) REFERENCES fv_data.document_versions(family_id,id),
  FOREIGN KEY (family_id,device_id,member_id) REFERENCES fv_data.devices(family_id,id,member_id),
  FOREIGN KEY (family_id,owner_id) REFERENCES fv_data.members(family_id,id),
  CHECK ((action='metadata' AND owner_id IS NOT NULL AND metadata_box IS NOT NULL)
      OR (action<>'metadata' AND owner_id IS NULL AND metadata_box IS NULL))
);
ALTER TABLE fv_data.document_changes ENABLE ROW LEVEL SECURITY;
ALTER TABLE fv_data.document_changes FORCE ROW LEVEL SECURITY;
CREATE POLICY internal_executor ON fv_data.document_changes TO familyvault_executor USING (true) WITH CHECK (true);
REVOKE ALL ON TABLE fv_data.document_changes FROM PUBLIC, anon, authenticated, service_role;
CREATE TRIGGER fv_document_change_immutable BEFORE UPDATE OR DELETE OR TRUNCATE ON fv_data.document_changes
  FOR EACH STATEMENT EXECUTE FUNCTION fv_internal.forbid_audit_change();

CREATE FUNCTION fv_internal.document_change(p_device uuid,p_proof text,p_operation uuid,p_document uuid,p_version uuid,
  p_base bigint,p_action text,p_owner uuid,p_metadata text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE actor fv_internal.device_context := fv_internal.document_actor(p_device,p_proof,true);
DECLARE seen fv_data.document_changes;
DECLARE doc fv_data.documents;
DECLARE latest uuid;
BEGIN
  IF p_operation IS NULL OR p_document IS NULL OR p_version IS NULL OR p_base IS NULL
    OR p_base NOT BETWEEN 1 AND 9223372036854775806 OR p_action IS NULL
    OR p_action NOT IN ('metadata','archive','restore')
    OR (p_action='metadata' AND (p_owner IS NULL OR p_metadata IS NULL))
    OR (p_action<>'metadata' AND (p_owner IS NOT NULL OR p_metadata IS NOT NULL)) THEN
    RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='Invalid document edit request';
  END IF;
  SELECT * INTO seen FROM fv_data.document_changes WHERE (family_id,id)=(actor.family_id,p_operation);
  IF seen.id IS NOT NULL THEN
    IF (seen.device_id,seen.member_id,seen.document_id,seen.version_id,seen.base_revision,seen.action,seen.owner_id,seen.metadata_box)
        IS DISTINCT FROM (actor.device_id,actor.member_id,p_document,p_version,p_base,p_action,p_owner,p_metadata) THEN
      RAISE EXCEPTION USING ERRCODE='23505', MESSAGE='This document operation ID is already in use';
    END IF;
  ELSE
    SELECT * INTO doc FROM fv_data.documents WHERE (family_id,id)=(actor.family_id,p_document);
    SELECT id INTO latest FROM fv_data.document_versions WHERE (family_id,document_id)=(actor.family_id,p_document)
      ORDER BY version DESC LIMIT 1;
    IF doc.revision IS DISTINCT FROM p_base OR latest IS DISTINCT FROM p_version
      OR (p_action='restore') IS DISTINCT FROM (doc.archived_at IS NOT NULL) THEN
      RAISE EXCEPTION USING ERRCODE='PT409', MESSAGE='The document changed before editing';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM fv_data.document_key_grants
      WHERE (family_id,version_id,recipient_id)=(actor.family_id,p_version,actor.device_id)) THEN
      RAISE EXCEPTION USING ERRCODE='42501', MESSAGE='The device has no key grant for this version';
    END IF;
    INSERT INTO fv_data.document_changes(family_id,id,document_id,version_id,member_id,device_id,base_revision,action,owner_id,metadata_box)
      VALUES(actor.family_id,p_operation,p_document,p_version,actor.member_id,actor.device_id,p_base,p_action,p_owner,p_metadata);
    UPDATE fv_data.documents SET owner_id=coalesce(p_owner,owner_id),metadata_box=coalesce(p_metadata,metadata_box),
      revision=p_base+1,updated_by=actor.member_id,updated_at=statement_timestamp(),
      archived_at=CASE WHEN p_action='archive' THEN statement_timestamp() ELSE NULL END
      WHERE (family_id,id)=(actor.family_id,p_document);
    INSERT INTO fv_data.document_access_events(family_id,version_id,actor_id,device_id,action)
      VALUES(actor.family_id,p_version,actor.member_id,actor.device_id,p_action);
  END IF;
  RETURN jsonb_build_object('operation_id',p_operation,'document_id',p_document,'version_id',p_version,
    'revision',p_base+1,'action',p_action);
END;
$$;

CREATE OR REPLACE FUNCTION fv_internal.document_list(p_device uuid,p_proof text) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE actor fv_internal.device_context := fv_internal.document_actor(p_device,p_proof);
BEGIN
  RETURN coalesce((SELECT jsonb_agg(to_jsonb(rows) ORDER BY id) FROM (
    SELECT d.id,d.owner_id,d.revision,d.metadata_box,d.created_by,d.updated_by,d.created_at,d.updated_at,d.archived_at,
      v.id AS latest_version_id,v.version AS latest_version,g.envelope AS key_grant
    FROM fv_data.documents d
    JOIN LATERAL (SELECT id,version FROM fv_data.document_versions WHERE (family_id,document_id)=(d.family_id,d.id)
      ORDER BY version DESC LIMIT 1) v ON true
    LEFT JOIN fv_data.document_key_grants g ON (g.family_id,g.version_id,g.recipient_id)=(d.family_id,v.id,actor.device_id)
    WHERE d.family_id=actor.family_id
  ) rows),'[]'::jsonb);
END;
$$;

GRANT EXECUTE ON FUNCTION fv_internal.document_change(uuid,text,uuid,uuid,uuid,bigint,text,uuid,text) TO authenticated;
RESET ROLE;

CREATE FUNCTION public.fv_document_change(p_device uuid,p_proof text,p_operation uuid,p_document uuid,p_version uuid,
  p_base bigint,p_action text,p_owner uuid,p_metadata text) RETURNS jsonb
  LANGUAGE sql SET search_path = '' AS
  'SELECT fv_internal.document_change(p_device,p_proof,p_operation,p_document,p_version,p_base,p_action,p_owner,p_metadata)';
REVOKE ALL ON FUNCTION public.fv_document_change(uuid,text,uuid,uuid,uuid,bigint,text,uuid,text) FROM PUBLIC, anon, service_role;
GRANT EXECUTE ON FUNCTION public.fv_document_change(uuid,text,uuid,uuid,uuid,bigint,text,uuid,text) TO authenticated;

COMMIT;
