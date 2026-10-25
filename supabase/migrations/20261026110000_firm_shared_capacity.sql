-- ===========================================================================
-- 2026-10-26 — Chamber capacity is shared between associates and the owner's
-- own devices.
--
-- **Why.** The tier's slots (Firm 5, Firm Plus 10, Enterprise 20, owner
-- included) only bound new joins, and every chamber account was held to one
-- device. An owner could therefore never use more than one device of the
-- capacity they paid for, and a downgrade never signed anybody out. The user's
-- ruling: a chamber has `S` slots; each associate uses one, and the owner's
-- active devices use the rest. `associates + owner devices <= S`, with the
-- owner's first device always reserved.
--
-- **The model, in one place:**
--
--   a = non-owner firm_members rows (seated and signed-out)
--   d = the owner's active user_devices
--   join:   a + max(d, 1) + 1 <= S
--   admit:  seated + max(d, 1) + 1 <= S
--   trim:   d -> max(1, S - a);  seated -> min(a, S - 1)
--   owner device cap = max(1, S - a)
--
-- Signed-out members keep their membership and their seats; only an owner
-- removal frees a slot. A member signed out for capacity can sign in again only
-- after being admitted by the owner.
--
-- **When capacity shrinks.** Only after a queued downgrade has started. The
-- payment migration (`20261026100000`) starts a lower tier 48h after the period
-- it replaces ends. `rebalance_firm_capacity` then trims the owner's extra
-- devices first (least recently seen) and the newest associates next. A legacy
-- over-roster chamber with no pending downgrade is never mass-signed-out; the
-- owner trims it from the roster card.
--
-- **Lock order (documented once):** `firm_capacity:<firm id>` first, then the
-- invite row / the per-user device lock / the membership row. `join_firm` reads
-- the invite once to learn the firm, takes the capacity lock, then re-reads the
-- invite `for update`; locking the invite first would deadlock against
-- `dissolve_firm`, which holds the capacity lock while it updates invites.
--
-- **Revocation reasons.** `capacity` (a signed-out associate or a trimmed owner
-- device) and `removed` (the owner removed the account). `lapse` is not reused:
-- its client copy is built around a device-cap number.
--
-- **No deploy-time sweep.** The cron only acts on firms whose lower-tier pending
-- change has started; a legacy over-roster is the owner's to trim. A device that
-- registers also rebalances lazily, so a shrink is enforced on first contact
-- even if the cron is late.
--
-- Requires `20261026100000_payment_downgrade_after_grace.sql` (it defines
-- `tier_seat_cap` and the grace-aware pending start).
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 1. Schema: join order, the signed-out marker, and the orphan cleanup.
-- ---------------------------------------------------------------------------

alter table public.firm_members
  add column if not exists joined_at timestamptz not null default now(),
  add column if not exists capacity_signed_out_at timestamptz;

comment on column public.firm_members.joined_at is
  'When this membership began, used to choose the newest associates when a shrink has to sign people out. Backfilled approximately from the permission stamps for rows that predate it.';
comment on column public.firm_members.capacity_signed_out_at is
  'Null while the associate is seated. Set when the owner or the capacity trim signs their devices out; the membership and its seat remain until the owner removes them.';

-- Existing rows: the oldest permission stamp is the best join time the cache
-- has. The order is approximate, and the trim breaks ties on id.
update public.firm_members m
   set joined_at = case
     when coalesce(m.synced_at, 0) > 0 and coalesce(m.permissions_synced_at, 0) > 0
       then to_timestamp(
         (least(m.synced_at, m.permissions_synced_at) / 1000.0)::double precision
       )
     when coalesce(m.synced_at, 0) > 0
       then to_timestamp((m.synced_at / 1000.0)::double precision)
     when coalesce(m.permissions_synced_at, 0) > 0
       then to_timestamp((m.permissions_synced_at / 1000.0)::double precision)
     else m.joined_at
   end;

-- The old join path did not check `profiles.firm_id`, so a member of one
-- chamber could redeem another chamber's code and leave a row behind in the
-- first. That row grants nothing (every read is scoped by the profile) but it
-- would hold a seat forever. Delete those rows; never the owner's own row.
do $$
declare
  v_count integer;
begin
  delete from public.firm_members m
   using public.firms f
   where f.id = m.firm_id
     and m.user_id <> f.owner_id
     and not exists (
       select 1
         from public.profiles p
        where p.id = m.user_id
          and p.firm_id = m.firm_id
     );
  get diagnostics v_count = row_count;
  raise notice 'orphaned firm_members rows removed: %', v_count;
end;
$$;

