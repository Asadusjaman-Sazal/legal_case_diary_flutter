-- Firm capacity proof — proves `20261026110000_firm_shared_capacity.sql`.
--
-- Self-contained and rolled back: throwaway accounts, three chambers, real RPC
-- calls (`join_firm`, `sign_out_firm_member`, `admit_firm_member`,
-- `remove_firm_member`, `rebalance_firm_capacity`). The capacity helpers are
-- called as the proof owner because the migration deliberately revokes EXECUTE
-- from `authenticated`.
--
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/firm_capacity_test.sql
--
-- Checks, in order: the tier slot map; the owner/associate/signed-out device
-- caps; the join invariant with the owner's first device reserved; the frozen
-- and already-in-firm refusals; owner sign-out/admit; the trim order (owner
-- devices first, then the newest associates); a legacy over-roster is not
-- trimmed; removal revokes devices but never touches another chamber's orphan.

begin;

create or replace function pg_temp.assert_true(p_condition boolean, p_message text)
returns void
language plpgsql
as $$
begin
  if p_condition is not true then
    raise exception 'CAPACITY FAIL: %', p_message;
  end if;
end;
$$;

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

create or replace function pg_temp.as_owner()
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims', '', true);
  execute 'reset role';
end;
$$;

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

create or replace function pg_temp.invite_of(p_firm uuid, p_code text)
returns public.firm_invites
language sql
as $$
  select i
    from public.firm_invites i
   where i.firm_id = p_firm
     and i.code_hash = public.sha256_hex(upper(pg_catalog.btrim(p_code)));
$$;

create temporary table cap_c_members (
  idx integer primary key,
  id uuid not null
) on commit drop;

do $$
declare
  c_owner uuid := gen_random_uuid();
  c_owner_b uuid := gen_random_uuid();
  c_owner_c uuid := gen_random_uuid();
  c_a1 uuid := gen_random_uuid();
  c_a2 uuid := gen_random_uuid();
  c_a3 uuid := gen_random_uuid();
  c_a4 uuid := gen_random_uuid();
  c_a5 uuid := gen_random_uuid();
  c_a6 uuid := gen_random_uuid();
  c_a7 uuid := gen_random_uuid();
  c_designate uuid := gen_random_uuid();
  c_orphan uuid := gen_random_uuid();
  v_firm uuid := gen_random_uuid();
  v_firm_b uuid := gen_random_uuid();
  v_firm_c uuid := gen_random_uuid();
  v_now_ms bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint;
  v_result jsonb;
  v_session uuid;
  v_i integer;
  v_active integer;
  v_revoked integer;
  v_row public.firm_members%rowtype;
