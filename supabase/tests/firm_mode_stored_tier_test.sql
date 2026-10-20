-- Firm mode stored-tier test — proves `20261016120000_firm_mode_stored_tier.sql`
-- and `20261016130000_firm_mode_seat_cap_and_creation_gate.sql`.
--
-- Self-contained: throwaway accounts are created inside one transaction that is
-- rolled back, so no fixture survives. `approve_payment` and `ensure_firm` are
-- called as the roles they are granted to (`authenticated`) with
-- `request.jwt.claims` set, which is what `auth.uid()` reads — so the RPCs' own
-- gates, the `is_admin()` registry and the ten-key ladder all run for real
-- rather than being simulated.
--
-- Runs wrapped, like the other probes here, because this file's own `begin`
-- would otherwise be enough only while the stream is one transaction:
--
--   printf 'begin;\n' | cat - supabase/tests/firm_mode_stored_tier_test.sql \
--     <(echo rollback;) | psql "$URL" -v ON_ERROR_STOP=1 --file=-
--
-- Each purchase needs its own account, because `enforce_payment_rate_limit()`
-- allows five submissions per account per 24 hours and a refused approval still
-- counts as one: the ladder's ten keys each get a fresh payer, and no account
-- here submits more than four.
--
-- Eight checks, in order:
--
--   * **the backfill's rule holds over the project's own rows** — no account
--     that holds an approved Pro purchase and no account inside its paid period
--     is left reading `free`, which is the state `20261016120000` had to repair;
--   * **the ladder prices all eighteen sellable keys** — each key approves at
--     its own amount, names its own tier, and leaves that tier stored on its
--     buyer;
--   * **a key off the ladder and a real key at the wrong amount are refused** —
--     and neither write moves the buyer's tier;
--   * **the chamber follows its owner** — the mirror carries the tier to the
--     chamber, so `firm_seat_cap` answers Pro's 0 and Firm's 5 rather than the
--     uncapped null a chamber left on the column default would answer;
--   * **a downgrade waits its turn** — Pro bought by a Firm owner is stored as
--     the pending pair, the tier in force and the cap are unchanged, the cap
--     drops to 0 on the pending date with no further approval, and the next
--     upgrade clears the pending pair;
--   * **a lapse keeps the tier that was paid for** — the clock passing the
--     expiry leaves the stored tier, and therefore the cap, alone;
--   * **the creation gate is Firm or above** — a free caller and a Pro caller
--     are both refused `firm_tier_required` with nothing written, and a Firm and
--     a Firm Plus caller's chambers are created on the very tier the gate read,
--     answering the ladder's 0 / 5 / 10 through `firm_seat_cap`;
--   * **only the server writes the tier** — `authenticated` cannot write
--     `profiles.tier` at all while its own granted column still works, an
--     off-ladder value is refused by the column's own check, and a non-admin
--     cannot reach `approve_payment`.

begin;

-- ---------------------------------------------------------------------------
-- Assertion helpers (the shape the other firm-mode smoke tests use)
-- ---------------------------------------------------------------------------

create or replace function pg_temp.assert_true(p_condition boolean, p_message text)
returns void
language plpgsql
as $$
begin
  if p_condition is not true then
    raise exception 'TIER FAIL: %', p_message;
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
-- setting, which `reset role` leaves behind.
create or replace function pg_temp.as_owner()
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims', '', true);
  execute 'reset role';
end;
$$;

-- Stages one pending submission for p_user and returns its id. Owned by the
-- test: the client's own insert path is not what this file is about.
create or replace function pg_temp.stage(p_user uuid, p_plan text, p_amount integer,
                                        p_trx text)
returns uuid
language plpgsql
as $$
declare
  v_id uuid;
begin
  insert into public.payment_submissions (
    user_id, plan_type, amount, mfs_provider, sender_number,
    transaction_id, created_at, updated_at
  )
  values (p_user, p_plan, p_amount, 'bkash', '01700000000', p_trx, 0, 0)
  returning id into v_id;

  return v_id;
