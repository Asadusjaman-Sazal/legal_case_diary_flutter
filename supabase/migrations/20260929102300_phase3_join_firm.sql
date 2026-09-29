-- Phase 3 (4/6) — join_firm(code).
--
-- Onboarding is online-only and runs entirely here: an associate cannot SELECT
-- `firm_invites` before membership, so redemption has to be a SECURITY DEFINER
-- RPC. One call rate-limits, matches, creates the membership, relinks the
-- profile, consumes the invite — or returns a status without changing anything.
--
-- Two details matter for correctness:
--   * a FAILED match records its attempt through a normal `return`, never by
--     inserting and then raising — a raise would roll the attempt back with the
--     statement and the rate limit would never fill up;
--   * only the sha256 hex of the normalized code is ever compared, so a
--     plaintext code exists only in the user's hands and the invite row.

create or replace function public.join_firm(code text)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  -- Five failures per 15 minutes, and attempts older than a day are dropped by
  -- the call itself, so no scheduled job is needed.
  c_max_failures constant integer := 5;
  c_window constant interval := interval '15 minutes';
  c_retention constant interval := interval '1 day';

  v_user_id uuid := auth.uid();
  v_code_hash text;
  v_invite public.firm_invites%rowtype;
  v_failures integer;
  v_used_at bigint;
begin
  if v_user_id is null then
    return jsonb_build_object('status', 'unauthenticated');
  end if;

  delete from public.invite_attempts a
   where a.attempted_at < now() - c_retention;

  select pg_catalog.count(*) into v_failures
    from public.invite_attempts a
   where a.user_id = v_user_id
     and a.attempted_at > now() - c_window;

  if v_failures >= c_max_failures then
    raise exception 'Too many attempts — try again later'
      using errcode = 'P0001';
  end if;

  -- Normalization: trim, uppercase, sha256 hex. The client's invite generator
  -- (Task 20) must hash a code the same way.
  v_code_hash := public.sha256_hex(upper(pg_catalog.btrim(coalesce(code, ''))));

  select * into v_invite
    from public.firm_invites i
   where i.code_hash = v_code_hash
     and i.used_by is null
     and i.revoked = false
   for update;

  if not found then
    -- Non-exception return path: the attempt insert must commit.
    insert into public.invite_attempts (user_id) values (v_user_id);
    return jsonb_build_object('status', 'invalid_code');
  end if;

  v_used_at := (extract(epoch from clock_timestamp()) * 1000)::bigint;

  -- Single-use means single-use: a retry by someone already in the firm still
  -- consumes the code rather than leaving it redeemable for a stranger.
  if exists (
    select 1 from public.firm_members m
     where m.firm_id = v_invite.firm_id and m.user_id = v_user_id
  ) then
    update public.firm_invites i
       set used_by = v_user_id, used_at = v_used_at
     where i.id = v_invite.id;

    delete from public.invite_attempts a where a.user_id = v_user_id;

    return jsonb_build_object(
      'status', 'already_member',
      'firm_id', v_invite.firm_id
    );
  end if;

  insert into public.firm_members (
    firm_id, user_id, role, can_add, can_edit, can_delete
  )
  values (v_invite.firm_id, v_user_id, 'associate', true, false, false);

  update public.profiles p
     set firm_id = v_invite.firm_id,
         role = 'associate'
   where p.id = v_user_id;

  update public.firm_invites i
     set used_by = v_user_id, used_at = v_used_at
   where i.id = v_invite.id;

  delete from public.invite_attempts a where a.user_id = v_user_id;

  return jsonb_build_object(
    'status', 'joined',
    'firm_id', v_invite.firm_id
  );
end;
$$;

comment on function public.join_firm(text) is
  'Single-use invite redemption: rate limit, hash, membership, profile relink, invite consumed — one transaction.';

-- `anon` is named explicitly for the same reason as `approve_payment`: a direct
-- EXECUTE grant from Supabase's default privileges outlives a revoke of PUBLIC.
revoke all on function public.join_firm(text) from public, anon;
grant execute on function public.join_firm(text) to authenticated;
