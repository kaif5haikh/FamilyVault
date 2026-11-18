-- Contract fixture for the provider-owned Storage catalog, isolated to tests.
CREATE SCHEMA storage;
CREATE TABLE storage.buckets (
  id text PRIMARY KEY,
  name text NOT NULL,
  public boolean,
  file_size_limit bigint,
  allowed_mime_types text[]
);
CREATE TABLE storage.objects (bucket_id text NOT NULL REFERENCES storage.buckets(id), name text NOT NULL);
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;
GRANT USAGE ON SCHEMA storage TO anon,authenticated;
GRANT SELECT,INSERT ON storage.objects TO anon,authenticated;
CREATE POLICY permissive_fixture ON storage.objects FOR ALL TO authenticated USING (true) WITH CHECK (true);
