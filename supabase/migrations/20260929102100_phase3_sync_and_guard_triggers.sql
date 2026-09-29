-- Phase 3 (2/6) — Sync columns and the write guards on the push/pull domain.
--
-- Four behaviours, applied to the twelve domain tables only (AGENTS.md rule 4 —
-- the pull-only caches, preference tables and server-managed tables deliberately
-- get none of them):
--
--   1. `server_updated_at` maintenance — the only column a delta pull filters
--      on, so it is trigger-assigned and never client-written.
--   2. Delete transition (`is_deleted false -> true`) — RLS `WITH CHECK` sees
--      only the NEW row and cannot compare OLD to NEW, so the field-level
--      `can_delete` rule has to be a trigger.
--   3. Resurrection (`is_deleted true -> false`) — refused unless a
--      transaction-local authorization flag is set by a separately audited
--      administrator recovery path. The guard never compares client
--      timestamps, client versions or editor UUIDs.
--   4. The two defense-in-depth limits that RLS cannot express: the free-tier
--      50-case ceiling and the 3-payments-per-24h ceiling.
--
-- The sync columns are maintained here; the `push_changes` RPC (Task 18) is
-- responsible for `version` and `last_modified_by`.

-- ---------------------------------------------------------------------------
-- 1. server_updated_at
-- ---------------------------------------------------------------------------

create or replace function public.set_server_updated_at()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
begin
  new.server_updated_at := now();
  return new;
end;
$$;

comment on function public.set_server_updated_at() is
  'BEFORE INSERT OR UPDATE on every domain table: the delta-pull cursor is server-assigned.';

-- ---------------------------------------------------------------------------
-- 2. Delete transition requires can_delete inside a firm
-- ---------------------------------------------------------------------------

create or replace function public.enforce_delete_transition()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if old.is_deleted = false and new.is_deleted = true then
    -- Individual rows (no firm) are the creator's own; a firm row needs either
    -- the owner or a member holding can_delete. An associate without it must go
    -- through the delete-request workflow instead.
    if not public.can_delete_firm(old.firm_id)
       and old.firm_id is not null then
      raise exception 'delete_not_permitted'
        using errcode = '42501',
              hint = 'Requires can_delete in this firm; raise a delete request instead.';
    end if;
  end if;
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. Resurrection guard
-- ---------------------------------------------------------------------------

create or replace function public.enforce_no_resurrection()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if old.is_deleted = true and new.is_deleted = false then
    -- Only a deliberate, audited administrator recovery path may undo a
    -- tombstone, and it marks that intent for the rest of its transaction:
    --   select set_config('app.allow_resurrection', 'true', true);
    if coalesce(current_setting('app.allow_resurrection', true), 'false')
       <> 'true' then
      raise exception 'resurrection_not_permitted'
        using errcode = '42501',
              hint = 'A soft-deleted row is a tombstone; recovery is an audited admin operation.';
    end if;
  end if;
  return new;
end;
$$;

comment on function public.enforce_no_resurrection() is
  'Refuses is_deleted true -> false unless the transaction set app.allow_resurrection. Compares no client timestamps, versions or UUIDs.';

-- ---------------------------------------------------------------------------
-- 4a. Free-tier case ceiling (defense in depth)
-- ---------------------------------------------------------------------------

create or replace function public.enforce_free_case_limit()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  c_free_case_limit constant integer := 50;
  v_existing integer;
begin
  if public.is_premium(new.user_id) then
    return new;
  end if;

  -- Serialize count-and-insert for this owner: under READ COMMITTED two
  -- concurrent inserts could otherwise both read 49.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtext(new.user_id::text)
  );

  select pg_catalog.count(*) into v_existing
    from public.cases c
   where c.user_id = new.user_id
     and c.is_deleted = false;

  if v_existing >= c_free_case_limit then
    raise exception 'free_case_limit_reached'
      using errcode = 'P0001',
            hint = 'A free account may hold 50 live cases; the client shows the paywall.';
  end if;
  return new;
end;
$$;

comment on function public.enforce_free_case_limit() is
  'Rejects an insert past 50 live cases on a free (derived) entitlement; soft-deleted cases do not count.';

-- ---------------------------------------------------------------------------
-- 4b. Payment submission rate limit
-- ---------------------------------------------------------------------------

create or replace function public.enforce_payment_rate_limit()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  c_daily_limit constant integer := 3;
  v_recent integer;
begin
  -- Server time only: a client-supplied submitted_at is overwritten, never
  -- trusted, and the rolling count reads this column.
  new.submitted_at := now();

  select pg_catalog.count(*) into v_recent
    from public.payment_submissions s
   where s.user_id = new.user_id
     and s.submitted_at > now() - interval '24 hours';

  if v_recent >= c_daily_limit then
    raise exception 'payment_submission_limit_reached'
      using errcode = 'P0001',
            hint = 'Three submissions per 24 hours; the client shows the friendly message.';
  end if;
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Attach the triggers to the twelve domain tables
-- ---------------------------------------------------------------------------

do $$
declare
  v_table text;
  v_tables text[] := array[
    'cases', 'case_history', 'notes', 'case_references', 'court_categories',
    'case_categories', 'courts', 'steps', 'case_types', 'on_behalfs',
    'delete_requests', 'conflict_log'
  ];
begin
  foreach v_table in array v_tables loop
    execute format(
      'drop trigger if exists trg_%1$s_server_updated_at on public.%1$I',
      v_table
    );
    execute format(
      'create trigger trg_%1$s_server_updated_at before insert or update on '
      'public.%1$I for each row execute function public.set_server_updated_at()',
      v_table
    );

    execute format(
      'drop trigger if exists trg_%1$s_delete_transition on public.%1$I',
      v_table
    );
    execute format(
      'create trigger trg_%1$s_delete_transition before update on public.%1$I '
      'for each row execute function public.enforce_delete_transition()',
      v_table
    );

    execute format(
      'drop trigger if exists trg_%1$s_resurrection_guard on public.%1$I',
      v_table
    );
    execute format(
      'create trigger trg_%1$s_resurrection_guard before update on public.%1$I '
      'for each row execute function public.enforce_no_resurrection()',
      v_table
    );
  end loop;
end;
$$;

-- The two limits belong to their own tables and are not part of the loop above:
-- `cases` counts rows per owner, and payment submissions are not a domain table.
drop trigger if exists trg_cases_free_limit on public.cases;
create trigger trg_cases_free_limit
  before insert on public.cases
  for each row
  execute function public.enforce_free_case_limit();

drop trigger if exists trg_payment_submissions_rate_limit
  on public.payment_submissions;
create trigger trg_payment_submissions_rate_limit
  before insert on public.payment_submissions
  for each row
  execute function public.enforce_payment_rate_limit();
