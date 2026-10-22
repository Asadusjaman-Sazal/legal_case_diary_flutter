-- ===========================================================================
-- Device limit — the grace period is closed.
--
-- The roll-out exemption was written for a public update: it let a third
-- device register as `grandfathered`, and let a session that had never
-- registered read and push, until 2026-11-21. This app is in active
-- development, currently alpha, tested only by the owner and family, so the
-- exemption protects nobody and is removed here.
--
-- After this migration:
--   * the cap is hard — a third device at the cap is refused unless a device
--     idle for seven days may be evicted (that rule stays);
--   * an unregistered session reads and pushes nothing;
--   * a revoked device reads and pushes nothing — the 14-day flush window is
--     gone, because every removal now discards rather than saves;
--   * `signed_out` is a distinct revocation reason for the third-device window;
--   * `touch_device()` lets the app mark real use on resume/sync so the idle
--     rule does not mistake a running app for an unused one;
--   * every successful `register_device` returns the active-device list, which
--     fixes the empty Manage Account → Devices screen.
--
-- The `grandfathered` flag is kept as history but no longer set; active rows
-- are cleared and surplus rows are revoked in the one-time cleanup below.
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 1. Reads and writes: an active device only.
-- ---------------------------------------------------------------------------

create or replace function public.device_may_push(p_at timestamptz default now())
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select public.current_session_id() is null
      or public.device_is_active();
$$;

comment on function public.device_may_push(timestamptz) is
  'True for an active device or a caller with no session claim. A revoked device cannot push, even immediately after revocation; a device that never registered cannot push either.';

create or replace function public.device_may_read(p_at timestamptz default now())
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select public.current_session_id() is null
      or public.device_is_active();
$$;

comment on function public.device_may_read(timestamptz) is
  'True for an active device or a caller with no session claim. A revoked or never-registered session reads nothing.';

-- ---------------------------------------------------------------------------
-- 2. The new revocation reason.
-- ---------------------------------------------------------------------------

alter table public.user_devices
  drop constraint if exists user_devices_reason_check;
alter table public.user_devices
  add constraint user_devices_reason_check
  check (
    revoked_reason is null
    or revoked_reason in ('replaced', 'user', 'cap', 'lapse', 'signed_out')
  );

-- ---------------------------------------------------------------------------
-- 3. register_device: no grandfather; every success carries the device list.
-- ---------------------------------------------------------------------------

