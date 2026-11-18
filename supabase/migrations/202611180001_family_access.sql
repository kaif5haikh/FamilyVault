-- FamilyVault access boundary. Apply using a database migration role.
BEGIN;

CREATE ROLE familyvault_executor NOLOGIN NOINHERIT NOBYPASSRLS;
DO $$
BEGIN
  EXECUTE format('GRANT familyvault_executor TO %I', current_user);
END;
$$;
CREATE SCHEMA fv_data AUTHORIZATION familyvault_executor;
CREATE SCHEMA fv_internal AUTHORIZATION familyvault_executor;
REVOKE ALL ON SCHEMA fv_data, fv_internal FROM PUBLIC, anon, authenticated, service_role;
GRANT USAGE ON SCHEMA fv_internal TO authenticated;
-- Keep the Auth catalog within its provider-owned schema. The migration role
-- can read these records and exposes only the checks needed by the app role.
CREATE SCHEMA fv_auth_bridge;
REVOKE ALL ON SCHEMA fv_auth_bridge FROM PUBLIC, anon, authenticated, service_role;
GRANT USAGE ON SCHEMA fv_auth_bridge TO familyvault_executor;

CREATE FUNCTION fv_auth_bridge.account_verified(p_user uuid) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT EXISTS (SELECT 1 FROM auth.users WHERE id = p_user AND email_confirmed_at IS NOT NULL AND email IS NOT NULL)
$$;

CREATE FUNCTION fv_auth_bridge.account_email_matches(p_user uuid, p_email text) RETURNS boolean
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
  SELECT EXISTS (SELECT 1 FROM auth.users WHERE id = p_user AND lower(email) = p_email)
$$;

CREATE FUNCTION fv_auth_bridge.current_identity()
RETURNS TABLE(user_id uuid, session_id uuid, email text, claims jsonb)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
BEGIN
  claims := auth.jwt();
  user_id := auth.uid();
  IF user_id IS NULL OR claims->>'role' IS DISTINCT FROM 'authenticated'
      OR coalesce(claims->>'is_anonymous', 'false') <> 'false'
      OR coalesce(claims->>'session_id', '') !~ '^[0-9a-fA-F]{8}(-[0-9a-fA-F]{4}){3}-[0-9a-fA-F]{12}$' THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'A current authenticated session is required';
  END IF;
  session_id := (claims->>'session_id')::uuid;
  SELECT lower(u.email) INTO email
    FROM auth.sessions s JOIN auth.users u ON u.id = s.user_id
    WHERE s.id = session_id AND s.user_id = current_identity.user_id
      AND (s.not_after IS NULL OR s.not_after > statement_timestamp())
      AND u.email_confirmed_at IS NOT NULL;
  IF email IS NULL THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'A current verified account is required';
  END IF;
  RETURN NEXT;
END;
$$;

REVOKE ALL ON ALL FUNCTIONS IN SCHEMA fv_auth_bridge FROM PUBLIC, anon, authenticated, service_role;
GRANT EXECUTE ON ALL FUNCTIONS IN SCHEMA fv_auth_bridge TO familyvault_executor;

SET LOCAL ROLE familyvault_executor;
SET LOCAL search_path = '';
ALTER DEFAULT PRIVILEGES REVOKE EXECUTE ON FUNCTIONS FROM PUBLIC;

CREATE TABLE fv_data.families (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL CHECK (length(btrim(name)) BETWEEN 1 AND 80),
  created_at timestamptz NOT NULL DEFAULT statement_timestamp()
);

CREATE TABLE fv_data.members (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id uuid NOT NULL REFERENCES fv_data.families(id),
  auth_user_id uuid NOT NULL,
  display_name text NOT NULL CHECK (length(btrim(display_name)) BETWEEN 1 AND 80),
  relationship text NOT NULL CHECK (length(btrim(relationship)) BETWEEN 1 AND 40),
  role text NOT NULL CHECK (role IN ('administrator', 'member')),
  active boolean NOT NULL DEFAULT true,
  revision bigint NOT NULL DEFAULT 1 CHECK (revision > 0),
  created_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  UNIQUE (family_id, auth_user_id),
  UNIQUE (family_id, id),
  UNIQUE (family_id, id, auth_user_id)
);
CREATE UNIQUE INDEX fv_one_administrator ON fv_data.members(family_id)
  WHERE role = 'administrator' AND active;

