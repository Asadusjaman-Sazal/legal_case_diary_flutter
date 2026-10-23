-- Device limit test — proves the registry/enforcement pair, the
-- `20261022150000_device_no_grace.sql` closure, and the install binding from
-- `20261022160000_device_install_secret.sql`.
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
-- It prints `DEVICE OK` when every check passes. The grace period is gone: an
-- unregistered session and a revoked device are refused in every case, and the
-- third device at the cap is refused rather than grandfathered.

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
-- `request.headers` stands in for the PostgREST GUC that carries the install's
-- `x-install-secret`; passing a different secret is how a clone is simulated.
create or replace function pg_temp.as_session(
  p_user uuid,
  p_session uuid,
  p_secret text default 'secret-1'
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
  perform set_config(
    'request.headers',
    jsonb_build_object('x-install-secret', p_secret)::text,
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
  perform set_config('request.headers', '', true);
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
  v_pro uuid := pg_temp.sign_up('device-pro@test.local');
  v_lapsed uuid := pg_temp.sign_up('device-lapsed@test.local');
  v_starter uuid := pg_temp.sign_up('device-starter@test.local');
  v_free uuid := pg_temp.sign_up('device-free@test.local');

  v_s1 uuid := gen_random_uuid();
  v_s2 uuid := gen_random_uuid();
  v_s3 uuid := gen_random_uuid();
  v_s4 uuid := gen_random_uuid();
  v_s5 uuid := gen_random_uuid();
  -- A session that never registers and a revoked one.
  v_old uuid := gen_random_uuid();
  v_rev uuid := gen_random_uuid();

  v_result jsonb;
  v_row public.user_devices%rowtype;
  v_idle uuid;
  v_first uuid;
  v_second uuid;
  v_free_session uuid := gen_random_uuid();
  v_identity uuid := pg_temp.sign_up('device-identity@test.local');
  v_collision uuid := pg_temp.sign_up('device-collision@test.local');
  v_collision_session uuid := gen_random_uuid();
  v_second_session uuid := gen_random_uuid();
  v_broadcast_solo uuid := pg_temp.sign_up('device-broadcast@test.local');
  v_broadcast_solo_session uuid := gen_random_uuid();
  v_broadcast_solo_device uuid;
  v_broadcast_firm_user uuid :=
    pg_temp.sign_up('device-broadcast-firm@test.local');
  v_broadcast_firm_session uuid := gen_random_uuid();
  v_broadcast_firm uuid := gen_random_uuid();
  v_broadcast_firm_device uuid;
  v_messages bigint;
  v_retention_a uuid := pg_temp.sign_up('device-retention-a@test.local');
  v_retention_b uuid := pg_temp.sign_up('device-retention-b@test.local');
  v_deleted bigint;
  v_id uuid;
  v_prosecdef boolean;
  v_proconfig text[];
begin
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
  -- 7. A session that never registered reads and writes nothing.
  ---------------------------------------------------------------------------
  perform pg_temp.as_session(v_pro, v_old);
  perform pg_temp.assert_true(
    public.device_may_read(now()) is false,
    'an unregistered session reads nothing'
  );
  perform pg_temp.assert_true(
    public.device_may_push(now()) is false,
    'an unregistered session may not push'
  );
  begin
    perform public.push_changes('[]'::jsonb);
    perform pg_temp.as_owner();
    raise exception 'DEVICE FAIL: an unregistered session pushed';
  exception when others then
    perform pg_temp.as_owner();
    perform pg_temp.assert_true(
      position('device_revoked' in sqlerrm) > 0,
      'push_changes refuses an unregistered session with device_revoked'
    );
  end;

  -- A revoked session has a row, so it is never mistaken for an old install.
  insert into public.user_devices (
    user_id, session_id, device_key, platform, label, last_seen_at,
    revoked_at, revoked_reason
  )
  values (
    v_pro, v_rev, 'revoked-phone', 'android', 'Revoked Phone',
    now() - interval '30 days', now() - interval '15 days', 'cap'
  );
  perform pg_temp.as_session(v_pro, v_rev);
  perform pg_temp.assert_true(
    public.device_may_push(now()) is false,
    'a revoked device may not push, however recently it was revoked'
  );
  begin
    perform public.push_changes('[]'::jsonb);
    perform pg_temp.as_owner();
    raise exception 'DEVICE FAIL: a revoked device pushed';
  exception when others then
    perform pg_temp.as_owner();
    perform pg_temp.assert_true(
      position('device_revoked' in sqlerrm) > 0,
      'push_changes refuses a revoked device with device_revoked'
    );
  end;
  perform pg_temp.as_owner();

  ---------------------------------------------------------------------------
  -- 8. The cap binds: a third device is refused, never grandfathered.
  ---------------------------------------------------------------------------
  -- v_pro currently holds phone-c (v_s3) active; add a second active device.
  insert into public.user_devices (user_id, session_id, device_key, platform, label)
  values (v_pro, gen_random_uuid(), 'fill-phone', 'android', 'Fill Phone');

  perform pg_temp.as_session(v_pro, gen_random_uuid());
  v_result := public.register_device('phone-d', 'android', 'Phone D');
  perform pg_temp.as_owner();
  perform pg_temp.assert_true(
    v_result ->> 'status' = 'device_limit_reached',
    'a third device at the cap is refused'
  );
  perform pg_temp.assert_true(
    not exists (
      select 1 from public.user_devices d
       where d.user_id = v_pro and d.device_key = 'phone-d'
    ),
    'no row is written for the refused device'
  );
  perform pg_temp.assert_true(
    jsonb_array_length(v_result -> 'devices') = 2,
    'the refusal names the two devices holding the slots'
  );

  ---------------------------------------------------------------------------
  -- 9. Writes: active yes; revoked no, with no flush window.
  ---------------------------------------------------------------------------
  perform pg_temp.as_session(v_pro, v_s3);
  v_result := public.push_changes('[]'::jsonb);
  perform pg_temp.as_owner();
  perform pg_temp.assert_true(v_result -> 'results' = '[]'::jsonb, 'an active device may push');

  -- v_s4 was revoked in section 6; it may not push at all now.
  perform pg_temp.as_session(v_pro, v_s4);
  perform pg_temp.assert_true(
    public.device_may_push(now()) is false,
    'a revoked device may not push even inside the old flush window'
  );
  begin
    perform public.push_changes('[]'::jsonb);
    perform pg_temp.as_owner();
    raise exception 'DEVICE FAIL: a revoked device pushed';
  exception when others then
    perform pg_temp.as_owner();
    perform pg_temp.assert_true(
      position('device_revoked' in sqlerrm) > 0,
      'a revoked device is refused with device_revoked'
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
  -- v_pro currently holds two active rows (phone-c and fill-phone): after a
  -- downgrade to one device the caller keeps its slot and the other is revoked
  -- as `lapse`, so its owner is told the plan changed rather than that someone
  -- stole the slot. last_seen_at is old, which also proves the trim does not
  -- wait for the seven-day eviction floor: that floor guards an *automatic*
  -- eviction, not a ceiling the account itself lowered.
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
        and d.revoked_reason = 'lapse') = 1,
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

  ---------------------------------------------------------------------------
  -- 12. Third-device sign-out and the real-use heartbeat.
  ---------------------------------------------------------------------------
  -- Give v_pro a second active row to sign out from v_s3.
  insert into public.user_devices (user_id, session_id, device_key, platform, label)
  values (v_pro, gen_random_uuid(), 'signout-phone', 'android', 'Sign-out Phone')
  returning id into v_second;

  insert into public.device_tokens (token, user_id, device_key)
  values ('signout-token', v_pro, 'signout-phone');

  perform pg_temp.as_session(v_pro, v_s3);
  v_result := public.sign_out_device(v_second);
  perform pg_temp.as_owner();
  perform pg_temp.assert_true(
    v_result ->> 'status' = 'revoked'
      and v_result ->> 'reason' = 'signed_out',
    'another device can be signed out with the signed_out reason'
  );
  select * into v_row from public.user_devices d where d.id = v_second;
  perform pg_temp.assert_true(
    v_row.revoked_at is not null and v_row.revoked_reason = 'signed_out',
    'the signed-out row records signed_out'
  );
  perform pg_temp.assert_true(
    not exists (select 1 from public.device_tokens t where t.token = 'signout-token'),
    'the signed-out device loses its push token'
  );

  -- The heartbeat moves last_seen_at even though the app did not re-register.
  update public.user_devices d
     set last_seen_at = now() - interval '30 days'
   where d.session_id = v_s3;

  perform pg_temp.as_session(v_pro, v_s3);
  v_result := public.touch_device();
  perform pg_temp.as_owner();
  perform pg_temp.assert_true(v_result ->> 'status' = 'ok', 'an active device may report real use');
  select * into v_row from public.user_devices d where d.session_id = v_s3;
  perform pg_temp.assert_true(
    v_row.last_seen_at > now() - interval '1 minute',
    'the heartbeat refreshes last_seen_at'
  );

  ---------------------------------------------------------------------------
  -- 13. A session is bound to the install that claimed it.
  ---------------------------------------------------------------------------
  -- A registration writes the hash, never the secret itself.
  perform pg_temp.as_session(v_free, v_free_session, 'free-secret');
  v_result := public.register_device('free-phone', 'android', 'Free Phone',
                                     'free-secret');
  perform pg_temp.as_owner();
  perform pg_temp.assert_true(v_result ->> 'status' = 'ok',
    'a fresh install registers with its secret');
  select * into v_row
    from public.user_devices d
   where d.session_id = v_free_session;
  perform pg_temp.assert_true(
    v_row.install_secret_hash = public.sha256_hex('free-secret'),
    'only the sha256 of the install secret is stored'
  );

  -- The same token replayed from another install is refused, and the real
  -- row is untouched so the real device keeps its slot.
  perform pg_temp.as_session(v_starter, v_s5, 'clone-secret');
  v_result := public.register_device('new-phone', 'android', 'New Phone',
                                     'clone-secret');
  perform pg_temp.as_owner();
  perform pg_temp.assert_true(v_result ->> 'status' = 'session_in_use',
    'a different install secret is refused as session_in_use');
  select * into v_row
    from public.user_devices d
   where d.session_id = v_s5;
  perform pg_temp.assert_true(
    v_row.revoked_at is null
      and v_row.install_secret_hash = public.sha256_hex('secret-1'),
    'the cloned registration leaves the real device untouched'
  );

  perform pg_temp.as_session(v_starter, v_s5, 'clone-secret');
  v_result := public.device_state();
  perform pg_temp.as_owner();
  perform pg_temp.assert_true(v_result ->> 'status' = 'session_in_use',
    'the launch check reports the clone instead of active');

  perform pg_temp.as_session(v_starter, v_s5, 'clone-secret');
  perform pg_temp.assert_true(public.device_may_push() is false,
    'a clone may not push');
  perform pg_temp.assert_true(public.device_may_read() is false,
    'a clone presenting a wrong secret reads nothing');
  begin
    perform public.push_changes('[]'::jsonb);
    perform pg_temp.as_owner();
    raise exception 'DEVICE FAIL: a cloned session pushed';
  exception when others then
    perform pg_temp.as_owner();
    perform pg_temp.assert_true(
      position('device_revoked' in sqlerrm) > 0,
      'push_changes refuses a clone with device_revoked'
    );
  end;

  -- Omitting the secret is not an escape: a caller with neither the parameter
  -- nor the header cannot register at all.
  perform pg_temp.as_session(v_starter, v_s5, null);
  v_result := public.register_device('new-phone', 'android', 'New Phone');
  perform pg_temp.as_owner();
  perform pg_temp.assert_true(v_result ->> 'status' = 'invalid_install_secret',
    'a registration with no install secret is refused');

  -- The real install keeps working.
  perform pg_temp.as_session(v_starter, v_s5);
  v_result := public.register_device('new-phone', 'android', 'New Phone',
                                     'secret-1');
  perform pg_temp.as_owner();
  perform pg_temp.assert_true(v_result ->> 'status' = 'ok',
    'the install that bound the session still registers');
  perform pg_temp.assert_true(public.sha256_hex('secret-1') <> public.sha256_hex('clone-secret'),
    'different secrets hash differently');

  -- A restored copy has the same device key but not the this-device-only
  -- secret, so it is a new device, not a `replaced` sign-in.
  perform pg_temp.as_session(v_starter, gen_random_uuid(), 'restored-secret');
  v_result := public.register_device('new-phone', 'android', 'Restored Phone',
                                     'restored-secret');
  perform pg_temp.as_owner();
  perform pg_temp.assert_true(v_result ->> 'status' = 'device_limit_reached',
    'a restored copy does not replace the original device');
  perform pg_temp.assert_true(
    not exists (
      select 1 from public.user_devices d
       where d.user_id = v_starter and d.revoked_reason = 'replaced'
    ),
    'the original row is not marked replaced'
  );

  ---------------------------------------------------------------------------
  -- 14. Every row carries the account holder's identity.
  ---------------------------------------------------------------------------
  update public.profiles
     set subscription_status = 'premium',
         subscription_expiry = now() + interval '30 days',
         tier = 'pro',
         full_name = 'Device Owner'
   where id = v_identity;

  perform pg_temp.as_session(v_identity, gen_random_uuid(), 'secret-1');
  v_result := public.register_device('identity-phone', 'android',
                                     'Identity Phone', 'secret-1');
  perform pg_temp.as_owner();
  perform pg_temp.assert_true(v_result ->> 'status' = 'ok',
    'the identity fixture registers');

  select * into v_row
    from public.user_devices d
   where d.user_id = v_identity and d.revoked_at is null;
  perform pg_temp.assert_true(v_row.full_name = 'Device Owner',
    'the device row carries the account holder''s name');
  perform pg_temp.assert_true(v_row.email = 'device-identity@test.local',
    'the device row carries the login e-mail');

  ---------------------------------------------------------------------------
  -- 15. Two installs presenting one key do not fail the unique index.
  ---------------------------------------------------------------------------
  update public.profiles
     set subscription_status = 'premium',
         subscription_expiry = now() + interval '30 days',
         tier = 'pro'
   where id = v_collision;

  perform pg_temp.as_session(v_collision, v_collision_session, 'secret-1');
  v_result := public.register_device('shared-key', 'android', 'First Phone',
                                     'secret-1');
  perform pg_temp.as_owner();
  perform pg_temp.assert_true(v_result ->> 'status' = 'ok',
    'the first phone claims the key');

  -- A different install with the same key and its own secret: the same-phone
  -- branch cannot take it, and an insert would violate the active-device index.
  perform pg_temp.as_session(v_collision, gen_random_uuid(), 'secret-2');
  v_result := public.register_device('shared-key', 'android', 'Second Phone',
                                     'secret-2');
  perform pg_temp.as_owner();
  perform pg_temp.assert_true(v_result ->> 'status' = 'device_limit_reached',
    'a colliding key is refused as a full plan, not raised as 23505');
  perform pg_temp.assert_true(
    (select count(*) from public.user_devices d
      where d.user_id = v_collision and d.revoked_at is null) = 1,
    'the collision leaves exactly one active row'
  );
  select * into v_row
    from public.user_devices d
   where d.user_id = v_collision and d.revoked_at is null;
  perform pg_temp.assert_true(
    v_row.label = 'First Phone' and v_row.device_key = 'shared-key',
    'the existing device is untouched'
  );

  -- A known session re-registering with a key another active row holds keeps
  -- its own key and still succeeds.
  perform pg_temp.as_session(v_collision, v_second_session, 'secret-2');
  v_result := public.register_device('second-key', 'android', 'Second Phone',
                                     'secret-2');
  perform pg_temp.as_owner();
  perform pg_temp.assert_true(v_result ->> 'status' = 'ok',
    'the second device takes a free slot');

  perform pg_temp.as_session(v_collision, v_collision_session, 'secret-1');
  v_result := public.register_device('second-key', 'android', 'First Phone',
                                     'secret-1');
  perform pg_temp.as_owner();
  perform pg_temp.assert_true(v_result ->> 'status' = 'ok',
    'a known session may not steal another active row''s key');
  select * into v_row
    from public.user_devices d
   where d.session_id = v_collision_session;
  perform pg_temp.assert_true(v_row.device_key = 'shared-key',
    'the known session keeps its own key');

  ---------------------------------------------------------------------------
  -- 16. A revocation is broadcast on the topic the device actually joined.
  ---------------------------------------------------------------------------
  if to_regclass('realtime.messages') is not null
     and to_regprocedure('realtime.send(jsonb,text,text,boolean)') is not null
  then
    -- An individual device listens on user:<user_id>.
    perform pg_temp.as_session(v_broadcast_solo, v_broadcast_solo_session,
                               'secret-1');
    v_result := public.register_device('broadcast-solo', 'android',
                                       'Broadcast Solo', 'secret-1');
    perform pg_temp.as_owner();
    v_broadcast_solo_device := (v_result -> 'device' ->> 'id')::uuid;

    update public.user_devices d
       set revoked_at = now(),
           revoked_reason = 'user'
     where d.id = v_broadcast_solo_device;

    select count(*) into v_messages
      from realtime.messages m
     where m.topic = 'user:' || v_broadcast_solo::text
       and m.event = 'row_change'
       and m.payload ->> 'table' = 'user_devices'
       and m.payload ->> 'id' = v_broadcast_solo_device::text
       and m.private;
    perform pg_temp.assert_true(v_messages = 1,
      'an individual revocation broadcasts on the user topic');

    -- The second update is not a revocation transition.
    update public.user_devices d
       set revoked_at = now()
     where d.id = v_broadcast_solo_device;

    select count(*) into v_messages
      from realtime.messages m
     where m.topic = 'user:' || v_broadcast_solo::text
       and m.payload ->> 'id' = v_broadcast_solo_device::text;
    perform pg_temp.assert_true(v_messages = 1,
      'revoking an already-revoked row sends no second message');

    -- A firm member listens on firm:<firm_id>, so the ping must go there.
    insert into public.firms (
      id, name, owner_id, subscription_status, subscription_expiry
    )
    values (
      v_broadcast_firm, 'Broadcast Chamber', v_broadcast_firm_user,
      'premium', now() + interval '30 days'
    );
    update public.profiles
       set firm_id = v_broadcast_firm
     where id = v_broadcast_firm_user;

    perform pg_temp.as_session(v_broadcast_firm_user,
                               v_broadcast_firm_session, 'secret-1');
    v_result := public.register_device('broadcast-firm', 'android',
                                       'Broadcast Firm', 'secret-1');
    perform pg_temp.as_owner();
    v_broadcast_firm_device := (v_result -> 'device' ->> 'id')::uuid;

    update public.user_devices d
       set revoked_at = now(),
           revoked_reason = 'user'
     where d.id = v_broadcast_firm_device;

    select count(*) into v_messages
      from realtime.messages m
     where m.topic = 'firm:' || v_broadcast_firm::text
       and m.event = 'row_change'
       and m.payload ->> 'id' = v_broadcast_firm_device::text
       and m.private;
    perform pg_temp.assert_true(v_messages = 1,
      'a firm member''s revocation broadcasts on the firm topic');

    select count(*) into v_messages
      from realtime.messages m
     where m.topic = 'user:' || v_broadcast_firm_user::text
       and m.payload ->> 'id' = v_broadcast_firm_device::text;
    perform pg_temp.assert_true(v_messages = 0,
      'the firm member''s revocation is not sent to the user topic');
  end if;

  ---------------------------------------------------------------------------
  -- 17. Device-row retention: six months, plus the newest revoked per device.
  ---------------------------------------------------------------------------
  insert into public.user_devices (
    id, user_id, session_id, device_key, platform, label,
    created_at, last_seen_at, revoked_at, revoked_reason, flushed_at
  )
  values
    -- An old build-ID key shared by two phones: only the newest survives.
    ('00000000-0000-4000-8000-000000000001'::uuid, v_retention_a,
     gen_random_uuid(), 'SKQ1.210908.001', 'android', 'Old Pro 1',
     now(), now(), now() - interval '18 months', 'replaced', null),
    ('00000000-0000-4000-8000-000000000002'::uuid, v_retention_a,
     gen_random_uuid(), 'SKQ1.210908.001', 'android', 'Old Pro 2',
     now(), now(), now() - interval '12 months', 'replaced', null),
    -- An old row with a recent newer revocation.
    ('00000000-0000-4000-8000-000000000003'::uuid, v_retention_a,
     gen_random_uuid(), 'retention-recent', 'android', 'Recent 1',
     now(), now(), now() - interval '18 months', 'user', null),
    ('00000000-0000-4000-8000-000000000004'::uuid, v_retention_a,
     gen_random_uuid(), 'retention-recent', 'android', 'Recent 2',
     now(), now(), now() - interval '5 months', 'user', null),
    -- Two rows at the same newest instant: both survive.
    ('00000000-0000-4000-8000-000000000005'::uuid, v_retention_a,
     gen_random_uuid(), 'retention-tie', 'android', 'Tie 1',
     now(), now(), now() - interval '14 months', 'cap', null),
    ('00000000-0000-4000-8000-000000000006'::uuid, v_retention_a,
     gen_random_uuid(), 'retention-tie', 'android', 'Tie 2',
     now(), now(), now() - interval '14 months', 'cap', null),
    -- Exactly six months old survives; one second older is deleted.
    ('00000000-0000-4000-8000-000000000007'::uuid, v_retention_a,
     gen_random_uuid(), 'retention-boundary', 'android', 'Boundary',
     now(), now(), now() - interval '6 months', 'lapse', null),
    ('00000000-0000-4000-8000-000000000008'::uuid, v_retention_a,
     gen_random_uuid(), 'retention-boundary', 'android', 'Boundary Older',
     now(), now(), now() - interval '6 months' - interval '1 second',
     'lapse', null),
    ('00000000-0000-4000-8000-000000000009'::uuid, v_retention_a,
     gen_random_uuid(), 'retention-boundary', 'android', 'Boundary Newer',
     now(), now(), now() - interval '5 months', 'lapse', null),
    -- A missing reason is still a revoked row.
    ('00000000-0000-4000-8000-000000000010'::uuid, v_retention_a,
     gen_random_uuid(), 'retention-null-reason', 'android', 'Null Reason 1',
     now(), now(), now() - interval '20 months', null, null),
    ('00000000-0000-4000-8000-000000000011'::uuid, v_retention_a,
     gen_random_uuid(), 'retention-null-reason', 'android', 'Null Reason 2',
     now(), now(), now() - interval '10 months', null, null),
    -- The wipe acknowledgement is not the age.
    ('00000000-0000-4000-8000-000000000012'::uuid, v_retention_a,
     gen_random_uuid(), 'retention-flushed', 'android', 'Flushed 1',
     now(), now(), now() - interval '24 months', 'signed_out', now()),
    ('00000000-0000-4000-8000-000000000013'::uuid, v_retention_a,
     gen_random_uuid(), 'retention-flushed', 'android', 'Flushed 2',
     now(), now(), now() - interval '13 months', 'signed_out', now()),
    -- A newer last_seen_at does not keep an old revoked row.
    ('00000000-0000-4000-8000-000000000014'::uuid, v_retention_a,
     gen_random_uuid(), 'retention-heartbeat', 'android', 'Heartbeat Old',
     now(), now(), now() - interval '18 months', 'user', null),
    ('00000000-0000-4000-8000-000000000015'::uuid, v_retention_a,
     gen_random_uuid(), 'retention-heartbeat', 'android', 'Heartbeat New',
     now(), now(), now() - interval '12 months', 'user', null),
    -- An active row is never a candidate, however old it is.
    ('00000000-0000-4000-8000-000000000016'::uuid, v_retention_a,
     gen_random_uuid(), 'retention-active', 'android', 'Active Old',
     now() - interval '24 months', now(), null, null, null),
    -- An active row plus its only revoked row: both survive.
    ('00000000-0000-4000-8000-000000000017'::uuid, v_retention_a,
     gen_random_uuid(), 'retention-active-one-revoked', 'android', 'Active',
     now(), now(), null, null, null),
    ('00000000-0000-4000-8000-000000000018'::uuid, v_retention_a,
     gen_random_uuid(), 'retention-active-one-revoked', 'android',
     'Only Revoked', now(), now(), now() - interval '24 months', 'cap', null),
    -- Two accounts share a key; each keeps its own newest revoked row.
    ('00000000-0000-4000-8000-000000000019'::uuid, v_retention_a,
     gen_random_uuid(), 'retention-shared', 'android', 'Shared A Old',
     now(), now(), now() - interval '20 months', 'user', null),
    ('00000000-0000-4000-8000-000000000020'::uuid, v_retention_a,
     gen_random_uuid(), 'retention-shared', 'android', 'Shared A New',
     now(), now(), now() - interval '11 months', 'user', null),
    ('00000000-0000-4000-8000-000000000021'::uuid, v_retention_b,
     gen_random_uuid(), 'retention-shared', 'android', 'Shared B Old',
     now(), now(), now() - interval '20 months', 'user', null),
    ('00000000-0000-4000-8000-000000000022'::uuid, v_retention_b,
     gen_random_uuid(), 'retention-shared', 'android', 'Shared B New',
     now(), now(), now() - interval '11 months', 'user', null),
    -- Separate install keys each keep their only revoked row.
    ('00000000-0000-4000-8000-000000000023'::uuid, v_retention_a,
     gen_random_uuid(), 'retention-install-1', 'android', 'Install 1',
     now(), now(), now() - interval '15 months', 'user', null),
    ('00000000-0000-4000-8000-000000000024'::uuid, v_retention_a,
     gen_random_uuid(), 'retention-install-2', 'android', 'Install 2',
     now(), now(), now() - interval '9 months', 'user', null),
    -- Everything inside six months is kept.
    ('00000000-0000-4000-8000-000000000025'::uuid, v_retention_b,
     gen_random_uuid(), 'retention-all-recent', 'android', 'Recent A',
     now(), now(), now() - interval '4 months', 'user', null),
    ('00000000-0000-4000-8000-000000000026'::uuid, v_retention_b,
     gen_random_uuid(), 'retention-all-recent', 'android', 'Recent B',
     now(), now(), now() - interval '2 months', 'user', null);

  perform pg_temp.as_owner();
  v_deleted := public.prune_user_devices();
  perform pg_temp.assert_true(
    v_deleted >= 8,
    'retention: at least the eight old non-newest fixtures are deleted'
  );

  foreach v_id in array array[
    '00000000-0000-4000-8000-000000000002'::uuid,
    '00000000-0000-4000-8000-000000000004'::uuid,
    '00000000-0000-4000-8000-000000000005'::uuid,
    '00000000-0000-4000-8000-000000000006'::uuid,
    '00000000-0000-4000-8000-000000000007'::uuid,
    '00000000-0000-4000-8000-000000000009'::uuid,
    '00000000-0000-4000-8000-000000000011'::uuid,
    '00000000-0000-4000-8000-000000000013'::uuid,
    '00000000-0000-4000-8000-000000000015'::uuid,
    '00000000-0000-4000-8000-000000000016'::uuid,
    '00000000-0000-4000-8000-000000000017'::uuid,
    '00000000-0000-4000-8000-000000000018'::uuid,
    '00000000-0000-4000-8000-000000000020'::uuid,
    '00000000-0000-4000-8000-000000000022'::uuid,
    '00000000-0000-4000-8000-000000000023'::uuid,
    '00000000-0000-4000-8000-000000000024'::uuid,
    '00000000-0000-4000-8000-000000000025'::uuid,
    '00000000-0000-4000-8000-000000000026'::uuid
  ] loop
    perform pg_temp.assert_true(
      exists (select 1 from public.user_devices d where d.id = v_id),
      format('retention: expected survivor %s is missing', v_id)
    );
  end loop;

  foreach v_id in array array[
    '00000000-0000-4000-8000-000000000001'::uuid,
    '00000000-0000-4000-8000-000000000003'::uuid,
    '00000000-0000-4000-8000-000000000008'::uuid,
    '00000000-0000-4000-8000-000000000010'::uuid,
    '00000000-0000-4000-8000-000000000012'::uuid,
    '00000000-0000-4000-8000-000000000014'::uuid,
    '00000000-0000-4000-8000-000000000019'::uuid,
    '00000000-0000-4000-8000-000000000021'::uuid
  ] loop
    perform pg_temp.assert_true(
      not exists (select 1 from public.user_devices d where d.id = v_id),
      format('retention: %s should have been deleted', v_id)
    );
  end loop;

  perform pg_temp.assert_true(
    exists (
      select 1 from public.user_devices d
       where d.id = '00000000-0000-4000-8000-000000000016'::uuid
         and d.revoked_at is null
    ),
    'retention: an old active device is untouched'
  );
  perform pg_temp.assert_true(
    exists (
      select 1 from public.user_devices d
       where d.id = '00000000-0000-4000-8000-000000000017'::uuid
         and d.revoked_at is null
    ),
    'retention: the second active device is untouched'
  );
  perform pg_temp.assert_true(
    exists (
      select 1 from public.user_devices d
       where d.id = '00000000-0000-4000-8000-000000000007'::uuid
    ),
    'retention: a row exactly six months old survives'
  );
  perform pg_temp.assert_true(
    exists (
      select 1 from public.user_devices d
       where d.id = '00000000-0000-4000-8000-000000000005'::uuid
    )
    and exists (
      select 1 from public.user_devices d
       where d.id = '00000000-0000-4000-8000-000000000006'::uuid
    ),
    'retention: tied newest rows both survive'
  );

  v_deleted := public.prune_user_devices();
  perform pg_temp.assert_true(
    v_deleted = 0,
    'retention: a second run deletes nothing'
  );

  perform pg_temp.assert_true(
    not has_function_privilege('anon',
      'public.prune_user_devices(interval)', 'execute'),
    'retention: anon cannot execute the pruner'
  );
  perform pg_temp.assert_true(
    not has_function_privilege('authenticated',
      'public.prune_user_devices(interval)', 'execute'),
    'retention: authenticated cannot execute the pruner'
  );
  perform pg_temp.assert_true(
    has_function_privilege(current_user,
      'public.prune_user_devices(interval)', 'execute'),
    'retention: the owner can execute the pruner'
  );

  select p.prosecdef, p.proconfig
    into v_prosecdef, v_proconfig
    from pg_proc p
   where p.oid = 'public.prune_user_devices(interval)'::regprocedure;
  perform pg_temp.assert_true(v_prosecdef,
    'retention: the pruner is security definer');
  perform pg_temp.assert_true(
    array_to_string(v_proconfig, ',') like '%pg_catalog%'
    and array_to_string(v_proconfig, ',') like '%public%',
    'retention: the pruner pins its search_path'
  );

  if to_regclass('cron.job') is not null then
    perform pg_temp.assert_true(
      exists (
        select 1 from cron.job
         where jobname = 'prune-user-devices'
           and schedule = '45 3 * * *'
           and command like '%public.prune_user_devices%'
           and active
      ),
      'retention: the daily prune job is missing or inactive'
    );
    perform pg_temp.assert_true(
      (select count(*) from cron.job where jobname = 'prune-user-devices') = 1,
      'retention: the prune job is scheduled once'
    );
    perform pg_temp.assert_true(
      exists (select 1 from cron.job where jobname = 'purge-tombstones'),
      'retention: the tombstone job is untouched'
    );
  end if;

  raise notice 'DEVICE OK';
end;
$$;

rollback;