create or replace function public.register_device(
  p_device_key text,
  p_platform text default 'unknown',
  p_label text default ''
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

    update public.user_devices d
       set device_key = v_key,
           platform = v_platform,
           label = v_label
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
  ---------------------------------------------------------------------------
  select * into v_row
    from public.user_devices d
   where d.user_id = v_user
     and d.device_key = v_key
     and d.revoked_at is null
     for update;

  if found then
    update public.user_devices d
       set revoked_at = v_now,
           revoked_reason = 'replaced',
           flushed_at = v_now
     where d.id = v_row.id;

    insert into public.user_devices (user_id, session_id, device_key, platform, label)
    values (v_user, v_session, v_key, v_platform, v_label)
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
  -- A new device: a free slot, the idle-spare eviction, or a refusal.
  ---------------------------------------------------------------------------
  select count(*) into v_active
    from public.user_devices d
   where d.user_id = v_user
     and d.revoked_at is null;

  if v_active < v_cap then
    insert into public.user_devices (user_id, session_id, device_key, platform, label)
    values (v_user, v_session, v_key, v_platform, v_label)
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
  -- contact. There is no save-then-erase flush after this migration.
  update public.user_devices d
     set revoked_at = v_now,
         revoked_reason = 'cap'
   where d.id = v_evicted.id;

  -- Its push registration goes with it, in the same transaction.
  delete from public.device_tokens t
   where t.user_id = v_user
     and t.device_key = v_evicted.device_key;

  insert into public.user_devices (user_id, session_id, device_key, platform, label)
  values (v_user, v_session, v_key, v_platform, v_label)
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

comment on function public.register_device(text, text, text) is
  'Claims a device slot for the caller''s session: re-registering is idempotent, the same device key replaces its own row, a free slot is taken, and at the cap the least recently seen device is evicted only when it has been idle 7+ days and the account has a live plan; otherwise the call answers device_limit_reached with the list. Every success carries the active-device list.';

-- ---------------------------------------------------------------------------
-- 4. Explicit sign-out from the third-device window.
-- ---------------------------------------------------------------------------

create or replace function public.sign_out_device(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_user uuid := auth.uid();
  v_session uuid := public.current_session_id();
  v_row public.user_devices%rowtype;
begin
  if v_user is null then
    return jsonb_build_object('status', 'unauthenticated');
  end if;

  select * into v_row
    from public.user_devices d
   where d.id = p_id
     and d.user_id = v_user
     for update;

  if not found then
    return jsonb_build_object('status', 'not_found');
  end if;

  if v_row.revoked_at is not null then
    return jsonb_build_object('status', 'already_revoked');
  end if;

  if v_row.session_id = v_session then
    -- A device removing itself is a sign-out, not a slot to free.
    return jsonb_build_object('status', 'is_current');
  end if;

  update public.user_devices d
     set revoked_at = now(),
         revoked_reason = 'signed_out'
   where d.id = v_row.id;

  delete from public.device_tokens t
   where t.user_id = v_user
     and t.device_key = v_row.device_key;

  return jsonb_build_object('status', 'revoked', 'id', v_row.id, 'reason', 'signed_out');
end;
$$;

comment on function public.sign_out_device(uuid) is
  'Signs out one of the caller''s other devices with reason signed_out. The device discards its unsynced work and wipes at its next contact; a device cannot sign itself out this way.';

-- ---------------------------------------------------------------------------
-- 5. Real-use heartbeat.
-- ---------------------------------------------------------------------------

create or replace function public.touch_device()
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_user uuid := auth.uid();
  v_session uuid := public.current_session_id();
  v_count integer;
begin
  if v_user is null then
    return jsonb_build_object('status', 'unauthenticated');
  end if;

  if v_session is null then
    return jsonb_build_object('status', 'unmanaged');
  end if;

  update public.user_devices d
     set last_seen_at = now()
   where d.user_id = v_user
     and d.session_id = v_session
     and d.revoked_at is null;

  get diagnostics v_count = row_count;
  if v_count = 0 then
    return jsonb_build_object('status', 'not_active');
  end if;

  return jsonb_build_object('status', 'ok');
end;
$$;

comment on function public.touch_device() is
  'Marks the caller''s active device as used, so the seven-day idle rule measures real contact rather than app launches. A revoked or unregistered session updates nothing.';

-- ---------------------------------------------------------------------------
-- 6. One-time cleanup: no one stays over the cap, and no stale flag remains.
-- ---------------------------------------------------------------------------

do $$
declare
  r record;
begin
  for r in
    select ranked.id, ranked.user_id, ranked.device_key
      from (
        select d.id,
               d.user_id,
               d.device_key,
               row_number() over (
                 partition by d.user_id
                 order by d.last_seen_at desc, d.created_at desc
               ) as rn,
               coalesce(public.device_cap(d.user_id), 1) as cap
          from public.user_devices d
         where d.revoked_at is null
      ) ranked
     where ranked.rn > ranked.cap
       and public.has_sync_entitlement(ranked.user_id)
  loop
    update public.user_devices
       set revoked_at = now(),
           revoked_reason = 'cap'
     where id = r.id;

    delete from public.device_tokens
     where user_id = r.user_id
       and device_key = r.device_key;
  end loop;
end;
$$;

-- The grace flag is no longer set anywhere; clear it from every row.
update public.user_devices
   set grandfathered = false
 where grandfathered;

-- ---------------------------------------------------------------------------
-- 7. The roll-out seam is gone.
-- ---------------------------------------------------------------------------

drop function if exists public.device_rollout_end();

-- ---------------------------------------------------------------------------
-- 8. Grants for the new RPCs.
-- ---------------------------------------------------------------------------

revoke all on function public.sign_out_device(uuid) from public, anon;
revoke all on function public.touch_device() from public, anon;

grant execute on function public.sign_out_device(uuid) to authenticated;
grant execute on function public.touch_device() to authenticated;