CREATE TABLE fv_data.invitations (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id uuid NOT NULL REFERENCES fv_data.families(id),
  email text NOT NULL CHECK (length(email) BETWEEN 3 AND 254 AND email = lower(btrim(email))),
  display_name text NOT NULL CHECK (length(btrim(display_name)) BETWEEN 1 AND 80),
  relationship text NOT NULL CHECK (length(btrim(relationship)) BETWEEN 1 AND 40),
  invited_by uuid NOT NULL,
  created_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  expires_at timestamptz NOT NULL,
  accepted_member_id uuid,
  accepted_at timestamptz,
  revoked_at timestamptz,
  FOREIGN KEY (family_id, invited_by) REFERENCES fv_data.members(family_id, id),
  FOREIGN KEY (family_id, accepted_member_id) REFERENCES fv_data.members(family_id, id),
  CHECK (expires_at > created_at),
  CHECK ((accepted_at IS NULL) = (accepted_member_id IS NULL)),
  CHECK (accepted_at IS NULL OR revoked_at IS NULL)
);
CREATE INDEX fv_invitations_email ON fv_data.invitations(email) WHERE accepted_at IS NULL AND revoked_at IS NULL;

CREATE TABLE fv_data.devices (
  id uuid PRIMARY KEY,
  family_id uuid NOT NULL,
  member_id uuid NOT NULL,
  name text NOT NULL CHECK (length(btrim(name)) BETWEEN 1 AND 80),
  proof_hash bytea NOT NULL CHECK (octet_length(proof_hash) = 32),
  signing_public bytea NOT NULL CHECK (octet_length(signing_public) = 32),
  exchange_public bytea NOT NULL CHECK (octet_length(exchange_public) = 32),
  state text NOT NULL DEFAULT 'pending' CHECK (state IN ('pending', 'enrolled', 'revoked')),
  created_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  approved_at timestamptz,
  approved_by uuid,
  revoked_at timestamptz,
  FOREIGN KEY (family_id, member_id) REFERENCES fv_data.members(family_id, id),
  FOREIGN KEY (family_id, approved_by) REFERENCES fv_data.members(family_id, id),
  UNIQUE (family_id, id, member_id),
  UNIQUE (family_id, signing_public),
  UNIQUE (family_id, exchange_public),
  CHECK (state <> 'enrolled' OR approved_at IS NOT NULL),
  CHECK ((state = 'revoked') = (revoked_at IS NOT NULL))
);
CREATE INDEX fv_devices_member ON fv_data.devices(family_id, member_id);

CREATE TABLE fv_data.session_bindings (
  session_id uuid PRIMARY KEY,
  auth_user_id uuid NOT NULL,
  family_id uuid NOT NULL,
  member_id uuid NOT NULL,
  device_id uuid NOT NULL,
  bound_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  revoked_at timestamptz,
  FOREIGN KEY (family_id, member_id, auth_user_id) REFERENCES fv_data.members(family_id, id, auth_user_id),
  FOREIGN KEY (family_id, device_id, member_id) REFERENCES fv_data.devices(family_id, id, member_id)
);
CREATE INDEX fv_bindings_device ON fv_data.session_bindings(family_id, device_id);

CREATE TABLE fv_data.access_audit (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  family_id uuid NOT NULL REFERENCES fv_data.families(id),
  actor_id uuid,
  actor_device_id uuid,
  target_id uuid NOT NULL,
  action text NOT NULL CHECK (action IN ('family_created', 'member_invited', 'invitation_revoked', 'invitation_accepted',
    'device_requested', 'device_enrolled', 'device_revoked', 'member_revoked', 'session_bound', 'session_revoked')),
  occurred_at timestamptz NOT NULL DEFAULT statement_timestamp(),
  FOREIGN KEY (family_id, actor_id) REFERENCES fv_data.members(family_id, id),
  FOREIGN KEY (family_id, actor_device_id, actor_id) REFERENCES fv_data.devices(family_id, id, member_id),
  CHECK (actor_device_id IS NULL OR actor_id IS NOT NULL)
);
CREATE INDEX fv_access_audit_family ON fv_data.access_audit(family_id, occurred_at DESC, id);

