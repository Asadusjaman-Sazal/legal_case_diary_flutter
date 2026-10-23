-- ===========================================================================
-- Device registry retention — six months of history, the newest revoked row.
--
-- Every sign-in creates one `user_devices` row; the revoked ones are history,
-- and without a policy they accumulate forever. The owner chose this rule:
--
--   * every row from the last six months is kept;
--   * an active row (`revoked_at is null`) is never deleted;
--   * for each `(user_id, device_key)` the newest revoked row is kept even
--     when it is older than six months, so a device that returns late still
--     sees the revocation and discards;
--   * only revoked rows older than six months that have a strictly newer
--     revoked row for the same account/device key are deleted.
--
-- **Age is `revoked_at`, never `last_seen_at`:** the BEFORE UPDATE trigger
-- `trg_user_devices_touch` rewrites `last_seen_at := now()` on every update,
-- including the revocation itself and a later wipe acknowledgement, so it
-- cannot measure how long a session has been revoked.
--
-- **A DELETE here is silent:** no table references `user_devices`, no DELETE
-- trigger exists, and `device_tokens.device_key` is plain text with no foreign
-- key. Nothing cascades and no Realtime frame is sent.
--
-- **This function is deliberately internal.** `purge_tombstones` has no revoke
-- and is therefore callable by client roles with a caller-chosen retention; a
-- retention job for the device registry must not repeat that. Only the owner
-- and the pg_cron job may execute this one.
--
-- There is no delete in this migration. The first scheduled run (or a
-- deliberate manual run) performs the first deletion.
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 1. The revoked-row lookup behind the "newest revoked per device" check.
-- ---------------------------------------------------------------------------

create index if not exists user_devices_revoked_retention_idx
  on public.user_devices (user_id, device_key, revoked_at desc)
  where revoked_at is not null;

comment on index public.user_devices_revoked_retention_idx is
  'Retention lookup: the newest revoked row for one (user_id, device_key). Partial because active rows are never pruned.';

-- ---------------------------------------------------------------------------
-- 2. The pruner.
-- ---------------------------------------------------------------------------

create or replace function public.prune_user_devices(
  p_retention interval default interval '6 months'
)
returns bigint
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_cutoff timestamptz;
  v_deleted bigint;
begin
  if p_retention is null or p_retention <= interval '0' then
    raise exception
      'prune_user_devices: p_retention must be a positive interval, got %',
      p_retention;
  end if;

  v_cutoff := now() - p_retention;

  -- The correlated EXISTS is the rule itself: an old row survives only when no
  -- newer revoked row exists for the same account/device key. Rows tied at the
  -- newest instant are all kept; none is strictly older than another.
  delete from public.user_devices d
   where d.revoked_at is not null
     and d.revoked_at < v_cutoff
     and exists (
       select 1
         from public.user_devices newer
        where newer.user_id = d.user_id
          and newer.device_key = d.device_key
          and newer.revoked_at is not null
          and newer.revoked_at > d.revoked_at
     );

  get diagnostics v_deleted = row_count;

  raise notice
    'prune_user_devices: % row(s) deleted; revoked before %, newest revoked per (user_id, device_key) kept',
    v_deleted, v_cutoff;

  return v_deleted;
end;
$$;

comment on function public.prune_user_devices(interval) is
  'Deletes revoked user_devices rows older than p_retention (six months by default) except the newest revoked row(s) for each (user_id, device_key); active rows are never touched. Internal: no client role may execute.';

-- A new function in public reaches anon/authenticated through Supabase's default
-- privileges, so the revoke is explicit. The owner and the pg_cron job keep it.
revoke all on function public.prune_user_devices(interval) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 3. Schedule it daily, after the tombstone purge.
-- ---------------------------------------------------------------------------

do $$
begin
  begin
    create extension if not exists pg_cron;
  exception
    when others then
      raise notice
        'pg_cron could not be created (%); schedule public.prune_user_devices() '
        'from the dashboard.', sqlerrm;
  end;

  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    -- Re-running replaces the job instead of stacking a second one. The
    -- tombstone job is a different name and is never touched here.
    perform cron.unschedule('prune-user-devices')
     where exists (select 1 from cron.job where jobname = 'prune-user-devices');

    perform cron.schedule(
      'prune-user-devices',
      '45 3 * * *',
      'select public.prune_user_devices()'
    );

    raise notice 'pg_cron: prune-user-devices scheduled daily at 03:45.';
  else
    raise notice
      'pg_cron is not installed; public.prune_user_devices() exists but is not '
      'scheduled yet.';
  end if;
end;
$$;
