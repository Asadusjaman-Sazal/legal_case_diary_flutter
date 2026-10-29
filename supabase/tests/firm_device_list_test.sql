-- Firm device list proof — proves `20261029100000_firm_device_list.sql`.
--
-- Self-contained and rolled back: throwaway accounts, one chamber, one
-- individual, real RPC calls as each caller. Checks, in order: the owner's
-- answer carries the chamber's slots and its associate count; every active
-- device of the chamber is listed and a revoked row is not; the owner's own
-- rows come first and the current one is marked; an associate's device carries
-- that associate's name; a device whose profile has left the chamber is not
-- listed; an associate and an individual both read `not_owner`.
--
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/firm_device_list_test.sql

begin;

create or replace function pg_temp.assert_true(p_condition boolean, p_message text)
returns void
language plpgsql
as $$
begin
  if p_condition is not true then
    raise exception 'FIRM DEVICE LIST FAIL: %', p_message;
  end if;
end;
$$;

create or replace function pg_temp.as_user(
  p_role text,
  p_user uuid,
  p_session uuid default null
)
returns void
language plpgsql
as $$
begin
  perform set_config(
    'request.jwt.claims',
    (
      jsonb_build_object('sub', p_user::text, 'role', p_role)
      || case
           when p_session is null then '{}'::jsonb
           else jsonb_build_object('session_id', p_session::text)
         end
    )::text,
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

create or replace function pg_temp.firm_devices(p_user uuid, p_session uuid)
returns jsonb
language plpgsql
as $$
declare
  v_out jsonb;
begin
  perform pg_temp.as_user('authenticated', p_user, p_session);
  v_out := public.firm_device_list();
  perform pg_temp.as_owner();
  return v_out;
end;
$$;

do $$
declare
  c_owner uuid := gen_random_uuid();
  c_a1 uuid := gen_random_uuid();
  c_a2 uuid := gen_random_uuid();
  c_gone uuid := gen_random_uuid();
  c_individual uuid := gen_random_uuid();
  v_firm uuid := gen_random_uuid();
  v_owner_session uuid := gen_random_uuid();
  v_result jsonb;
  v_devices jsonb;
begin
  -- -------------------------------------------------------------------------
  -- Fixtures: one chamber with an owner, two associates and a departed member,
  -- plus an individual outside every chamber.
  -- -------------------------------------------------------------------------
  insert into auth.users (
    id, email, email_confirmed_at, created_at, updated_at, is_sso_user, is_anonymous
  )
  values
    (c_owner, 'fdl-owner@test.local', now(), now(), now(), false, false),
    (c_a1, 'fdl-a1@test.local', now(), now(), now(), false, false),
    (c_a2, 'fdl-a2@test.local', now(), now(), now(), false, false),
    (c_gone, 'fdl-gone@test.local', now(), now(), now(), false, false),
    (c_individual, 'fdl-individual@test.local', now(), now(), now(), false, false);

  update public.profiles
     set full_name = 'Firm Owner',
         tier = 'firm',
         subscription_status = 'premium',
         subscription_expiry = now() + interval '30 days'
   where id = c_owner;
  update public.profiles set full_name = 'Associate One' where id = c_a1;
  update public.profiles set full_name = 'Associate Two' where id = c_a2;
  update public.profiles set full_name = 'Departed Member' where id = c_gone;
  update public.profiles set full_name = 'Individual Lawyer' where id = c_individual;

  insert into public.firms (
    id, name, owner_id, subscription_status, subscription_expiry, tier
  )
  values (v_firm, 'Device List', c_owner, 'premium', now() + interval '30 days', 'firm');

  insert into public.firm_members (firm_id, user_id, role, can_add, can_edit, can_delete)
  values
    (v_firm, c_owner, 'owner', true, true, true),
    (v_firm, c_a1, 'associate', true, false, false),
    (v_firm, c_a2, 'associate', true, false, false);

  update public.profiles set firm_id = v_firm, role = 'owner' where id = c_owner;
  update public.profiles set firm_id = v_firm, role = 'associate'
   where id in (c_a1, c_a2);
  -- Departed: the roster row is gone and the profile points nowhere.
  update public.profiles set firm_id = null, role = 'individual' where id = c_gone;

  -- The owner's current phone, the owner's older phone, one associate's phone,
  -- a revoked phone of the second associate, and a device of the departed
  -- member that must not be listed.
  insert into public.user_devices (
    user_id, session_id, device_key, platform, label, last_seen_at
  )
  values
    (c_owner, v_owner_session, 'fdl-owner-current', 'android',
     'Samsung SM-A525F', now()),
    (c_owner, gen_random_uuid(), 'fdl-owner-older', 'windows',
     'Dell Latitude', now() - interval '2 hours'),
    (c_a1, gen_random_uuid(), 'fdl-a1-phone', 'android',
     'Xiaomi 13', now() - interval '5 minutes'),
    (c_a2, gen_random_uuid(), 'fdl-a2-phone', 'android',
     'Pixel 8', now() - interval '10 minutes'),
    (c_gone, gen_random_uuid(), 'fdl-gone-phone', 'android',
     'Nokia G22', now() - interval '1 minute');

  update public.user_devices
     set revoked_at = now(),
         revoked_reason = 'user'
   where device_key = 'fdl-a2-phone';

  -- -------------------------------------------------------------------------
  -- 1. The owner reads the whole chamber.
  -- -------------------------------------------------------------------------
  v_result := pg_temp.firm_devices(c_owner, v_owner_session);
  perform pg_temp.assert_true(v_result ->> 'status' = 'ok', 'the owner is not admitted');
  perform pg_temp.assert_true(
    (v_result ->> 'slots')::integer = 5,
    'the chamber slots are not Firm 5'
  );
  perform pg_temp.assert_true(
    (v_result ->> 'associates')::integer = 2,
    'the associate count is not two'
  );

  v_devices := v_result -> 'devices';
  perform pg_temp.assert_true(
    jsonb_array_length(v_devices) = 3,
    format('the list is not three active chamber devices: %s', v_devices)
  );

  -- The owner's own rows lead, newest contact first, and the current session is
  -- marked.
  perform pg_temp.assert_true(
    v_devices -> 0 ->> 'member_name' = 'Firm Owner'
      and (v_devices -> 0 ->> 'is_owner')::boolean
      and (v_devices -> 0 ->> 'is_current')::boolean
      and (v_devices -> 0 ->> 'label') = 'Samsung SM-A525F',
    format('the current owner device is not first: %s', v_devices -> 0)
  );
  perform pg_temp.assert_true(
    v_devices -> 1 ->> 'label' = 'Dell Latitude'
      and (v_devices -> 1 ->> 'is_current')::boolean = false,
    format('the older owner device is not second: %s', v_devices -> 1)
  );

  -- The associate's device carries the associate's name, not the owner's.
  perform pg_temp.assert_true(
    v_devices -> 2 ->> 'member_name' = 'Associate One'
      and (v_devices -> 2 ->> 'is_owner')::boolean = false
      and (v_devices -> 2 ->> 'label') = 'Xiaomi 13',
    format('the associate device is not named: %s', v_devices -> 2)
  );

  -- Nothing from the departed member, and nothing revoked.
  perform pg_temp.assert_true(
    not v_devices @> '[{"label": "Nokia G22"}]'::jsonb,
    'a departed member''s device is listed'
  );
  perform pg_temp.assert_true(
    not v_devices @> '[{"label": "Pixel 8"}]'::jsonb,
    'a revoked device is listed'
  );

  -- The current mark follows the caller's session, not the row's owner: the
  -- owner reading from the older phone sees that one marked.
  v_result := pg_temp.firm_devices(
    c_owner,
    (
      select d.session_id
        from public.user_devices d
       where d.device_key = 'fdl-owner-older'
    )
  );
  perform pg_temp.assert_true(
    (
      select count(*)
        from jsonb_array_elements(v_result -> 'devices') e
       where e ->> 'label' = 'Dell Latitude'
         and (e ->> 'is_current')::boolean
    ) = 1
    and (
      select count(*)
        from jsonb_array_elements(v_result -> 'devices') e
       where e ->> 'label' = 'Samsung SM-A525F'
         and (e ->> 'is_current')::boolean
    ) = 0,
    'the current mark does not follow the calling session'
  );

  -- -------------------------------------------------------------------------
  -- 2. Only the owner may read it.
  -- -------------------------------------------------------------------------
  perform pg_temp.assert_true(
    pg_temp.firm_devices(c_a1, gen_random_uuid()) ->> 'status' = 'not_owner',
    'an associate was admitted'
  );
  perform pg_temp.assert_true(
    pg_temp.firm_devices(c_individual, gen_random_uuid()) ->> 'status' = 'not_owner',
    'an individual was admitted'
  );
  -- A signed-out caller has no claims at all.
  perform pg_temp.as_user('authenticated', null, null);
  perform pg_temp.assert_true(
    public.firm_device_list() ->> 'status' = 'unauthenticated',
    'a signed-out caller was admitted'
  );
  perform pg_temp.as_owner();

  raise notice 'FIRM DEVICE LIST OK';
end;
$$;

rollback;
