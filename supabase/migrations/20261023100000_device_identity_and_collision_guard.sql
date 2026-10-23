-- ===========================================================================
-- Device registry — who the device belongs to, and a collision that failed hard.
--
-- **The defect.** `device_info_plus`'s Android `id` is the *build ID*, not the
-- SSAID, and two identical phones on the same firmware report the same value.
-- Two Redmi Note 10 Pro handsets therefore presented `SKQ1.210908.001`. The
-- second one could not insert its active row past
-- `user_devices_active_device_idx`, so `register_device` raised 23505 and the
-- client saw a failed check: no sync, sign-out appeared to fail, and the device
-- list stayed incomplete. The client now uses a persisted per-install UUID; this
-- migration makes the server safe for old keys too.
--
-- **What changes here.**
--   * `full_name` and `email` are copied onto every device row at registration,
--     so support can identify the person without joining `profiles`.
--   * a key that an **active** row already holds is answered with
--     `device_limit_reached` instead of a unique-violation error; the existing
--     device keeps working and the new sign-in can free that slot from the
--     window like any other full plan;
--   * re-registering a known session no longer rewrites `device_key` to a key
--     another active row holds — the row keeps its own key and still returns ok.
--
-- **Table class.** `user_devices` stays server-managed; the trigger and the
-- RPCs are the only writers.
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 1. Who the device belongs to.
-- ---------------------------------------------------------------------------

alter table public.user_devices
  add column if not exists full_name text not null default '',
  add column if not exists email text not null default '';

comment on column public.user_devices.full_name is
  'The account holder''s display name when this device registered; copied from profiles for support.';
comment on column public.user_devices.email is
  'The account holder''s login e-mail when this device registered; copied from profiles for support.';

-- Existing rows, revoked ones included, get the identity they already point at.
update public.user_devices d
   set full_name = p.full_name,
       email = p.email
  from public.profiles p
 where p.id = d.user_id
   and (d.full_name = '' or d.email = '');

-- A snapshot at registration, not a live join: a later rename or e-mail change
-- does not rewrite history, and the hourly heartbeat never pays for a profile
-- lookup.
create or replace function public.fill_device_party_identity()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  select p.full_name, p.email
    into new.full_name, new.email
    from public.profiles p
   where p.id = new.user_id;

  if not found then
    new.full_name := '';
    new.email := '';
  end if;

  return new;
end;
$$;

comment on function public.fill_device_party_identity() is
  'Copies the account holder''s profile name and e-mail onto a new user_devices row.';

drop trigger if exists trg_user_devices_party_identity on public.user_devices;
create trigger trg_user_devices_party_identity
  before insert on public.user_devices
  for each row
  execute function public.fill_device_party_identity();

-- ---------------------------------------------------------------------------
-- 2. register_device: refuse a key collision instead of raising 23505.
-- ---------------------------------------------------------------------------

