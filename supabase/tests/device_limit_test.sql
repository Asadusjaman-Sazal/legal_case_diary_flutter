-- Device limit test — proves `20261022100000_device_limit_registry.sql` and
-- `20261022110000_device_limit_enforcement.sql`.
--
-- Self-contained: throwaway accounts are created inside one transaction that is
-- rolled back, so no fixture survives. The client paths are exercised the way
-- PostgREST does it — `set local role authenticated` plus `request.jwt.claims`
-- carrying both `sub` and `session_id` — so the cap, the read policy and the
-- push gate run for real rather than being simulated.
--
-- Runs as it stands, because it opens and closes its own transaction:
--
--   psql "$URL" -v ON_ERROR_STOP=1 -f supabase/tests/device_limit_test.sql
--
-- It prints `DEVICE OK` when every check passes.
--
-- The roll-out window is simulated through `app.device_rollout_end`, the seam
-- the migrations expose for exactly this: the checks that must refuse a device
-- run against a date after the window, and the grand-fathering check runs
-- against the live default.

begin;

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------

create or replace function pg_temp.assert_true(p_condition boolean, p_message text)
returns void
language plpgsql
as $$
begin
  if p_condition is not true then
    raise exception 'DEVICE FAIL: %', p_message;
  end if;
end;
$$;

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

-- A signed-in device: role + claims, including the session the cap counts.
create or replace function pg_temp.as_session(
  p_user uuid,
  p_session uuid
)
returns void
language plpgsql
as $$
begin
  perform set_config(
    'request.jwt.claims',
    jsonb_build_object(
      'sub', p_user::text,
      'role', 'authenticated',
      'session_id', p_session::text
    )::text,
    true
  );
  execute 'set local role authenticated';
end;
$$;

-- The trusted path: a caller with no session claim (psql, service role).
create or replace function pg_temp.as_owner()
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims', '', true);
  execute 'reset role';
end;
$$;

-- Runs one statement as a session and returns its row count, so a policy that
-- silently filters rows is distinguishable from one that refuses.
create or replace function pg_temp.count_as(
  p_user uuid,
  p_session uuid,
  p_sql text
)
returns bigint
language plpgsql
as $$
declare
  v_rows bigint;
begin
  perform pg_temp.as_session(p_user, p_session);
  execute p_sql;
  get diagnostics v_rows = row_count;
  perform pg_temp.as_owner();
  return v_rows;
end;
$$;

-- ---------------------------------------------------------------------------
-- The checks
-- ---------------------------------------------------------------------------

do $$
declare
  -- After the roll-out window: the cap binds every device.
  c_after_rollout constant text := '2026-10-01 00:00:00+00';

  v_pro uuid := pg_temp.sign_up('device-pro@test.local');
  v_lapsed uuid := pg_temp.sign_up('device-lapsed@test.local');
  v_starter uuid := pg_temp.sign_up('device-starter@test.local');
  v_free uuid := pg_temp.sign_up('device-free@test.local');

  v_s1 uuid := gen_random_uuid();
  v_s2 uuid := gen_random_uuid();
  v_s3 uuid := gen_random_uuid();
  v_s4 uuid := gen_random_uuid();
  v_s5 uuid := gen_random_uuid();

  v_result jsonb;
  v_row public.user_devices%rowtype;
  v_idle uuid;
  v_first uuid;
  v_second uuid;
