-- ===========================================================================
-- Device limit (1/2) — the registry: one row per signed-in device.
--
-- **Why.** Every paid card promises a number of devices at the same time
-- (Starter 1, Pro 2, one per member on each chamber tier, the owner included),
-- and the app only *states* it: `payment_plans.dart` carries `deviceCap` with
-- the note "not enforced yet (user ruling, 2026-10-19)". This migration is the
-- server half: the cap per tier, the per-device rows, and the RPCs that claim,
-- list and release a slot. `20261022110000` is the enforcement half.
--
-- **Table class.** `user_devices` is **server-managed**: written only by the
-- RPCs below, never queued, never pulled into Drift. The client reads it
-- through `device_state()` and nothing else.
--
-- **What a device is.** Two keys, and only one of them is trusted:
--
--   * `session_id` — read from the access token (`auth.jwt() ->> 'session_id'`),
--     a claim Supabase documents as always present. Server-issued, one per
--     sign-in, unforgeable. **This is what the cap counts.**
--   * `device_key` — the phone's own stable id (Android SSAID) or a stored
--     install UUID elsewhere. Client-supplied, so it never grants anything; it
--     only lets a sign-out and back-in on the same phone reuse its own slot
--     instead of spending a second one.
--
-- **The four safety rules the user set (2026-10-21).** A device over the limit
-- is signed out and emptied, but (1) only after its unsent work has been handed
-- to the account, (2) never while the account has no live plan, because then
-- there is nowhere to hand it to, (3) an automatic eviction needs the spare to
-- have been idle at least seven days, and (4) a free account, which has no cloud
-- copy at all, is outside the limit.
--
-- **Rollout.** On the day the app updates, every install registers for the
-- first time. Refusing or evicting on that day would punish people for
-- updating, so registrations before `2026-11-21` that exceed the cap are
-- admitted and flagged `grandfathered`; the cap binds every device added after
-- the window. The same date gates unknown sessions in `20261022110000`.
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 1. The cap, per tier — one number, mirroring the client's `deviceCap`.
-- ---------------------------------------------------------------------------

create or replace function public.tier_device_cap(p_tier text)
returns integer
language sql
immutable
set search_path = pg_catalog, public
as $$
  select case p_tier
    when 'pro' then 2
    -- Starter, and every chamber tier, allow one device per person: the
    -- chamber cards say "one concurrent device each", the owner included.
    when 'starter' then 1
    when 'firm' then 1
    when 'firm_plus' then 1
    when 'enterprise' then 1
    -- Free is never synced, so its number only matters as a floor.
    else 1
  end;
$$;

comment on function public.tier_device_cap(text) is
  'Devices an account may sync at once: pro 2, every other tier 1. Mirrors SubscriptionTier.deviceCap in payment_plans.dart, pinned by a drift test.';

-- ---------------------------------------------------------------------------
-- 2. The session a request carries.
-- ---------------------------------------------------------------------------

-- Supabase puts `session_id` in every access token. Reading it here keeps the
-- cast in one place; a JWT always carries a UUID, so the cast is safe, and an
-- empty string is normalised to null rather than throwing.
create or replace function public.current_session_id()
returns uuid
language sql
stable
set search_path = pg_catalog, public
as $$
  select nullif(auth.jwt() ->> 'session_id', '')::uuid;
$$;

comment on function public.current_session_id() is
  'The auth.sessions id inside the caller''s access token; null for psql and service-role callers, which carry no JWT.';

-- The roll-out end, overridable by a server-side GUC so a proof can simulate
-- the day after it. A client cannot set a GUC through PostgREST, so this is a
-- test seam, not a client input.
create or replace function public.device_rollout_end()
returns timestamptz
language sql
stable
set search_path = pg_catalog, public
as $$
  select coalesce(
    nullif(current_setting('app.device_rollout_end', true), '')::timestamptz,
    timestamptz '2026-11-21 00:00:00+00'
  );
$$;

comment on function public.device_rollout_end() is
  'The instant after which a registration is no longer grandfathered. Overridable through app.device_rollout_end for proofs only.';