-- Two reasons the client words differently: a member signed out for capacity
-- stays in the firm, while a removed account is gone.
alter table public.user_devices
  drop constraint if exists user_devices_reason_check;
alter table public.user_devices
  add constraint user_devices_reason_check
  check (
    revoked_reason is null
    or revoked_reason in (
      'replaced', 'user', 'cap', 'lapse', 'signed_out', 'capacity', 'removed'
    )
  );

-- ---------------------------------------------------------------------------
-- 2. Close the direct-write bypass on `firm_members`.
-- ---------------------------------------------------------------------------
--
-- Supabase's default privileges give `authenticated` table-level INSERT/UPDATE/
-- DELETE on every public table, and the owner policies then accept any row of
-- the caller's firm. That let an owner insert a seat without `join_firm`, delete
-- one without the RPC, and — after this migration — write the signed-out marker.
-- The app only ever updates the four permission columns, so the grant is
-- narrowed to exactly those and every write path is the RPC.
revoke insert, delete, update on public.firm_members from authenticated, anon;
grant update (role, can_add, can_edit, can_delete) on public.firm_members to authenticated;

-- ---------------------------------------------------------------------------
-- 3. Capacity helpers. All internal: no client role may execute them.
-- ---------------------------------------------------------------------------

create or replace function public.firm_seat_cap(p_firm_id uuid)
returns integer
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select coalesce(
    (
      select public.tier_seat_cap(
        public.effective_tier(f.tier, f.tier_pending, f.tier_pending_from)
      )
        from public.firms f
       where f.id = p_firm_id
    ),
    0
  );
$$;

comment on function public.firm_seat_cap(uuid) is
  'Slots a chamber may hold, owner included: firm 5, firm_plus 10, enterprise 20, 0 for every other tier. Never null.';

create or replace function public.firm_associate_count(p_firm_id uuid)
returns integer
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select count(*)::integer
    from public.firm_members m
    join public.firms f
      on f.id = m.firm_id
    join public.profiles p
      on p.id = m.user_id
     and p.firm_id = m.firm_id
   where m.firm_id = p_firm_id
     and m.user_id <> f.owner_id;
$$;

comment on function public.firm_associate_count(uuid) is
  'Non-owner members of the chamber whose profile still points at it. An orphaned row (its profile moved to another chamber) never consumes a seat. Signed-out members count.';

create or replace function public.firm_seated_count(p_firm_id uuid)
returns integer
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select count(*)::integer
    from public.firm_members m
    join public.firms f
      on f.id = m.firm_id
    join public.profiles p
      on p.id = m.user_id
     and p.firm_id = m.firm_id
   where m.firm_id = p_firm_id
     and m.user_id <> f.owner_id
     and m.capacity_signed_out_at is null;
$$;

comment on function public.firm_seated_count(uuid) is
  'Associates of the chamber who are currently allowed a device (capacity_signed_out_at is null).';

create or replace function public.firm_owner_device_count(p_firm_id uuid)
returns integer
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select count(*)::integer
    from public.user_devices d
    join public.firms f
      on f.id = p_firm_id
   where d.user_id = f.owner_id
     and d.revoked_at is null;
$$;

comment on function public.firm_owner_device_count(uuid) is
  'The owner''s active devices, which share the chamber''s slots with its associates.';

