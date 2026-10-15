-- Firm mode (4) — a removed member's device stops being pushed to.
--
-- The gap. `remove_firm_member` revokes membership, relinks the profile to the
-- individual default and announces the revocation on both topics, but it leaves
-- the member's `device_tokens` rows behind. Those rows are the fan-set the admin
-- payment-alert sender reads, and they are the member's own to delete only while
-- they can still sign in — which, after removal, is a state the server may never
-- observe again: the device wipes itself on the next open and the row is only
-- cleaned up if the client runs its own sign-out path.
--
-- What that costs. A removed member's phone keeps receiving the chamber's pushes
-- (approval alerts, roster changes) even though their access has ended. The
-- chamber's data is unreachable — `profiles.firm_id` is null, so every read is
-- filtered and every write lands firm-less — but a phone being told about a
-- chamber it has left is both a leak of the chamber's activity and a reason for
-- the removed member to keep opening an app that erases their copy on launch.
--
-- The fix is one statement inside the same transaction as the revoke, so the two
-- cannot come apart: a removal that commits has already taken the tokens. It is
-- server-side on purpose (not left to the client's sign-out) because the whole
-- point is to reach the devices of an account that is no longer cooperating.
-- The service-role sender's fan-set is unaffected for every *current* member.

-- ---------------------------------------------------------------------------
-- remove_firm_member — clear the removed member's push registrations
-- ---------------------------------------------------------------------------

-- `create or replace` of the whole function: the body is otherwise unchanged, so
-- the diff against the previous revision is the DELETE below and nothing else.
create or replace function public.remove_firm_member(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog', 'public'
as $function$
declare
  v_actor uuid := auth.uid();
  v_firm_id uuid;
  v_locked boolean;
begin
  if v_actor is null then
    raise exception 'unauthenticated' using errcode = '42501';
  end if;

  if p_user_id is null then
    return jsonb_build_object('status', 'invalid_request');
  end if;

  -- The caller's own firm, and only if they own it. A non-owner gets an answer
  -- rather than an error: it is a state the UI can word, not a bug.
  select f.id into v_firm_id
    from public.firms f
   where f.owner_id = v_actor;

  if v_firm_id is null then
    return jsonb_build_object('status', 'not_owner');
  end if;

  if p_user_id = v_actor then
    -- A firm is not transferable in this task, so removing the owner would
    -- leave `firms.owner_id` pointing at a non-member and the firm with nobody
    -- who may administer it.
    return jsonb_build_object('status', 'cannot_remove_self');
  end if;

  -- Locked, so two concurrent removals cannot both claim the same row and one
  -- of them cannot report `removed` for a membership it did not delete.
  select true into v_locked
    from public.firm_members m
   where m.firm_id = v_firm_id
     and m.user_id = p_user_id
   for update;

  if not found then
    return jsonb_build_object('status', 'not_found');
  end if;

  delete from public.firm_members m
   where m.firm_id = v_firm_id
     and m.user_id = p_user_id;

  -- The revocation, in one statement: `firm_id` is what every scoped read, every
  -- topic join and every queued `push_changes` write at once. `role` follows it
  -- back to the individual default rather than being left as `associate` with no
  -- firm.
  update public.profiles p
     set firm_id = null,
         role = 'individual'
   where p.id = p_user_id;

  -- The member's push registrations go with the access. A row here is keyed by
  -- the FCM token, so this reaches every device that registered one, including
  -- devices that will never sign in again to clean up after themselves.
  delete from public.device_tokens t
   where t.user_id = p_user_id;

  -- Two audiences, two topics — both as the trigger's own `row_change` event,
  -- so the client needs no second decoder:
  --
  --   * `user:{removed}` reaches the removed account's own devices at once,
  --     whatever topic they were joined to (`can_read_topic` always allows a
  --     caller their own user topic, including after the relink above);
  --   * `firm:{firm}` refreshes every remaining member's roster view.
  --
  -- The DELETE above fires no row trigger — the broadcast trigger is
  -- INSERT/UPDATE only — so this announcement is explicit rather than implied.
  perform realtime.send(
    jsonb_build_object('table', 'firm_members', 'id', p_user_id),
    'row_change',
    'user:' || p_user_id::text,
    true
  );
  perform realtime.send(
    jsonb_build_object('table', 'firm_members', 'id', p_user_id),
    'row_change',
    'firm:' || v_firm_id::text,
    true
  );

  return jsonb_build_object(
    'status', 'removed',
    'user_id', p_user_id,
    'firm_id', v_firm_id
  );
end;
$function$;

-- Same ownership contract as before: only `authenticated` may call it, and the
-- function itself refuses a non-owner. `anon` is named explicitly because a
-- direct EXECUTE grant from Supabase's default privileges outlives a revoke of
-- PUBLIC.
revoke all on function public.remove_firm_member(uuid) from public, anon;
grant execute on function public.remove_firm_member(uuid) to authenticated;

comment on function public.remove_firm_member(uuid) is
  'Owner-only removal: locks the membership, deletes it, relinks the profile to the individual default, clears the member''s push registrations, and announces the revocation on the member''s own topic and the chamber''s. The member''s authored rows are untouched and stay the firm''s.';