-- ---------------------------------------------------------------------------
-- 3. The registry.
-- ---------------------------------------------------------------------------

create table if not exists public.user_devices (
  id uuid primary key default gen_random_uuid(),
  -- Deleting the account takes its device rows with it, like its push tokens.
  user_id uuid not null references auth.users (id) on delete cascade,
  -- The sign-in this row belongs to. One session, one device.
  session_id uuid not null,
  -- The phone's own key: SSAID on Android, a stored install UUID elsewhere.
  device_key text not null,
  platform text not null default 'unknown',
  label text not null default '',
  created_at timestamptz not null default now(),
  -- Server-timed by the trigger below: a device's clock is not evidence.
  last_seen_at timestamptz not null default now(),
  revoked_at timestamptz,
  -- replaced (same phone signed in again), user, cap, lapse.
  revoked_reason text,
  -- Set when the device has handed over its unsent work and erased itself.
  flushed_at timestamptz,
  -- Admitted past the cap during the rollout window.
  grandfathered boolean not null default false,
  constraint user_devices_platform_check
    check (platform in ('android', 'ios', 'windows', 'unknown')),
  constraint user_devices_reason_check
    check (revoked_reason is null or revoked_reason in ('replaced', 'user', 'cap', 'lapse'))
);

comment on table public.user_devices is
  'One row per signed-in device: the session that counts toward the plan''s device cap, the device key that lets a re-login reuse its own slot, and the revocation the device erases itself under. Server-managed; read only through device_state().';

-- A session can only ever name one row.
create unique index if not exists user_devices_session_idx
  on public.user_devices (session_id);

-- One *active* row per device per account: signing in again on the same phone
-- replaces its own row instead of spending a second slot.
create unique index if not exists user_devices_active_device_idx
  on public.user_devices (user_id, device_key)
  where revoked_at is null;

-- The cap's own lookup: the active rows of one account.
create index if not exists user_devices_active_user_idx
  on public.user_devices (user_id)
  where revoked_at is null;

create or replace function public.touch_user_device()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
begin
  new.last_seen_at := now();
  return new;
end;
$$;

comment on function public.touch_user_device() is
  'Keeps user_devices.last_seen_at server-timed on every re-registration; the seven-day eviction floor reads it.';

drop trigger if exists trg_user_devices_touch on public.user_devices;
create trigger trg_user_devices_touch
before update on public.user_devices
for each row execute function public.touch_user_device();

-- RLS with no policy: the RPCs are SECURITY DEFINER and are the only readers
-- and writers. A client cannot list its own rows directly, which also keeps
-- session ids out of reach.
alter table public.user_devices enable row level security;

revoke all on table public.user_devices from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 4. Push tokens learn which device they belong to.
-- ---------------------------------------------------------------------------

-- Without this a revocation cannot find the right token: `device_tokens` is
-- keyed by the FCM token, which nothing links to a session. Rows written before
-- this column existed stay unmatched and are removed by that device's own
-- sign-out, which is the one path that can name them.
alter table public.device_tokens add column if not exists device_key text;

comment on column public.device_tokens.device_key is
  'The install key of the device holding this token, written with it, so a device revocation can delete exactly that device''s push registration.';

-- ---------------------------------------------------------------------------
-- 5. The caller's cap.
-- ---------------------------------------------------------------------------

-- A chamber member's allowance is one device, whatever the chamber's tier says:
-- the card reads "one concurrent device each". An individual reads their own
-- effective tier, so a queued change applies on its start date, not when it was
-- bought.
create or replace function public.device_cap(p_user_id uuid default auth.uid())
returns integer
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select case
           when p.firm_id is not null then 1
           else public.tier_device_cap(
             public.effective_tier(p.tier, p.tier_pending, p.tier_pending_from)
           )
         end
    from public.profiles p
   where p.id = p_user_id;
$$;

comment on function public.device_cap(uuid) is
  'The caller''s concurrent-device allowance: 1 while they hold a chamber (member or owner), otherwise the effective tier''s cap. Null when there is no profile.';

