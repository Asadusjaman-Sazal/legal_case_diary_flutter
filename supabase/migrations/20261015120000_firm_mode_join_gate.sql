-- Firm mode, phase 3 — the join gate.
--
-- Three rulings land here, and they share one RPC because they are one decision
-- made at one moment: `firm_invites` redemption. The second guard this replaces
-- the shipped `join_firm` (20260929102300_phase3_join_firm.sql) had was only
-- "is this code valid"; everything below is what else has to be true before a
-- stranger's rows enter a chamber.
--
--   1. **A seat starts empty** (§2.1). Joining is refused when the redeemer
--      already holds their own diary: non-deleted rows they authored as an
--      individual — `firm_id is null` **and no scope owner**, which is what stops
--      a dissolved chamber's rows (§4.4) ever counting as anybody's own diary.
--      Rows authored *inside* a chamber are the chamber's and never block a
--      later join, which is what lets a removed member join another chamber with
--      the same account.
--   2. **The seat cap** (§5.3, §5.4). A tier sells seats — Pro 0, Firm 5, Firm
--      Plus 20 — and until now no `join_firm` of any version checked a seat
--      count at all, so a Firm chamber could seat a hundred associates. The cap
--      reads the **effective** tier, because a chamber whose subscription is
--      lapsed past the grace window has no tier in force, and a lapsed chamber is
--      deliberately still joinable (§2.4): its seats stay open while it is lapsed
--      and close again on renewal.
--   3. **The default permissions** (§3.1). A newly joined associate starts with
--      `can_add = true` and `can_edit = true`, superseding the shipped
--      `can_edit = false`; `can_delete` stays false, because deletion inside a
--      chamber runs through the owner-reviewed delete-request flow.
--
-- The §2.5 fumble is fixed in the same transaction: an already-member
-- redemption still answers `already_member`, but the code is **retired as
-- revoked** rather than consumed as `used_by`, so the owner's list reads
-- *retired* instead of *used by [member]* — the owner is not left thinking a new
-- colleague joined, and the code is still dead for a stranger, which was the only
-- reason the shipped version consumed it.
--
-- The refusal counts live cases and returns their number so the client can word
-- the sentence §2.1 specifies. Nothing is written on any refusal path, and none
-- of them raises: a returned status is what makes the outcome reportable rather
-- than a stack trace, except the rate limit, which the shipped version already
-- raises deliberately and this one keeps raising.
--
-- What the client is owed, and what this migration does NOT do (later work):
-- `ensure_firm`'s creation gate still points at `is_premium()`. It belongs with
-- the seat cap — creation needs Firm or above, and Pro's cap is 0 — but the
-- tier columns it would read at the same time do not exist yet, so the creation
-- gate moves with them; the seat cap below is written so that adding them is
-- one `when` branch and nothing else. This is the approved sequence's Phase 3;
-- the creation-gate re-point and `tier_pending` are owed separately, and the
-- seat check's live tier reads return null until `firms.tier` and
-- `mirror_owner_subscription_to_firm`'s widened trigger arrive.

-- What counts as *the caller's own diary*: rows they authored as an individual,
-- not rows authored inside a chamber they are (or were) a member of. A scope
-- owner marks an unscoped row as belonging to somebody by a dissolve, so such a
-- row is not a fresh diary either.
create or replace function public.individual_diary_cases(p_user_id uuid)
returns integer
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select pg_catalog.count(*)::integer
    from public.cases c
   where c.user_id = p_user_id
     and c.is_deleted = false
     and c.firm_id is null
     and c.scope_owner_id is null;
$$;

comment on function public.individual_diary_cases(uuid) is
  'Non-deleted cases the account authored while it had no chamber and no scope owner — the §2.1 seat is empty test.';

-- Whether the account holds rows that make its diary its own: the same four
-- case-data tables plus every reference table, where a row it added or edited
-- counts even after a soft delete (`is_deleted` is not consulted here; a deleted
-- custom court is still a row the account authored for itself).
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
    'on_behalfs'
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

comment on function public.holds_own_diary(uuid) is
  'Whether the account authored any firm-less, scope-owner-less row — the §2.1 test that a seat is not empty.';

-- How many seats the chamber's effective tier sells, or null for **unlimited**.
--
-- The tier map is a constant here rather than a lookup because there is nowhere
-- to look: the ladder's `firms.tier` column belongs to a later phase. Until it
-- arrives, a lapsed-or-not **premium** chamber is treated as a Firm chamber, and
-- the consequence is bounded and visible: a Firm Plus chamber sees its roster
-- refused at six rather than at twenty until the column lands, which the client
-- can word from the returned `seats`. Everything else is unchanged by the
-- substitution — see the note above about the creation gate; adding the column
-- is three lines here (`when 'firm_plus' then 20` already exists) and its
-- `mirror_owner_subscription_to_firm` widened trigger beside it.
--
-- Null is both "no tier in force" — a lapsed or never-purchased chamber, which
-- §2.4 keeps joinable — and "Unlimited by agreement". The two are the same
-- answer here on purpose: neither is a number to refuse at.
create or replace function public.firm_seat_cap(p_firm_id uuid)
returns integer
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select case
           when public.is_premium(f.owner_id) then 5
           else null
         end
    from public.firms f
   where f.id = p_firm_id;
$$;

comment on function public.firm_seat_cap(uuid) is
  'Seats the chamber''s effective tier sells (Firm 5 until firms.tier lands), null for unlimited or no tier in force.';