create or replace function public.firm_capacity_frozen(p_firm_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select coalesce(
    (
      select f.subscription_expiry is null
          or f.subscription_expiry + interval '48 hours' <= now()
        from public.firms f
       where f.id = p_firm_id
    ),
    true
  );
$$;

comment on function public.firm_capacity_frozen(uuid) is
  'True once the chamber''s 48h grace has ended (or it never had a plan): no new associate may join.';

create or replace function public.firm_capacity_usage(p_firm_id uuid)
returns jsonb
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  with c as (
    select
      public.firm_seat_cap(p_firm_id) as slots,
      public.firm_associate_count(p_firm_id) as associates,
      public.firm_seated_count(p_firm_id) as seated,
      public.firm_owner_device_count(p_firm_id) as owner_devices
  )
  select jsonb_build_object(
    'slots', c.slots,
    'associates', c.associates,
    'seated', c.seated,
    'signed_out', c.associates - c.seated,
    'owner_devices', c.owner_devices,
    'owner_device_cap', greatest(1, c.slots - c.associates),
    'used', c.associates + c.owner_devices,
    'active', c.seated + c.owner_devices,
    'over', c.associates > c.slots - 1
            or c.associates + c.owner_devices > c.slots,
    'frozen', public.firm_capacity_frozen(p_firm_id)
  )
  from c;
$$;

comment on function public.firm_capacity_usage(uuid) is
  'One chamber''s capacity picture: slots, associates, seated/signed-out counts, owner devices, the owner device cap, committed and active usage, and whether it is over or frozen.';

create or replace function public.firm_capacity_needs_trim(p_firm_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select public.firm_owner_device_count(p_firm_id)
           > greatest(
               1,
               public.firm_seat_cap(p_firm_id) - public.firm_associate_count(p_firm_id)
             )
      or public.firm_seated_count(p_firm_id)
           > least(
               public.firm_associate_count(p_firm_id),
               greatest(public.firm_seat_cap(p_firm_id) - 1, 0)
             );
$$;

comment on function public.firm_capacity_needs_trim(uuid) is
  'True when there are more active devices than the plan allows. Unlike "over", it becomes false once the trim has signed the excess out, even though signed-out members still hold seats.';

create or replace function public.firm_capacity_trim_due(p_firm_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select coalesce(
    (
      select f.tier_pending is not null
          and f.tier_pending_from is not null
          and f.tier_pending_from <= now()
          /* a legacy pending upgrade is not a shrink */
          and public.tier_seat_cap(f.tier_pending) < public.tier_seat_cap(f.tier)
          and public.firm_capacity_needs_trim(p_firm_id)
        from public.firms f
       where f.id = p_firm_id
    ),
    false
  );
$$;

comment on function public.firm_capacity_trim_due(uuid) is
  'The only automatic-trim gate: a lower-tier pending change has started and the active usage is above it. A legacy over-roster with no pending shrink never trims automatically.';

-- ---------------------------------------------------------------------------
-- 4. The caller's device cap: dynamic for the owner, zero for a signed-out
--    associate, one for a seated associate.
-- ---------------------------------------------------------------------------

create or replace function public.device_cap(p_user_id uuid default auth.uid())
returns integer
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select case
           -- A chamber owner's devices share the chamber's remaining slots.
           when p.firm_id is not null
                and exists (
                  select 1
                    from public.firms f
                   where f.id = p.firm_id
                     and f.owner_id = p.id
                )
             then greatest(
               1,
               public.firm_seat_cap(p.firm_id) - public.firm_associate_count(p.firm_id)
             )
           -- A member signed out for capacity has no device until admitted.
           when p.firm_id is not null
                and exists (
                  select 1
                    from public.firm_members m
                   where m.firm_id = p.firm_id
                     and m.user_id = p.id
                     and m.capacity_signed_out_at is not null
                )
             then 0
           -- Every other chamber account: one device.
           when p.firm_id is not null then 1
           -- An individual reads their own effective tier.
           else public.tier_device_cap(
             public.effective_tier(p.tier, p.tier_pending, p.tier_pending_from)
           )
         end
    from public.profiles p
   where p.id = p_user_id;
$$;

comment on function public.device_cap(uuid) is
  'The caller''s concurrent-device allowance: a chamber owner gets the slots left after associates (at least 1), a seated associate 1, a capacity-signed-out associate 0, an individual their effective tier''s cap.';

-- ---------------------------------------------------------------------------
-- 5. Joining a chamber: shared slots, the freeze, and one chamber per account.
-- ---------------------------------------------------------------------------

create or replace function public.join_firm(code text)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  c_max_failures constant integer := 5;
  c_window constant interval := interval '15 minutes';
  c_retention constant interval := interval '1 day';
  c_role_associate constant text := 'associate';

  v_user_id uuid := auth.uid();
  v_code_hash text;
  v_invite public.firm_invites%rowtype;
  v_failures integer;
  v_used_at bigint;
  v_diary_cases integer;
  v_firm_id uuid;
  v_current_firm uuid;
  v_seat_cap integer;
  v_associates integer;
  v_owner_devices integer;
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

  v_code_hash := public.sha256_hex(upper(pg_catalog.btrim(coalesce(code, ''))));

  -- Learn the chamber without a row lock, take the capacity lock first, then
  -- re-read the invite. Locking the invite first would deadlock against
  -- dissolve_firm, which holds the capacity lock while it retires invites.
  select i.firm_id into v_firm_id
    from public.firm_invites i
   where i.code_hash = v_code_hash
     and i.used_by is null
     and i.revoked = false;

  if v_firm_id is null then
    insert into public.invite_attempts (user_id) values (v_user_id);
    return jsonb_build_object('status', 'invalid_code');
  end if;

  perform pg_advisory_xact_lock(hashtext('firm_capacity:' || v_firm_id::text));

  select * into v_invite
    from public.firm_invites i
   where i.code_hash = v_code_hash
     and i.used_by is null
     and i.revoked = false
   for update;

  if not found then
    -- Another redemption won the race while this call waited for the lock.
    insert into public.invite_attempts (user_id) values (v_user_id);
    return jsonb_build_object('status', 'invalid_code');
  end if;

  v_used_at := (extract(epoch from clock_timestamp()) * 1000)::bigint;

  -- Retry by someone already in the firm. The code is retired as revoked.
  if exists (
    select 1
      from public.firm_members m
     where m.firm_id = v_invite.firm_id
       and m.user_id = v_user_id
  ) then
    update public.firm_invites i
       set revoked = true
     where i.id = v_invite.id;

    delete from public.invite_attempts a where a.user_id = v_user_id;

    return jsonb_build_object(
      'status', 'already_member',
      'firm_id', v_invite.firm_id
    );
  end if;

  -- One chamber per account. The old path did not check this, so a member of
  -- chamber A could join B and leave an orphaned seat in A. The code is left
  -- unused for someone who can actually redeem it.
  select p.firm_id into v_current_firm
    from public.profiles p
   where p.id = v_user_id;

  if v_current_firm is not null and v_current_firm is distinct from v_invite.firm_id then
    delete from public.invite_attempts a where a.user_id = v_user_id;
    return jsonb_build_object(
      'status', 'already_in_firm',
      'firm_id', v_invite.firm_id
    );
  end if;

  -- A seat starts empty (§2.1).
  v_diary_cases := public.individual_diary_cases(v_user_id);

  if public.holds_own_diary(v_user_id) then
    delete from public.invite_attempts a where a.user_id = v_user_id;

    return jsonb_build_object(
      'status', 'has_own_diary',
      'cases', v_diary_cases
    );
  end if;

  -- A lapsed chamber is frozen: no new associate may join until the owner
  -- renews. Existing members keep working locally; nothing syncs.
  if public.firm_capacity_frozen(v_invite.firm_id) then
    delete from public.invite_attempts a where a.user_id = v_user_id;

    return jsonb_build_object(
      'status', 'firm_lapsed',
      'firm_id', v_invite.firm_id
    );
  end if;

  -- The shared capacity: a new associate uses one slot, and the owner's first
  -- device is always reserved. Signed-out members still count, which is what
  -- forces an owner to remove them before inviting anyone else.
  v_seat_cap := public.firm_seat_cap(v_invite.firm_id);
  v_associates := public.firm_associate_count(v_invite.firm_id);
  v_owner_devices := public.firm_owner_device_count(v_invite.firm_id);

  if v_associates + greatest(v_owner_devices, 1) + 1 > v_seat_cap then
    delete from public.invite_attempts a where a.user_id = v_user_id;

    return jsonb_build_object(
      'status', 'seats_full',
      'firm_id', v_invite.firm_id,
      'seats', v_seat_cap,
      'used', v_associates + v_owner_devices
    );
  end if;

  insert into public.firm_members (
    firm_id, user_id, role, can_add, can_edit, can_delete,
    synced_at, permissions_synced_at, joined_at
  )
  values (
    v_invite.firm_id, v_user_id, c_role_associate, true, true, false,
    v_used_at, v_used_at, now()
  )
  on conflict (firm_id, user_id) do update
    set role = 'associate',
        can_add = true,
        can_edit = true,
        can_delete = false,
        synced_at = excluded.synced_at,
        permissions_synced_at = excluded.permissions_synced_at;

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
  'Single-use invite redemption: rate limit, hash, chamber freeze, own-diary and shared-capacity gates (associates + owner devices), one-chamber-per-account, membership, profile relink, invite consumed — one transaction.';

-- ---------------------------------------------------------------------------
-- 6. Registering a device: the firm lock first, then the user lock.
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
  c_evict_after constant interval := interval '7 days';

  v_user uuid := auth.uid();
  v_session uuid := public.current_session_id();
  v_now timestamptz := now();
  v_firm_id uuid;
  v_cap integer;
  v_key text := pg_catalog.btrim(coalesce(p_device_key, ''));
  v_platform text := case
                       when p_platform in ('android', 'ios', 'windows') then p_platform
                       else 'unknown'
                     end;
  v_label text := left(pg_catalog.btrim(coalesce(p_label, '')), 120);
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

  if v_session is null then
    return jsonb_build_object('status', 'unmanaged');
  end if;

  if v_key = '' then
    return jsonb_build_object('status', 'invalid_device_key');
  end if;

  if v_hash is null then
    return jsonb_build_object('status', 'invalid_install_secret');
  end if;

  -- Lock order: the capacity lock first, then the per-user device lock. A
  -- chamber whose lower tier has started is rebalanced before this device is
  -- allowed to claim a slot.
  select p.firm_id into v_firm_id
    from public.profiles p
   where p.id = v_user;

  if v_firm_id is not null then
    perform pg_advisory_xact_lock(hashtext('firm_capacity:' || v_firm_id::text));
    if public.firm_capacity_trim_due(v_firm_id) then
      perform public.rebalance_firm_capacity(v_firm_id, v_session);
    end if;
  end if;

  perform pg_advisory_xact_lock(hashtext('user_devices:' || v_user::text));

  -- A member signed out for capacity cannot claim a slot until the owner
  -- admits them again.
  if v_firm_id is not null and exists (
    select 1
      from public.firm_members m
     where m.firm_id = v_firm_id
       and m.user_id = v_user
       and m.capacity_signed_out_at is not null
  ) then
    return jsonb_build_object(
      'status', 'revoked',
      'cap', 0,
      'reason', 'capacity'
    );
  end if;

  v_cap := coalesce(public.device_cap(v_user), 1);

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
      return jsonb_build_object(
        'status', 'revoked',
        'cap', v_cap,
        'reason', v_row.revoked_reason
      );
    end if;

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
  -- The key is held by another active device.
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

  update public.user_devices d
     set revoked_at = v_now,
         revoked_reason = 'cap'
   where d.id = v_evicted.id;

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
  'Claims a device slot for the caller''s session under the firm capacity lock and the per-user lock. A capacity-signed-out associate is refused; a chamber owner''s cap is the slots left after associates; every other device rule (install secret, same-phone replacement, key collision, 7-day eviction) is unchanged.';

-- ---------------------------------------------------------------------------
-- 7. Removing an associate: only their own chamber's access, never another's.
-- ---------------------------------------------------------------------------

create or replace function public.remove_firm_member(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path to 'pg_catalog', 'public'
as $function$
declare
  v_actor uuid := auth.uid();
  v_firm_id uuid;
  v_target_firm uuid;
  v_locked boolean;
begin
  if v_actor is null then
    raise exception 'unauthenticated' using errcode = '42501';
  end if;

  if p_user_id is null then
    return jsonb_build_object('status', 'invalid_request');
  end if;

  select f.id into v_firm_id
    from public.firms f
   where f.owner_id = v_actor
   order by f.created_at
   limit 1;

  if v_firm_id is null then
    return jsonb_build_object('status', 'not_owner');
  end if;

  if p_user_id = v_actor then
    return jsonb_build_object('status', 'cannot_remove_self');
  end if;

  perform pg_advisory_xact_lock(hashtext('firm_capacity:' || v_firm_id::text));

  select true into v_locked
    from public.firm_members m
   where m.firm_id = v_firm_id
     and m.user_id = p_user_id
   for update;

  if not found then
    return jsonb_build_object('status', 'not_found');
  end if;

  -- An orphaned row (the person now belongs to another chamber) is only a
  -- stale seat. Do not relink their profile or revoke their devices: both
  -- belong to the other chamber.
  select p.firm_id into v_target_firm
    from public.profiles p
   where p.id = p_user_id;

  if v_target_firm = v_firm_id then
    update public.user_devices d
       set revoked_at = now(),
           revoked_reason = 'removed'
     where d.user_id = p_user_id
       and d.revoked_at is null;

    delete from public.device_tokens t
     where t.user_id = p_user_id;
  end if;

  delete from public.firm_members m
   where m.firm_id = v_firm_id
     and m.user_id = p_user_id;

  if v_target_firm = v_firm_id then
    update public.profiles p
       set firm_id = null,
           role = 'individual'
     where p.id = p_user_id;
  end if;

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

comment on function public.remove_firm_member(uuid) is
  'Owner-only removal: locks the membership, revokes the member''s devices as removed (only when their profile still points at this chamber), clears push registrations, deletes the membership, relinks the profile to individual, and announces on both topics. An orphaned row is deleted without touching the other chamber. Authored rows stay with the chamber.';

-- ---------------------------------------------------------------------------
-- 8. Owner actions: sign a member out for capacity, or admit them again.
-- ---------------------------------------------------------------------------

create or replace function public.sign_out_firm_member(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_actor uuid := auth.uid();
  v_firm_id uuid;
  v_target_firm uuid;
  v_signed_out_at timestamptz;
begin
  if v_actor is null then
    raise exception 'unauthenticated' using errcode = '42501';
  end if;

  if p_user_id is null then
    return jsonb_build_object('status', 'invalid_request');
  end if;

  select f.id into v_firm_id
    from public.firms f
   where f.owner_id = v_actor
   order by f.created_at
   limit 1;

  if v_firm_id is null then
    return jsonb_build_object('status', 'not_owner');
  end if;

  if p_user_id = v_actor then
    return jsonb_build_object('status', 'cannot_sign_out_self');
  end if;

  perform pg_advisory_xact_lock(hashtext('firm_capacity:' || v_firm_id::text));

  select m.capacity_signed_out_at into v_signed_out_at
    from public.firm_members m
   where m.firm_id = v_firm_id
     and m.user_id = p_user_id
   for update;

  if not found then
    return jsonb_build_object('status', 'not_found');
  end if;

  if v_signed_out_at is not null then
    return jsonb_build_object('status', 'already_signed_out');
  end if;

  select p.firm_id into v_target_firm
    from public.profiles p
   where p.id = p_user_id;

  if v_target_firm is distinct from v_firm_id then
    return jsonb_build_object('status', 'not_found');
  end if;

  update public.firm_members m
     set capacity_signed_out_at = now()
   where m.firm_id = v_firm_id
     and m.user_id = p_user_id;

  update public.user_devices d
     set revoked_at = now(),
         revoked_reason = 'capacity'
   where d.user_id = p_user_id
     and d.revoked_at is null;

  delete from public.device_tokens t
   where t.user_id = p_user_id;

  return jsonb_build_object(
    'status', 'signed_out',
    'user_id', p_user_id,
    'firm_id', v_firm_id
  );
end;
$$;

comment on function public.sign_out_firm_member(uuid) is
  'Owner-only: keeps the membership but marks it capacity-signed-out, revokes all its devices as capacity and clears their push registrations. Used to choose who loses access before or after a shrink.';

create or replace function public.admit_firm_member(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_actor uuid := auth.uid();
  v_firm_id uuid;
  v_target_firm uuid;
  v_signed_out_at timestamptz;
  v_seated integer;
  v_owner_devices integer;
  v_seat_cap integer;
begin
  if v_actor is null then
    raise exception 'unauthenticated' using errcode = '42501';
  end if;

  if p_user_id is null then
    return jsonb_build_object('status', 'invalid_request');
  end if;

  select f.id into v_firm_id
    from public.firms f
   where f.owner_id = v_actor
   order by f.created_at
   limit 1;

  if v_firm_id is null then
    return jsonb_build_object('status', 'not_owner');
  end if;

  if p_user_id = v_actor then
    return jsonb_build_object('status', 'cannot_admit_self');
  end if;

  perform pg_advisory_xact_lock(hashtext('firm_capacity:' || v_firm_id::text));

  select m.capacity_signed_out_at into v_signed_out_at
    from public.firm_members m
   where m.firm_id = v_firm_id
     and m.user_id = p_user_id
   for update;

  if not found then
    return jsonb_build_object('status', 'not_found');
  end if;

  if v_signed_out_at is null then
    return jsonb_build_object('status', 'not_signed_out');
  end if;

  select p.firm_id into v_target_firm
    from public.profiles p
   where p.id = p_user_id;

  if v_target_firm is distinct from v_firm_id then
    return jsonb_build_object('status', 'not_found');
  end if;

  v_seat_cap := public.firm_seat_cap(v_firm_id);
  v_seated := public.firm_seated_count(v_firm_id);
  v_owner_devices := public.firm_owner_device_count(v_firm_id);

  if v_seated + greatest(v_owner_devices, 1) + 1 > v_seat_cap then
    return jsonb_build_object(
      'status', 'seats_full',
      'firm_id', v_firm_id,
      'seats', v_seat_cap
    );
  end if;

  update public.firm_members m
     set capacity_signed_out_at = null
   where m.firm_id = v_firm_id
     and m.user_id = p_user_id;

  return jsonb_build_object(
    'status', 'admitted',
    'user_id', p_user_id,
    'firm_id', v_firm_id
  );
end;
$$;

comment on function public.admit_firm_member(uuid) is
  'Owner-only: clears a capacity-signed-out marker when the chamber has room for the member''s device and the owner''s reserved one. The member signs in again normally.';

-- ---------------------------------------------------------------------------
-- 9. Dissolving a chamber takes the capacity lock too.
-- ---------------------------------------------------------------------------

create or replace function public.dissolve_firm()
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_actor uuid := auth.uid();
  v_firm_id uuid;
  v_members integer;
  v_table text;
  c_ledger constant text[] := array[
    'cases', 'case_history', 'notes', 'case_references', 'delete_requests',
    'court_categories', 'case_categories', 'courts', 'steps', 'case_types',
    'on_behalfs'
  ];
begin
  if v_actor is null then
    raise exception 'unauthenticated' using errcode = '42501';
  end if;

  -- Resolve without a lock, take the capacity lock (same key and order as a
  -- join), then lock the row. A join cannot add a member between the roster
  -- count and the delete.
  select f.id into v_firm_id
    from public.firms f
   where f.owner_id = v_actor
   order by f.created_at
   limit 1;

  if v_firm_id is null then
    return jsonb_build_object('status', 'not_owner');
  end if;

  perform pg_advisory_xact_lock(hashtext('firm_capacity:' || v_firm_id::text));

  select f.id into v_firm_id
    from public.firms f
   where f.id = v_firm_id
   for update;

  if not found then
    return jsonb_build_object('status', 'not_owner');
  end if;

  select count(*) into v_members
    from public.firm_members m
   where m.firm_id = v_firm_id
     and m.user_id <> v_actor;

  if v_members > 0 then
    return jsonb_build_object(
      'status', 'members_remaining',
      'members', v_members
    );
  end if;

  update public.firm_invites i
     set revoked = true
   where i.firm_id = v_firm_id
     and i.revoked = false;

  foreach v_table in array c_ledger loop
    execute format(
      'update public.%1$I set firm_id = null, scope_owner_id = $1 where firm_id = $2',
      v_table
    ) using v_actor, v_firm_id;
  end loop;

  update public.conflict_log c
     set firm_id = null
   where c.firm_id = v_firm_id;

  update public.profiles p
     set firm_id = null,
         role = 'individual'
   where p.id = v_actor;

  delete from public.firms f where f.id = v_firm_id;

  perform realtime.send(
    jsonb_build_object('table', 'firm_members', 'id', v_actor),
    'row_change',
    'user:' || v_actor::text,
    true
  );

  return jsonb_build_object('status', 'dissolved', 'firm_id', v_firm_id);
end;
$$;

comment on function public.dissolve_firm() is
  'Owner-only: dissolves the caller''s chamber once its roster holds nobody else, under the same capacity lock a join takes. Every ledger row loses firm_id and gains the owner as scope_owner_id, open invites are retired, the firms row is removed and the account returns to individual.';

-- ---------------------------------------------------------------------------
-- 10. The trim: owner's extra devices first, then the newest associates.
-- ---------------------------------------------------------------------------

create or replace function public.rebalance_firm_capacity(
  p_firm_id uuid,
  p_keep_session uuid default null
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_owner uuid;
  v_slots integer;
  v_associates integer;
  v_seated integer;
  v_devices integer;
  v_owner_cap integer;
  v_seat_target integer;
  v_keep_id uuid;
  v_ids uuid[];
  v_keys text[];
  v_flag uuid[];
  v_trimmed_owner integer := 0;
  v_flagged integer := 0;
begin
  perform pg_advisory_xact_lock(hashtext('firm_capacity:' || p_firm_id::text));

  select f.owner_id into v_owner
    from public.firms f
   where f.id = p_firm_id;

  if not found then
    return jsonb_build_object('status', 'not_found');
  end if;

  v_slots := public.firm_seat_cap(p_firm_id);
  v_associates := public.firm_associate_count(p_firm_id);
  v_seated := public.firm_seated_count(p_firm_id);
  v_devices := public.firm_owner_device_count(p_firm_id);
  v_owner_cap := greatest(1, v_slots - v_associates);
  v_seat_target := least(v_associates, greatest(v_slots - 1, 0));

  -- Never revoke the device that is making this call.
  if p_keep_session is not null then
    select d.id into v_keep_id
      from public.user_devices d
     where d.user_id = v_owner
       and d.session_id = p_keep_session
       and d.revoked_at is null;
  end if;

  select array_agg(s.id), array_agg(s.device_key)
    into v_ids, v_keys
    from (
      select d.id, d.device_key
        from public.user_devices d
       where d.user_id = v_owner
         and d.revoked_at is null
         and (v_keep_id is null or d.id <> v_keep_id)
       order by d.last_seen_at asc, d.created_at asc
       limit greatest(v_devices - v_owner_cap, 0)
    ) s;

  if v_ids is not null then
    update public.user_devices d
       set revoked_at = now(),
           revoked_reason = 'capacity'
     where d.id = any(v_ids);

    delete from public.device_tokens t
     where t.user_id = v_owner
       and t.device_key = any(v_keys);

    v_trimmed_owner := cardinality(v_ids);
  end if;

  select array_agg(s.user_id)
    into v_flag
    from (
      select m.user_id
        from public.firm_members m
        join public.profiles p
          on p.id = m.user_id
         and p.firm_id = m.firm_id
       where m.firm_id = p_firm_id
         and m.user_id <> v_owner
         and m.capacity_signed_out_at is null
       order by m.joined_at desc, m.id desc
       limit greatest(v_seated - v_seat_target, 0)
    ) s;

  if v_flag is not null then
    update public.firm_members m
       set capacity_signed_out_at = now()
     where m.firm_id = p_firm_id
       and m.user_id = any(v_flag);

    update public.user_devices d
       set revoked_at = now(),
           revoked_reason = 'capacity'
     where d.user_id = any(v_flag)
       and d.revoked_at is null;

    delete from public.device_tokens t
     where t.user_id = any(v_flag);

    v_flagged := cardinality(v_flag);
  end if;

  return jsonb_build_object(
    'status', 'ok',
    'slots', v_slots,
    'associates', v_associates,
    'seated', v_seated,
    'owner_devices', v_devices,
    'owner_devices_trimmed', v_trimmed_owner,
    'associates_signed_out', v_flagged
  );
end;
$$;

comment on function public.rebalance_firm_capacity(uuid, uuid) is
  'Enforces a chamber''s shared slots: revokes the owner''s devices beyond max(1, slots - associates), least recently seen first (never p_keep_session), then signs out the newest seated associates beyond min(associates, slots - 1), revoking their devices. Never clears a marker.';

create or replace function public.rebalance_all_firm_capacities()
returns integer
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_firm record;
  v_count integer := 0;
begin
  for v_firm in
    select f.id
      from public.firms f
     where public.firm_capacity_trim_due(f.id)
  loop
    perform public.rebalance_firm_capacity(v_firm.id);
    v_count := v_count + 1;
  end loop;

  return v_count;
end;
$$;

comment on function public.rebalance_all_firm_capacities() is
  'The cron target: rebalances only chambers whose lower-tier pending change has started and whose active usage is over. Returns how many chambers were processed.';

-- Schedule every 15 minutes so a shrink is enforced shortly after its deadline.
-- The same guarded pattern as the other pg_cron jobs; if the extension is not
-- available, the lazy rebalance in register_device still enforces it on contact.
do $$
begin
  begin
    create extension if not exists pg_cron;
  exception
    when others then
      raise notice
        'pg_cron could not be created (%); schedule public.rebalance_all_firm_capacities() '
        'from the dashboard.', sqlerrm;
  end;

  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.unschedule('rebalance-firm-capacity')
     where exists (select 1 from cron.job where jobname = 'rebalance-firm-capacity');

    perform cron.schedule(
      'rebalance-firm-capacity',
      '*/15 * * * *',
      'select public.rebalance_all_firm_capacities()'
    );

    raise notice 'pg_cron: rebalance-firm-capacity scheduled every 15 minutes.';
  else
    raise notice
      'pg_cron is not installed; public.rebalance_firm_capacity exists but is '
      'only invoked by register_device.';
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- 11. Grants: every new helper is internal; the RPCs keep their client shape.
-- ---------------------------------------------------------------------------

revoke all on function public.tier_seat_cap(text) from public, anon, authenticated;
revoke all on function public.firm_seat_cap(uuid) from public, anon, authenticated;
revoke all on function public.firm_associate_count(uuid) from public, anon, authenticated;
revoke all on function public.firm_seated_count(uuid) from public, anon, authenticated;
revoke all on function public.firm_owner_device_count(uuid) from public, anon, authenticated;
revoke all on function public.firm_capacity_frozen(uuid) from public, anon, authenticated;
revoke all on function public.firm_capacity_usage(uuid) from public, anon, authenticated;
revoke all on function public.firm_capacity_needs_trim(uuid) from public, anon, authenticated;
revoke all on function public.firm_capacity_trim_due(uuid) from public, anon, authenticated;
revoke all on function public.device_cap(uuid) from public, anon, authenticated;

revoke all on function public.join_firm(text) from public, anon;
grant execute on function public.join_firm(text) to authenticated;

revoke all on function public.register_device(text, text, text, text) from public, anon;
grant execute on function public.register_device(text, text, text, text) to authenticated;

revoke all on function public.remove_firm_member(uuid) from public, anon;
grant execute on function public.remove_firm_member(uuid) to authenticated;

revoke all on function public.sign_out_firm_member(uuid) from public, anon;
grant execute on function public.sign_out_firm_member(uuid) to authenticated;

revoke all on function public.admit_firm_member(uuid) from public, anon;
grant execute on function public.admit_firm_member(uuid) to authenticated;

revoke all on function public.rebalance_firm_capacity(uuid, uuid)
  from public, anon, authenticated;
revoke all on function public.rebalance_all_firm_capacities()
  from public, anon, authenticated;