-- ---------------------------------------------------------------------------
-- 6. Is this session a registered, active device?
-- ---------------------------------------------------------------------------

-- Null sessions are the trusted paths — psql, the service role, an admin RPC —
-- and are always allowed. A client always carries a session.
create or replace function public.device_is_active(
  p_user_id uuid default auth.uid(),
  p_session_id uuid default public.current_session_id()
)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select p_session_id is null
      or exists (
           select 1
             from public.user_devices d
            where d.user_id = p_user_id
              and d.session_id = p_session_id
              and d.revoked_at is null
         );
$$;

comment on function public.device_is_active(uuid, uuid) is
  'True when the caller''s session holds an active device row, or when the caller carries no session at all (psql, service role).';

-- ---------------------------------------------------------------------------
-- 7. The ceiling may have fallen since the devices registered.
-- ---------------------------------------------------------------------------

-- A downgrade, or a lapse and renewal, can leave more active rows than the cap.
-- The surplus is revoked as `lapse`, least recently seen first, never the
-- caller: the phone in hand keeps working (user ruling). Nothing is revoked
-- while the account has no live plan, because a revoked device with nowhere to
-- hand its work must not erase.
create or replace function public.device_trim_surplus(
  p_user_id uuid,
  p_session_id uuid,
  p_cap integer
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_ids uuid[];
  v_keys text[];
begin
  if not public.has_sync_entitlement(p_user_id) then
    return;
  end if;

  select array_agg(s.id), array_agg(s.device_key)
    into v_ids, v_keys
    from (
      select d.id, d.device_key
        from public.user_devices d
       where d.user_id = p_user_id
         and d.revoked_at is null
         and d.session_id is distinct from p_session_id
       order by d.last_seen_at desc
       offset greatest(p_cap - 1, 0)
    ) s;

  if v_ids is null then
    return;
  end if;

  update public.user_devices d
     set revoked_at = now(),
         revoked_reason = 'lapse'
   where d.id = any(v_ids);

  delete from public.device_tokens t
   where t.user_id = p_user_id
     and t.device_key = any(v_keys);
end;
$$;

comment on function public.device_trim_surplus(uuid, uuid, integer) is
  'Revokes the devices above the cap after the ceiling falls (downgrade, lapse and renewal), least recently seen first and never the caller, and only while the account has a live plan.';

-- ---------------------------------------------------------------------------
-- 8. The decision table: registering a device.
-- ---------------------------------------------------------------------------

-- Returns one of:
--   {"status":"ok",            "cap":n, "device":{...}, "evicted":{...}|null}
--   {"status":"device_limit_reached", "cap":n, "devices":[...]}
--   {"status":"revoked",       "cap":n, "reason":"cap"|"user"|"replaced"|"lapse"}
--   {"status":"unauthenticated"}
--
-- `devices` names every active device with when it was last seen, so the client
-- can show the lawyer what is holding the slots.
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
  -- Registrations before `device_rollout_end()` never refuse or evict: the
  -- update itself must not strand anyone. The cap binds every device added
  -- afterwards.
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
  v_devices jsonb;
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
      -- It has been revoked: the client must flush and erase, never revive.
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
      'device', jsonb_build_object('id', v_row.id, 'label', v_label)
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
      'device', jsonb_build_object('id', v_row.id, 'label', v_row.label)
    );
  end if;

  ---------------------------------------------------------------------------
  -- A new device: a free slot, or the eviction rules, or a refusal.
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
      'device', jsonb_build_object('id', v_row.id, 'label', v_row.label)
    );
  end if;

  -- The rollout window: admit, flag, evict nobody.
  if v_now < public.device_rollout_end() then
    insert into public.user_devices (
      user_id, session_id, device_key, platform, label, grandfathered
    )
    values (v_user, v_session, v_key, v_platform, v_label, true)
    returning * into v_row;

    return jsonb_build_object(
      'status', 'ok',
      'cap', v_cap,
      'evicted', null,
      'device', jsonb_build_object('id', v_row.id, 'label', v_label)
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

  -- Rule 1 starts here: it is revoked now, but it may still push its unsent
  -- work for the flush window, and only then erases.
  update public.user_devices d
     set revoked_at = v_now,
         revoked_reason = 'cap'
   where d.id = v_evicted.id;

  -- Its push registration goes with it, in the same transaction (the rule
  -- `remove_firm_member` already applies to a removed member's devices).
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
  'Claims a device slot for the caller''s session: re-registering is idempotent, the same device key replaces its own row, a free slot is taken, and at the cap the least recently seen device is evicted only when it has been idle 7+ days and the account has a live plan; otherwise the call answers device_limit_reached with the list.';

-- ---------------------------------------------------------------------------
-- 8. The device list, shared by register_device and device_state.
-- ---------------------------------------------------------------------------

create or replace function public.device_list(p_user_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', d.id,
        'label', d.label,
        'platform', d.platform,
        'last_seen_at', d.last_seen_at,
        'is_current', d.session_id = public.current_session_id()
      )
      order by d.last_seen_at desc
    ),
    '[]'::jsonb
  )
  from public.user_devices d
  where d.user_id = p_user_id
    and d.revoked_at is null;
