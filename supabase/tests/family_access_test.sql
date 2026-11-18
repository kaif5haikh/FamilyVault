-- All identities and keys in this test are synthetic. Transaction is rolled back.
BEGIN;
SET LOCAL plpgsql.check_asserts = on;
CREATE FUNCTION pg_temp.login_as(p_user uuid, p_session uuid, p_aal text DEFAULT 'aal1', p_mfa_age integer DEFAULT 0)
RETURNS void LANGUAGE sql AS $$
  SELECT set_config('request.jwt.claims', jsonb_build_object(
    'sub', p_user, 'session_id', p_session, 'role', 'authenticated', 'aal', p_aal,
    'amr', jsonb_build_array(jsonb_build_object('method', 'totp',
      'timestamp', extract(epoch FROM statement_timestamp())::bigint - p_mfa_age)))::text, true);
$$;
DO $$
DECLARE
  owner_user uuid := gen_random_uuid();
  outsider uuid := gen_random_uuid();
  other_owner uuid := gen_random_uuid();
  owner_session uuid := gen_random_uuid();
  outsider_session uuid := gen_random_uuid();
  other_session uuid := gen_random_uuid();
  next_session uuid := gen_random_uuid();
  owner_device uuid := gen_random_uuid();
  other_device uuid := gen_random_uuid();
  owner_proof text := repeat('1', 64);
  other_proof text := repeat('2', 64);
  owner_sign text := repeat('a', 64);
  owner_exchange text := repeat('b', 64);
  other_sign text := repeat('c', 64);
  other_exchange text := repeat('d', 64);
  owner_family uuid;
  other_family uuid;
  member_user uuid;
  member_session uuid;
  member_device uuid;
  member_sign text;
  member_exchange text;
  member_proof text;
  member_id uuid;
  invite uuid;
  login_email text;
  members uuid[] := '{}';
  member_devices uuid[] := '{}';
  member_proofs text[] := '{}';
  member_users uuid[] := '{}';
  member_sessions uuid[] := '{}';
  ready jsonb;
