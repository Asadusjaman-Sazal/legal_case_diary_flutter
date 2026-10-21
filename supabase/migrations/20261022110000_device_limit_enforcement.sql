-- ===========================================================================
-- Device limit (2/2) — enforcement: writes, reads, and the flush window.
--
-- **Why.** `20261022100000` gives the server the registry and the decision
-- table; this migration makes an unregistered or revoked session unable to
-- write or pull. A limit a client can ignore by not calling `register_device`
-- is not a limit.
--
-- **Three gates.**
--
--   1. **Writes** — `push_changes` gains a guard. The existing body is not
--      re-typed: it is renamed to `push_changes_core` (grants and all) and a
--      small wrapper checks the device before delegating. Re-typing a 400-line
--      function to add one `if` is how its rules silently change.
--   2. **Reads and pulls** — pulls are plain PostgREST selects, so this is an
--      RLS change: `device_may_read()` is ANDed into the read policy of the
--      eleven ledger tables and `conflict_log`. Realtime is governed by the
--      same policies, so a revoked device stops receiving frames on its next
--      subscription.
--   3. **The flush window** — a revoked device may still **write** for 14 days
--      so its unsent work reaches the account before it erases (the user's
--      rule: nothing is erased that could have been saved). It may not read.
--
-- **What is deliberately not gated here.** `profiles` and the billing tables
-- stay readable: a revoked device needs its own profile to show the refusal
-- screen, and billing history is the account's, not the chamber's. The roster
-- (`firms`, `firm_members`) is left readable for the same reason — the device
-- erases at its next contact anyway. Recorded rather than silently widened.
--
-- **Trusted paths.** A caller with no session claim (psql, the service role,
-- every SQL proof in `supabase/tests`) is allowed through every gate. A
-- PostgREST request always carries a session claim, so no client can reach that
-- branch by stripping one.
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 1. The two predicates.
-- ---------------------------------------------------------------------------

-- Writes: an active device, or a revoked one inside its 14-day flush window.
create or replace function public.device_may_push(p_at timestamptz default now())
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select public.current_session_id() is null
      or public.device_is_active()
      or exists (
           select 1
             from public.user_devices d
            where d.user_id = auth.uid()
              and d.session_id = public.current_session_id()
              and d.revoked_at is not null
              and d.revoked_at + interval '14 days' > p_at
         );
$$;

comment on function public.device_may_push(timestamptz) is
  'True for an active device, a revoked device still inside its 14-day flush window, or a caller with no session claim.';

-- Reads: an active device. A revoked device reads nothing new. A session that
-- never registered is the roll-out case — an install that has not updated yet —
-- and is admitted only until the same date registrations stop being
-- grandfathered, so an old app keeps working through the update and no longer
-- after it.
create or replace function public.device_may_read(p_at timestamptz default now())
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select public.current_session_id() is null
      or public.device_is_active()
      or (
           p_at < public.device_rollout_end()
           and not exists (
             select 1
               from public.user_devices d
              where d.user_id = auth.uid()
                and d.session_id = public.current_session_id()
           )
         );
$$;

comment on function public.device_may_read(timestamptz) is
  'True for an active device, a caller with no session claim, or an unregistered session before the roll-out end (2026-11-21). A revoked session is always false.';

-- ---------------------------------------------------------------------------
-- 2. Writes: one guard in front of the existing push_changes.
-- ---------------------------------------------------------------------------

do $$
begin
  -- Idempotent: a second apply finds the core already in place.
  if to_regprocedure('public.push_changes_core(jsonb)') is null then
    alter function public.push_changes(jsonb) rename to push_changes_core;
  end if;
end;
$$;

revoke all on function public.push_changes_core(jsonb) from public, anon, authenticated;

create or replace function public.push_changes(rows jsonb)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if not public.device_may_push() then
    -- The client maps this message to its "this device was signed out" state.
    raise exception 'device_revoked' using errcode = '42501';
  end if;

  return public.push_changes_core(rows);
end;
$$;

comment on function public.push_changes(jsonb) is
  'The device gate in front of push_changes_core: refuses a revoked session that is past its flush window. A caller carrying no session (service role, psql) passes.';

revoke all on function public.push_changes(jsonb) from public, anon;
grant execute on function public.push_changes(jsonb) to authenticated, service_role;

-- ---------------------------------------------------------------------------
-- 3. Reads: the ledger tables and the merge log.
-- ---------------------------------------------------------------------------

-- The four case-data tables: one shape, one loop (copied from
-- `20261015100000` with `device_may_read()` added), so their spellings cannot
-- drift.
do $$
declare
  v_table text;
  v_tables text[] := array['cases', 'case_history', 'notes', 'case_references'];
begin
  foreach v_table in array v_tables loop
    execute format(
      'drop policy if exists %1$s_select_scoped on public.%1$I',
      v_table
    );
    execute format(
      'create policy %1$s_select_scoped on public.%1$I for select to '
      'authenticated using (public.device_may_read() and '
      '((user_id = auth.uid() and firm_id is null and '
      'scope_owner_id is null) or firm_id = public.current_firm_id() or '
      'scope_owner_id = auth.uid()))',
      v_table
    );
  end loop;
end;
$$;

-- The six reference tables keep the built-in baseline readable to every
-- registered install; only a *custom* row is scoped.
do $$
declare
  v_table text;
  v_tables text[] := array[
    'court_categories', 'case_categories', 'courts', 'steps', 'case_types',
    'on_behalfs'
  ];
begin
  foreach v_table in array v_tables loop
    execute format(
      'drop policy if exists %1$s_select_scoped on public.%1$I',
      v_table
    );
    execute format(
      'create policy %1$s_select_scoped on public.%1$I for select to '
      'authenticated using (public.device_may_read() and '
      '(is_custom = false or (user_id = auth.uid() and '
      'firm_id is null and scope_owner_id is null) or firm_id = '
      'public.current_firm_id() or scope_owner_id = auth.uid()))',
      v_table
    );
  end loop;
end;
$$;

-- delete_requests: the author column is `requested_by`.
drop policy if exists delete_requests_select_firm on public.delete_requests;
drop policy if exists delete_requests_select_scoped on public.delete_requests;
create policy delete_requests_select_scoped on public.delete_requests
  for select to authenticated
  using (
    public.device_may_read()
    and (
      (requested_by = auth.uid() and firm_id is null and scope_owner_id is null)
      or firm_id = public.current_firm_id()
      or scope_owner_id = auth.uid()
    )
  );

-- conflict_log: membership condition only, no scope owner.
drop policy if exists conflict_log_select_own on public.conflict_log;
create policy conflict_log_select_own on public.conflict_log
  for select to authenticated
  using (
    public.device_may_read()
    and user_id = auth.uid()
    and (
      firm_id is null
      or firm_id is not distinct from public.current_firm_id()
    )
  );

-- ---------------------------------------------------------------------------
-- 4. Grants.
-- ---------------------------------------------------------------------------

revoke all on function public.device_may_push(timestamptz) from public, anon;
revoke all on function public.device_may_read(timestamptz) from public, anon;
grant execute on function public.device_may_push(timestamptz) to authenticated, service_role;
grant execute on function public.device_may_read(timestamptz) to authenticated, service_role;
