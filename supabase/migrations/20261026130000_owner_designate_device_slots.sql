-- 2026-10-26 — A chamber-tier buyer keeps the seats they paid for before the
-- firm exists.
--
-- The paywall sells Firm / Firm Plus / Enterprise as "up to N devices
-- simultaneously or up to N-1 associates". A buyer who has not created the
-- chamber yet is still on their personal account, and `device_cap` fell through
-- to `tier_device_cap`, which answers 1 for every chamber tier (the per-member
-- rule). The buyer therefore saw "Devices 1 of 1" after paying for five.
--
-- An account with a chamber-tier plan and no firm is an **owner-designate**: it
-- reads the tier's full seat cap (Firm 5, Firm Plus 10, Enterprise 20) for its
-- own devices. Once it owns a firm the existing owner branch applies — the
-- slots left after associates; a seated associate still reads 1, a
-- capacity-signed-out associate 0, and non-chamber tiers keep their own caps.
--
-- Table class: `profiles`/`firms`/`firm_members` remain pull-only caches; this
-- is a server-side cap function only. No table, column or grant changes.

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
           -- A chamber tier with no chamber yet is an owner-designate: it keeps
           -- the seats it paid for until an associate takes one. A non-chamber
           -- tier reads its own device cap.
           else coalesce(
             nullif(
               public.tier_seat_cap(
                 public.effective_tier(p.tier, p.tier_pending, p.tier_pending_from)
               ),
               0
             ),
             public.tier_device_cap(
               public.effective_tier(p.tier, p.tier_pending, p.tier_pending_from)
             )
           )
         end
    from public.profiles p
   where p.id = p_user_id;
$$;

comment on function public.device_cap(uuid) is
  'The caller''s concurrent-device allowance: a chamber owner gets the slots left after associates (at least 1); a chamber-tier account with no chamber keeps the tier''s full seat cap (Firm 5, Firm Plus 10, Enterprise 20); a seated associate 1; a capacity-signed-out associate 0; a non-chamber tier its own cap.';