DO $$
DECLARE name text;
BEGIN
  FOREACH name IN ARRAY ARRAY['families', 'members', 'invitations', 'devices', 'session_bindings', 'access_audit'] LOOP
    EXECUTE format('ALTER TABLE fv_data.%I ENABLE ROW LEVEL SECURITY', name);
    EXECUTE format('ALTER TABLE fv_data.%I FORCE ROW LEVEL SECURITY', name);
    EXECUTE format('CREATE POLICY internal_executor ON fv_data.%I TO familyvault_executor USING (true) WITH CHECK (true)', name);
    EXECUTE format('REVOKE ALL ON TABLE fv_data.%I FROM PUBLIC, anon, authenticated, service_role', name);
  END LOOP;
END;
$$;

CREATE FUNCTION fv_internal.forbid_audit_change() RETURNS trigger
LANGUAGE plpgsql SET search_path = '' AS $$
BEGIN
  RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'Audit history is append-only';
END;
$$;
CREATE TRIGGER fv_access_audit_immutable BEFORE UPDATE OR DELETE OR TRUNCATE ON fv_data.access_audit
  FOR EACH STATEMENT EXECUTE FUNCTION fv_internal.forbid_audit_change();

CREATE TYPE fv_internal.auth_context AS (user_id uuid, session_id uuid, email text, claims jsonb);
CREATE TYPE fv_internal.device_context AS (family_id uuid, member_id uuid, device_id uuid, role text, session_id uuid);

CREATE FUNCTION fv_internal.current_auth() RETURNS fv_internal.auth_context
LANGUAGE sql STABLE SET search_path = '' AS $$
  SELECT ROW(i.user_id, i.session_id, i.email, i.claims)::fv_internal.auth_context
  FROM fv_auth_bridge.current_identity() i
$$;

CREATE FUNCTION fv_internal.proof_digest(p_proof text) RETURNS bytea
LANGUAGE plpgsql IMMUTABLE SET search_path = '' AS $$
BEGIN
  IF p_proof IS NULL OR p_proof !~ '^[0-9a-f]{64}$' THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'Device verification required';
  END IF;
  RETURN sha256(decode(p_proof, 'hex'));
END;
$$;

CREATE FUNCTION fv_internal.require_device(p_device uuid, p_proof text, p_administrator boolean DEFAULT false)
RETURNS fv_internal.device_context LANGUAGE plpgsql STABLE SET search_path = '' AS $$
DECLARE caller fv_internal.auth_context := fv_internal.current_auth();
DECLARE device fv_internal.device_context;
BEGIN
  SELECT d.family_id, m.id, d.id, m.role, b.session_id INTO device
  FROM fv_data.session_bindings b
  JOIN fv_data.devices d ON (d.family_id, d.id, d.member_id) = (b.family_id, b.device_id, b.member_id)
  JOIN fv_data.members m ON (m.family_id, m.id, m.auth_user_id) = (b.family_id, b.member_id, b.auth_user_id)
  WHERE b.session_id = caller.session_id AND b.auth_user_id = caller.user_id AND b.revoked_at IS NULL
    AND d.id = p_device AND d.proof_hash = fv_internal.proof_digest(p_proof) AND d.state = 'enrolled' AND m.active;
  IF device.member_id IS NULL THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'This device or session is unavailable';
  END IF;
  IF p_administrator AND (device.role <> 'administrator' OR caller.claims->>'aal' IS DISTINCT FROM 'aal2'
      OR NOT EXISTS (SELECT 1 FROM jsonb_array_elements(
        CASE WHEN jsonb_typeof(caller.claims->'amr') = 'array' THEN caller.claims->'amr' ELSE '[]'::jsonb END
      ) entry WHERE entry->>'method' IN ('totp', 'mfa') AND CASE
        WHEN coalesce(entry->>'timestamp', '') ~ '^[0-9]{1,12}$' THEN
          (entry->>'timestamp')::bigint BETWEEN extract(epoch FROM statement_timestamp()) - 600
            AND extract(epoch FROM statement_timestamp()) + 30
        ELSE false END)) THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'An administrator must verify a recent second factor';
  END IF;
  RETURN device;
