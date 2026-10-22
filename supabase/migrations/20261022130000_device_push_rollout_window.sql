-- ===========================================================================
-- Device limit (3/3) — writes get the same roll-out window as reads.
--
-- **Why.** `20261022110000` gave an unregistered session ("an install that has
-- not updated yet") until `device_rollout_end()` to READ, so the update strands
-- nobody, but gave it no such allowance to WRITE. The result was the opposite
-- of the promise in the plan: an install that had not updated could pull the
-- account's diary down and could not hand a single edit back up. Its queued
-- mutations were refused as `device_revoked` on the first push, and because a
-- refusal is not retryable the client marked each one `blocked` — visible in
-- Sync Status as *the server refused this change*, but never sent again on its
-- own. A limit that turns a lawyer's backup off silently is worse than one that
-- arrives a month later.
--
-- **What changes.** One branch, the same shape and the same date as
-- `device_may_read`'s: a session with **no row in `user_devices` at all** is
-- admitted to push while `now() < device_rollout_end()`. A session that has a
-- row is not affected in the slightest — an active device is admitted as
-- before, and a revoked device keeps exactly its 14-day flush window.
--
-- **Why this cannot become a loophole.** Revocation in this registry is a
-- timestamp on a row, never a deletion: `revoke_device` and
-- `device_trim_surplus` both `update` `revoked_at`, so every session the server
-- has ever seen a registration for still has its row. The unregistered branch is
-- therefore reachable only by a session that has never called `register_device`
-- — the old install, and nobody else. A device the server revoked, by any
-- reason and at any time, stays refused, including during the window.
--
-- **After the window nothing changes for a revoked device**, and an old install
-- stops writing at the same instant it stops reading: one date closes both
-- gates, so the two halves cannot drift apart again.
-- ===========================================================================

create or replace function public.device_may_push(p_at timestamptz default now())
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select public.current_session_id() is null
      or public.device_is_active()
      -- The roll-out case, identical to device_may_read's: a session that never
      -- registered is an install that has not updated yet, admitted only until
      -- the same date registrations stop being grandfathered.
      or (
           p_at < public.device_rollout_end()
           and not exists (
             select 1
               from public.user_devices d
              where d.user_id = auth.uid()
                and d.session_id = public.current_session_id()
           )
         )
      -- A revoked device may still hand its unsent work over before it erases.
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
  'True for an active device, a revoked device still inside its 14-day flush window, an unregistered session before the roll-out end (2026-11-21), or a caller with no session claim. A revoked session is never admitted by the roll-out branch, because revocation stamps a row rather than deleting it.';