BEGIN
  INSERT INTO auth.users VALUES (owner_user, 'owner@example.invalid', now()),
    (other_owner, 'other@example.invalid', now()), (outsider, 'outside@example.invalid', now());
  INSERT INTO auth.sessions(id, user_id) VALUES (owner_session, owner_user), (next_session, owner_user),
    (other_session, other_owner), (outsider_session, outsider);
  owner_family := fv_internal.bootstrap_family(owner_user, 'Synthetic family A', 'Synthetic owner');
  other_family := fv_internal.bootstrap_family(other_owner, 'Synthetic family B', 'Synthetic other owner');

  ASSERT NOT has_schema_privilege('authenticated', 'fv_data', 'USAGE');
  ASSERT NOT has_schema_privilege('authenticated', 'fv_auth_bridge', 'USAGE');
  ASSERT NOT has_function_privilege('anon', 'public.fv_list_access()', 'EXECUTE');
  ASSERT NOT has_function_privilege('service_role', 'public.fv_list_access()', 'EXECUTE');
  ASSERT NOT has_function_privilege('authenticated', 'fv_internal.approve_first_device(uuid,text)', 'EXECUTE');
  ASSERT NOT has_function_privilege('authenticated', 'fv_internal.bootstrap_family(uuid,text,text)', 'EXECUTE');
  ASSERT NOT has_function_privilege('authenticated', 'fv_internal.require_device(uuid,text,boolean)', 'EXECUTE');
  ASSERT NOT EXISTS (SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
    WHERE n.nspname = 'fv_data' AND c.relkind = 'r' AND (NOT c.relrowsecurity OR NOT c.relforcerowsecurity));

  SET LOCAL ROLE authenticated;
  PERFORM pg_temp.login_as(owner_user, owner_session, 'aal2');
  ASSERT jsonb_array_length(public.fv_list_access()->'families') = 1;
  ASSERT public.fv_request_device(owner_family, owner_device, owner_proof, 'Synthetic Android device', owner_sign, owner_exchange) = 'pending';
  BEGIN
    PERFORM public.fv_bind_device(owner_device, owner_proof);
    RAISE EXCEPTION 'An unapproved device bound to a session';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  RESET ROLE;
  PERFORM fv_internal.approve_first_device(owner_device, encode(sha256(decode(owner_sign || owner_exchange, 'hex')), 'hex'));
  SET LOCAL ROLE authenticated;
  PERFORM public.fv_bind_device(owner_device, owner_proof);
  PERFORM public.fv_bind_device(owner_device, owner_proof);
  ready := public.fv_workspace(owner_device, owner_proof);
  ASSERT (ready->>'family_id')::uuid = owner_family;
  ASSERT ready->>'role' = 'administrator';
  ASSERT jsonb_array_length(ready->'members') = 1;
  ASSERT NOT (ready->'devices'->0 ? 'proof_hash');
  BEGIN
    PERFORM public.fv_workspace(owner_device, other_proof);
    RAISE EXCEPTION 'A bound session omitted valid device proof';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM pg_temp.login_as(owner_user, next_session, 'aal2');
  BEGIN
    PERFORM public.fv_workspace(owner_device, owner_proof);
    RAISE EXCEPTION 'A new session inherited a bind';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM pg_temp.login_as(owner_user, owner_session, 'aal2', 601);
  BEGIN
    PERFORM public.fv_invite_member(owner_device, owner_proof, 'late@example.invalid', 'Synthetic invitation', 'member');
    RAISE EXCEPTION 'Stale MFA authorized an administrator action';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM pg_temp.login_as(owner_user, owner_session, 'aal1');
  BEGIN
    PERFORM public.fv_admin_access(owner_device, owner_proof);
    RAISE EXCEPTION 'Password-only session accessed administrator data';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  FOR slot IN 1..3 LOOP
    RESET ROLE;
    member_user := gen_random_uuid();
    member_session := gen_random_uuid();
    member_device := gen_random_uuid();
    login_email := 'member' || slot || '@example.invalid';
    member_proof := encode(sha256(convert_to('device proof fixture ' || slot, 'UTF8')), 'hex');
    member_sign := encode(sha256(convert_to('signing fixture ' || slot, 'UTF8')), 'hex');
    member_exchange := encode(sha256(convert_to('exchange fixture ' || slot, 'UTF8')), 'hex');
    INSERT INTO auth.users VALUES (member_user, login_email, now());
    INSERT INTO auth.sessions(id, user_id) VALUES (member_session, member_user);
    SET LOCAL ROLE authenticated;
    PERFORM pg_temp.login_as(owner_user, owner_session, 'aal2');
    invite := public.fv_invite_member(owner_device, owner_proof, login_email, 'Synthetic member ' || slot, 'member');
    ASSERT public.fv_invite_member(owner_device, owner_proof, login_email, 'Synthetic member ' || slot, 'member') = invite;
    PERFORM pg_temp.login_as(outsider, outsider_session);
    ASSERT public.fv_list_access()->'invitations' = '[]'::jsonb;
    BEGIN
      PERFORM public.fv_accept_invite(invite);
      RAISE EXCEPTION 'An outsider claimed an invitation';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
    PERFORM pg_temp.login_as(member_user, member_session);
    ASSERT (public.fv_list_access()->'invitations'->0->>'invite_id')::uuid = invite;
    ASSERT public.fv_accept_invite(invite) = owner_family;
    ASSERT public.fv_accept_invite(invite) = owner_family;
    member_id := (public.fv_list_access()->'families'->0->>'member_id')::uuid;
    ASSERT public.fv_request_device(owner_family, member_device, member_proof, 'Synthetic member phone', member_sign, member_exchange) = 'pending';
    BEGIN
      PERFORM public.fv_request_device(other_family, gen_random_uuid(), member_proof, 'Synthetic wrong family', member_sign, member_exchange);
      RAISE EXCEPTION 'A member enrolled in another family';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
    PERFORM pg_temp.login_as(owner_user, owner_session, 'aal2');
    BEGIN
      PERFORM public.fv_approve_device(owner_device, owner_proof, member_device, repeat('0', 64));
      RAISE EXCEPTION 'Administrator approved without matching fingerprint';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
    PERFORM public.fv_approve_device(owner_device, owner_proof, member_device,
      encode(sha256(decode(member_sign || member_exchange, 'hex')), 'hex'));
    PERFORM pg_temp.login_as(member_user, member_session);
    PERFORM public.fv_bind_device(member_device, member_proof);
    ready := public.fv_workspace(member_device, member_proof);
    ASSERT ready->>'role' = 'member' AND (ready->>'family_id')::uuid = owner_family;
    BEGIN
      PERFORM public.fv_admin_access(member_device, member_proof);
      RAISE EXCEPTION 'A member obtained administrator records';
    EXCEPTION WHEN insufficient_privilege THEN NULL;
    END;
    members := array_append(members, member_id);
    member_devices := array_append(member_devices, member_device);
    member_proofs := array_append(member_proofs, member_proof);
    member_users := array_append(member_users, member_user);
    member_sessions := array_append(member_sessions, member_session);
  END LOOP;
  FOR slot IN 1..3 LOOP
    PERFORM pg_temp.login_as(member_users[slot], member_sessions[slot]);
    ASSERT jsonb_array_length(public.fv_workspace(member_devices[slot], member_proofs[slot])->'members') = 4;
  END LOOP;
  PERFORM pg_temp.login_as(other_owner, other_session, 'aal2');
  ASSERT public.fv_request_device(other_family, other_device, other_proof, 'Synthetic other phone', other_sign, other_exchange) = 'pending';
  RESET ROLE;
  PERFORM fv_internal.approve_first_device(other_device, encode(sha256(decode(other_sign || other_exchange, 'hex')), 'hex'));
  SET LOCAL ROLE authenticated;
  PERFORM public.fv_bind_device(other_device, other_proof);
  ASSERT jsonb_array_length(public.fv_workspace(other_device, other_proof)->'members') = 1;
  BEGIN
    PERFORM public.fv_revoke_access(other_device, other_proof, 'member', members[1]);
    RAISE EXCEPTION 'Administrator changed a different family';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  PERFORM pg_temp.login_as(member_users[1], member_sessions[1]);
  PERFORM public.fv_sign_out_device(member_devices[1], member_proofs[1]);
  BEGIN
    PERFORM public.fv_bind_device(member_devices[1], member_proofs[1]);
    RAISE EXCEPTION 'A signed-out binding was reopened';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;

  PERFORM pg_temp.login_as(owner_user, owner_session, 'aal2');
  PERFORM public.fv_revoke_access(owner_device, owner_proof, 'device', member_devices[2]);
  PERFORM public.fv_revoke_access(owner_device, owner_proof, 'member', members[1]);
  PERFORM pg_temp.login_as(member_users[2], member_sessions[2]);
  BEGIN
    PERFORM public.fv_workspace(member_devices[2], member_proofs[2]);
    RAISE EXCEPTION 'Revoked device read workspace data';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  PERFORM pg_temp.login_as(member_users[1], member_sessions[1]);
  ASSERT jsonb_array_length(public.fv_list_access()->'families') = 0;
  RESET ROLE;
  DELETE FROM auth.sessions WHERE id = member_sessions[3];
  SET LOCAL ROLE authenticated;
  PERFORM pg_temp.login_as(member_users[3], member_sessions[3]);
  BEGIN
    PERFORM public.fv_workspace(member_devices[3], member_proofs[3]);
    RAISE EXCEPTION 'A removed Auth session continued to authorize requests';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  RESET ROLE;
  ASSERT (SELECT count(*) FROM fv_data.access_audit WHERE family_id = owner_family AND action = 'session_bound') = 4;
  BEGIN
    UPDATE fv_data.access_audit SET occurred_at = now();
    RAISE EXCEPTION 'Audit history was mutable';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  BEGIN
    TRUNCATE fv_data.access_audit;
    RAISE EXCEPTION 'Audit history could be truncated';
  EXCEPTION WHEN insufficient_privilege THEN NULL;
  END;
  -- An accidental SELECT grant still cannot bypass forced RLS.
  GRANT USAGE ON SCHEMA fv_data TO authenticated;
  GRANT SELECT ON fv_data.members TO authenticated;
  SET LOCAL ROLE authenticated;
  ASSERT NOT EXISTS (SELECT 1 FROM fv_data.members);
  RESET ROLE;
END;
$$;
ROLLBACK;