begin
  -- The roll-out window is over for the cap checks.
  perform set_config('app.device_rollout_end', c_after_rollout, true);

  -- Two live accounts and one lapsed one.
  update public.profiles
     set subscription_status = 'premium',
         subscription_expiry = now() + interval '30 days',
         tier = 'pro'
   where id = v_pro;

  update public.profiles
     set subscription_status = 'premium',
         subscription_expiry = now() + interval '30 days',
         tier = 'starter'
   where id = v_starter;

  update public.profiles
     set subscription_status = 'free',
         subscription_expiry = now() - interval '5 days',
         tier = 'pro'
   where id = v_lapsed;

  perform pg_temp.assert_true(public.device_cap(v_pro) = 2, 'pro allows 2 devices');
  perform pg_temp.assert_true(public.device_cap(v_starter) = 1, 'starter allows 1');
  perform pg_temp.assert_true(public.device_cap(v_free) = 1, 'free reads 1');
  perform pg_temp.assert_true(public.tier_device_cap('firm') = 1, 'firm allows 1 per member');
  perform pg_temp.assert_true(public.tier_device_cap('firm_plus') = 1, 'firm plus allows 1 per member');
  perform pg_temp.assert_true(public.tier_device_cap('enterprise') = 1, 'enterprise allows 1 per member');

  ---------------------------------------------------------------------------
  -- 1. A free slot, then a full plan.
  ---------------------------------------------------------------------------
  perform pg_temp.as_session(v_pro, v_s1);
  v_result := public.register_device('phone-a', 'android', 'Phone A');
  perform pg_temp.as_owner();
  perform pg_temp.assert_true(v_result ->> 'status' = 'ok', 'first device registers');
  perform pg_temp.assert_true((v_result ->> 'cap')::int = 2, 'the answer names the cap');
  v_first := (v_result -> 'device' ->> 'id')::uuid;

  perform pg_temp.as_session(v_pro, v_s2);
  v_result := public.register_device('phone-b', 'android', 'Phone B');
  perform pg_temp.as_owner();
  perform pg_temp.assert_true(v_result ->> 'status' = 'ok', 'second device registers');

  -- Both were seen this instant, so the seven-day floor forbids eviction.
  perform pg_temp.as_session(v_pro, v_s3);
  v_result := public.register_device('phone-c', 'android', 'Phone C');
  perform pg_temp.as_owner();
  perform pg_temp.assert_true(
    v_result ->> 'status' = 'device_limit_reached',
    'a third device is refused while both others are active'
  );
  perform pg_temp.assert_true(
    jsonb_array_length(v_result -> 'devices') = 2,
    'the refusal names the two devices holding the slots'
  );

  ---------------------------------------------------------------------------
  -- 2. The same phone signing in again replaces its own row.
  ---------------------------------------------------------------------------
  perform pg_temp.as_session(v_pro, v_s4);
  v_result := public.register_device('phone-a', 'android', 'Phone A');
  perform pg_temp.as_owner();
  perform pg_temp.assert_true(v_result ->> 'status' = 'ok', 'a re-login on a known phone is admitted');

  select * into v_row from public.user_devices d where d.session_id = v_s1;
  perform pg_temp.assert_true(
    v_row.revoked_at is not null and v_row.revoked_reason = 'replaced',
    'the old session of that phone is replaced, not kept'
  );
  perform pg_temp.assert_true(
    (select count(*) from public.user_devices d
      where d.user_id = v_pro and d.revoked_at is null) = 2,
    'a re-login spends no extra slot'
  );

  ---------------------------------------------------------------------------
  -- 3. An idle spare is evicted; its push token goes with it.
  ---------------------------------------------------------------------------
  v_idle := gen_random_uuid();
  insert into public.user_devices (
    user_id, session_id, device_key, platform, label, last_seen_at
  )
  values (v_starter, v_idle, 'idle-phone', 'android', 'Idle Phone',
          now() - interval '10 days');

  insert into public.device_tokens (token, user_id, device_key)
  values ('idle-token', v_starter, 'idle-phone');

  perform pg_temp.as_session(v_starter, v_s5);
  v_result := public.register_device('new-phone', 'android', 'New Phone');
  perform pg_temp.as_owner();

  perform pg_temp.assert_true(v_result ->> 'status' = 'ok', 'an idle spare is evicted for the new device');
  perform pg_temp.assert_true(
    (v_result -> 'evicted' ->> 'label') = 'Idle Phone',
    'the answer names the device it evicted'
  );
  select * into v_row from public.user_devices d where d.session_id = v_idle;
  perform pg_temp.assert_true(
    v_row.revoked_at is not null and v_row.revoked_reason = 'cap',
    'the evicted device is revoked as cap'
  );
  perform pg_temp.assert_true(
    not exists (select 1 from public.device_tokens t where t.token = 'idle-token'),
    'the evicted device loses its push token'
  );

  ---------------------------------------------------------------------------
  -- 4. No live plan: nothing is evicted, the new device is refused.
  ---------------------------------------------------------------------------
  -- A lapse does not shrink the tier, so a lapsed Pro still holds two slots:
  -- both are filled here, which is what makes the third sign-in an eviction
  -- question at all.
  insert into public.user_devices (
    user_id, session_id, device_key, platform, label, last_seen_at
  )
  values (v_lapsed, gen_random_uuid(), 'lapsed-idle', 'android', 'Lapsed Spare',
          now() - interval '20 days'),
         (v_lapsed, gen_random_uuid(), 'lapsed-idle-2', 'android', 'Lapsed Spare 2',
          now() - interval '21 days');

  perform pg_temp.as_session(v_lapsed, gen_random_uuid());
  v_result := public.register_device('lapsed-new', 'android', 'Lapsed New');
  perform pg_temp.as_owner();
  perform pg_temp.assert_true(
    v_result ->> 'status' = 'device_limit_reached',
    'a lapsed account cannot evict: its spare has nowhere to hand its work'
  );
  perform pg_temp.assert_true(
    not exists (
      select 1 from public.user_devices d
       where d.user_id = v_lapsed and d.revoked_at is not null
    ),
    'nothing was revoked without a live plan'
  );

  ---------------------------------------------------------------------------
  -- 5. The lawyer frees a slot; a device cannot free its own.
  ---------------------------------------------------------------------------
  -- The row is read as the owner: the registry has no read grant at all, which
  -- is the point of it.
  select * into v_row from public.user_devices d where d.session_id = v_s2;
  v_second := v_row.id;

  perform pg_temp.as_session(v_pro, v_s2);
  v_result := public.revoke_device(v_second);
  perform pg_temp.as_owner();
  perform pg_temp.assert_true(v_result ->> 'status' = 'is_current', 'a device cannot revoke itself');

  perform pg_temp.as_session(v_pro, v_s4);
  v_result := public.revoke_device(v_second);
  perform pg_temp.as_owner();
  perform pg_temp.assert_true(v_result ->> 'status' = 'revoked', 'another device can be released');

  perform pg_temp.as_session(v_pro, v_s3);
  v_result := public.register_device('phone-c', 'android', 'Phone C');
  perform pg_temp.as_owner();
  perform pg_temp.assert_true(v_result ->> 'status' = 'ok', 'the freed slot admits the next device');

  ---------------------------------------------------------------------------
  -- 6. Reads: active sees its rows, revoked sees none.
  ---------------------------------------------------------------------------
  insert into public.conflict_log (
    id, user_id, mutation_id, entity_type, entity_id, base_version,
    base_payload, submitted_payload, changed_fields, server_version,
    server_payload, resolution_state, conflict_at, updated_at
  )
  values (
    'device-conflict-1', v_pro, 'm1', 'cases', 'case-1', 1,
    '{}', '{}', '{}', 2, '{}', 'pending', 0, 0
  );

  perform pg_temp.assert_true(
    pg_temp.count_as(v_pro, v_s4, 'select 1 from public.conflict_log') = 1,
    'an active device reads the diary'
  );

  update public.user_devices d
     set revoked_at = now(),
         revoked_reason = 'cap'
   where d.session_id = v_s4;

  perform pg_temp.assert_true(
    pg_temp.count_as(v_pro, v_s4, 'select 1 from public.conflict_log') = 0,
    'a revoked device reads nothing new'
  );

  ---------------------------------------------------------------------------
  -- 7. A session that never registered, around the roll-out end.
  ---------------------------------------------------------------------------
  -- The window is pushed far out so this pair of checks does not go stale with
  -- the calendar: one instant well inside it, and the instant it closes.
  perform set_config('app.device_rollout_end', '2030-01-01 00:00:00+00', true);
  perform pg_temp.as_session(v_pro, gen_random_uuid());
  perform pg_temp.assert_true(
    public.device_may_read(now()) is true,
    'an unregistered session is admitted during the roll-out window'
  );
  perform pg_temp.assert_true(
    public.device_may_read(timestamptz '2030-01-01 00:00:00+00') is false,
    'after the window an unregistered session reads nothing'
  );
  perform pg_temp.as_owner();

  ---------------------------------------------------------------------------
  -- 8. The grand-fathering window admits past the cap.
  ---------------------------------------------------------------------------
  -- Fill the plan again, so the next registration is genuinely past the cap.
  insert into public.user_devices (user_id, session_id, device_key, platform, label)
  values (v_pro, gen_random_uuid(), 'fill-phone', 'android', 'Fill Phone');

  perform set_config('app.device_rollout_end', '2027-01-01 00:00:00+00', true);
  perform pg_temp.as_session(v_pro, gen_random_uuid());
  v_result := public.register_device('phone-d', 'android', 'Phone D');
  perform pg_temp.as_owner();
  perform pg_temp.assert_true(
    v_result ->> 'status' = 'ok',
    'during the window a registration past the cap is admitted, not refused'
  );
  perform pg_temp.assert_true(
    (select d.grandfathered from public.user_devices d
      where d.device_key = 'phone-d' and d.revoked_at is null) is true,
    'and it is flagged as grandfathered'
  );

  -- Back to the enforced world for the push checks.
  perform set_config('app.device_rollout_end', c_after_rollout, true);

  ---------------------------------------------------------------------------
  -- 9. Writes: active, revoked inside the flush window, revoked past it.
  ---------------------------------------------------------------------------
  perform pg_temp.as_session(v_pro, v_s3);
  v_result := public.push_changes('[]'::jsonb);
  perform pg_temp.as_owner();
  perform pg_temp.assert_true(v_result -> 'results' = '[]'::jsonb, 'an active device may push');

  -- v_s4 was revoked a moment ago: it may still hand over its unsent work.
  perform pg_temp.as_session(v_pro, v_s4);
  v_result := public.push_changes('[]'::jsonb);
  perform pg_temp.as_owner();
  perform pg_temp.assert_true(v_result -> 'results' = '[]'::jsonb, 'a revoked device may push inside its flush window');

  update public.user_devices d
     set revoked_at = now() - interval '15 days'
   where d.session_id = v_s4;

  perform pg_temp.as_session(v_pro, v_s4);
  begin
    perform public.push_changes('[]'::jsonb);
    perform pg_temp.as_owner();
    raise exception 'DEVICE FAIL: a flushed-out device pushed';
  exception when others then
    perform pg_temp.as_owner();
    perform pg_temp.assert_true(
      position('device_revoked' in sqlerrm) > 0,
      'a revoked device past its window is refused with device_revoked'
    );
  end;

  ---------------------------------------------------------------------------
  -- 10. The wipe acknowledgement, and the trusted path.
  ---------------------------------------------------------------------------
  perform pg_temp.as_session(v_pro, v_s4);
  v_result := public.ack_device_wipe('phone-a');
  perform pg_temp.as_owner();
  perform pg_temp.assert_true(
    (v_result ->> 'flushed')::int = 1,
    'the device reports that it flushed and erased'
  );
  perform pg_temp.assert_true(
    (select d.flushed_at from public.user_devices d where d.session_id = v_s4) is not null,
    'the eviction is recorded as flushed'
  );

  perform pg_temp.assert_true(
    public.device_may_read() is true and public.device_may_push() is true,
    'a caller with no session claim is allowed through both gates'
  );

  ---------------------------------------------------------------------------
  -- 11. A ceiling that fell: the surplus is revoked, the caller is not.
  ---------------------------------------------------------------------------
  -- v_pro currently holds three active rows (phone-c, fill-phone, phone-d):
  -- after a downgrade to one device the caller keeps its slot and the other
  -- two are revoked as `lapse`, so their owners are told the plan changed
  -- rather than that someone stole the slot. last_seen_at is old, which also
  -- proves the trim does not wait for the seven-day eviction floor: that floor
  -- guards an *automatic* eviction, not a ceiling the account itself lowered.
  update public.user_devices d
     set last_seen_at = now() - interval '30 days'
   where d.user_id = v_pro
     and d.session_id <> v_s3;

  perform public.device_trim_surplus(v_pro, v_s3, 1);

  perform pg_temp.assert_true(
    (select count(*) from public.user_devices d
      where d.user_id = v_pro and d.revoked_at is null) = 1,
    'a fallen ceiling leaves exactly the new cap of active devices'
  );
  perform pg_temp.assert_true(
    exists (
      select 1 from public.user_devices d
       where d.session_id = v_s3 and d.revoked_at is null
    ),
    'the phone in the lawyer''s hand keeps its slot'
  );
  perform pg_temp.assert_true(
    (select count(*) from public.user_devices d
      where d.user_id = v_pro
        and d.revoked_at is not null
        and d.revoked_reason = 'lapse') = 2,
    'the surplus is revoked as lapse, not as cap'
  );

  -- The renewal case: a lapsed account gets its plan back, and its old spare
  -- is over the new ceiling. Nothing was revoked while the plan was down, and
  -- the trim only runs once the plan is live again.
  perform pg_temp.assert_true(
    not exists (
      select 1 from public.user_devices d
       where d.user_id = v_lapsed and d.revoked_at is not null
    ),
    'a lapse revokes nothing, even when the ceiling is below the row count'
  );
  perform public.device_trim_surplus(v_lapsed, gen_random_uuid(), 1);
  perform pg_temp.assert_true(
    not exists (
      select 1 from public.user_devices d
       where d.user_id = v_lapsed and d.revoked_at is not null
    ),
    'a trim without a live plan revokes nothing: an erased device has nowhere to hand its work'
  );

  raise notice 'DEVICE OK';
end;
$$;

rollback;
