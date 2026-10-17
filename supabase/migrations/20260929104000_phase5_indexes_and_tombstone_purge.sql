-- Phase 5 — Indexes and the scheduled tombstone purge.
--
-- Two jobs:
--
--   1. Make every read the client performs index-backed. The delta pull is
--      scoped (one firm, or one user) and ordered by the composite cursor
--      `(server_updated_at, id)`, so each domain table gets the unscoped
--      composite for a full pull plus a scoped variant for the normal case.
--   2. Purge tombstones after 180 days — long enough that the 150-day
--      per-device extended-offline rule then in force could never resurrect
--      data, short enough that deleted rows do not accumulate forever.
--      **Both numbers have since moved (§5.5): 365 days of tombstones and a
--      335-day recovery window, in
--      `20261017120000_firm_mode_retention_window.sql`.** That file replaces
--      the default below; this statement is the history.
--
-- Table class: indexes and the purge touch the push/pull domain class only.

-- ---------------------------------------------------------------------------
-- 1a. Payment submission window index (the rate limiter and the UI both read it)
-- ---------------------------------------------------------------------------

create index if not exists payment_submissions_user_submitted_at_idx
  on public.payment_submissions (user_id, submitted_at desc);

-- `invite_attempts_user_attempted_at_idx` is created with its table in Phase 2.

-- ---------------------------------------------------------------------------
-- 1b. Delta-pull indexes
-- ---------------------------------------------------------------------------

do $$
declare
  v_table text;
  -- Every domain table except delete_requests carries user_id; that one carries
  -- the requester instead and is handled below.
  v_tables text[] := array[
    'cases', 'case_history', 'notes', 'case_references', 'court_categories',
    'case_categories', 'courts', 'steps', 'case_types', 'on_behalfs',
    'conflict_log'
  ];
begin
  foreach v_table in array v_tables loop
    execute format(
      'create index if not exists %1$s_delta_idx on public.%1$I '
      '(server_updated_at, id)',
      v_table
    );
    execute format(
      'create index if not exists %1$s_firm_delta_idx on public.%1$I '
      '(firm_id, server_updated_at, id)',
      v_table
    );
    execute format(
      'create index if not exists %1$s_user_delta_idx on public.%1$I '
      '(user_id, server_updated_at, id)',
      v_table
    );
  end loop;
end;
$$;

create index if not exists delete_requests_delta_idx
  on public.delete_requests (server_updated_at, id);
create index if not exists delete_requests_firm_delta_idx
  on public.delete_requests (firm_id, server_updated_at, id);
create index if not exists delete_requests_requester_delta_idx
  on public.delete_requests (requested_by, server_updated_at, id);

-- ---------------------------------------------------------------------------
-- 2. Tombstone purge
-- ---------------------------------------------------------------------------

create or replace function public.purge_tombstones(p_retention_days integer default 180)
returns integer
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_cutoff timestamptz;
  v_table text;
  v_deleted integer;
  v_total integer := 0;
  -- Children before parents: the FK graph is case data -> cases -> the
  -- reference tables that cases point at, with case_categories and
  -- court_categories last. Deleting in this order never trips a foreign key.
  v_order text[] := array[
    'case_history',
    'delete_requests',
    'conflict_log',
    'notes',
    'case_references',
    'cases',
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
    execute format(
      'delete from public.%1$I where is_deleted = true '
      'and server_updated_at < $1',
      v_table
    )
    using v_cutoff;

    get diagnostics v_deleted = row_count;
    v_total := v_total + v_deleted;
  end loop;

  return v_total;
end;
$$;

comment on function public.purge_tombstones(integer) is
  'Deletes soft-deleted rows older than the retention (180 days by default), children first.';

-- Schedule it daily. pg_cron is a project-level extension: where it cannot be
-- created from SQL the function still exists and the schedule is made from the
-- dashboard instead (see supabase/README.md).
do $$
begin
  begin
    create extension if not exists pg_cron;
  exception
    when others then
      raise notice
        'pg_cron could not be created (%); schedule public.purge_tombstones() '
        'from the dashboard.', sqlerrm;
  end;

  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    -- Re-running replaces the job instead of stacking a second one.
    perform cron.unschedule('purge-tombstones')
     where exists (select 1 from cron.job where jobname = 'purge-tombstones');

    perform cron.schedule(
      'purge-tombstones',
      '15 3 * * *',
      'select public.purge_tombstones()'
    );

    raise notice 'pg_cron: purge-tombstones scheduled daily at 03:15.';
  else
    raise notice
      'pg_cron is not installed; public.purge_tombstones() exists but is not '
      'scheduled yet.';
  end if;
end;
$$;
