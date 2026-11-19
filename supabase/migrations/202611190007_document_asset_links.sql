-- Extend shared document links with an independently validated asset target.
BEGIN;
SET LOCAL ROLE familyvault_executor;
SET LOCAL search_path = '';

ALTER TABLE fv_data.document_links ALTER COLUMN journal_id DROP NOT NULL,
  ADD COLUMN asset_id uuid,
  ADD FOREIGN KEY (family_id,asset_id) REFERENCES fv_data.wealth_assets(family_id,id),
  ADD CONSTRAINT fv_document_one_link_target CHECK ((journal_id IS NULL) <> (asset_id IS NULL));
CREATE UNIQUE INDEX fv_document_active_asset ON fv_data.document_links(family_id,document_id,asset_id)
  WHERE asset_id IS NOT NULL AND deleted_at IS NULL;
DROP TRIGGER fv_document_link_origin ON fv_data.document_links;
CREATE TRIGGER fv_document_link_origin BEFORE UPDATE ON fv_data.document_links FOR EACH ROW
  WHEN (OLD.revision <> 1 OR NEW.revision <> 2 OR
    (OLD.id,OLD.family_id,OLD.document_id,OLD.journal_id,OLD.asset_id,OLD.created_at,OLD.created_by)
      IS DISTINCT FROM (NEW.id,NEW.family_id,NEW.document_id,NEW.journal_id,NEW.asset_id,NEW.created_at,NEW.created_by))
  EXECUTE FUNCTION fv_internal.forbid_audit_change();

ALTER TABLE fv_data.document_changes ADD COLUMN asset_id uuid,
  DROP CONSTRAINT fv_document_change_link_fields,
  ADD CONSTRAINT fv_document_change_link_fields CHECK (
    (action IN ('link','unlink') AND link_id IS NOT NULL AND ((journal_id IS NULL) <> (asset_id IS NULL)))
    OR (action NOT IN ('link','unlink') AND link_id IS NULL AND journal_id IS NULL AND asset_id IS NULL)),
  ADD FOREIGN KEY (family_id,asset_id) REFERENCES fv_data.wealth_assets(family_id,id);

CREATE FUNCTION fv_internal.document_record_link(p_device uuid,p_proof text,p_operation uuid,p_document uuid,p_version uuid,
  p_base bigint,p_action text,p_link uuid,p_journal uuid,p_asset uuid) RETURNS jsonb
LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE actor fv_internal.device_context := fv_internal.document_actor(p_device,p_proof,true);
DECLARE seen fv_data.document_changes;
DECLARE doc fv_data.documents;
DECLARE latest uuid;
DECLARE journal fv_data.ledger_journals;
DECLARE asset fv_data.wealth_assets;
BEGIN
  IF p_operation IS NULL OR p_document IS NULL OR p_version IS NULL OR p_base IS NULL
    OR p_base NOT BETWEEN 1 AND 9223372036854775806 OR p_action IS NULL OR p_action NOT IN ('link','unlink')
    OR p_link IS NULL OR (p_journal IS NULL)=(p_asset IS NULL) THEN
    RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='Invalid document link request';
  END IF;
  SELECT * INTO seen FROM fv_data.document_changes WHERE (family_id,id)=(actor.family_id,p_operation);
  IF seen.id IS NOT NULL THEN
    IF (seen.device_id,seen.member_id,seen.document_id,seen.version_id,seen.base_revision,seen.action,seen.link_id,seen.journal_id,seen.asset_id)
        IS DISTINCT FROM (actor.device_id,actor.member_id,p_document,p_version,p_base,p_action,p_link,p_journal,p_asset) THEN
      RAISE EXCEPTION USING ERRCODE='23505', MESSAGE='This document operation ID is already in use';
    END IF;
  ELSE
    SELECT * INTO doc FROM fv_data.documents WHERE (family_id,id)=(actor.family_id,p_document);
    SELECT id INTO latest FROM fv_data.document_versions WHERE (family_id,document_id)=(actor.family_id,p_document)
      ORDER BY version DESC LIMIT 1;
    IF doc.revision IS DISTINCT FROM p_base OR latest IS DISTINCT FROM p_version OR
        (p_action='link' AND doc.archived_at IS NOT NULL) THEN
      RAISE EXCEPTION USING ERRCODE='PT409', MESSAGE='The document changed before linking';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM fv_data.document_key_grants
      WHERE (family_id,version_id,recipient_id)=(actor.family_id,p_version,actor.device_id)) THEN
      RAISE EXCEPTION USING ERRCODE='42501', MESSAGE='The device has no key grant for this version';
    END IF;
    IF p_action='link' THEN
      IF p_journal IS NOT NULL THEN
        SELECT * INTO journal FROM fv_data.ledger_journals WHERE (family_id,id)=(actor.family_id,p_journal);
        IF journal.id IS NULL THEN RAISE EXCEPTION USING ERRCODE='PT424', MESSAGE='Wait for the family transaction'; END IF;
        IF journal.status<>'posted' OR journal.deleted_at_us IS NOT NULL OR journal.kind='reversal' THEN
          RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='Link a posted active family transaction';
        END IF;
      ELSE
        SELECT * INTO asset FROM fv_data.wealth_assets WHERE (family_id,id)=(actor.family_id,p_asset);
        IF asset.id IS NULL THEN RAISE EXCEPTION USING ERRCODE='PT424', MESSAGE='Wait for the family asset'; END IF;
        IF asset.deleted_at_us IS NOT NULL THEN
          RAISE EXCEPTION USING ERRCODE='22023', MESSAGE='Link an active family asset';
        END IF;
      END IF;
      IF EXISTS (SELECT 1 FROM fv_data.document_links l WHERE (l.family_id,l.document_id)=(actor.family_id,p_document)
        AND ((l.journal_id,l.asset_id) IS NOT DISTINCT FROM (p_journal,p_asset)) AND l.deleted_at IS NULL) THEN
        RAISE EXCEPTION USING ERRCODE='PT409', MESSAGE='This record already has the document link';
      END IF;
      INSERT INTO fv_data.document_links(family_id,id,document_id,journal_id,asset_id,created_by,updated_by)
        VALUES(actor.family_id,p_link,p_document,p_journal,p_asset,actor.member_id,actor.member_id);
    ELSE
      UPDATE fv_data.document_links SET updated_by=actor.member_id,updated_at=statement_timestamp(),
        deleted_at=statement_timestamp(),revision=2
        WHERE (family_id,id,document_id)=(actor.family_id,p_link,p_document)
          AND (journal_id,asset_id) IS NOT DISTINCT FROM (p_journal,p_asset) AND deleted_at IS NULL;
      IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='PT409', MESSAGE='The document link changed'; END IF;
    END IF;
    INSERT INTO fv_data.document_changes(family_id,id,document_id,version_id,member_id,device_id,base_revision,action,link_id,journal_id,asset_id)
      VALUES(actor.family_id,p_operation,p_document,p_version,actor.member_id,actor.device_id,p_base,p_action,p_link,p_journal,p_asset);
    UPDATE fv_data.documents SET revision=p_base+1,updated_by=actor.member_id,updated_at=statement_timestamp()
      WHERE (family_id,id)=(actor.family_id,p_document);
  END IF;
  RETURN jsonb_build_object('operation_id',p_operation,'document_id',p_document,'version_id',p_version,
    'revision',p_base+1,'action',p_action,'link_id',p_link,'journal_id',p_journal,'asset_id',p_asset);
END;
$$;

CREATE OR REPLACE FUNCTION fv_internal.document_journal_link(p_device uuid,p_proof text,p_operation uuid,p_document uuid,p_version uuid,
  p_base bigint,p_action text,p_link uuid,p_journal uuid) RETURNS jsonb
LANGUAGE sql SECURITY DEFINER SET search_path = '' AS $$
  SELECT fv_internal.document_record_link(p_device,p_proof,p_operation,p_document,p_version,p_base,p_action,p_link,p_journal,NULL) - 'asset_id'
$$;
CREATE FUNCTION fv_internal.document_asset_link(p_device uuid,p_proof text,p_operation uuid,p_document uuid,p_version uuid,
  p_base bigint,p_action text,p_link uuid,p_asset uuid) RETURNS jsonb