create or replace function public.register_device(
  p_device_key text,
  p_platform text default 'unknown',
  p_label text default '',
  p_install_secret text default null
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  -- The user's own ruling: only a spare this idle may be evicted automatically.
  c_evict_after constant interval := interval '7 days';

  v_user uuid := auth.uid();
  v_session uuid := public.current_session_id();
  v_now timestamptz := now();
  v_cap integer;
  v_key text := pg_catalog.btrim(coalesce(p_device_key, ''));
  v_platform text := case
                       when p_platform in ('android', 'ios', 'windows') then p_platform
                       else 'unknown'
                     end;
  v_label text := left(pg_catalog.btrim(coalesce(p_label, '')), 120);
  -- The body parameter is the documented channel; the header is the one every
  -- client sends, so either can bind. A caller with neither has no install to
  -- bind and is refused below.
  v_secret text := coalesce(
    nullif(pg_catalog.btrim(coalesce(p_install_secret, '')), ''),
    public.current_install_secret()
  );
  v_hash text := case
                   when v_secret is null then null
                   else public.sha256_hex(v_secret)
                 end;
  v_row public.user_devices%rowtype;
  v_evicted public.user_devices%rowtype;
  v_active integer;
begin
  if v_user is null then
    return jsonb_build_object('status', 'unauthenticated');
  end if;

  -- A caller with no session (psql, service role) has nothing to register.
  if v_session is null then
    return jsonb_build_object('status', 'unmanaged');
  end if;

  if v_key = '' then
    return jsonb_build_object('status', 'invalid_device_key');
  end if;

  if v_hash is null then
    return jsonb_build_object('status', 'invalid_install_secret');
  end if;

  v_cap := coalesce(public.device_cap(v_user), 1);

  -- Serialise two devices racing for the last slot: without it both could read
  -- "one free" and both insert.
  perform pg_advisory_xact_lock(hashtext('user_devices:' || v_user::text));

  -- The ceiling may have fallen since these rows were written. A revoked caller
  -- is skipped: it cannot take a slot, so trimming for it would be unfair.
  if not exists (
    select 1
      from public.user_devices d
     where d.session_id = v_session
       and d.revoked_at is not null
  ) then
    perform public.device_trim_surplus(v_user, v_session, v_cap);
  end if;

  ---------------------------------------------------------------------------
  -- This session is already known.
  ---------------------------------------------------------------------------
  select * into v_row
    from public.user_devices d
   where d.session_id = v_session
     and d.user_id = v_user;

  if found then
    if v_row.revoked_at is not null then
      -- It has been revoked: the client must wipe and sign out, never revive.
      return jsonb_build_object(
        'status', 'revoked',
        'cap', v_cap,
        'reason', v_row.revoked_reason
      );
    end if;

    -- A different install presenting this session's token is a clone. The row
    -- is left untouched, so the real device keeps its slot.
    if v_row.install_secret_hash is not null
       and v_row.install_secret_hash is distinct from v_hash then
      return jsonb_build_object(
        'status', 'session_in_use',
        'cap', v_cap,
        'reason', 'session_in_use'
      );
    end if;

    update public.user_devices d
       set device_key = case
             -- Never steal a key from another active row: the unique index
             -- would fail the whole registration. The session is what counts;
             -- this row keeps its own key and stays active.
             when exists (
               select 1
                 from public.user_devices x
                where x.user_id = v_user
                  and x.device_key = v_key
                  and x.revoked_at is null
                  and x.id <> v_row.id
             ) then d.device_key
             else v_key
           end,
           platform = v_platform,
           label = v_label,
           -- Rows written before the binding existed bind on first contact.
           install_secret_hash = coalesce(d.install_secret_hash, v_hash)
     where d.id = v_row.id;

    return jsonb_build_object(
      'status', 'ok',
      'cap', v_cap,
      'evicted', null,
      'device', jsonb_build_object('id', v_row.id, 'label', v_label),
      'devices', public.device_list(v_user)
    );
  end if;

  ---------------------------------------------------------------------------
  -- The same phone, a different session: it replaces its own row.
  --
  -- "Same phone" now means the same device key *and* the same install secret:
  -- a restored backup carries the key but not the this-device-only secret, so
  -- it is treated as a new device rather than as the old one.
  ---------------------------------------------------------------------------
  select * into v_row
    from public.user_devices d
   where d.user_id = v_user
     and d.device_key = v_key
     and d.revoked_at is null
     and (d.install_secret_hash is null or d.install_secret_hash = v_hash)
     for update;

  if found then
    update public.user_devices d
       set revoked_at = v_now,
           revoked_reason = 'replaced',
           flushed_at = v_now
     where d.id = v_row.id;

    insert into public.user_devices (
      user_id, session_id, device_key, platform, label, install_secret_hash
    )
    values (v_user, v_session, v_key, v_platform, v_label, v_hash)
    returning * into v_row;

    return jsonb_build_object(
      'status', 'ok',
      'cap', v_cap,
      'evicted', null,
      'device', jsonb_build_object('id', v_row.id, 'label', v_row.label),
      'devices', public.device_list(v_user)
    );
  end if;

  ---------------------------------------------------------------------------
  -- The key is held by another active device. That is two different installs
  -- presenting one key (an old build-ID client, or a clone), never the same
  -- phone: the same-phone branch above would have taken it. The unique index
  -- allows one active row per key, so the only safe answer is the plan-full one
  -- — the existing device keeps working and the new sign-in can free its slot
  -- from the window. Returning this instead of inserting is what stops the
  -- 23505 that broke sync and sign-out.
  ---------------------------------------------------------------------------
  if exists (
    select 1
      from public.user_devices d
     where d.user_id = v_user
       and d.device_key = v_key
       and d.revoked_at is null
  ) then
    return jsonb_build_object(
      'status', 'device_limit_reached',
      'cap', v_cap,
      'devices', public.device_list(v_user)
    );
  end if;

  ---------------------------------------------------------------------------
  -- A new device: a free slot, the idle-spare eviction, or a refusal.
  ---------------------------------------------------------------------------
  select count(*) into v_active
    from public.user_devices d
   where d.user_id = v_user
     and d.revoked_at is null;

  if v_active < v_cap then
    insert into public.user_devices (
      user_id, session_id, device_key, platform, label, install_secret_hash
    )
    values (v_user, v_session, v_key, v_platform, v_label, v_hash)
    returning * into v_row;

    return jsonb_build_object(
      'status', 'ok',
      'cap', v_cap,
      'evicted', null,
      'device', jsonb_build_object('id', v_row.id, 'label', v_label),
      'devices', public.device_list(v_user)
    );
  end if;

  -- The least recently seen device, under a row lock so two registrations
  -- cannot evict the same one.
  select * into v_evicted
    from public.user_devices d
   where d.user_id = v_user
     and d.revoked_at is null
   order by d.last_seen_at asc, d.created_at asc
   limit 1
   for update;

  -- Rule 2: with no live plan the evicted device has nowhere to hand its work,
  -- so nothing is evicted and the new device is refused instead.
  if not public.has_sync_entitlement(v_user) then
    return jsonb_build_object(
      'status', 'device_limit_reached',
      'cap', v_cap,
      'devices', public.device_list(v_user)
    );
  end if;

  -- Rule 3: only a device idle for a week may be evicted automatically.
  if v_evicted.id is null
     or v_evicted.last_seen_at > v_now - c_evict_after then
    return jsonb_build_object(
      'status', 'device_limit_reached',
      'cap', v_cap,
      'devices', public.device_list(v_user)
    );
  end if;

  -- Rule 1: the device is signed out now; it discards and wipes at its next
  -- contact. There is no save-then-erase flush.
  update public.user_devices d
     set revoked_at = v_now,
         revoked_reason = 'cap'
   where d.id = v_evicted.id;

  -- Its push registration goes with it, in the same transaction.
  delete from public.device_tokens t
   where t.user_id = v_user
     and t.device_key = v_evicted.device_key;

  insert into public.user_devices (
    user_id, session_id, device_key, platform, label, install_secret_hash
  )
  values (v_user, v_session, v_key, v_platform, v_label, v_hash)
  returning * into v_row;

  return jsonb_build_object(
    'status', 'ok',
    'cap', v_cap,
    'device', jsonb_build_object('id', v_row.id, 'label', v_row.label),
    'devices', public.device_list(v_user),
    'evicted', jsonb_build_object(
      'id', v_evicted.id,
      'label', v_evicted.label,
      'platform', v_evicted.platform,
      'last_seen_at', v_evicted.last_seen_at
    )
  );
end;
$$;

comment on function public.register_device(text, text, text, text) is
  'Claims a device slot for the caller''s session and binds it to the install secret: a different secret answers session_in_use, no secret answers invalid_install_secret, a key held by another active device answers device_limit_reached instead of failing the unique index, the same device key and secret replace their own row, and at the cap the least recently seen device is evicted only when idle 7+ days on a live plan. Every success carries the active-device list.';
