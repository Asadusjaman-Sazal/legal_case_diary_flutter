-- Firm Mode Phase 7, the behavioural half — the seat cap reads the stored tier,
-- and a chamber needs Firm. (The blueprint numbers these two phases the other way
-- round: Phase 7 is the stored tier plus this gate, Phase 8 is the ten-plan
-- ladder that `20261016120000` also carries. Both files landed in one pass, as
-- Phase 7's hazard requires.)
--
-- Both functions below were written before the tier existed. They are rebuilt
-- here, after `20261016120000_firm_mode_stored_tier.sql` added the columns and
-- the ladder's keys, because both now read those columns and neither could have
-- been expressed before them.
--
-- The two rules this migration is:
--
--   1. **`firm_seat_cap` reads the chamber's tier** (blueprint Phase 8): Pro 0,
--      Firm 5, Firm Plus 20. It previously asked `is_premium(owner)` and
--      answered 5 for anyone premium, so a Firm Plus chamber was capped at the
--      Firm number and a Pro owner's chamber — which cannot seat anybody — was
--      capped at 5. A cap that does not know the tier cannot enforce §5.4's
--      ceilings.
--
--   2. **Creating a chamber needs the Firm tier or above** (blueprint Phase 8,
--      user ruling): `ensure_firm`'s gate moves from `is_premium()` to the tier.
--      Pro's cap is 0, so a Pro owner could otherwise build a chamber nobody can
--      be invited into — the gate belongs with the cap, not with a bare premium
--      check. The refusal keeps the same `status` shape the client already
--      handles and names the reason in a new key rather than reusing
--      `premium_required`, which would tell a paying Pro user they are not
--      premium.
--
-- A seat cap binds **new joins only**: nobody is auto-removed by a billing
-- change (blueprint §5.4). Neither function here removes a member, and this
-- migration touches no membership row.
--
-- The cap is `null` for a chamber with no paid tier. In the join path a null
-- cap is **not** a refusal: `join_firm` skips its whole seat block when the cap
-- is null, so null means "no cap is enforced here". That is the existing
-- behaviour and it is unchanged by this migration — which is exactly why the
-- chamber's tier has to be right from its first moment, and why the creation
-- below now writes it (see `ensure_firm`, step 2). A chamber created by an
-- account that holds a tier would otherwise sit at the column default, `free`,
-- cap null, and take members without a ceiling until its owner's subscription
-- next changed.
--
-- Table class: `firms` stays a server-owned row and a **pull-only cache** on the
-- device; `firm_members` is unchanged, and no policy is added or dropped here.
--
-- APPLIED to the live project `lsthasywrdrhuuxnykau` on 2026-10-16, after
-- `20261016120000_firm_mode_stored_tier.sql` — it reads the `firms.tier` column
-- that migration adds — and recorded in `supabase_migrations.schema_migrations`.
--
-- Proven by `supabase/tests/firm_mode_stored_tier_test.sql` and re-checked by
-- `supabase/tests/firm_mode_join_gate_test.sql`, both run against the applied
-- project: a Pro chamber answers 0 seats, a Firm chamber 5, and a free or Pro
-- caller is refused at the creation gate with `firm_tier_required`.

-- ---------------------------------------------------------------------------
-- 1. The seat cap, by the chamber's stored tier.
-- ---------------------------------------------------------------------------

-- The tier is read through `effective_tier` so a chamber mid-downgrade is capped
-- by the tier actually in force, not by the newer one it has not paid for yet.
-- `create or replace`, never `drop function`: a dropped function is a new
-- object, and a new function carries Postgres's default of execute for PUBLIC,
-- which undoes the revoke `20261015120000_firm_mode_join_gate.sql` made. The
-- explicit revoke/grant pair at the foot of this file states the answer anyway.
create or replace function public.firm_seat_cap(p_firm_id uuid)
returns integer
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select case public.effective_tier(f.tier, f.tier_pending, f.tier_pending_from)
           when 'firm' then 5
           when 'firm_plus' then 20
           -- Pro's cap is 0, and the arm had to be written out: `else null`
           -- would engulf it, and a null answer is not a small ceiling but no
           -- ceiling at all — `join_firm` runs its seat check only when this
           -- answer is not null, so a Pro chamber would take unlimited
           -- associates. Pro takes nobody new, which is what makes the creation
           -- gate below the coherent answer rather than a warning. Only "no tier
           -- in force" — free, or a lapse with no paid history — is null, which
           -- §2.4 keeps joinable.
           when 'pro' then 0
           else null
         end
    from public.firms f
   where f.id = p_firm_id;
$$;

comment on function public.firm_seat_cap(uuid) is
  'How many associates a chamber may hold: Firm 5, Firm Plus 20, Pro 0 (no join may be taken), null when the chamber holds no paid tier. Read from the chamber''s stored, effective tier — a cap binds new joins only and never removes a member.';

-- ---------------------------------------------------------------------------
-- 2. The chamber-creation gate: Firm or above.
-- ---------------------------------------------------------------------------

-- `ensure_firm` is ~5.4 KB and two things in it change: its gate, and the tier
-- the chamber is created with. The whole body is re-issued with only those two
-- touched — the membership guard, the idempotent re-call, the stamping of
-- existing rows on a first creation and the rename path are otherwise the version
-- in `20261015110000_firm_mode_creation_and_scope.sql`, so a re-issue cannot
-- silently change behaviour.
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
  -- True only when this call created the firm: the stamping below is the
  -- creation's own act, and an idempotent re-call (a rename, a repair) must not
  -- re-stamp rows a member has since written.
  v_created boolean := false;
  v_table text;
  v_case_tables text[] := array[
    'cases', 'case_history', 'notes', 'case_references'
  ];
  v_reference_tables text[] := array[
    'court_categories', 'case_categories', 'courts', 'steps', 'case_types',
    'on_behalfs'
  ];
  -- The tier required to create a chamber (Phase 7's behavioural half): Firm is
  -- rank 2 on the ladder free 0 / pro 1 / firm 2 / firm_plus 3.
  c_required_tier_rank constant integer := 2;
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
  -- Captured immediately: `FOUND` belongs to the most recent SQL statement, and
  -- the membership guard below runs one of its own.
  v_has_firm := found;

  -- Membership guard: refuse to become the owner of a new firm while the
  -- caller's profile points at a firm they do not own. Returned rather than
  -- raised so the answer is a value the client can report; nothing is written.
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
    -- The transition to firm mode is the tier-gated step. The gate is Firm or
    -- above rather than premium, because Pro's seat cap is 0: a chamber on Pro
    -- could never take a member, so Pro must not be able to build one. The tier
    -- in force is read, so an approval still being settled does not open the
    -- gate early and a mid-term downgrade is honoured on its own date.
    select public.effective_tier(p.tier, p.tier_pending, p.tier_pending_from)
      into v_profile_tier
      from public.profiles p
     where p.id = v_user_id;

    if public.tier_rank(v_profile_tier) < c_required_tier_rank then
      -- A distinct reason from `premium_required`: a paying Pro user told they
      -- are "not premium" would be told something untrue. The status is a value
      -- the client already reports, so no new handling shape is needed.
      return jsonb_build_object('status', 'firm_tier_required');
    end if;

    -- `created_at` is a server instant (`timestamptz`) and takes the column
    -- default: the bigint `v_now` below is epoch ms for the client-facing
    -- `firm_members` stamps only.
    --
    -- The chamber takes its owner's tier here, in the same statement that makes
    -- it, because the seat cap reads this row: a chamber left at the column
    -- default would answer `null` — no cap enforced — for every join until the
    -- owner's subscription next changed, which is the opposite of the ceiling
    -- this migration exists to enforce. The gate above has already read the
    -- effective tier into `v_profile_tier`, so the chamber starts on exactly the
    -- tier the gate allowed, and the mirror keeps it there from the next
    -- approval on.
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
      -- No profile row: the sign-up trigger creates one, so this is a bug state,
      -- never something to explain to a user. Raising here rolls the firm back.
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

  -- The conversion itself: firm scope for every policy, owner role for the app.
  update public.profiles p
     set firm_id = v_firm.id,
         role = 'owner'
   where p.id = v_user_id;

  -- The owner holds every permission explicitly, so `can_edit_firm` /
  -- `can_delete_firm` and the client's cached flags agree with the role.
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

  -- Sharing the diary: every ledger row the owner authored while firm-less
  -- becomes the chamber's (§1). The four case-data tables first, then the six
  -- reference tables — custom rows only, because a built-in row (`is_custom =
  -- false`) has no author and is the globally shared baseline every install
  -- reads — and finally the owner's pending delete requests.
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

    -- A resolved request is audit history rather than a ledger row, so only a
    -- pending one follows the owner into his chamber.
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

comment on function public.ensure_firm(text) is
  'Creates (or renames) the calling user''s chamber and moves them into it as owner. Requires the Firm tier or above: Pro''s seat cap is 0, so a chamber on Pro could never take a member. Idempotent — a re-call renames rather than re-creating, and only a first creation stamps the user''s existing rows with the firm.';

-- ---------------------------------------------------------------------------
-- 3. Grants: the same shape as `20261015120000`, restated.
-- ---------------------------------------------------------------------------

-- `create or replace` preserves a function's ACL, so nothing here is strictly
-- required — but the ACL is then only a fact about an earlier file, and the
-- `drop function` this file used to open with is exactly how such a fact gets
-- lost without a red test. Both objects therefore state their own answer:
-- execute for `authenticated` alone, and never PUBLIC, which would hand a
-- signed-out caller the seat count of any chamber id it could guess.
revoke all on function public.ensure_firm(text) from public, anon;
revoke all on function public.firm_seat_cap(uuid) from public, anon, authenticated;
grant execute on function public.ensure_firm(text) to authenticated;
grant execute on function public.firm_seat_cap(uuid) to authenticated;