LANGUAGE sql SECURITY DEFINER SET search_path = '' AS $$
  SELECT fv_internal.document_record_link(p_device,p_proof,p_operation,p_document,p_version,p_base,p_action,p_link,NULL,p_asset)
$$;

CREATE FUNCTION fv_internal.document_record_list(p_device uuid,p_proof text,p_assets boolean) RETURNS jsonb
LANGUAGE plpgsql SET search_path = '' AS $$
DECLARE actor fv_internal.device_context := fv_internal.document_actor(p_device,p_proof);
BEGIN
  RETURN coalesce((SELECT jsonb_agg(to_jsonb(rows) ORDER BY id) FROM (
    SELECT d.id,d.owner_id,d.revision,d.metadata_box,d.created_by,d.updated_by,d.created_at,d.updated_at,d.archived_at,
      v.id AS latest_version_id,v.version AS latest_version,g.envelope AS key_grant,
      coalesce((SELECT jsonb_agg(jsonb_build_object('id',l.id,'journal_id',l.journal_id,'revision',l.revision,
        'created_at',l.created_at,'updated_at',l.updated_at,'deleted_at',l.deleted_at,'created_by',l.created_by,'updated_by',l.updated_by)
        || CASE WHEN p_assets THEN jsonb_build_object('asset_id',l.asset_id) ELSE '{}'::jsonb END ORDER BY l.created_at,l.id)
        FROM fv_data.document_links l WHERE (l.family_id,l.document_id)=(d.family_id,d.id)
          AND g.recipient_id IS NOT NULL AND (p_assets OR l.journal_id IS NOT NULL)),'[]'::jsonb) AS links
    FROM fv_data.documents d
    JOIN LATERAL (SELECT id,version FROM fv_data.document_versions WHERE (family_id,document_id)=(d.family_id,d.id)
      ORDER BY version DESC LIMIT 1) v ON true
    LEFT JOIN fv_data.document_key_grants g ON (g.family_id,g.version_id,g.recipient_id)=(d.family_id,v.id,actor.device_id)
    WHERE d.family_id=actor.family_id
  ) rows),'[]'::jsonb);
END;
$$;

CREATE OR REPLACE FUNCTION fv_internal.document_list(p_device uuid,p_proof text) RETURNS jsonb
LANGUAGE sql SECURITY DEFINER SET search_path = '' AS $$
  SELECT fv_internal.document_record_list(p_device,p_proof,false)
$$;
CREATE FUNCTION fv_internal.document_list_with_assets(p_device uuid,p_proof text) RETURNS jsonb
LANGUAGE sql SECURITY DEFINER SET search_path = '' AS $$
  SELECT fv_internal.document_record_list(p_device,p_proof,true)
$$;
GRANT EXECUTE ON FUNCTION fv_internal.document_asset_link(uuid,text,uuid,uuid,uuid,bigint,text,uuid,uuid),
  fv_internal.document_list_with_assets(uuid,text) TO authenticated;
RESET ROLE;

CREATE FUNCTION public.fv_document_asset_link(p_device uuid,p_proof text,p_operation uuid,p_document uuid,p_version uuid,
  p_base bigint,p_action text,p_link uuid,p_asset uuid) RETURNS jsonb
LANGUAGE sql SET search_path = '' AS
  'SELECT fv_internal.document_asset_link(p_device,p_proof,p_operation,p_document,p_version,p_base,p_action,p_link,p_asset)';
CREATE FUNCTION public.fv_document_list_with_assets(p_device uuid,p_proof text) RETURNS jsonb
LANGUAGE sql SET search_path = '' AS
  'SELECT fv_internal.document_list_with_assets(p_device,p_proof)';
REVOKE ALL ON FUNCTION public.fv_document_asset_link(uuid,text,uuid,uuid,uuid,bigint,text,uuid,uuid),
  public.fv_document_list_with_assets(uuid,text) FROM PUBLIC,anon,service_role;
GRANT EXECUTE ON FUNCTION public.fv_document_asset_link(uuid,text,uuid,uuid,uuid,bigint,text,uuid,uuid),
  public.fv_document_list_with_assets(uuid,text) TO authenticated;

COMMIT;