$$;

comment on function public.device_list(uuid) is
  'The account''s active devices, newest contact first, each marked is_current for the caller''s session.';

-- ---------------------------------------------------------------------------
-- 9. What this device is: active, revoked, or never registered.
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

  return jsonb_build_object(
    'status', 'active',
    'cap', coalesce(public.device_cap(v_user), 1),
    'device', jsonb_build_object('id', v_row.id, 'label', v_row.label),
    'devices', public.device_list(v_user)
  );
end;
$$;

comment on function public.device_state() is
  'The launch check: active, revoked (with its reason) or unregistered, plus the cap and the device list.';

-- ---------------------------------------------------------------------------
-- 10. The lawyer frees a slot themselves.
-- ---------------------------------------------------------------------------

create or replace function public.revoke_device(p_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_user uuid := auth.uid();
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

  if v_row.session_id = public.current_session_id() then
    -- A device removing itself is a sign-out, not a slot to free.
    return jsonb_build_object('status', 'is_current');
  end if;

  update public.user_devices d
     set revoked_at = now(),
         revoked_reason = 'user'
   where d.id = v_row.id;

  delete from public.device_tokens t
   where t.user_id = v_user
     and t.device_key = v_row.device_key;

  return jsonb_build_object('status', 'revoked', 'id', v_row.id);
end;
$$;

comment on function public.revoke_device(uuid) is
  'Frees one of the caller''s own device slots. The revoked device flushes its unsent work and erases at its next contact; a device cannot revoke itself.';

-- ---------------------------------------------------------------------------
-- 11. The revoked device reports that it has handed over its work and erased.
-- ---------------------------------------------------------------------------

create or replace function public.ack_device_wipe(p_device_key text default null)
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

  update public.user_devices d
     set flushed_at = now()
   where d.user_id = v_user
     and d.revoked_at is not null
     and d.flushed_at is null
     and (
       (v_session is not null and d.session_id = v_session)
       or (p_device_key is not null and d.device_key = p_device_key)
     );

  get diagnostics v_count = row_count;
  return jsonb_build_object('status', 'ok', 'flushed', v_count);
end;
$$;

comment on function public.ack_device_wipe(text) is
  'Records that a revoked device has flushed its unsent work and erased itself, so the eviction is auditable rather than assumed.';

-- ---------------------------------------------------------------------------
-- 12. Grants: the RPCs are the whole surface.
-- ---------------------------------------------------------------------------

revoke all on function public.register_device(text, text, text) from public, anon;
revoke all on function public.revoke_device(uuid) from public, anon;
revoke all on function public.device_state() from public, anon;
revoke all on function public.ack_device_wipe(text) from public, anon;

grant execute on function public.register_device(text, text, text) to authenticated;
grant execute on function public.revoke_device(uuid) to authenticated;
grant execute on function public.device_state() to authenticated;
grant execute on function public.ack_device_wipe(text) to authenticated;