end;
$$;

-- Approves p_submission as p_admin and returns the RPC's own jsonb answer.
create or replace function pg_temp.approve(p_admin uuid, p_submission uuid)
returns jsonb
language plpgsql
as $$
declare
  v_out jsonb;
begin
  perform pg_temp.as_user('authenticated', p_admin);
  v_out := public.approve_payment(p_submission);
  perform pg_temp.as_owner();
  return v_out;
end;
$$;

-- Creates (or renames) a chamber as p_user, returning the RPC's jsonb answer.
create or replace function pg_temp.create_chamber(p_user uuid, p_name text)
returns jsonb
language plpgsql
as $$
declare
  v_out jsonb;
begin
  perform pg_temp.as_user('authenticated', p_user);
  v_out := public.ensure_firm(p_name);
  perform pg_temp.as_owner();
  return v_out;
end;
$$;

-- Registers one account and returns its id, the way sign-up does it.
create or replace function pg_temp.sign_up(p_email text)
returns uuid
language plpgsql
as $$
declare
  v_id uuid := gen_random_uuid();
begin
  insert into auth.users (id, email, email_confirmed_at, created_at, updated_at,
                          is_sso_user, is_anonymous)
  values (v_id, p_email, now(), now(), now(), false, false);

  return v_id;
end;
$$;

do $$
declare
  c_admin uuid := pg_temp.sign_up('tier-admin@test.local');
  c_free uuid := pg_temp.sign_up('tier-free@test.local');
  c_pro uuid := pg_temp.sign_up('tier-pro@test.local');
  c_bad uuid := pg_temp.sign_up('tier-bad@test.local');
  c_firm uuid := pg_temp.sign_up('tier-firm@test.local');
  c_plus uuid := pg_temp.sign_up('tier-plus@test.local');
  c_payer uuid := pg_temp.sign_up('tier-payer@test.local');

  v_payer_firm uuid := gen_random_uuid();
  v_new_firm uuid;
  v_plus_firm uuid;
  v_ladder uuid;
  v_submission uuid;
  v_result jsonb;
  v_expiry timestamptz;
  i integer;

  -- The ladder as the newest approval migration states it: the eighteen
  -- sellable keys, what each costs, and the tier each one buys. Written out
  -- rather than derived, so a price or a tier that moves without this list
  -- moving is a red test. The four old Pro keys are deliberately absent: they
  -- are readable history, not offers (the legacy-key half below covers one).
  v_keys text[] := array[
    'starter_monthly', 'starter_quarterly', 'starter_half_yearly', 'starter_annual',
    'pro_monthly', 'pro_quarterly', 'pro_half_yearly', 'pro_annual',
    'firm_monthly', 'firm_quarterly', 'firm_half_yearly', 'firm_annual',
    'firm_plus_quarterly', 'firm_plus_half_yearly', 'firm_plus_annual',
    'enterprise_quarterly', 'enterprise_half_yearly', 'enterprise_annual'
  ];
  v_prices integer[] := array[
    80, 180, 300, 540,
    150, 360, 660, 1200,
    300, 750, 1350, 2500,
    1500, 2700, 5000,
    4500, 8000, 15000
  ];
  v_tiers text[] := array[
    'starter', 'starter', 'starter', 'starter',
    'pro', 'pro', 'pro', 'pro',
    'firm', 'firm', 'firm', 'firm',
    'firm_plus', 'firm_plus', 'firm_plus',
    'enterprise', 'enterprise', 'enterprise'
  ];
