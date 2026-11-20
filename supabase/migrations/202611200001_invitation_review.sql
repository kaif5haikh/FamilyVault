-- Add the inviter's displayed name to the existing signed-in invite review.
-- The verified caller's email and the original state checks still scope every row.
CREATE OR REPLACE FUNCTION fv_internal.list_access() RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
DECLARE caller fv_internal.auth_context := fv_internal.current_auth();
BEGIN
  RETURN jsonb_build_object(
    'families', coalesce((SELECT jsonb_agg(jsonb_build_object('family_id', m.family_id, 'family_name', f.name,
      'member_id', m.id, 'role', m.role, 'display_name', m.display_name) ORDER BY f.name, f.id)
      FROM fv_data.members m JOIN fv_data.families f ON f.id = m.family_id WHERE m.auth_user_id = caller.user_id AND m.active), '[]'),
    'invitations', coalesce((SELECT jsonb_agg(jsonb_build_object('invite_id', i.id, 'family_name', f.name,
      'display_name', i.display_name, 'invited_by_name', inviter.display_name,
      'expires_at', i.expires_at) ORDER BY i.created_at DESC)
      FROM fv_data.invitations i JOIN fv_data.families f ON f.id = i.family_id
      JOIN fv_data.members inviter ON (inviter.family_id, inviter.id) = (i.family_id, i.invited_by)
      WHERE i.email = caller.email AND i.revoked_at IS NULL AND i.accepted_at IS NULL
        AND i.expires_at > statement_timestamp()), '[]'));
END;
$$;
