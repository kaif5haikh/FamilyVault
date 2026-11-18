-- Test adapter for the Auth catalog and trusted API claim context only.
-- This fixture runs against a private socket and never ships to Supabase.
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE ROLE service_role NOLOGIN;
CREATE SCHEMA auth;
CREATE TABLE auth.users (id uuid PRIMARY KEY, email text UNIQUE NOT NULL, email_confirmed_at timestamptz);
CREATE TABLE auth.sessions (id uuid PRIMARY KEY, user_id uuid NOT NULL REFERENCES auth.users(id), not_after timestamptz);
CREATE FUNCTION auth.jwt() RETURNS jsonb LANGUAGE sql STABLE SET search_path = ''
  AS $$SELECT coalesce(nullif(current_setting('request.jwt.claims', true), ''), '{}')::jsonb$$;
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE SET search_path = ''
  AS $$SELECT (auth.jwt()->>'sub')::uuid$$;