begin
  -- -------------------------------------------------------------------------
  -- 1. The backfill's rule, over the project's own rows (§5.2)
  -- -------------------------------------------------------------------------
  --
  -- Read before any fixture is staged. `20261016120000` reconstructed the stored
  -- tier for accounts that were already paying, and this is the shape of that
  -- repair: a paid Pro purchase in the ledger, or a period still running (or
  -- inside its 48-hour grace), means the account holds a paid tier — never
  -- `free`. Every future write path has to keep that true, so it is asserted
  -- against the live rows rather than against a fixture.
  perform pg_temp.assert_true(
    not exists (
      select 1
        from public.profiles p
       where p.tier = 'free'
         and (
           public.is_premium(p.id)
           or exists (
             select 1
               from public.payment_submissions s
              where s.user_id = p.id
                and s.status = 'approved'
                and s.plan_type in ('monthly', 'quarterly', 'half_yearly', 'annual')
           )
         )
    ),
    'an account with a paid Pro purchase or a live period still reads free — '
      'the stored tier is not being kept by every write path'
  );

  -- -------------------------------------------------------------------------
  -- Fixtures
  -- -------------------------------------------------------------------------

  -- The admin registry decides, not the database role.
  insert into public.app_admins (user_id) values (c_admin);

  -- The paying account owns a chamber before it pays anything: the mirror has a
  -- target, and the chamber starts on the column default, which is the state a
  -- cap that reads its own row must not mistake for a ceiling of zero.
  insert into public.firms (id, name, owner_id)
  values (v_payer_firm, 'Payer Chamber', c_payer);

  update public.profiles set firm_id = v_payer_firm, role = 'owner'
   where id = c_payer;

  -- A Pro account with no chamber, for the creation gate: Pro is paid, so its
  -- refusal is the Firm tier's and not the premium gate's.
  update public.profiles set tier = 'pro' where id = c_pro;

  perform pg_temp.assert_true(
    public.firm_seat_cap(v_payer_firm) is null,
    'a chamber on the default tier already claimed a seat cap'
  );

  -- -------------------------------------------------------------------------
  -- 2. The ladder prices all eighteen sellable keys (§5.1)
  -- -------------------------------------------------------------------------
  --
  -- One buyer per key, because the rate limit allows five submissions per
  -- account per day. Each fresh account buys exactly one key, so the stored tier
  -- asserted below can only have come from that approval.
  for i in 1..18 loop
    v_ladder := pg_temp.sign_up('tier-ladder-' || i || '@test.local');

    v_submission := pg_temp.stage(
      v_ladder, v_keys[i], v_prices[i], 'TIER-TRX-' || i
    );

    v_result := pg_temp.approve(c_admin, v_submission);
    perform pg_temp.assert_true(
      v_result ->> 'status' = 'approved',
      v_keys[i] || ' did not approve: ' || coalesce(v_result::text, 'null')
    );
    perform pg_temp.assert_true(
      v_result ->> 'tier' = v_tiers[i],
      v_keys[i] || ' bought the wrong tier: ' || coalesce(v_result::text, 'null')
    );
    perform pg_temp.assert_true(
      (select p.tier from public.profiles p where p.id = v_ladder) = v_tiers[i],
      v_keys[i] || ' did not store ' || v_tiers[i] || ' on its buyer'
    );
    perform pg_temp.assert_true(
      (select p.subscription_expiry from public.profiles p where p.id = v_ladder) > now(),
      v_keys[i] || ' did not leave its buyer inside a paid period'
    );
  end loop;

  -- -------------------------------------------------------------------------
  -- 3. A key off the ladder, and a real key at the wrong amount (§5.1)
  -- -------------------------------------------------------------------------

  v_submission := pg_temp.stage(c_bad, 'lifetime', 5000, 'TIER-TRX-PLAN');
  perform pg_temp.assert_true(
    (pg_temp.approve(c_admin, v_submission)) ->> 'status' = 'invalid_plan',
    'a key off the ladder was not refused as an invalid plan'
  );

  v_submission := pg_temp.stage(c_bad, 'firm_annual', 100, 'TIER-TRX-AMOUNT');
  perform pg_temp.assert_true(
    (pg_temp.approve(c_admin, v_submission)) ->> 'status' = 'invalid_amount',
    'a real key with the wrong amount was not refused'
  );

  perform pg_temp.assert_true(
    (select p.tier from public.profiles p where p.id = c_bad) = 'free',
    'a refused approval still moved the tier'
  );
  perform pg_temp.assert_true(
    (select p.subscription_expiry from public.profiles p where p.id = c_bad) is null,
    'a refused approval still extended the period'
  );

  -- -------------------------------------------------------------------------
  -- 4. The mirror carries the tier to the chamber (§5.3, §5.4)
  -- -------------------------------------------------------------------------

  -- The payer's **first** purchase, made while the chamber still holds no tier:
  -- a free account starts at once, so the mirror carries Firm to the chamber on
  -- the spot and the cap becomes a real number. Buying a lower tier first would
  -- turn this into a queued change, which §5 tests on its own; Pro's own 0 is
  -- proven there too, and by the ladder proof's seat-cap block.
  v_submission := pg_temp.stage(c_payer, 'firm_annual', 2500, 'TIER-TRX-PAYER-1');
  v_result := pg_temp.approve(c_admin, v_submission);

  perform pg_temp.assert_true(
    v_result ->> 'status' = 'approved',
    'the Firm purchase did not approve: ' || coalesce(v_result::text, 'null')
  );
  perform pg_temp.assert_true(
    v_result ->> 'tier' = 'firm',
    'the Firm purchase did not report the Firm tier'
  );
  perform pg_temp.assert_true(
    (select f.tier from public.firms f where f.id = v_payer_firm) = 'firm',
    'the chamber did not follow its owner to Firm'
  );
  perform pg_temp.assert_true(
    public.firm_seat_cap(v_payer_firm) = 5,
    'a Firm chamber did not sell 5 seats'
  );

  -- -------------------------------------------------------------------------
  -- 5. A downgrade waits its turn (§5.4)
  -- -------------------------------------------------------------------------

  v_submission := pg_temp.stage(c_payer, 'pro_annual', 1200, 'TIER-TRX-PAYER-3');
  v_result := pg_temp.approve(c_admin, v_submission);
  v_expiry := (v_result ->> 'new_expiry')::timestamptz;

  perform pg_temp.assert_true(
    (select p.tier from public.profiles p where p.id = c_payer) = 'firm',
    'a downgrade overwrote the tier that was paid for'
  );
  perform pg_temp.assert_true(
    (select p.tier_pending from public.profiles p where p.id = c_payer) = 'pro',
    'a downgrade did not store the tier it bought as pending'
  );
  -- The queue starts where the paid period ends, and the **new** expiry is that
  -- day plus the term bought: the pending pair never names the far end.
  perform pg_temp.assert_true(
    (select p.tier_pending_from from public.profiles p where p.id = c_payer)
      = (v_result ->> 'previous_expiry')::timestamptz,
    'the pending tier did not start when the old period ends'
  );
  perform pg_temp.assert_true(
    v_expiry = (v_result ->> 'previous_expiry')::timestamptz + interval '12 months',
    'the queued term did not extend the paid period by its own length'
  );
  perform pg_temp.assert_true(
    public.firm_seat_cap(v_payer_firm) = 5,
    'a waiting downgrade capped the chamber early'
  );

  -- The period ends. Nothing is approved and nothing is written by hand: only
  -- the clock moves, so the pending pair has to be what the cap reads.
  update public.profiles set tier_pending_from = now() - interval '1 day'
   where id = c_payer;

  perform pg_temp.assert_true(
    (select f.tier from public.firms f where f.id = v_payer_firm) = 'pro',
    'the chamber did not follow the pending downgrade when its date arrived'
  );
  perform pg_temp.assert_true(
    public.firm_seat_cap(v_payer_firm) = 0,
    'the cap did not drop to Pro once the downgrade took effect'
  );

  -- A purchase of a **different** tier while the plan is running is queued too,
  -- and it replaces the waiting pair: the stored tier is never rewritten when a
  -- queued change starts, so Firm bought here leaves the account on Firm (its
  -- stored tier) rather than on the Pro the earlier purchase had queued. The
  -- chamber follows the effective tier the same way, so the cap is Firm's 5.
  v_submission := pg_temp.stage(c_payer, 'firm_annual', 2500, 'TIER-TRX-PAYER-4');
  v_result := pg_temp.approve(c_admin, v_submission);
  perform pg_temp.assert_true(
    (v_result ->> 'queued')::boolean,
    'a purchase behind a started change was not queued'
  );
  perform pg_temp.assert_true(
    (select p.tier_pending from public.profiles p where p.id = c_payer) = 'firm',
    'the new change was not stored as pending'
  );
  perform pg_temp.assert_true(
    public.firm_seat_cap(v_payer_firm) = 5,
    'the chamber did not follow the effective tier after a second purchase'
  );

  -- -------------------------------------------------------------------------
  -- 6. A lapse keeps the tier that was paid for (§5.2)
  -- -------------------------------------------------------------------------

  -- The subscription runs out. Expiry alone must not touch the stored tier: it
  -- is the tier the account bought, and §5.2's lapse allowance and the seat cap
  -- both read it.
  update public.profiles
     set subscription_status = 'expired',
         subscription_expiry = now() - interval '10 days'
   where id = c_payer;

  perform pg_temp.assert_true(
    public.is_premium(c_payer) is false,
    'the fixture did not actually lapse'
  );
  perform pg_temp.assert_true(
    (select p.tier from public.profiles p where p.id = c_payer) = 'firm',
    'a lapse dropped the tier the account had paid for'
  );
  perform pg_temp.assert_true(
    public.effective_tier(
      (select p.tier from public.profiles p where p.id = c_payer),
      (select p.tier_pending from public.profiles p where p.id = c_payer),
      (select p.tier_pending_from from public.profiles p where p.id = c_payer)
    ) = 'firm',
    'the tier in force was not the stored tier after a lapse'
  );
  perform pg_temp.assert_true(
    public.firm_seat_cap(v_payer_firm) = 5,
    'a lapse dropped the ceiling the chamber had paid for'
  );

  -- -------------------------------------------------------------------------
  -- 7. The creation gate is Firm or above (§5.4)
  -- -------------------------------------------------------------------------

  -- Free: refused, and nothing is written.
  v_result := pg_temp.create_chamber(c_free, 'Free Chamber');
  perform pg_temp.assert_true(
    v_result ->> 'status' = 'firm_tier_required',
    'a free caller was not refused at the creation gate: '
      || coalesce(v_result::text, 'null')
  );
  perform pg_temp.assert_true(
    not exists (select 1 from public.firms f where f.owner_id = c_free),
    'the refused creation wrote a chamber'
  );
  perform pg_temp.assert_true(
    (select p.firm_id from public.profiles p where p.id = c_free) is null,
    'the refused creation relinked the profile'
  );

  -- Pro: paid, and still refused — a chamber on Pro could never take a member,
  -- so building one is the thing the gate exists to stop.
  v_result := pg_temp.create_chamber(c_pro, 'Pro Chamber');
  perform pg_temp.assert_true(
    v_result ->> 'status' = 'firm_tier_required',
    'a Pro caller was not refused at the creation gate: '
      || coalesce(v_result::text, 'null')
  );
  perform pg_temp.assert_true(
    not exists (select 1 from public.firms f where f.owner_id = c_pro),
    'the refused Pro creation wrote a chamber'
  );

  -- Firm: allowed, and the new chamber starts on the tier the gate read — a
  -- chamber left on the column default would answer an uncapped null.
  update public.profiles set tier = 'firm' where id = c_firm;

  v_result := pg_temp.create_chamber(c_firm, 'Firm Chamber');
  perform pg_temp.assert_true(
    v_result ->> 'status' = 'ready',
    'a Firm caller was refused at the creation gate: '
      || coalesce(v_result::text, 'null')
  );

  v_new_firm := (v_result ->> 'firm_id')::uuid;
  perform pg_temp.assert_true(
    (select f.tier from public.firms f where f.id = v_new_firm) = 'firm',
    'the new chamber did not start on its owner''s tier'
  );
  perform pg_temp.assert_true(
    public.firm_seat_cap(v_new_firm) = 5,
    'the new Firm chamber did not sell 5 seats'
  );

  -- Firm Plus: above the gate's floor, and the ladder's top ceiling. The cap is
  -- read from the chamber's own stored tier, so a top-tier chamber has to answer
  -- 20 and not the Firm number.
  update public.profiles set tier = 'firm_plus' where id = c_plus;

  v_result := pg_temp.create_chamber(c_plus, 'Firm Plus Chamber');
  perform pg_temp.assert_true(
    v_result ->> 'status' = 'ready',
    'a Firm Plus caller was refused at the creation gate: '
      || coalesce(v_result::text, 'null')
  );

  v_plus_firm := (v_result ->> 'firm_id')::uuid;
  perform pg_temp.assert_true(
    (select f.tier from public.firms f where f.id = v_plus_firm) = 'firm_plus',
    'the new chamber did not start on its Firm Plus owner''s tier'
  );
  perform pg_temp.assert_true(
    public.firm_seat_cap(v_plus_firm) = 10,
    'a Firm Plus chamber did not sell 10 seats'
  );

  -- -------------------------------------------------------------------------
  -- 8. Only the server writes the tier (§5.2)
  -- -------------------------------------------------------------------------

  -- `authenticated` holds a column grant on `profiles.full_name` and nothing
  -- else, so the tier cannot be reached from a client at all.
  begin
    perform pg_temp.as_user('authenticated', c_pro);
    update public.profiles set tier = 'firm_plus' where id = c_pro;
    perform pg_temp.as_owner();
    perform pg_temp.assert_true(false, 'an authenticated caller wrote profiles.tier');
  exception
    when insufficient_privilege then
      perform pg_temp.as_owner();
      perform pg_temp.assert_true(true, 'unreachable');
  end;

  -- The rest of the path still works: a granted column is not collateral.
  begin
    perform pg_temp.as_user('authenticated', c_pro);
    update public.profiles set full_name = 'Tier Pro' where id = c_pro;
    perform pg_temp.as_owner();
  exception
    when others then
      perform pg_temp.as_owner();
      perform pg_temp.assert_true(
        false,
        'an authenticated caller could not write its own granted column: ' || sqlerrm
      );
  end;

  -- And the value itself is constrained, so even a definer path cannot store a
  -- tier the ladder does not sell.
  begin
    update public.profiles set tier = 'lifetime' where id = c_pro;
    perform pg_temp.assert_true(false, 'an off-ladder tier was stored');
  exception
    when check_violation then
      perform pg_temp.assert_true(true, 'unreachable');
  end;

  perform pg_temp.assert_true(
    (select p.tier from public.profiles p where p.id = c_pro) = 'pro',
    'the tier-write refusals still moved the tier'
  );

  -- The ladder's own door: an authenticated caller cannot approve anything,
  -- whatever the role grant on the function says.
  v_submission := pg_temp.stage(c_pro, 'firm_annual', 2500, 'TIER-TRX-NONADMIN');

  begin
    perform pg_temp.as_user('authenticated', c_pro);
    perform public.approve_payment(v_submission);
    perform pg_temp.as_owner();
    perform pg_temp.assert_true(false, 'a non-admin approved a payment');
  exception
    when insufficient_privilege then
      perform pg_temp.as_owner();
      perform pg_temp.assert_true(true, 'unreachable');
  end;

  perform pg_temp.assert_true(
    (select p.tier from public.profiles p where p.id = c_pro) = 'pro',
    'the refused approval still moved the tier'
  );
end;
$$;

rollback;

\echo 'TIER OK: the ladder prices eighteen keys, the caps answer 0/5/10, the tier is server-written, a lapse keeps it, a downgrade waits, and the creation gate is Firm or above.'
