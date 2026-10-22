-- ===========================================================================
-- Device limit — a session belongs to the install that created it.
--
-- The cap counts sessions, and until now a copied access token could be
-- replayed from a second phone: that phone presented a *known* session, was
-- re-registered as the same device, and the original row's `device_key` was
-- simply overwritten. One sign-in could therefore drive any number of installs.
--
-- **The binding.** Every install generates a 32-byte random secret once, keeps
-- it in this-device-only secure storage, and sends it as `x-install-secret` on
-- every Supabase request and as `p_install_secret` to `register_device`. The
-- server stores only `sha256(secret)`:
--
--   * a known session presented with a different secret answers
--     `session_in_use` — the app discards and wipes, it never revives;
--   * `replaced` (a re-login from the same phone) now needs the same
--     `device_key` **and** the same install secret, so a restored backup is a
--     new device, not the old one;
--   * `push_changes`, `touch_device` and `register_device` refuse a mismatched
--     install; reads decline only when a secret is present and wrong, because
--     Realtime does not reliably forward custom headers and must keep working.
--
-- **Known limits, accepted for an alpha tested by owner and family:**
--   * the *first* registration of a session binds the secret, so a clone that
--     connects before the real device after this migration wins that row;
--   * a full-device clone (token + secret) is indistinguishable from the
--     original. The connection does not bind to hardware.
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 1. The hash on the device row.
-- ---------------------------------------------------------------------------

alter table public.user_devices
  add column if not exists install_secret_hash text;

comment on column public.user_devices.install_secret_hash is
  'sha256 of the install secret that claimed this session; a request presenting a different secret is a clone. Null on rows written before the binding existed, which bind on their next registration.';

-- ---------------------------------------------------------------------------
-- 2. What secret did this request carry?
-- ---------------------------------------------------------------------------

create or replace function public.current_install_secret()
returns text
language plpgsql
stable
set search_path = pg_catalog, public
as $$
declare
  v_headers text := current_setting('request.headers', true);
  v_value text;
begin
  if v_headers is null or v_headers = '' then
    return null;
  end if;

  -- PostgREST builds this GUC as JSON; anything unreadable is treated as absent.
  begin
    v_value := v_headers::jsonb ->> 'x-install-secret';
  exception when others then
    return null;
  end;

  return nullif(pg_catalog.btrim(v_value), '');
end;
$$;

comment on function public.current_install_secret() is
  'The x-install-secret request header, or null when the caller sent none (psql, service role, a client without the header, Realtime).';

create or replace function public.current_install_hash()
returns text
language sql
stable
set search_path = pg_catalog, public, extensions
as $$
  select case
           when s is null then null
           else public.sha256_hex(s)
         end
    from (select public.current_install_secret() as s) q;
$$;

comment on function public.current_install_hash() is
  'sha256 of the caller''s install secret, or null when none was sent.';

revoke all on function public.current_install_secret() from public, anon;
revoke all on function public.current_install_hash() from public, anon;
grant execute on function public.current_install_secret() to authenticated, service_role;
grant execute on function public.current_install_hash() to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 3. Writes and reads: an active device on the right install.
-- ---------------------------------------------------------------------------

create or replace function public.device_may_push(p_at timestamptz default now())
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select public.current_session_id() is null
      or exists (
           select 1
             from public.user_devices d
            where d.user_id = auth.uid()
              and d.session_id = public.current_session_id()
              and d.revoked_at is null
              and (
                d.install_secret_hash is null
                or d.install_secret_hash = public.current_install_hash()
              )
         );
$$;

comment on function public.device_may_push(timestamptz) is
  'True for an active device whose install secret matches the row, or a caller with no session claim. A revoke, an unregistered session and a cloned session all fail closed.';

-- Reads keep a permissive fallback when no secret is present: Realtime does not
-- reliably carry custom headers, and its rows must still arrive. A present but
-- wrong secret is refused.
create or replace function public.device_may_read(p_at timestamptz default now())
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select public.current_session_id() is null
      or exists (
           select 1
             from public.user_devices d
            where d.user_id = auth.uid()
              and d.session_id = public.current_session_id()
              and d.revoked_at is null
              and (
                public.current_install_hash() is null
                or d.install_secret_hash is null
                or d.install_secret_hash = public.current_install_hash()
              )
         );
$$;

comment on function public.device_may_read(timestamptz) is
  'True for an active device. A present secret must match the row; with no secret (Realtime, older clients) reads stay open so real-time delivery does not break. Revoked and unregistered sessions read nothing either way.';

-- ---------------------------------------------------------------------------
-- 4. register_device: binding the session to the install.
-- ---------------------------------------------------------------------------

-- The old 3-argument form must go: leaving it would let a caller skip the
-- secret and keep the clone path open.
drop function if exists public.register_device(text, text, text);

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
       set device_key = v_key,
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
  'Claims a device slot for the caller''s session and binds it to the install secret (parameter or x-install-secret header): re-registering is idempotent, a different secret answers session_in_use, no secret at all answers invalid_install_secret, the same device key and secret replace their own row, a free slot is taken, and at the cap the least recently seen device is evicted only when idle 7+ days on a live plan; otherwise device_limit_reached with the list.';

revoke all on function public.register_device(text, text, text, text)
  from public, anon;
grant execute on function public.register_device(text, text, text, text)
  to authenticated;

-- ---------------------------------------------------------------------------
-- 5. The launch check reports the clone instead of "active".
-- ---------------------------------------------------------------------------

create or replace function public.device_state()
returns jsonb
language plpgsql
stable
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

  if v_session is null then
    return jsonb_build_object('status', 'unmanaged');
  end if;

  select * into v_row
    from public.user_devices d
   where d.user_id = v_user
     and d.session_id = v_session;

  if not found then
    return jsonb_build_object(
      'status', 'unregistered',
      'cap', coalesce(public.device_cap(v_user), 1)
    );
  end if;

  if v_row.revoked_at is not null then
    return jsonb_build_object(
      'status', 'revoked',
      'cap', coalesce(public.device_cap(v_user), 1),
      'reason', v_row.revoked_reason,
      'revoked_at', v_row.revoked_at,
      'flushed', v_row.flushed_at is not null,
      'device', jsonb_build_object('id', v_row.id, 'label', v_row.label)
    );
  end if;

  if v_row.install_secret_hash is not null
     and v_row.install_secret_hash is distinct from public.current_install_hash() then
    return jsonb_build_object(
      'status', 'session_in_use',
      'cap', coalesce(public.device_cap(v_user), 1),
      'reason', 'session_in_use'
    );
  end if;

  return jsonb_build_object(
    'status', 'active',
    'cap', coalesce(public.device_cap(v_user), 1),
    'device', jsonb_build_object('id', v_row.id, 'label', v_row.label),
    'devices', public.device_list(v_user)
  );
end;
$$;

comment on function public.device_state() is
  'The launch check: active, revoked (with its reason), session_in_use for a cloned session, or unregistered, plus the cap and the device list.';

-- ---------------------------------------------------------------------------
-- 6. The heartbeat only counts contact from the bound install.
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
     and d.revoked_at is null
     and (
       d.install_secret_hash is null
       or d.install_secret_hash = public.current_install_hash()
     );

  get diagnostics v_count = row_count;
  if v_count = 0 then
    return jsonb_build_object('status', 'not_active');
  end if;

  return jsonb_build_object('status', 'ok');
end;
$$;

comment on function public.touch_device() is
  'Marks the caller''s active device as used when its install secret matches, so neither a revoked session nor a clone can keep a slot warm.';
