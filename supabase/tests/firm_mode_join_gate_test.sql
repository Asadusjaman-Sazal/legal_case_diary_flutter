-- Firm mode join-gate test — proves `20261015120000_firm_mode_join_gate.sql`.
--
-- Self-contained: throwaway accounts are created inside one transaction that is
-- rolled back, so no fixture survives. `join_firm` is called as the role it is
-- granted to (`authenticated`) with `request.jwt.claims` set, which is what
-- `auth.uid()` reads — so the RPC's own guards, its locks and its rate limiter
-- all run for real rather than being simulated.
--
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/firm_mode_join_gate_test.sql
--
-- Six checks, in order:
--
--   * **a seat starts empty** — an account holding an individual case is
--     refused with the count, and the refusal writes nothing: no membership, no
--     profile relink, no consumed code;
--   * **rows inside a chamber do not block a later join** — the same account's
--     chamber-authored row leaves `holds_own_diary` false, so a removed member
--     may join another chamber with the same account;
--   * **an already-member redemption retires the code as revoked**, not as
--     `used_by`, while still answering `already_member` and still killing the
--     code for a stranger;
--   * **the §3.1 defaults** — a joined associate lands with `can_add` and
--     `can_edit` true and `can_delete` false, both freshness stamps written;
--   * **the seat cap** — a Firm chamber sells 5, the sixth join is refused with
--     the cap in the answer, a Pro chamber sells 0, and a chamber holding no
--     paid tier has no cap at all and stays joinable (§2.4). Since firm mode's
--     Phase 7 the cap is read from the chamber's **stored tier**, so a lapse
--     leaves the tier it paid for in place and only a chamber with no paid
--     history is the uncapped one;
--   * **the rate limiter** still raises after five failures and still clears on
--     a success.

begin;

-- ---------------------------------------------------------------------------
-- Assertion helpers (the shape the other smoke tests use)
-- ---------------------------------------------------------------------------

create or replace function pg_temp.assert_true(p_condition boolean, p_message text)
returns void
language plpgsql
as $$
begin
  if p_condition is not true then
    raise exception 'JOIN FAIL: %', p_message;
  end if;
end;
$$;

-- Makes auth.uid() resolve to p_user, as the given role.
create or replace function pg_temp.as_user(p_role text, p_user uuid)
returns void
language plpgsql
as $$
begin
  perform set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', p_user::text, 'role', p_role)::text,
    true
  );
  execute format('set local role %I', p_role);
end;
$$;

-- Puts the session back the way it was found: the role **and** the claims
-- setting. Clearing the claim is not tidiness. Since firm mode's Phase 5 the
-- permission trigger reads `auth.uid()`, and `reset role` restores the role but
-- leaves `request.jwt.claims` behind — so a fixture staged after an
-- impersonation would be judged as that member's write and refused
-- `add_not_permitted`, which is exactly what happened before this helper
-- existed.
create or replace function pg_temp.as_owner()
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims', '', true);
  execute 'reset role';
end;
$$;

-- Redeems p_code as p_user and returns the RPC's own jsonb answer.
create or replace function pg_temp.redeem(p_user uuid, p_code text)
returns jsonb
language plpgsql
as $$
declare
  v_out jsonb;
begin
  perform pg_temp.as_user('authenticated', p_user);
  v_out := public.join_firm(p_code);
  perform pg_temp.as_owner();
  return v_out;
end;
$$;

-- The invite row behind a code, as the server stored it.
create or replace function pg_temp.invite_of(p_firm uuid, p_code text)
returns public.firm_invites
language sql
as $$
  select i from public.firm_invites i
   where i.firm_id = p_firm
     and i.code_hash = public.sha256_hex(upper(pg_catalog.btrim(p_code)));
$$;

-- ---------------------------------------------------------------------------
-- Fixtures
-- ---------------------------------------------------------------------------

create temporary table gate_fixtures (
  name text primary key,
  id text not null
) on commit drop;

do $$
declare
  c_owner uuid := gen_random_uuid();
  c_empty uuid := gen_random_uuid();
  c_diary uuid := gen_random_uuid();
  c_member uuid := gen_random_uuid();
  c_filler uuid;
  v_firm uuid := gen_random_uuid();
  v_now_ms bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint;
  v_court text;
  v_on_behalf text;
  i integer;
  v_result jsonb;
  v_row public.firm_members%rowtype;
  v_invite public.firm_invites%rowtype;