END;
$$;

CREATE FUNCTION fv_internal.bootstrap_family(p_user uuid, p_name text, p_owner text) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE family uuid;
DECLARE member uuid;
BEGIN
  IF NOT fv_auth_bridge.account_verified(p_user) THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Verify the first administrator account in Auth';
  END IF;
  INSERT INTO fv_data.families(name) VALUES (btrim(p_name)) RETURNING id INTO family;
  INSERT INTO fv_data.members(family_id, auth_user_id, display_name, relationship, role)
    VALUES (family, p_user, btrim(p_owner), 'administrator', 'administrator') RETURNING id INTO member;
  INSERT INTO fv_data.access_audit(family_id, actor_id, target_id, action) VALUES (family, member, family, 'family_created');
  RETURN family;
END;
$$;

CREATE FUNCTION fv_internal.approve_first_device(p_device uuid, p_fingerprint text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE candidate fv_data.devices;
BEGIN
  SELECT d.* INTO candidate FROM fv_data.devices d JOIN fv_data.members m
    ON (m.family_id, m.id) = (d.family_id, d.member_id)
    WHERE d.id = p_device AND d.state = 'pending' AND m.role = 'administrator' AND m.active
      AND encode(sha256(d.signing_public || d.exchange_public), 'hex') = p_fingerprint;
  IF candidate.id IS NULL THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'Verify the pending administrator device and fingerprint';
  END IF;
  PERFORM 1 FROM fv_data.families WHERE id = candidate.family_id FOR UPDATE;
  IF EXISTS (SELECT 1 FROM fv_data.devices d JOIN fv_data.members m
      ON (m.family_id, m.id) = (d.family_id, d.member_id) WHERE d.family_id = candidate.family_id
      AND d.state = 'enrolled' AND m.role = 'administrator' AND m.active) THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'Approve using the enrolled administrator device';
  END IF;
  UPDATE fv_data.devices SET state = 'enrolled', approved_at = statement_timestamp(), approved_by = candidate.member_id
    WHERE id = candidate.id AND state = 'pending';
  IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'Device is no longer pending'; END IF;
  INSERT INTO fv_data.access_audit(family_id, actor_id, target_id, action)
    VALUES (candidate.family_id, candidate.member_id, candidate.id, 'device_enrolled');
END;
$$;

CREATE FUNCTION fv_internal.list_access() RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE caller fv_internal.auth_context := fv_internal.current_auth();
BEGIN
  RETURN jsonb_build_object(
    'families', coalesce((SELECT jsonb_agg(jsonb_build_object('family_id', m.family_id, 'family_name', f.name,
      'member_id', m.id, 'role', m.role, 'display_name', m.display_name) ORDER BY f.name, f.id)
      FROM fv_data.members m JOIN fv_data.families f ON f.id = m.family_id WHERE m.auth_user_id = caller.user_id AND m.active), '[]'),
    'invitations', coalesce((SELECT jsonb_agg(jsonb_build_object('invite_id', i.id, 'family_name', f.name,
      'display_name', i.display_name, 'expires_at', i.expires_at) ORDER BY i.created_at DESC)
      FROM fv_data.invitations i JOIN fv_data.families f ON f.id = i.family_id WHERE i.email = caller.email
        AND i.revoked_at IS NULL AND i.accepted_at IS NULL AND i.expires_at > statement_timestamp()), '[]'));
END;
$$;

CREATE FUNCTION fv_internal.invite_member(p_device uuid, p_proof text, p_email text, p_name text, p_relationship text)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE actor fv_internal.device_context := fv_internal.require_device(p_device, p_proof, true);
DECLARE invite uuid;
DECLARE email_address text := lower(btrim(p_email));
BEGIN
  IF email_address IS NULL OR length(email_address) > 254 OR email_address !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'
    OR p_name IS NULL OR length(btrim(p_name)) NOT BETWEEN 1 AND 80
    OR p_relationship IS NULL OR length(btrim(p_relationship)) NOT BETWEEN 1 AND 40 THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Check the invitee email, name and relationship';
  END IF;
  PERFORM 1 FROM fv_data.families WHERE id = actor.family_id FOR UPDATE;
  IF EXISTS (SELECT 1 FROM fv_data.members m
      WHERE m.family_id = actor.family_id AND fv_auth_bridge.account_email_matches(m.auth_user_id, email_address)) THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'This account already has a membership record';
  END IF;
  SELECT id INTO invite FROM fv_data.invitations WHERE family_id = actor.family_id AND email = email_address
    AND accepted_at IS NULL AND revoked_at IS NULL AND expires_at > statement_timestamp() LIMIT 1;
  IF invite IS NOT NULL THEN RETURN invite; END IF;
  INSERT INTO fv_data.invitations(family_id, email, display_name, relationship, invited_by, expires_at)
    VALUES (actor.family_id, email_address, btrim(p_name), btrim(p_relationship), actor.member_id, statement_timestamp() + interval '7 days')
    RETURNING id INTO invite;
  INSERT INTO fv_data.access_audit(family_id, actor_id, actor_device_id, target_id, action)
    VALUES (actor.family_id, actor.member_id, actor.device_id, invite, 'member_invited');
  RETURN invite;
END;
$$;

CREATE FUNCTION fv_internal.accept_invite(p_invite uuid) RETURNS uuid
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE caller fv_internal.auth_context := fv_internal.current_auth();
DECLARE invite fv_data.invitations;
DECLARE member uuid;
BEGIN
  SELECT * INTO invite FROM fv_data.invitations WHERE id = p_invite AND email = caller.email FOR UPDATE;
  IF invite.id IS NULL OR invite.revoked_at IS NOT NULL OR (invite.accepted_at IS NULL AND invite.expires_at <= statement_timestamp()) THEN
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'The invitation is unavailable for this account';
  END IF;
  IF invite.accepted_at IS NOT NULL THEN
    IF EXISTS (SELECT 1 FROM fv_data.members WHERE id = invite.accepted_member_id AND auth_user_id = caller.user_id AND active) THEN
      RETURN invite.family_id;
    END IF;
    RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'The invitation is unavailable for this account';
  END IF;
  INSERT INTO fv_data.members(family_id, auth_user_id, display_name, relationship, role)
    VALUES (invite.family_id, caller.user_id, invite.display_name, invite.relationship, 'member') RETURNING id INTO member;
  UPDATE fv_data.invitations SET accepted_member_id = member, accepted_at = statement_timestamp() WHERE id = invite.id;
  INSERT INTO fv_data.access_audit(family_id, actor_id, target_id, action) VALUES (invite.family_id, member, invite.id, 'invitation_accepted');
  RETURN invite.family_id;
END;
$$;

CREATE FUNCTION fv_internal.request_device(p_family uuid, p_device uuid, p_proof text, p_name text,
  p_signing_public text, p_exchange_public text) RETURNS text
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE caller fv_internal.auth_context := fv_internal.current_auth();
DECLARE member uuid;
DECLARE candidate fv_data.devices;
DECLARE hash bytea := fv_internal.proof_digest(p_proof);
BEGIN
  SELECT id INTO member FROM fv_data.members WHERE family_id = p_family AND auth_user_id = caller.user_id AND active FOR UPDATE;
  IF member IS NULL THEN RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'Family membership is required'; END IF;
  IF p_name IS NULL OR length(btrim(p_name)) NOT BETWEEN 1 AND 80 OR p_device IS NULL
    OR coalesce(p_signing_public, '') !~ '^[0-9a-f]{64}$' OR coalesce(p_exchange_public, '') !~ '^[0-9a-f]{64}$'
    OR p_signing_public = repeat('0', 64) OR p_exchange_public = repeat('0', 64) THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Invalid device enrollment details';
  END IF;
  SELECT * INTO candidate FROM fv_data.devices WHERE id = p_device;
  IF candidate.id IS NOT NULL THEN
    IF (candidate.family_id, candidate.member_id, candidate.proof_hash, candidate.signing_public, candidate.exchange_public)
        IS DISTINCT FROM (p_family, member, hash, decode(p_signing_public, 'hex'), decode(p_exchange_public, 'hex')) THEN
      RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'Device verification failed';
    END IF;
    RETURN candidate.state;
  END IF;
  IF (SELECT count(*) FROM fv_data.devices WHERE family_id = p_family AND member_id = member AND state <> 'revoked') >= 12 THEN
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Revoke an unused device before requesting another';
  END IF;
  INSERT INTO fv_data.devices(id, family_id, member_id, name, proof_hash, signing_public, exchange_public)
    VALUES (p_device, p_family, member, btrim(p_name), hash, decode(p_signing_public, 'hex'), decode(p_exchange_public, 'hex'));
  INSERT INTO fv_data.access_audit(family_id, actor_id, target_id, action) VALUES (p_family, member, p_device, 'device_requested');
  RETURN 'pending';
END;
$$;

CREATE FUNCTION fv_internal.approve_device(p_device uuid, p_proof text, p_candidate uuid, p_fingerprint text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE actor fv_internal.device_context := fv_internal.require_device(p_device, p_proof, true);
BEGIN
  UPDATE fv_data.devices d SET state = 'enrolled', approved_at = statement_timestamp(), approved_by = actor.member_id
    FROM fv_data.members m WHERE d.family_id = actor.family_id AND d.id = p_candidate AND d.state = 'pending'
      AND (m.family_id, m.id) = (d.family_id, d.member_id) AND m.active
      AND encode(sha256(d.signing_public || d.exchange_public), 'hex') = p_fingerprint;
  IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'The pending device and fingerprint do not match'; END IF;
  INSERT INTO fv_data.access_audit(family_id, actor_id, actor_device_id, target_id, action)
    VALUES (actor.family_id, actor.member_id, actor.device_id, p_candidate, 'device_enrolled');
END;
$$;

CREATE FUNCTION fv_internal.bind_device(p_device uuid, p_proof text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE caller fv_internal.auth_context := fv_internal.current_auth();
DECLARE candidate fv_data.devices;
BEGIN
  SELECT d.* INTO candidate FROM fv_data.devices d JOIN fv_data.members m
    ON (m.family_id, m.id) = (d.family_id, d.member_id)
    WHERE d.id = p_device AND d.proof_hash = fv_internal.proof_digest(p_proof) AND d.state = 'enrolled'
      AND m.active AND m.auth_user_id = caller.user_id;
  IF candidate.id IS NULL THEN RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'This device is not approved for this account'; END IF;
  INSERT INTO fv_data.session_bindings(session_id, auth_user_id, family_id, member_id, device_id)
    VALUES (caller.session_id, caller.user_id, candidate.family_id, candidate.member_id, candidate.id) ON CONFLICT DO NOTHING;
  IF FOUND THEN
    INSERT INTO fv_data.access_audit(family_id, actor_id, actor_device_id, target_id, action)
      VALUES (candidate.family_id, candidate.member_id, candidate.id, candidate.id, 'session_bound');
  END IF;
  PERFORM fv_internal.require_device(p_device, p_proof);
END;
$$;

CREATE FUNCTION fv_internal.revoke_access(p_device uuid, p_proof text, p_kind text, p_target uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE actor fv_internal.device_context := fv_internal.require_device(p_device, p_proof, true);
DECLARE audit_action text;
BEGIN
  IF p_kind = 'invitation' THEN
    UPDATE fv_data.invitations SET revoked_at = statement_timestamp() WHERE family_id = actor.family_id
      AND id = p_target AND accepted_at IS NULL AND revoked_at IS NULL;
    audit_action := 'invitation_revoked';
  ELSIF p_kind = 'device' THEN
    UPDATE fv_data.devices SET state = 'revoked', revoked_at = statement_timestamp() WHERE family_id = actor.family_id
      AND id = p_target AND state <> 'revoked';
    audit_action := 'device_revoked';
  ELSIF p_kind = 'member' THEN
    UPDATE fv_data.members SET active = false, revision = revision + 1 WHERE family_id = actor.family_id
      AND id = p_target AND active AND role = 'member';
    audit_action := 'member_revoked';
  ELSE
    RAISE EXCEPTION USING ERRCODE = '22023', MESSAGE = 'Unknown access record';
  END IF;
  IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE = '42501', MESSAGE = 'The access record is unavailable'; END IF;
  INSERT INTO fv_data.access_audit(family_id, actor_id, actor_device_id, target_id, action)
    VALUES (actor.family_id, actor.member_id, actor.device_id, p_target, audit_action);
END;
$$;

CREATE FUNCTION fv_internal.sign_out_device(p_device uuid, p_proof text) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE actor fv_internal.device_context := fv_internal.require_device(p_device, p_proof);
BEGIN
  UPDATE fv_data.session_bindings SET revoked_at = statement_timestamp()
    WHERE session_id = actor.session_id AND revoked_at IS NULL;
  IF FOUND THEN
    INSERT INTO fv_data.access_audit(family_id, actor_id, actor_device_id, target_id, action)
      VALUES (actor.family_id, actor.member_id, actor.device_id, actor.device_id, 'session_revoked');
  END IF;
END;
$$;

CREATE FUNCTION fv_internal.workspace(p_device uuid, p_proof text) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE actor fv_internal.device_context := fv_internal.require_device(p_device, p_proof);
BEGIN
  RETURN jsonb_build_object('family_id', actor.family_id, 'member_id', actor.member_id, 'device_id', actor.device_id,
    'role', actor.role, 'server_time_us', (extract(epoch FROM statement_timestamp()) * 1000000)::bigint,
    'family', (SELECT jsonb_build_object('id', id, 'name', name, 'mode', 'cloud', 'currency', 'INR',
      'created_at_us', (extract(epoch FROM created_at) * 1000000)::bigint) FROM fv_data.families WHERE id = actor.family_id),
    'members', (SELECT jsonb_agg(jsonb_build_object('id', id, 'family_id', family_id, 'display_name', display_name,
      'relationship', relationship, 'role', role, 'active', active, 'revision', revision,
      'created_at_us', (extract(epoch FROM created_at) * 1000000)::bigint) ORDER BY created_at, id)
      FROM fv_data.members WHERE family_id = actor.family_id),
    'devices', (SELECT jsonb_agg(jsonb_build_object('id', id, 'family_id', family_id, 'member_id', member_id,
      'name', name, 'state', state, 'created_at_us', (extract(epoch FROM created_at) * 1000000)::bigint,
      'signing_public', encode(signing_public, 'hex'), 'exchange_public', encode(exchange_public, 'hex'),
      'fingerprint', encode(sha256(signing_public || exchange_public), 'hex')) ORDER BY created_at, id)
      FROM fv_data.devices WHERE family_id = actor.family_id AND (state <> 'pending' OR actor.role = 'administrator')));
END;
$$;

CREATE FUNCTION fv_internal.admin_access(p_device uuid, p_proof text) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE actor fv_internal.device_context := fv_internal.require_device(p_device, p_proof, true);
BEGIN
  RETURN jsonb_build_object(
    'invitations', coalesce((SELECT jsonb_agg(jsonb_build_object('id', id, 'email', email,
      'display_name', display_name, 'expires_at', expires_at) ORDER BY created_at DESC)
      FROM fv_data.invitations WHERE family_id = actor.family_id AND accepted_at IS NULL
        AND revoked_at IS NULL AND expires_at > statement_timestamp()), '[]'),
    'audit', coalesce((SELECT jsonb_agg(to_jsonb(events)) FROM (
      SELECT id, actor_id, actor_device_id, target_id, action, occurred_at FROM fv_data.access_audit
      WHERE family_id = actor.family_id ORDER BY occurred_at DESC, id LIMIT 100) events), '[]'));
END;
$$;

GRANT EXECUTE ON FUNCTION fv_internal.list_access(), fv_internal.accept_invite(uuid),
  fv_internal.request_device(uuid, uuid, text, text, text, text), fv_internal.bind_device(uuid, text),
  fv_internal.invite_member(uuid, text, text, text, text), fv_internal.approve_device(uuid, text, uuid, text),
  fv_internal.revoke_access(uuid, text, text, uuid), fv_internal.sign_out_device(uuid, text),
  fv_internal.workspace(uuid, text), fv_internal.admin_access(uuid, text) TO authenticated;

RESET ROLE;
-- Expose only invoker wrappers. Their private implementations validate every call.
CREATE FUNCTION public.fv_list_access() RETURNS jsonb LANGUAGE sql STABLE SET search_path = ''
  AS 'SELECT fv_internal.list_access()';
CREATE FUNCTION public.fv_accept_invite(p_invite uuid) RETURNS uuid LANGUAGE sql SET search_path = ''
  AS 'SELECT fv_internal.accept_invite(p_invite)';
CREATE FUNCTION public.fv_request_device(p_family uuid, p_device uuid, p_proof text, p_name text, p_signing_public text, p_exchange_public text)
  RETURNS text LANGUAGE sql SET search_path = ''
  AS 'SELECT fv_internal.request_device(p_family, p_device, p_proof, p_name, p_signing_public, p_exchange_public)';
CREATE FUNCTION public.fv_bind_device(p_device uuid, p_proof text) RETURNS void LANGUAGE sql SET search_path = ''
  AS 'SELECT fv_internal.bind_device(p_device, p_proof)';
CREATE FUNCTION public.fv_invite_member(p_device uuid, p_proof text, p_email text, p_name text, p_relationship text)
  RETURNS uuid LANGUAGE sql SET search_path = ''
  AS 'SELECT fv_internal.invite_member(p_device, p_proof, p_email, p_name, p_relationship)';
CREATE FUNCTION public.fv_approve_device(p_device uuid, p_proof text, p_candidate uuid, p_fingerprint text)
  RETURNS void LANGUAGE sql SET search_path = ''
  AS 'SELECT fv_internal.approve_device(p_device, p_proof, p_candidate, p_fingerprint)';
CREATE FUNCTION public.fv_revoke_access(p_device uuid, p_proof text, p_kind text, p_target uuid)
  RETURNS void LANGUAGE sql SET search_path = ''
  AS 'SELECT fv_internal.revoke_access(p_device, p_proof, p_kind, p_target)';
CREATE FUNCTION public.fv_sign_out_device(p_device uuid, p_proof text) RETURNS void LANGUAGE sql SET search_path = ''
  AS 'SELECT fv_internal.sign_out_device(p_device, p_proof)';
CREATE FUNCTION public.fv_workspace(p_device uuid, p_proof text) RETURNS jsonb LANGUAGE sql STABLE SET search_path = ''
  AS 'SELECT fv_internal.workspace(p_device, p_proof)';
CREATE FUNCTION public.fv_admin_access(p_device uuid, p_proof text) RETURNS jsonb LANGUAGE sql STABLE SET search_path = ''
  AS 'SELECT fv_internal.admin_access(p_device, p_proof)';

DO $$
DECLARE signature regprocedure;
BEGIN
  FOR signature IN SELECT p.oid::regprocedure FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public' AND p.proname IN ('fv_list_access', 'fv_accept_invite', 'fv_request_device',
      'fv_bind_device', 'fv_invite_member', 'fv_approve_device', 'fv_revoke_access', 'fv_sign_out_device', 'fv_workspace', 'fv_admin_access')
  LOOP
    EXECUTE format('REVOKE ALL ON FUNCTION %s FROM PUBLIC, anon, authenticated, service_role', signature);
    EXECUTE format('GRANT EXECUTE ON FUNCTION %s TO authenticated', signature);
  END LOOP;
END;
$$;

COMMIT;