create or replace function public.join_firm(code text)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  -- Five failures per 15 minutes, and attempts older than a day are dropped by
  -- the call itself, so no scheduled job is needed.
  c_max_failures constant integer := 5;
  c_window constant interval := interval '15 minutes';
  c_retention constant interval := interval '1 day';

  -- Two values only ever compared with each other, so they carry no status of
  -- their own.
  c_role_associate constant text := 'associate';

  v_user_id uuid := auth.uid();
  v_code_hash text;
  v_invite public.firm_invites%rowtype;
  v_failures integer;
  v_used_at bigint;
  v_diary_cases integer;
  v_seat_cap integer;
  v_seats_taken integer;
  v_own_diary boolean;
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

  -- The normalization the client mirrors: trim, upper, then hash. Only the
  -- sha256 hex is ever compared, so a plaintext code exists only in the user's
  -- hands and the invite row (Task 20) must hash a code the same way.
  v_code_hash := public.sha256_hex(upper(pg_catalog.btrim(coalesce(code, ''))));

  select * into v_invite
    from public.firm_invites i
   where i.code_hash = v_code_hash
     and i.used_by is null
     and i.revoked = false
   for update;

  if not found then
    -- Non-exception return path: the attempt insert must commit.
    insert into public.invite_attempts (user_id) values (v_user_id);
    return jsonb_build_object('status', 'invalid_code');
  end if;

  v_used_at := (extract(epoch from clock_timestamp()) * 1000)::bigint;

  -- Retry by someone already in the firm. The code is retired as **revoked**,
  -- never as `used_by`, so the owner sees *retired* rather than a colleague who
  -- joined, while the code stays dead for a stranger. The single-use rule is
  -- unchanged; only its recording is.
  if exists (
    select 1 from public.firm_members m
     where m.firm_id = v_invite.firm_id and m.user_id = v_user_id
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

  -- A seat starts empty (§2.1). Rows authored inside a chamber are the chamber's
  -- and do not count, so a member removed from one chamber may still join
  -- another with the same account.
  v_diary_cases := public.individual_diary_cases(v_user_id);

  if public.holds_own_diary(v_user_id) then
    delete from public.invite_attempts a where a.user_id = v_user_id;

    return jsonb_build_object(
      'status', 'has_own_diary',
      'cases', v_diary_cases
    );
  end if;

  -- The seat cap (§5.3, §5.4). A member leaving deletes their `firm_members`
  -- row outright (`remove_firm_member`, phase 4 territory), so a plain count of
  -- the chamber's rows is the number of seats taken — the history of who was
  -- once here lives in the ledger's attribution, not in the membership table.
  v_seat_cap := public.firm_seat_cap(v_invite.firm_id);

  if v_seat_cap is not null then
    select pg_catalog.count(*) into v_seats_taken
      from public.firm_members m
     where m.firm_id = v_invite.firm_id;

    if v_seats_taken >= v_seat_cap then
      delete from public.invite_attempts a where a.user_id = v_user_id;

      return jsonb_build_object(
        'status', 'seats_full',
        'firm_id', v_invite.firm_id,
        'seats', v_seat_cap
      );
    end if;
  end if;

  -- The defaults of §3.1: members write from the first day, and the owner
  -- narrows them afterwards if he wants to. `can_delete` stays false because
  -- deletion in a chamber is the owner-reviewed request flow.
  -- `firm_members` carries no sync columns of its own (it is a live read, not a
  -- ledger table): the two stamps are the client's permission-freshness pair.
  insert into public.firm_members (
    firm_id, user_id, role, can_add, can_edit, can_delete,
    synced_at, permissions_synced_at
  )
  values (
    v_invite.firm_id, v_user_id, c_role_associate, true, true, false,
    v_used_at, v_used_at
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
  'Single-use invite redemption: rate limit, hash, empty-seat and seat-cap gates, membership, profile relink, invite consumed — one transaction.';

-- `anon` is named explicitly for the same reason as `approve_payment`: a direct
-- EXECUTE grant from Supabase's default privileges outlives a revoke of PUBLIC.
revoke all on function public.join_firm(text) from public, anon;
grant execute on function public.join_firm(text) to authenticated;

-- The three new helpers are `authenticated`-only, and `anon` is named
-- explicitly for the same reason as `join_firm` above: a direct EXECUTE grant
-- from Supabase's default privileges outlives a revoke of PUBLIC.
--
-- They are not opened to the app's client either. Each is a fact about **the
-- caller and their own chamber** — whether this account still holds an
-- individual diary, how many such cases it holds, and how many seats its
-- chamber sells — so a signed-out caller and a probing one must both be refused:
-- the gate's own refusal must not become an oracle for another account's diary,
-- and `firm_seat_cap` reads `firms` and `profiles`, which no client role may
-- read at all. `join_firm` and the screens' own local reads are what need them,
-- and both run as `authenticated` (or as the RPC's definer).
revoke all on function public.individual_diary_cases(uuid) from public, anon, authenticated;
revoke all on function public.holds_own_diary(uuid) from public, anon, authenticated;
revoke all on function public.firm_seat_cap(uuid) from public, anon, authenticated;

grant execute on function public.individual_diary_cases(uuid) to authenticated;
grant execute on function public.holds_own_diary(uuid) to authenticated;
grant execute on function public.firm_seat_cap(uuid) to authenticated;