begin
  -- The built-in baseline every install reads, used to make a valid case row.
  select id into v_court from public.courts where is_custom = false limit 1;
  select id into v_on_behalf from public.on_behalfs limit 1;

  insert into pg_temp.gate_fixtures values
    ('owner', c_owner::text), ('empty', c_empty::text),
    ('diary', c_diary::text), ('member', c_member::text),
    ('firm', v_firm::text), ('court', v_court),
    ('on_behalf', v_on_behalf);

  -- Accounts. The sign-up trigger writes each profile row.
  insert into auth.users (id, email, email_confirmed_at, created_at, updated_at,
                          is_sso_user, is_anonymous)
  values
    (c_owner, 'gate-owner@test.local', now(), now(), now(), false, false),
    (c_empty, 'gate-empty@test.local', now(), now(), now(), false, false),
    (c_diary, 'gate-diary@test.local', now(), now(), now(), false, false),
    (c_member, 'gate-member@test.local', now(), now(), now(), false, false);

  -- The owner rides a live subscription, and the tier that subscription bought
  -- is stored rather than derived: `firm_seat_cap` reads the chamber's tier, so
  -- a fixture that left it at the `free` default would be asserting about a
  -- chamber holding no paid tier at all. Firm's 5 seats is what this file's
  -- seat check is about.
  update public.profiles
     set subscription_expiry = now() + interval '30 days',
         subscription_status = 'active',
         tier = 'firm'
   where id = c_owner;

  insert into public.firms (id, name, owner_id, subscription_status,
                            subscription_expiry, tier)
  values (v_firm, 'Gate Chamber', c_owner, 'active',
          now() + interval '30 days', 'firm');

  insert into public.firm_members (firm_id, user_id, role, can_add, can_edit, can_delete)
  values (v_firm, c_owner, 'owner', true, true, true);

  update public.profiles set firm_id = v_firm, role = 'owner' where id = c_owner;

  -- One code per refusal and per join: 01 for the emptied seat, 02 for the
  -- retired code, 03 for the defaults, 04 for the cap and the lapse, and 05 for
  -- the Pro chamber's 0 (firm mode's Phase 7).
  insert into public.firm_invites (firm_id, code_hash, created_by, created_at)
  values
    (v_firm, public.sha256_hex(upper('GATECODE01')), c_owner, v_now_ms),
    (v_firm, public.sha256_hex(upper('GATECODE02')), c_owner, v_now_ms),
    (v_firm, public.sha256_hex(upper('GATECODE03')), c_owner, v_now_ms),
    (v_firm, public.sha256_hex(upper('GATECODE04')), c_owner, v_now_ms),
    (v_firm, public.sha256_hex(upper('GATECODE05')), c_owner, v_now_ms);

  -- -------------------------------------------------------------------------
  -- 1. A seat starts empty: an individual case blocks the join (§2.1)
  -- -------------------------------------------------------------------------

  insert into public.cases (
    id, user_id, firm_id, scope_owner_id, is_deleted, case_number,
    petitioner, respondent, case_type, court_id, on_behalf_id,
    created_at, updated_at, version, server_updated_at
  )
  values (
    'gate-case-1', c_diary, null, null, false, 'GATE-1',
    'Petitioner', 'Respondent', 'civil', v_court, v_on_behalf,
    v_now_ms, v_now_ms, 1, now()
  );

  v_result := pg_temp.redeem(c_diary, 'GATECODE01');
  perform pg_temp.assert_true(
    v_result ->> 'status' = 'has_own_diary',
    'an account with its own diary was not refused: ' || coalesce(v_result::text, 'null')
  );
  perform pg_temp.assert_true(
    (v_result ->> 'cases')::int = 1,
    'the refusal did not carry the case count: ' || coalesce(v_result::text, 'null')
  );
  perform pg_temp.assert_true(
    not exists (
      select 1 from public.firm_members
       where firm_id = v_firm and user_id = c_diary
    ),
    'the refused join wrote a membership row'
  );
  perform pg_temp.assert_true(
    (select p.firm_id from public.profiles p where p.id = c_diary) is null,
    'the refused join relinked the profile'
  );
  perform pg_temp.assert_true(
    (pg_temp.invite_of(v_firm, 'GATECODE01')).used_by is null,
    'the refused join consumed the invite code'
  );

  -- -------------------------------------------------------------------------
  -- 2. A chamber-authored row is the chamber's, not a diary (§2.1, second half)
  -- -------------------------------------------------------------------------

  -- The step-1 case is the *only* thing that made that seat non-empty, so it
  -- goes first: this half is about what a chamber row does to a clean account,
  -- and leaving the individual row behind would be testing the previous case
  -- again.
  delete from public.cases where id = 'gate-case-1';

  insert into public.cases (
    id, user_id, firm_id, scope_owner_id, is_deleted, case_number,
    petitioner, respondent, case_type, court_id, on_behalf_id,
    created_at, updated_at, version, server_updated_at
  )
  values (
    'gate-case-2', c_diary, v_firm, null, false, 'GATE-2',
    'Petitioner', 'Respondent', 'civil', v_court, v_on_behalf,
    v_now_ms, v_now_ms, 1, now()
  );

  perform pg_temp.assert_true(
    not public.holds_own_diary(c_diary),
    'a chamber-authored row was counted as the account''s own diary'
  );
  perform pg_temp.assert_true(
    public.individual_diary_cases(c_diary) = 0,
    'a chamber-authored row was counted as an individual case'
  );

  -- An unscoped row that a dissolve handed to a scope owner is the chamber's
  -- business, not a fresh diary either (§4.4) — but the *member* may still be in
  -- the chamber that owns it, so this is checked through the helper rather than
  -- through `join_firm`, which would answer `already_member` first.
  update public.cases set firm_id = null, scope_owner_id = c_owner
   where id = 'gate-case-2';
  perform pg_temp.assert_true(
    not public.holds_own_diary(c_diary),
    'a scope-owned row counted as the account''s own diary (§4.4)'
  );
  perform pg_temp.assert_true(
    public.individual_diary_cases(c_diary) = 0,
    'a scope-owned row was counted as an individual case'
  );

  -- And the two helpers agree with `join_firm`: with a scope-owned row but no
  -- individual one, a different empty account still joins cleanly.
  delete from public.cases where id = 'gate-case-2';

  -- -------------------------------------------------------------------------
  -- 3. An already-member redemption retires the code as revoked (§2.5)
  -- -------------------------------------------------------------------------

  v_result := pg_temp.redeem(c_owner, 'GATECODE02');
  perform pg_temp.assert_true(
    v_result ->> 'status' = 'already_member',
    'a member''s own code did not answer already_member: ' || coalesce(v_result::text, 'null')
  );

  v_invite := pg_temp.invite_of(v_firm, 'GATECODE02');
  perform pg_temp.assert_true(
    v_invite.revoked,
    'the already-member code was not retired as revoked'
  );
  perform pg_temp.assert_true(
    v_invite.used_by is null,
    'the already-member code was consumed as used_by instead of revoked'
  );

  -- -------------------------------------------------------------------------
  -- 4. A join lands with the §3.1 defaults
  -- -------------------------------------------------------------------------

  v_result := pg_temp.redeem(c_empty, 'GATECODE03');
  perform pg_temp.assert_true(
    v_result ->> 'status' = 'joined',
    'an empty account could not join: ' || coalesce(v_result::text, 'null')
  );

  select * into v_row from public.firm_members
   where firm_id = v_firm and user_id = c_empty;
  perform pg_temp.assert_true(v_row.role = 'associate', 'the join wrote the wrong role');
  perform pg_temp.assert_true(v_row.can_add, 'a joining associate could not add');
  perform pg_temp.assert_true(
    v_row.can_edit,
    'a joining associate could not edit — can_edit should supersede the shipped false'
  );
  perform pg_temp.assert_true(not v_row.can_delete, 'a joining associate could delete');
  perform pg_temp.assert_true(
    v_row.synced_at is not null and v_row.permissions_synced_at is not null,
    'the join did not stamp the permission-freshness pair'
  );
  perform pg_temp.assert_true(
    (select p.firm_id from public.profiles p where p.id = c_empty) = v_firm
      and (select p.role from public.profiles p where p.id = c_empty) = 'associate',
    'the join did not relink the profile as an associate'
  );
  perform pg_temp.assert_true(
    (pg_temp.invite_of(v_firm, 'GATECODE03')).used_by = c_empty,
    'the join did not consume the code as used_by'
  );

  -- -------------------------------------------------------------------------
  -- 5. The seat cap by tier (§5.3, §5.4) and the chamber that still joins with
  --    no paid tier (§2.4)
  -- -------------------------------------------------------------------------

  perform pg_temp.assert_true(
    public.firm_seat_cap(v_firm) = 5,
    'a live Firm chamber did not sell 5 seats'
  );

  -- Pro's cap is 0 and must be a number, not a silence: `join_firm` runs its
  -- whole seat check only when the answer is not null, so a null here is an
  -- uncapped chamber. This is the ruling the creation gate rests on.
  update public.profiles set tier = 'pro' where id = c_owner;
  update public.firms set tier = 'pro' where id = v_firm;

  perform pg_temp.assert_true(
    public.firm_seat_cap(v_firm) = 0,
    'a Pro chamber did not sell 0 seats'
  );

  v_result := pg_temp.redeem(c_member, 'GATECODE05');
  perform pg_temp.assert_true(
    v_result ->> 'status' = 'seats_full',
    'a Pro chamber accepted a join: ' || coalesce(v_result::text, 'null')
  );
  perform pg_temp.assert_true(
    (v_result ->> 'seats')::int = 0,
    'the Pro refusal did not carry its 0 cap: ' || coalesce(v_result::text, 'null')
  );

  -- Firm Plus is 20. Restored to Firm afterwards, because the fillers below
  -- bring this chamber to Firm's own cap.
  update public.profiles set tier = 'firm_plus' where id = c_owner;
  update public.firms set tier = 'firm_plus' where id = v_firm;
  perform pg_temp.assert_true(
    public.firm_seat_cap(v_firm) = 20,
    'a Firm Plus chamber did not sell 20 seats'
  );
  update public.profiles set tier = 'firm' where id = c_owner;
  update public.firms set tier = 'firm' where id = v_firm;

  -- owner + empty = 2, so three fillers bring the chamber to its cap.
  for i in 1..3 loop
    c_filler := gen_random_uuid();
    insert into auth.users (id, email, email_confirmed_at, created_at, updated_at,
                            is_sso_user, is_anonymous)
    values (c_filler, 'gate-filler' || i || '@test.local', now(), now(), now(), false, false);
    insert into public.firm_members (firm_id, user_id, role, can_add, can_edit, can_delete)
    values (v_firm, c_filler, 'associate', true, true, false);
  end loop;

  v_result := pg_temp.redeem(c_member, 'GATECODE04');
  perform pg_temp.assert_true(
    v_result ->> 'status' = 'seats_full',
    'a full chamber still accepted a join: ' || coalesce(v_result::text, 'null')
  );
  perform pg_temp.assert_true(
    (v_result ->> 'seats')::int = 5,
    'the seat refusal did not carry the cap: ' || coalesce(v_result::text, 'null')
  );
  perform pg_temp.assert_true(
    not exists (
      select 1 from public.firm_members where firm_id = v_firm and user_id = c_member
    ),
    'the over-cap join wrote a membership row'
  );
  perform pg_temp.assert_true(
    (pg_temp.invite_of(v_firm, 'GATECODE04')).used_by is null,
    'the over-cap join consumed the code'
  );

  -- Lapsed past the grace window. The stored tier is what the cap reads, so a
  -- chamber that lapses inside a year it paid for keeps the ceiling it paid for
  -- — only a chamber with no paid history is the uncapped one.
  update public.profiles set subscription_expiry = now() - interval '10 days'
   where id = c_owner;
  update public.firms set subscription_expiry = now() - interval '10 days'
   where id = v_firm;

  perform pg_temp.assert_true(
    public.firm_seat_cap(v_firm) = 5,
    'a lapse dropped the tier the chamber had paid for'
  );

  -- No paid tier in force, which is the uncapped chamber of §2.4: it stays
  -- joinable, with the newcomer local-only.
  update public.profiles set tier = 'free' where id = c_owner;
  update public.firms set tier = 'free' where id = v_firm;

  perform pg_temp.assert_true(
    public.firm_seat_cap(v_firm) is null,
    'a chamber with no paid tier still had a seat cap'
  );

  v_result := pg_temp.redeem(c_member, 'GATECODE04');
  perform pg_temp.assert_true(
    v_result ->> 'status' = 'joined',
    'a lapsed chamber refused a join it should have allowed: '
      || coalesce(v_result::text, 'null')
  );

  -- -------------------------------------------------------------------------
  -- 6. The rate limiter still raises, and a success still clears it
  -- -------------------------------------------------------------------------

  for i in 1..5 loop
    v_result := pg_temp.redeem(c_member, 'NOSUCHCODE');
    perform pg_temp.assert_true(
      v_result ->> 'status' = 'invalid_code',
      'a bad code did not answer invalid_code'
    );
  end loop;

  begin
    v_result := pg_temp.redeem(c_member, 'GATECODE01');
    perform pg_temp.assert_true(false, 'the rate limiter did not raise after five failures');
  exception
    when others then
      perform pg_temp.assert_true(
        sqlerrm like '%Too many attempts%',
        'the limiter raised the wrong error: ' || sqlerrm
      );
  end;

  -- A success clears the caller's failures, so the next wrong code counts from
  -- zero rather than from the sixth attempt. The limiter is what has to be
  -- stepped around first: five failures in the window is a hard stop, and the
  -- window is time-based, so the rows are removed exactly as the retention sweep
  -- would after a day. That is the only way to observe the clearing behaviour
  -- without waiting 15 minutes for the window to slide.
  delete from public.invite_attempts where user_id = c_member;

  perform pg_temp.redeem(c_member, 'GATECODE01');
  perform pg_temp.assert_true(
    not exists (select 1 from public.invite_attempts where user_id = c_member),
    'a successful redemption did not clear the caller''s failed attempts'
  );
end;
$$;

rollback;

\echo 'JOIN OK: an empty seat is required, the cap holds, and the defaults are §3.1''s.'
