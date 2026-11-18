-- Apply after Storage has initialized its provider-owned schema.
BEGIN;

INSERT INTO storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
VALUES ('familyvault-ciphertext','familyvault-ciphertext',false,25167392,ARRAY['application/octet-stream'])
ON CONFLICT (id) DO NOTHING;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM storage.buckets WHERE id='familyvault-ciphertext' AND public IS FALSE
      AND file_size_limit=25167392 AND allowed_mime_types=ARRAY['application/octet-stream']) THEN
    RAISE EXCEPTION 'Existing FamilyVault storage settings require review';
  END IF;
  IF NOT (SELECT relrowsecurity FROM pg_catalog.pg_class WHERE oid='storage.objects'::regclass) THEN
    RAISE EXCEPTION 'Storage object row-level security is required';
  END IF;
END;
$$;

ALTER TABLE storage.buckets ADD CONSTRAINT fv_ciphertext_private
  CHECK (id <> 'familyvault-ciphertext' OR public IS FALSE);

-- A permissive policy elsewhere in the project cannot grant ordinary clients
-- access to this bucket. The trusted gateway audits and authorizes access.
CREATE POLICY fv_private_object_gateway ON storage.objects AS RESTRICTIVE
  FOR ALL TO anon, authenticated
  USING (bucket_id <> 'familyvault-ciphertext')
  WITH CHECK (bucket_id <> 'familyvault-ciphertext');

COMMIT;
