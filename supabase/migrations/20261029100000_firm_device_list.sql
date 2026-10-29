-- The chamber owner can see every device sharing the firm's slots.
--
-- The gap this closes: `device_state()` answers for the caller's own session,
-- so an owner's Devices screen could only ever list the owner's own phones. The
-- chamber's slots are shared (`associates + owner devices <= slots`), and the
-- other holders of those slots were invisible to the one person who manages
-- them. `user_devices` is server-managed and grants no read to any client role,
-- so this function is the only way the owner's screen can name who holds a
-- slot — the same reason `device_state()` exists for a single device.
--
-- Owner-only and read-only: an associate keeps `device_state()` (their own
-- sign-in), an individual gets `not_owner`, and nothing here writes. The names
-- come from `profiles` (the account's current name) with the registration
-- snapshot on the device row as the fallback, so a renamed account does not
-- read stale on the owner's screen; only a row whose profile still points at
-- this chamber is listed, which is what keeps a removed member's devices out.
--
-- Proven by `supabase/tests/firm_device_list_test.sql`.

create or replace function public.firm_device_list()
returns jsonb
language plpgsql
stable
security definer
set search_path = pg_catalog, public
as $$
declare
  v_user uuid := auth.uid();
  v_firm uuid := public.current_firm_id();
  v_owner uuid;
begin
  if v_user is null then
    return jsonb_build_object('status', 'unauthenticated');
  end if;

  select f.owner_id into v_owner
    from public.firms f
   where f.id = v_firm;

  if v_owner is distinct from v_user then
    return jsonb_build_object('status', 'not_owner');
  end if;

  return jsonb_build_object(
    'status', 'ok',
    'slots', public.firm_seat_cap(v_firm),
    -- The seat count the screen's shared-slots note reads, so it does not need
    -- the roster as well.
    'associates', (
      select count(*)::integer
        from public.firm_members m
       where m.firm_id = v_firm
         and m.user_id <> v_owner
    ),
    'devices', coalesce(
      (
        select jsonb_agg(
                 jsonb_build_object(
                   'id', d.id,
                   'label', d.label,
                   'platform', d.platform,
                   'last_seen_at', d.last_seen_at,
                   'is_current', d.session_id = public.current_session_id(),
                   'is_owner', d.user_id = v_owner,
                   'member_name', coalesce(
                     nullif(pg_catalog.btrim(p.full_name), ''),
                     nullif(pg_catalog.btrim(d.full_name), ''),
                     ''
                   )
                 )
                 -- The owner's own devices first, then the associates', each
                 -- group newest contact first: the order the two sections draw.
                 order by (d.user_id = v_owner) desc, d.last_seen_at desc
               )
          from public.user_devices d
          join public.profiles p
            on p.id = d.user_id
           and p.firm_id = v_firm
         where d.revoked_at is null
      ),
      '[]'::jsonb
    )
  );
end;
$$;

comment on function public.firm_device_list() is
  'The chamber owner''s whole device picture: active devices of the owner and of every associate whose profile still points at the chamber, each with its member name and is_owner, plus the chamber''s slots and associate count. Owner-only; a member or an individual reads not_owner.';

revoke all on function public.firm_device_list() from public, anon;
grant execute on function public.firm_device_list() to authenticated;