begin
  -- -------------------------------------------------------------------------
  -- Fixtures: three chambers, their memberships and their codes.
  -- -------------------------------------------------------------------------
  insert into auth.users (
    id, email, email_confirmed_at, created_at, updated_at, is_sso_user, is_anonymous
  )
  values
    (c_owner, 'cap-owner@test.local', now(), now(), now(), false, false),
    (c_owner_b, 'cap-owner-b@test.local', now(), now(), now(), false, false),
    (c_owner_c, 'cap-owner-c@test.local', now(), now(), now(), false, false),
    (c_a1, 'cap-a1@test.local', now(), now(), now(), false, false),
    (c_a2, 'cap-a2@test.local', now(), now(), now(), false, false),
    (c_a3, 'cap-a3@test.local', now(), now(), now(), false, false),
    (c_a4, 'cap-a4@test.local', now(), now(), now(), false, false),
    (c_a5, 'cap-a5@test.local', now(), now(), now(), false, false),
    (c_a6, 'cap-a6@test.local', now(), now(), now(), false, false),
    (c_a7, 'cap-a7@test.local', now(), now(), now(), false, false),
    (c_designate, 'cap-designate@test.local', now(), now(), now(), false, false),
    (c_orphan, 'cap-orphan@test.local', now(), now(), now(), false, false);

  -- The seven associates of chamber C, so the trim's profile join is exercised.
  for v_i in 1..7 loop
    declare
      c_member uuid := gen_random_uuid();
    begin
      insert into auth.users (
        id, email, email_confirmed_at, created_at, updated_at, is_sso_user, is_anonymous
      )
      values (
        c_member, format('cap-c%s@test.local', v_i), now(), now(), now(),
        false, false
      );
      insert into cap_c_members (idx, id) values (v_i, c_member);
    end;
  end loop;

  update public.profiles
     set tier = 'firm',
         subscription_status = 'premium',
         subscription_expiry = now() + interval '30 days'
   where id in (c_owner, c_owner_b, c_owner_c);

  insert into public.firms (id, name, owner_id, subscription_status, subscription_expiry, tier)
  values
    (v_firm, 'Capacity A', c_owner, 'premium', now() + interval '30 days', 'firm'),
    (v_firm_b, 'Capacity B', c_owner_b, 'premium', now() + interval '30 days', 'firm'),
    (v_firm_c, 'Capacity C', c_owner_c, 'premium', now() + interval '30 days', 'firm');

  insert into public.firm_members (firm_id, user_id, role, can_add, can_edit, can_delete)
  values
    (v_firm, c_owner, 'owner', true, true, true),
    (v_firm_b, c_owner_b, 'owner', true, true, true),
    (v_firm_c, c_owner_c, 'owner', true, true, true);

  update public.profiles set firm_id = v_firm, role = 'owner' where id = c_owner;
  update public.profiles set firm_id = v_firm_b, role = 'owner' where id = c_owner_b;
  update public.profiles set firm_id = v_firm_c, role = 'owner' where id = c_owner_c;

  insert into public.firm_invites (firm_id, code_hash, created_by, created_at)
  values
    (v_firm, public.sha256_hex(upper('CAP01')), c_owner, v_now_ms),
    (v_firm, public.sha256_hex(upper('CAP02')), c_owner, v_now_ms),
    (v_firm, public.sha256_hex(upper('CAP03')), c_owner, v_now_ms),
    (v_firm, public.sha256_hex(upper('CAP04')), c_owner, v_now_ms),
    (v_firm, public.sha256_hex(upper('CAP05')), c_owner, v_now_ms),
    (v_firm, public.sha256_hex(upper('CAP06')), c_owner, v_now_ms),
    (v_firm_b, public.sha256_hex(upper('CAPB1')), c_owner_b, v_now_ms);

  -- -------------------------------------------------------------------------
  -- 1. The tier slot map.
  -- -------------------------------------------------------------------------
  perform pg_temp.assert_true(public.firm_seat_cap(v_firm) = 5, 'Firm is not 5');
  update public.firms set tier = 'firm_plus' where id = v_firm;
  perform pg_temp.assert_true(public.firm_seat_cap(v_firm) = 10, 'Firm Plus is not 10');
  update public.firms set tier = 'enterprise' where id = v_firm;
  perform pg_temp.assert_true(public.firm_seat_cap(v_firm) = 20, 'Enterprise is not 20');
  update public.firms set tier = 'pro' where id = v_firm;
  perform pg_temp.assert_true(public.firm_seat_cap(v_firm) = 0, 'Pro is not 0');
  update public.firms set tier = 'free' where id = v_firm;
  perform pg_temp.assert_true(public.firm_seat_cap(v_firm) = 0, 'Free is not 0');
  update public.firms set tier = 'firm' where id = v_firm;

  -- -------------------------------------------------------------------------
  -- 1b. A chamber-tier account with no chamber keeps the seats it paid for.
  -- -------------------------------------------------------------------------
  -- `tier_device_cap` stays 1 per member; the individual branch must read the
  -- tier's seat cap until a firm exists, then the owner branch takes over.
  update public.profiles set tier = 'firm' where id = c_designate;
  perform pg_temp.assert_true(
    public.device_cap(c_designate) = 5,
    'a Firm owner-designate does not read five devices'
  );
  update public.profiles set tier = 'firm_plus' where id = c_designate;
  perform pg_temp.assert_true(
    public.device_cap(c_designate) = 10,
    'a Firm Plus owner-designate does not read ten devices'
  );
  update public.profiles set tier = 'enterprise' where id = c_designate;
  perform pg_temp.assert_true(
    public.device_cap(c_designate) = 20,
    'an Enterprise owner-designate does not read twenty devices'
  );
  update public.profiles set tier = 'pro' where id = c_designate;
  perform pg_temp.assert_true(
    public.device_cap(c_designate) = 2,
    'a Pro individual lost its second device'
  );
  update public.profiles set tier = 'starter' where id = c_designate;
  perform pg_temp.assert_true(
    public.device_cap(c_designate) = 1,
    'a Starter individual does not read one device'
  );
  update public.profiles set tier = 'free' where id = c_designate;
  perform pg_temp.assert_true(
    public.device_cap(c_designate) = 1,
    'a free individual does not read one device'
  );

  -- -------------------------------------------------------------------------
  -- 2. The owner's device cap follows the associates.
  -- -------------------------------------------------------------------------
  perform pg_temp.assert_true(
    public.device_cap(c_owner) = 5,
    'an owner alone does not read five devices'
  );

  v_result := pg_temp.redeem(c_a1, 'CAP01');
  perform pg_temp.assert_true(v_result ->> 'status' = 'joined', 'associate 1 did not join');
  v_result := pg_temp.redeem(c_a2, 'CAP02');
  perform pg_temp.assert_true(v_result ->> 'status' = 'joined', 'associate 2 did not join');
  v_result := pg_temp.redeem(c_a3, 'CAP03');
  perform pg_temp.assert_true(v_result ->> 'status' = 'joined', 'associate 3 did not join');
  v_result := pg_temp.redeem(c_a4, 'CAP04');
  perform pg_temp.assert_true(v_result ->> 'status' = 'joined', 'associate 4 did not join');

  perform pg_temp.assert_true(
    public.device_cap(c_owner) = 1,
    'an owner with four associates does not read one device'
  );
  perform pg_temp.assert_true(
    public.device_cap(c_a1) = 1,
    'a seated associate does not read one device'
  );

  update public.firm_members
     set capacity_signed_out_at = now()
   where firm_id = v_firm and user_id = c_a1;
  perform pg_temp.assert_true(
    public.device_cap(c_a1) = 0,
    'a capacity-signed-out associate still reads a device'
  );
  update public.firm_members
     set capacity_signed_out_at = null
   where firm_id = v_firm and user_id = c_a1;

  -- -------------------------------------------------------------------------
  -- 3. The join invariant reserves the owner's first device.
  -- -------------------------------------------------------------------------
  -- Four associates and no owner device: 4 + max(0,1) + 1 = 6 > 5.
  v_result := pg_temp.redeem(c_a5, 'CAP05');
  perform pg_temp.assert_true(
    v_result ->> 'status' = 'seats_full',
    'a fifth associate joined with the owner slot unreserved: '
      || coalesce(v_result::text, 'null')
  );
  perform pg_temp.assert_true(
    (v_result ->> 'seats')::int = 5,
    'the refusal did not name the five slots'
  );
  perform pg_temp.assert_true(
    (pg_temp.invite_of(v_firm, 'CAP05')).used_by is null,
    'the refused join consumed the code'
  );

  -- One owner device: still full (4 + 1 + 1 = 6).
  insert into public.user_devices (user_id, session_id, device_key, label)
  values (c_owner, gen_random_uuid(), 'owner-phone', 'Owner phone');
  v_result := pg_temp.redeem(c_a5, 'CAP05');
  perform pg_temp.assert_true(
    v_result ->> 'status' = 'seats_full',
    'a fifth associate joined beside the owner device'
  );

  -- Free one seat, then the owner's device and three associates fit (3+1+1=5).
  delete from public.firm_members where firm_id = v_firm and user_id = c_a4;
  update public.profiles set firm_id = null, role = 'individual' where id = c_a4;
  v_result := pg_temp.redeem(c_a5, 'CAP05');
  perform pg_temp.assert_true(
    v_result ->> 'status' = 'joined',
    'a join that fits the slots was refused: ' || coalesce(v_result::text, 'null')
  );

  -- -------------------------------------------------------------------------
  -- 4. Frozen after the grace, joinable inside it.
  -- -------------------------------------------------------------------------
  update public.firms
     set subscription_expiry = now() - interval '3 days'
   where id = v_firm;
  v_result := pg_temp.redeem(c_a6, 'CAP06');
  perform pg_temp.assert_true(
    v_result ->> 'status' = 'firm_lapsed',
    'a frozen chamber accepted a join: ' || coalesce(v_result::text, 'null')
  );
  perform pg_temp.assert_true(
    (pg_temp.invite_of(v_firm, 'CAP06')).used_by is null,
    'the frozen refusal consumed the code'
  );

  update public.firms
     set tier = 'enterprise',
         subscription_expiry = now() - interval '1 hour'
   where id = v_firm;
  v_result := pg_temp.redeem(c_a6, 'CAP06');
  perform pg_temp.assert_true(
    v_result ->> 'status' = 'joined',
    'a chamber inside its grace refused a join: ' || coalesce(v_result::text, 'null')
  );

  -- -------------------------------------------------------------------------
  -- 5. One chamber per account.
  -- -------------------------------------------------------------------------
  v_result := pg_temp.redeem(c_a6, 'CAPB1');
  perform pg_temp.assert_true(
    v_result ->> 'status' = 'already_in_firm',
    'a member of one chamber joined another: ' || coalesce(v_result::text, 'null')
  );

  update public.firms
     set tier = 'firm',
         subscription_expiry = now() + interval '30 days'
   where id = v_firm;

  -- -------------------------------------------------------------------------
  -- 6. Owner sign-out and admit.
  -- -------------------------------------------------------------------------
  perform pg_temp.as_user('authenticated', c_owner);
  v_result := public.sign_out_firm_member(c_a2);
  perform pg_temp.as_owner();
  perform pg_temp.assert_true(
    v_result ->> 'status' = 'signed_out',
    'the owner could not sign an associate out: ' || coalesce(v_result::text, 'null')
  );
  perform pg_temp.assert_true(
    (select m.capacity_signed_out_at is not null
       from public.firm_members m
      where m.firm_id = v_firm and m.user_id = c_a2),
    'the signed-out marker was not written'
  );

  -- Make room, then admit the signed-out associate back.
  delete from public.firm_members where firm_id = v_firm and user_id = c_a5;
  update public.profiles set firm_id = null, role = 'individual' where id = c_a5;
  perform pg_temp.as_user('authenticated', c_owner);
  v_result := public.admit_firm_member(c_a2);
  perform pg_temp.as_owner();
  perform pg_temp.assert_true(
    v_result ->> 'status' = 'admitted',
    'the owner could not admit a member: ' || coalesce(v_result::text, 'null')
  );
  perform pg_temp.assert_true(
    (select m.capacity_signed_out_at is null
       from public.firm_members m
      where m.firm_id = v_firm and m.user_id = c_a2),
    'the admitted marker was not cleared'
  );

  -- -------------------------------------------------------------------------
  -- 7. The trim: the owner's extra devices first, never the caller's session.
  -- -------------------------------------------------------------------------
  -- Chamber B holds one associate and five owner devices; the cap is four.
  insert into public.firm_members (firm_id, user_id, role, can_add, can_edit, can_delete)
  values (v_firm_b, c_a3, 'associate', true, true, false);
  update public.profiles set firm_id = v_firm_b, role = 'associate' where id = c_a3;

  insert into public.user_devices (user_id, session_id, device_key, label, last_seen_at)
  values
    (c_owner_b, gen_random_uuid(), 'own-b1', 'B1', now() - interval '5 days'),
    (c_owner_b, gen_random_uuid(), 'own-b2', 'B2', now() - interval '4 days'),
    (c_owner_b, gen_random_uuid(), 'own-b3', 'B3', now() - interval '3 days'),
    (c_owner_b, gen_random_uuid(), 'own-b4', 'B4', now() - interval '2 days'),
    (c_owner_b, gen_random_uuid(), 'own-b5', 'B5', now() - interval '1 day');

  insert into public.device_tokens (token, user_id, device_key)
  values
    ('token-b1', c_owner_b, 'own-b1'),
    ('token-b2', c_owner_b, 'own-b2');

  select d.session_id into v_session
    from public.user_devices d
   where d.user_id = c_owner_b and d.device_key = 'own-b1';

  perform public.rebalance_firm_capacity(v_firm_b, v_session);
  select count(*) into v_active
    from public.user_devices d
   where d.user_id = c_owner_b and d.revoked_at is null;
  select count(*) into v_revoked
    from public.user_devices d
   where d.user_id = c_owner_b
     and d.revoked_at is not null
     and d.revoked_reason = 'capacity';
  perform pg_temp.assert_true(v_active = 4, 'the owner trim left the wrong count');
  perform pg_temp.assert_true(v_revoked = 1, 'the owner trim did not revoke one device');
  perform pg_temp.assert_true(
    (select d.revoked_at is null
       from public.user_devices d
      where d.user_id = c_owner_b and d.device_key = 'own-b1'),
    'the keep-session was revoked'
  );
  perform pg_temp.assert_true(
    exists (
      select 1 from public.device_tokens t
       where t.user_id = c_owner_b and t.device_key = 'own-b1'
    ),
    'the keep-session''s private token was removed'
  );
  perform pg_temp.assert_true(
    not exists (
      select 1 from public.device_tokens t
       where t.user_id = c_owner_b and t.device_key = 'own-b2'
    ),
    'the trimmed device''s private token survived'
  );

  -- -------------------------------------------------------------------------
  -- 8. The associate trim signs out the newest seven-to-four excess.
  -- -------------------------------------------------------------------------
  for v_i in 1..7 loop
    declare
      c_member uuid;
    begin
      select id into c_member from cap_c_members where idx = v_i;

      insert into public.firm_members (
        firm_id, user_id, role, can_add, can_edit, can_delete, joined_at
      )
      values (
        v_firm_c, c_member, 'associate', true, true, false,
        now() - (v_i || ' days')::interval
      );

      update public.profiles
         set firm_id = v_firm_c, role = 'associate'
       where id = c_member;

      insert into public.user_devices (user_id, session_id, device_key, label)
      values (c_member, gen_random_uuid(), format('member-c%s', v_i), 'C phone');
    end;
  end loop;

  v_result := public.rebalance_firm_capacity(v_firm_c);
  perform pg_temp.assert_true(v_result ->> 'status' = 'ok', 'the trim did not run');
  perform pg_temp.assert_true(
    (select count(*) from public.firm_members m
      where m.firm_id = v_firm_c
        and m.user_id <> c_owner_c
        and m.capacity_signed_out_at is not null) = 3,
    'the trim did not sign out the newest three associates'
  );
  perform pg_temp.assert_true(
    (select count(*) from public.firm_members m
      where m.firm_id = v_firm_c
        and m.user_id <> c_owner_c
        and m.capacity_signed_out_at is null) = 4,
    'the trim signed out the wrong number of associates'
  );
  perform pg_temp.assert_true(
    (select count(*) from public.user_devices d
       join public.profiles p on p.id = d.user_id
      where p.firm_id = v_firm_c and d.revoked_at is not null) = 3,
    'the trimmed associates'' devices were not revoked'
  );

  -- -------------------------------------------------------------------------
  -- 9. A legacy over-roster with no queued shrink is never auto-trimmed.
  -- -------------------------------------------------------------------------
  perform pg_temp.assert_true(
    not public.firm_capacity_trim_due(v_firm_c),
    'a chamber with no pending shrink was marked due for a trim'
  );
  perform pg_temp.assert_true(
    public.firm_capacity_needs_trim(v_firm_c) is false,
    'the trim did not clear the active overage'
  );
  perform pg_temp.assert_true(
    public.rebalance_all_firm_capacities() = 0,
    'the sweep trimmed a chamber with no pending shrink'
  );

  -- -------------------------------------------------------------------------
  -- 10. Removal: revokes the member's devices, leaves another chamber's alone.
  -- -------------------------------------------------------------------------
  insert into public.firm_members (firm_id, user_id, role, can_add, can_edit, can_delete)
  values (v_firm, c_a7, 'associate', true, true, false);
  update public.profiles set firm_id = v_firm, role = 'associate' where id = c_a7;
  insert into public.user_devices (user_id, session_id, device_key, label)
  values (c_a7, gen_random_uuid(), 'member-a7', 'A7 phone');

  perform pg_temp.as_user('authenticated', c_owner);
  v_result := public.remove_firm_member(c_a7);
  perform pg_temp.as_owner();
  perform pg_temp.assert_true(v_result ->> 'status' = 'removed', 'a member was not removed');
  perform pg_temp.assert_true(
    (select d.revoked_reason from public.user_devices d
      where d.user_id = c_a7 and d.device_key = 'member-a7') = 'removed',
    'a removed member''s device was not revoked'
  );
  perform pg_temp.assert_true(
    (select p.firm_id is null from public.profiles p where p.id = c_a7),
    'a removed member was not relinked to individual'
  );

  -- An orphaned row (the person now belongs to chamber B) is only a stale seat.
  insert into public.firm_members (firm_id, user_id, role, can_add, can_edit, can_delete)
  values (v_firm, c_orphan, 'associate', true, true, false);
  update public.profiles set firm_id = v_firm_b, role = 'associate' where id = c_orphan;
  insert into public.user_devices (user_id, session_id, device_key, label)
  values (c_orphan, gen_random_uuid(), 'orphan-phone', 'Orphan phone');

  perform pg_temp.as_user('authenticated', c_owner);
  v_result := public.remove_firm_member(c_orphan);
  perform pg_temp.as_owner();
  perform pg_temp.assert_true(v_result ->> 'status' = 'removed', 'the orphan was not removed');
  perform pg_temp.assert_true(
    not exists (
      select 1 from public.firm_members
       where firm_id = v_firm and user_id = c_orphan
    ),
    'the orphan membership row survived'
  );
  perform pg_temp.assert_true(
    (select p.firm_id from public.profiles p where p.id = c_orphan) = v_firm_b,
    'removing the orphan relinked their other chamber'
  );
  perform pg_temp.assert_true(
    (select d.revoked_at is null from public.user_devices d
      where d.user_id = c_orphan and d.device_key = 'orphan-phone'),
    'removing the orphan revoked their other chamber''s device'
  );

  raise notice 'CAPACITY OK';
end;
$$;

rollback;
