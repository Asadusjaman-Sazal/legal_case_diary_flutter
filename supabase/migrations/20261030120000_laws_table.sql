-- The statute list on the server — Phase 2 of the law-list plan.
--
-- The phone gained the list locally in 0.0.744; this migration makes it a real
-- shared row set, so the names the app already ships, a name a lawyer adds and a
-- name their chamber renames all travel the same way a court name does.
--
-- Table class (AGENTS.md rule 4): **push/pull domain** — editable, firm-shared
-- reference data, the seventh table in that family. It is not a pull-only cache,
-- and no generic sync behaviour is applied beyond the contract every domain
-- table already carries.
--
-- What this file does, in order:
--
--   1. Creates `public.laws` with the five sync columns, the client's `category`
--      (one of the seven stable law-category IDs), `server_updated_at` and the
--      firm-mode `scope_owner_id`. The column set is the phone's, plus the two
--      server-owned columns every domain table has today.
--   2. RLS: the 57 built-in rows are the baseline every install reads; a custom
--      row is readable while it is its author's firm-less diary (no scope owner),
--      or while it belongs to the caller's chamber, or to the caller as a
--      dissolve's scope owner. Writes are the caller's own insert and the
--      creator's or a `can_edit` member's update — the same matrix as the six
--      reference tables, so a chamber shares one statute list.
--   3. Grants: `scope_owner_id` is server-only, by the table-level revoke plus a
--      column grant that names every other column, exactly as the firm-mode read
--      scope migration does for the other eleven ledger tables.
--   4. Triggers: `server_updated_at`, the delete transition, the resurrection
--      guard, the member permission boundary and the realtime broadcast. No
--      in-use guard: a statute is free text on a reference row, so no child row
--      names a law.
--   5. Indexes: the delta cursor and its two scoped variants.
--   6. Eight functions re-created with `laws` in the list each one holds — the
--      newest shipped body of each, with that one list changed:
--        sync_entity_table / sync_dependency_rank  (the push path)
--        sync_can_write                            (the write verdict)
--        ensure_firm                               (creation shares custom rows)
--        holds_own_diary                           (the join gate's seat test)
--        dissolve_firm                             (the chamber's rows come back)
--        purge_tombstones                          (a tombstone finally purges)
--        delete_my_account                         (an account's rows go with it)
--      Without these the table would exist but be unreachable to a chamber
--      member, unshared at creation, unclaimed at dissolve, unpurgeable and
--      refusing to let its author delete their account — the kind of half-wired
--      table this project has been bitten by before.
--
-- The 57 rows themselves are in the next file (`20261030121000`), generated from
-- `lib/core/constants/pre_seeded_data.dart` by `tool/generate_supabase_seed.dart`
-- so the phone, the server and a backup name the same IDs byte for byte.
--
-- Applied to `lsthasywrdrhuuxnykau` ("Legal Case Diary") only — AGENTS.md rule 12.

-- ---------------------------------------------------------------------------
-- 1. The table
-- ---------------------------------------------------------------------------

create table if not exists public.laws (
  id text primary key,
  name text not null,
  category text not null default '',
  order_index integer not null default 0,
  is_custom boolean not null default false,
  is_user_modified boolean not null default false,
  user_id uuid references auth.users (id),
  firm_id uuid references public.firms (id),
  updated_at bigint not null,
  version integer not null default 1,
  server_updated_at timestamptz not null default now(),
  synced_at bigint,
  is_deleted boolean not null default false,
  last_modified_by text,
  scope_owner_id uuid
);

comment on table public.laws is
  'Editable statute list for case references. Built-in rows are the 57 seeded names; a custom row is a name a user or chamber added, and every row is firm-shared in firm mode.';
comment on column public.laws.category is
  'One of the seven stable law-category IDs (constitution_courts_practice … labour_everyday_regulation). The heading''s label lives in the app''s ARB files, so it follows the language while the law name does not.';
comment on column public.laws.scope_owner_id is
  'Scope key, not attribution: the owner of a row a dissolved chamber kept. Server-only; push_changes strips it and the column grant withholds it.';

-- ---------------------------------------------------------------------------
-- 2. Row-level security — the reference-table matrix
-- ---------------------------------------------------------------------------

alter table public.laws enable row level security;

drop policy if exists laws_select_scoped on public.laws;
create policy laws_select_scoped on public.laws
  for select to authenticated
  using (
    is_custom = false
    or (user_id = auth.uid() and firm_id is null and scope_owner_id is null)
    or firm_id = public.current_firm_id()
    or scope_owner_id = auth.uid()
  );

drop policy if exists laws_insert_own on public.laws;
create policy laws_insert_own on public.laws
  for insert to authenticated
  with check (
    user_id = auth.uid()
    and (firm_id is null or firm_id = public.current_firm_id())
  );

drop policy if exists laws_update_scoped on public.laws;
create policy laws_update_scoped on public.laws
  for update to authenticated
  using (user_id = auth.uid() or public.can_edit_firm(firm_id))
  with check (user_id = auth.uid() or public.can_edit_firm(firm_id));

-- No delete policy: deletion is the soft-delete transition, gated by
-- `enforce_delete_transition` and the member permission trigger, exactly as the
-- other reference tables do it.

-- ---------------------------------------------------------------------------
-- 3. Grants — every column but the server-owned scope key
-- ---------------------------------------------------------------------------

revoke insert, update on public.laws from authenticated, anon;
grant insert (
  id, name, category, order_index, is_custom, is_user_modified, user_id,
  firm_id, updated_at, version, server_updated_at, synced_at, is_deleted,
  last_modified_by
) on public.laws to authenticated;
grant update (
  id, name, category, order_index, is_custom, is_user_modified, user_id,
  firm_id, updated_at, version, server_updated_at, synced_at, is_deleted,
  last_modified_by
) on public.laws to authenticated;

-- ---------------------------------------------------------------------------
-- 4. Triggers
-- ---------------------------------------------------------------------------

drop trigger if exists trg_laws_server_updated_at on public.laws;
create trigger trg_laws_server_updated_at
  before insert or update on public.laws
  for each row execute function public.set_server_updated_at();

drop trigger if exists trg_laws_delete_transition on public.laws;
create trigger trg_laws_delete_transition
  before update on public.laws
  for each row execute function public.enforce_delete_transition();

drop trigger if exists trg_laws_resurrection_guard on public.laws;
create trigger trg_laws_resurrection_guard
  before update on public.laws
  for each row execute function public.enforce_no_resurrection();

drop trigger if exists trg_laws_add_permission on public.laws;
create trigger trg_laws_add_permission
  before insert on public.laws
  for each row execute function public.enforce_member_permission();

drop trigger if exists trg_laws_edit_permission on public.laws;
create trigger trg_laws_edit_permission
  before update on public.laws
  for each row execute function public.enforce_member_permission();

drop trigger if exists trg_laws_broadcast on public.laws;
create trigger trg_laws_broadcast
  after insert or update on public.laws
  for each row execute function public.broadcast_row_change();

-- ---------------------------------------------------------------------------
-- 5. Indexes — the delta pull reads these
-- ---------------------------------------------------------------------------

create index if not exists laws_delta_idx
  on public.laws (server_updated_at, id);
create index if not exists laws_firm_delta_idx
  on public.laws (firm_id, server_updated_at, id);
create index if not exists laws_user_delta_idx
  on public.laws (user_id, server_updated_at, id);

-- ---------------------------------------------------------------------------
-- 6. The functions that must know the table exists
-- ---------------------------------------------------------------------------
--
-- The newest shipped body of each function, with one list extended. Nothing else
-- changes; the header above says why each one is here.

-- sync_entity_table: The push path: a queued `law` mutation now names public.laws.

create or replace function public.sync_entity_table(p_entity_type text)
returns text
language sql
immutable
set search_path = pg_catalog, public
as $$
  select case p_entity_type
    when 'case' then 'cases'
    when 'case_history' then 'case_history'
    when 'note' then 'notes'
    when 'reference' then 'case_references'
    when 'court_category' then 'court_categories'
    when 'case_category' then 'case_categories'
    when 'court' then 'courts'
    when 'step' then 'steps'
    when 'case_type' then 'case_types'
    when 'on_behalf' then 'on_behalfs'
    when 'law' then 'laws'
    when 'delete_request' then 'delete_requests'
    when 'conflict_log' then 'conflict_log'
    else null
  end;
$$;

-- sync_dependency_rank: A law is configuration, so it pushes before a case.

create or replace function public.sync_dependency_rank(p_entity_type text)
returns integer
language sql
immutable
set search_path = pg_catalog, public
as $$
  select case public.sync_entity_table(p_entity_type)
    when 'court_categories' then 0
    when 'case_categories' then 0
    when 'courts' then 0
    when 'steps' then 0
    when 'case_types' then 0
    when 'on_behalfs' then 0
    when 'laws' then 0
    when 'cases' then 1
    when 'case_history' then 2
    when 'notes' then 2
    when 'case_references' then 2
    when 'delete_requests' then 2
    when 'conflict_log' then 2
    else 3
  end;
$$;

-- sync_can_write: The reference-write branch now judges a law row too.

create or replace function public.sync_can_write(
  p_table text,
  p_row jsonb,
  p_operation text
)
returns boolean
language plpgsql
stable
security definer
set search_path = pg_catalog, public
as $$
declare
  v_actor uuid := auth.uid();
  v_is_reference boolean := p_table in (
    'court_categories', 'case_categories', 'courts', 'steps', 'case_types',
    'on_behalfs', 'laws'
  );
  -- The firm a delete-request rule weighs: the row's own when it carries one,
  -- otherwise the stored request's.
  v_request_firm uuid;
begin
  if v_actor is null then
    return false;
  end if;

  if p_operation = 'insert' then
    if p_table = 'delete_requests' then
      return coalesce((p_row ->> 'requested_by')::uuid, null) = v_actor
         and coalesce((p_row ->> 'firm_id')::uuid, null)
             is not distinct from public.current_firm_id();
    elsif v_is_reference then
      return coalesce((p_row ->> 'is_custom')::boolean, false)
         and coalesce((p_row ->> 'user_id')::uuid, null) = v_actor
         and (
           p_row ->> 'firm_id' is null
           or coalesce((p_row ->> 'firm_id')::uuid, null)
                is not distinct from public.current_firm_id()
         )
         and (
           p_row ->> 'firm_id' is null
           or public.can_add_firm(coalesce((p_row ->> 'firm_id')::uuid, null))
         );
    else
      return coalesce((p_row ->> 'user_id')::uuid, null) = v_actor
         and (
           p_row ->> 'firm_id' is null
           or coalesce((p_row ->> 'firm_id')::uuid, null)
                is not distinct from public.current_firm_id()
         )
         and (
           p_row ->> 'firm_id' is null
           or public.can_add_firm(coalesce((p_row ->> 'firm_id')::uuid, null))
         );
    end if;
  end if;

  -- update / delete
  if p_table = 'delete_requests' then
    -- The requester may edit or withdraw their own request while it is pending,
    -- but only while the request's firm is still theirs: a removed requester must
    -- not be able to touch it. A member with delete permission may still review.
    --
    -- A review reaches this function without the firm in the row (see the file
    -- header), so the firm is taken from the request the payload names when the
    -- row itself has none. An update that names no such request — an id this
    -- table does not hold — stays unfirm and is refused, which is the safe
    -- direction: no caller may delete in a firm that cannot be read.
    v_request_firm := nullif(p_row ->> 'firm_id', '')::uuid;
    if v_request_firm is null then
      select d.firm_id into v_request_firm
        from public.delete_requests d
       where d.id::text = lower(nullif(p_row ->> 'id', ''));
    end if;

    return (
      coalesce((p_row ->> 'requested_by')::uuid, null) = v_actor
      and (p_row ->> 'status') = 'pending'
      and v_request_firm is not distinct from public.current_firm_id()
    ) or public.can_delete_firm(v_request_firm);
  elsif v_is_reference then
    -- A built-in row has no creator and no firm; only a custom row is writable.
    if not coalesce((p_row ->> 'is_custom')::boolean, false) then
      return false;
    end if;
    return (
        coalesce((p_row ->> 'user_id')::uuid, null) = v_actor
        and (
          p_row ->> 'firm_id' is null
          or coalesce((p_row ->> 'firm_id')::uuid, null)
               is not distinct from public.current_firm_id()
        )
      )
      or public.can_edit_firm(coalesce((p_row ->> 'firm_id')::uuid, null));
  elsif p_table = 'conflict_log' then
    return coalesce((p_row ->> 'user_id')::uuid, null) = v_actor;
  else
    -- Authorship only counts while the row's firm is still the caller's firm: a
    -- removed member keeps their own personal rows but not the firm's.
    if not (
      (
        coalesce((p_row ->> 'user_id')::uuid, null) = v_actor
        and (
          p_row ->> 'firm_id' is null
          or coalesce((p_row ->> 'firm_id')::uuid, null)
               is not distinct from public.current_firm_id()
        )
      )
      or public.can_edit_firm(coalesce((p_row ->> 'firm_id')::uuid, null))
    ) then
      return false;
    end if;
    -- The delete transition additionally needs can_delete, mirroring
    -- enforce_delete_transition().
    if p_operation = 'delete' and (p_row ->> 'firm_id') is not null then
      return public.can_delete_firm(coalesce((p_row ->> 'firm_id')::uuid, null));
    end if;
    return true;
  end if;
end;
$$;

-- ensure_firm: A custom law written before the chamber existed joins it.

create or replace function public.ensure_firm(p_name text)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_user_id uuid := auth.uid();
  v_now bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint;
  v_name text := pg_catalog.btrim(coalesce(p_name, ''));
  v_firm public.firms%rowtype;
  v_has_firm boolean;
  v_created boolean := false;
  v_table text;
  v_case_tables text[] := array[
    'cases', 'case_history', 'notes', 'case_references'
  ];
  v_reference_tables text[] := array[
    'court_categories', 'case_categories', 'courts', 'steps', 'case_types',
    'on_behalfs', 'laws'
  ];
  -- The tier required to create a chamber: Firm is rank 3 on the new ladder
  -- free 0 / starter 1 / pro 2 / firm 3 / firm_plus 4 / enterprise 5.
  c_required_tier_rank constant integer := 3;
  v_profile_tier text;
begin
  if v_user_id is null then
    return jsonb_build_object('status', 'unauthenticated');
  end if;

  select * into v_firm
    from public.firms f
   where f.owner_id = v_user_id
   order by f.created_at
   limit 1;
  v_has_firm := found;

  if exists (
    select 1
      from public.profiles p
     where p.id = v_user_id
       and p.firm_id is not null
       and (not v_has_firm or p.firm_id is distinct from v_firm.id)
  ) then
    return jsonb_build_object('status', 'member_of_another_firm');
  end if;

  if not v_has_firm then
    select public.effective_tier(p.tier, p.tier_pending, p.tier_pending_from)
      into v_profile_tier
      from public.profiles p
     where p.id = v_user_id;

    if public.tier_rank(v_profile_tier) < c_required_tier_rank then
      return jsonb_build_object('status', 'firm_tier_required');
    end if;

    insert into public.firms (
      name, owner_id, subscription_status, subscription_expiry,
      tier, tier_pending, tier_pending_from
    )
    select
      v_name,
      v_user_id,
      p.subscription_status,
      p.subscription_expiry,
      v_profile_tier,
      p.tier_pending,
      p.tier_pending_from
      from public.profiles p
     where p.id = v_user_id
    returning * into v_firm;

    if not found then
      raise exception 'ensure_firm: no profiles row for the caller'
        using errcode = 'P0001';
    end if;

    v_created := true;
  elsif v_name is distinct from v_firm.name then
    update public.firms f
       set name = v_name
     where f.id = v_firm.id
    returning * into v_firm;
  end if;

  update public.profiles p
     set firm_id = v_firm.id,
         role = 'owner'
   where p.id = v_user_id;

  insert into public.firm_members (
    firm_id, user_id, role, can_add, can_edit, can_delete,
    synced_at, permissions_synced_at
  )
  values (
    v_firm.id, v_user_id, 'owner', true, true, true, v_now, v_now
  )
  on conflict (firm_id, user_id) do update
    set role = 'owner',
        can_add = true,
        can_edit = true,
        can_delete = true,
        synced_at = excluded.synced_at,
        permissions_synced_at = excluded.permissions_synced_at;

  if v_created then
    foreach v_table in array v_case_tables loop
      execute format(
        'update public.%I t '
        '   set firm_id = $1, '
        '       version = coalesce(t.version, 1) + 1, '
        '       updated_at = $3 '
        ' where t.user_id = $2 '
        '   and t.firm_id is null',
        v_table
      ) using v_firm.id, v_user_id, v_now;
    end loop;

    foreach v_table in array v_reference_tables loop
      execute format(
        'update public.%I t '
        '   set firm_id = $1, '
        '       version = coalesce(t.version, 1) + 1, '
        '       updated_at = $3 '
        ' where t.user_id = $2 '
        '   and t.firm_id is null '
        '   and t.is_custom = true',
        v_table
      ) using v_firm.id, v_user_id, v_now;
    end loop;

    update public.delete_requests t
       set firm_id = v_firm.id,
           version = coalesce(t.version, 1) + 1,
           updated_at = v_now
     where t.requested_by = v_user_id
       and t.firm_id is null
       and t.status = 'pending';
  end if;

  return jsonb_build_object(
    'status', 'ready',
    'firm_id', v_firm.id,
    'name', v_firm.name
  );
end;
$$;

-- dissolve_firm: A dissolved chamber's laws pass to the owner with the rest of the ledger.

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
    'on_behalfs', 'laws'
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

-- purge_tombstones: A law tombstone now ages out like any other.

create or replace function public.purge_tombstones(p_retention_days integer default 365)
returns integer
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_cutoff timestamptz;
  v_table text;
  v_id text;
  v_deleted integer;
  v_total integer := 0;
  v_skipped integer := 0;
  -- Children before parents: the FK graph is case data -> cases -> the
  -- reference tables that cases point at, with case_categories and
  -- court_categories last. Deleting in this order never trips a foreign key for
  -- a row that is itself purgeable, so the skip below is reserved for the rows
  -- a **live** or not-yet-purgeable dependent still names.
  v_order text[] := array[
    'case_history',
    'delete_requests',
    'conflict_log',
    'notes',
    'case_references',
    'cases',
    'laws',
    'case_types',
    'steps',
    'courts',
    'case_categories',
    'on_behalfs',
    'court_categories'
  ];
begin
  -- server_updated_at is stamped by the delete transition itself, so it is the
  -- tombstone's age.
  v_cutoff := now() - make_interval(days => p_retention_days);

  foreach v_table in array v_order loop
    -- One candidate at a time. A row a dependent still names raises
    -- foreign_key_violation on its own DELETE, and this block skips that row
    -- alone: the shipped set-based statement let one such row abort every other
    -- tombstone's purge on the project.
    for v_id in execute format(
      'select id from public.%1$I where is_deleted = true '
      'and server_updated_at < $1',
      v_table
    ) using v_cutoff loop
      begin
        execute format('delete from public.%1$I where id = $1', v_table)
          using v_id;

        get diagnostics v_deleted = row_count;
        v_total := v_total + v_deleted;
      exception
        when foreign_key_violation then
          v_skipped := v_skipped + 1;
      end;
    end loop;
  end loop;

  -- Say so: the job runs daily from pg_cron, where a silent skip is invisible.
  if v_skipped > 0 then
    raise notice
      'purge_tombstones: % tombstone(s) kept; a dependent row still names them.',
      v_skipped;
  end if;

  return v_total;
end;
$$;

-- delete_my_account: An account's custom laws go with its other rows.

create or replace function public.delete_my_account()
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_user_id uuid := auth.uid();
  v_firm_id uuid;
  v_refusal text;
begin
  if v_user_id is null then
    return jsonb_build_object('status', 'unauthenticated');
  end if;

  -- Refusal 1: a firm account. Checked against both halves of "belongs to a
  -- firm" — the profile's own firm link (what the app calls firm mode) and
  -- ownership of a firm row, which is what the domain rows are shared through.
  select p.firm_id into v_firm_id from public.profiles p where p.id = v_user_id;

  if v_firm_id is not null
     or exists (select 1 from public.firms f where f.owner_id = v_user_id) then
    v_refusal := 'firm';
  end if;

  -- Refusal 2: an administrator. `app_admins` is server-internal, and an admin's
  -- rows include the payment ledger of every other account.
  if v_refusal is null
     and exists (select 1 from public.app_admins a where a.user_id = v_user_id)
  then
    v_refusal := 'administrator';
  end if;

  if v_refusal is not null then
    return jsonb_build_object('status', 'refused', 'reason', v_refusal);
  end if;

  -- --- Domain rows: everything the caller authored, children before parents. ---

  -- The caller's own requests go. A request they reviewed belongs to somebody
  -- else, so the reviewer link is the only part of it that is theirs.
  update public.delete_requests
     set reviewed_by = null
   where reviewed_by = v_user_id;
  delete from public.delete_requests where requested_by = v_user_id;

  delete from public.conflict_log where user_id = v_user_id;

  -- Authored history, plus any history of a case of theirs (the rest cascades
  -- from `cases` below).
  delete from public.case_history
   where user_id = v_user_id or created_by = v_user_id;

  delete from public.notes where user_id = v_user_id;
  delete from public.case_references where user_id = v_user_id;
  delete from public.case_notification_preferences where user_id = v_user_id;

  -- Cases last among the case data: `court_id`, `case_category_id` and
  -- `on_behalf_id` point at the reference rows deleted below.
  delete from public.cases where user_id = v_user_id;

  -- Custom reference rows. Seeded rows have `user_id is null`, so the baseline
  -- every account reads is untouched. Steps, case types and on-behalfs point at
  -- a court category, case types may point at a case category, and courts point
  -- at a court category: children first, `court_categories` last.
  delete from public.steps where user_id = v_user_id;
  delete from public.case_types where user_id = v_user_id;
  delete from public.on_behalfs where user_id = v_user_id;
  delete from public.courts where user_id = v_user_id;
  delete from public.laws where user_id = v_user_id;
  delete from public.case_categories where user_id = v_user_id;
  delete from public.court_categories where user_id = v_user_id;

  -- --- Money and audit rows. ---

  -- The deliberate exception described in the header: the ledger refuses deletes
  -- for every role, and this is the one legitimate reason to switch it off. Both
  -- statements and the delete are in this transaction, so the trigger is never
  -- left disabled.
  alter table public.payment_approval_events
    disable trigger trg_payment_approval_events_immutable;
  delete from public.payment_approval_events
   where user_id = v_user_id or approved_by = v_user_id;
  alter table public.payment_approval_events
    enable trigger trg_payment_approval_events_immutable;

  delete from public.payment_submissions where user_id = v_user_id;

  -- After the domain rows: a receipt is the record of a mutation they carried.
  delete from public.mutation_receipts where actor_id = v_user_id;

  -- --- Firm links the callers of a refused account cannot have; stated anyway. ---

  delete from public.firm_invites where created_by = v_user_id;
  delete from public.firm_members where user_id = v_user_id;

  -- --- The account itself. ---
  --
  -- One statement, and it cannot fail on a foreign key: every reference that does
  -- not cascade has been removed above, and the ones that do — `profiles`,
  -- `user_preferences`, `case_notification_preferences`, `invite_attempts`,
  -- `app_admins`, `firm_members` — go with it, along with the Auth sessions.
  delete from auth.users u where u.id = v_user_id;

  return jsonb_build_object('status', 'removed');
end;
$$;

-- holds_own_diary: A custom law is its author's own diary, like a custom court.

create or replace function public.holds_own_diary(p_user_id uuid)
returns boolean
language plpgsql
stable
security definer
set search_path = pg_catalog, public
as $$
declare
  v_table text;
  v_tables text[] := array[
    'cases', 'case_history', 'notes', 'case_references',
    'court_categories', 'case_categories', 'courts', 'steps', 'case_types',
    'on_behalfs', 'laws'
  ];
  v_found boolean;
begin
  foreach v_table in array v_tables loop
    execute format(
      'select exists (select 1 from public.%I t '
      ' where t.user_id = $1 and t.firm_id is null '
      '   and t.scope_owner_id is null)',
      v_table
    ) into v_found using p_user_id;

    if v_found then
      return true;
    end if;
  end loop;

  return false;
end;
$$;
