-- Device trim counts the caller only when it holds a slot.
--
-- The proof `supabase/tests/device_limit_test.sql` caught this on its first run:
-- a third sign-in on a two-device Pro account was **admitted**, and one of the
-- two devices already holding the slots was revoked as `lapse` — the plan-full
-- screen could never appear, and the lawyer's other phone was told the plan had
-- changed when nothing had.
--
-- The cause was here. `register_device` trims before it knows whether the caller
-- already has a row, and this function always kept `p_cap - 1` devices *other
-- than the caller* — arithmetic that is right only when the caller occupies one
-- of the slots. A brand-new device holds none, so the first trim of its
-- registration threw away a legitimate device and then found a free slot.
--
-- The fix is to ask the table instead of assuming: a caller with an active row
-- keeps the cap minus its own slot, and a caller with no row leaves the whole
-- cap to the devices that are actually there. Trimming above the cap still
-- happens for both — a fallen ceiling, or an account that is over it, is
-- trimmed to the cap and no further, so a new device still meets the plan-full
-- rules rather than a silent eviction.
--
-- Everything else is unchanged: the function returns without touching anything
-- while the account has no live plan, revokes the surplus as `lapse` (not
-- `cap`, so the owner is told the plan changed), clears the evicted devices'
-- push tokens in the same statement pair, and never revokes the caller.

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
  v_holds_slot boolean;
  v_ids uuid[];
  v_keys text[];
begin
  if not public.has_sync_entitlement(p_user_id) then
    return;
  end if;

  -- Does the caller already hold one of the slots? A brand-new device does not,
  -- and must not be counted as if it did.
  v_holds_slot := exists (
    select 1
      from public.user_devices d
     where d.user_id = p_user_id
       and d.session_id = p_session_id
       and d.revoked_at is null
  );

  select array_agg(s.id), array_agg(s.device_key)
    into v_ids, v_keys
    from (
      select d.id, d.device_key
        from public.user_devices d
       where d.user_id = p_user_id
         and d.revoked_at is null
         and d.session_id is distinct from p_session_id
       order by d.last_seen_at desc
       offset greatest(p_cap - case when v_holds_slot then 1 else 0 end, 0)
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
  'Revokes the devices above the cap after the ceiling falls (downgrade, lapse and renewal), least recently seen first and never the caller, and only while the account has a live plan. The caller counts against the cap only when it already holds an active row, so a device signing in for the first time does not evict a device that does.';
