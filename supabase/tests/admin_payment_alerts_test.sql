-- Smoke test — the admin payment-alert server half (device_tokens, the toggle, the
-- two service-only reads and the pg_net webhook).
--
-- Usage (self-contained: it creates its own accounts and rolls back):
--
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 \
--     -f supabase/tests/admin_payment_alerts_test.sql
--
-- One transaction, rolled back at the end, so no account, token, preference or
-- submission survives — and, because pg_net only sends a queued request **after**
-- the transaction commits, nothing is ever sent to the FCM sender by this test.
--
-- What it pins, in order:
--   * the objects exist at all (the table, the two reads, the trigger, pg_net);
--   * `device_tokens` is self-only under RLS, and `anon` has no privilege on it;
--   * the owner of a row can register, refresh and remove its own token, and can
--     neither see nor touch anybody else's;
--   * `user_preferences.payment_alerts_enabled` defaults to true and is writable
--     by its owner;
--   * the two reads are executable by `service_role` alone — `anon` and even
--     `authenticated` are refused, because the token list is not client data;
--   * the fan-set is administrators-only and honours the toggle;
--   * a pending submission moves the count by exactly one **and** queues exactly
--     one pg_net request, which is the whole wiring this phase exists for.
--
-- Every check raises "SMOKE FAIL: ...", so ON_ERROR_STOP turns a failure into a
-- non-zero exit.

begin;

-- ---------------------------------------------------------------------------
-- Tiny assertion helpers (the same shape the other smoke tests use)
-- ---------------------------------------------------------------------------

create or replace function pg_temp.assert_true(p_condition boolean, p_message text)
returns void
language plpgsql
as $$
begin
  if p_condition is not true then
    raise exception 'SMOKE FAIL: %', p_message;
  end if;
end;
$$;

create or replace function pg_temp.assert_raises(p_sql text, p_contains text)
returns void
language plpgsql
as $$
begin
  begin
    execute p_sql;
  exception when others then
    if position(p_contains in sqlerrm) > 0 then
      return;
    end if;
    raise exception 'SMOKE FAIL: raised "%", expected "%"', sqlerrm, p_contains;
  end;
  raise exception 'SMOKE FAIL: % did not raise', p_sql;
end;
$$;

do $$
declare
  c_admin constant uuid := gen_random_uuid();
  c_other constant uuid := gen_random_uuid();
  c_admin_token constant text := 'smoke-fcm-token-admin';
  c_other_token constant text := 'smoke-fcm-token-other';
  v_rows integer;
  v_enabled boolean;
  v_before integer;
  v_after integer;
  v_queue_before integer;
  v_queue_after integer;
  v_now_ms bigint := (extract(epoch from now()) * 1000)::bigint;
begin
  -- -------------------------------------------------------------------------
  -- 1. The objects this phase is made of exist.
  -- -------------------------------------------------------------------------

  if to_regclass('public.device_tokens') is null then
    raise exception 'SMOKE FAIL: public.device_tokens does not exist';
  end if;
  if to_regprocedure('public.push_pending_payment_count()') is null then
    raise exception 'SMOKE FAIL: public.push_pending_payment_count() does not exist';
  end if;
  if to_regprocedure('public.push_alert_targets()') is null then
    raise exception 'SMOKE FAIL: public.push_alert_targets() does not exist';
  end if;
  if to_regprocedure('public.notify_admin_payment_alerts()') is null then
    raise exception 'SMOKE FAIL: public.notify_admin_payment_alerts() does not exist';
  end if;
  if not exists (select 1 from pg_extension e where e.extname = 'pg_net') then
    raise exception 'SMOKE FAIL: pg_net is not installed';
  end if;

  perform pg_temp.assert_true(
    (select c.relrowsecurity from pg_class c
      where c.oid = 'public.device_tokens'::regclass),
    'device_tokens has row level security switched on'
  );

  -- Two triggers, not one: an INSERT trigger may not carry a WHEN clause that
  -- reads OLD values, which is what the first version of this migration tried.
  perform pg_temp.assert_true(
    exists (
      select 1 from information_schema.triggers t
       where t.event_object_schema = 'public'
         and t.event_object_table = 'payment_submissions'
         and t.trigger_name = 'trg_payment_submissions_admin_alerts_insert'
         and t.event_manipulation = 'INSERT'
    ),
    'a submission being created is announced to the sender'
  );
  perform pg_temp.assert_true(
    exists (
      select 1 from information_schema.triggers t
       where t.event_object_schema = 'public'
         and t.event_object_table = 'payment_submissions'
         and t.trigger_name = 'trg_payment_submissions_admin_alerts_update'
         and t.event_manipulation = 'UPDATE'
    ),
    'a status change is announced to the sender'
  );

  -- -------------------------------------------------------------------------
  -- 2. Grants: the token list has no client path at all.
  -- -------------------------------------------------------------------------

  perform pg_temp.assert_true(
    not has_table_privilege('anon', 'public.device_tokens', 'select'),
    'anon cannot read device_tokens'
  );
  perform pg_temp.assert_true(
    has_table_privilege('authenticated', 'public.device_tokens', 'select')
      and has_table_privilege('authenticated', 'public.device_tokens', 'insert')
      and has_table_privilege('authenticated', 'public.device_tokens', 'update')
      and has_table_privilege('authenticated', 'public.device_tokens', 'delete'),
    'a signed-in account may manage its own token row'
  );

  perform pg_temp.assert_true(
    not has_function_privilege(
      'anon', 'public.push_alert_targets()', 'execute'
    )
      and not has_function_privilege(
        'authenticated', 'public.push_alert_targets()', 'execute'
      )
      and not has_function_privilege(
        'anon', 'public.push_pending_payment_count()', 'execute'
      )
      and not has_function_privilege(
        'authenticated', 'public.push_pending_payment_count()', 'execute'
      ),
    'no client role can read the fan-set or the count'
  );
  perform pg_temp.assert_true(
    has_function_privilege('service_role', 'public.push_alert_targets()', 'execute')
      and has_function_privilege(
        'service_role', 'public.push_pending_payment_count()', 'execute'
      ),
    'the sender''s own role may execute both reads'
  );
  perform pg_temp.assert_true(
    not has_function_privilege(
      'anon', 'public.notify_admin_payment_alerts()', 'execute'
    )
      and not has_function_privilege(
        'authenticated', 'public.notify_admin_payment_alerts()', 'execute'
      ),
    'the webhook function is reachable by no client role'
  );

  -- -------------------------------------------------------------------------
  -- 3. Fixtures: one administrator, one ordinary account.
  -- -------------------------------------------------------------------------

  insert into auth.users (
    id, instance_id, aud, role, email, encrypted_password,
    email_confirmed_at, created_at, updated_at
  )
  values
    (c_admin, '00000000-0000-0000-0000-000000000000', 'authenticated',
     'authenticated', 'smoke-fcm-admin@example.test',
     extensions.crypt('x', extensions.gen_salt('bf')), now(), now(), now()),
    (c_other, '00000000-0000-0000-0000-000000000000', 'authenticated',
     'authenticated', 'smoke-fcm-other@example.test',
     extensions.crypt('x', extensions.gen_salt('bf')), now(), now(), now());

  insert into public.app_admins (user_id) values (c_admin)
  on conflict (user_id) do nothing;

  -- The administrator's device, registered the way the sender will read it.
  insert into public.device_tokens (token, user_id)
  values (c_admin_token, c_admin);

  -- -------------------------------------------------------------------------
  -- 4. RLS, as an ordinary signed-in account: its own row and nothing else.
  -- -------------------------------------------------------------------------

  perform set_config(
    'request.jwt.claims',
    json_build_object('sub', c_other, 'role', 'authenticated')::text,
    true
  );
  set local role authenticated;

  -- Registering its own device works …
  insert into public.device_tokens (token, user_id)
  values (c_other_token, c_other);

  -- … and it sees exactly that one row.
  select count(*) into v_rows from public.device_tokens;
  perform pg_temp.assert_true(
    v_rows = 1, 'an account sees only its own token'
  );

  -- Claiming the administrator's device is refused outright.
  perform pg_temp.assert_raises(
    format(
      'insert into public.device_tokens (token, user_id) values (%L, %L::uuid)',
      'smoke-fcm-token-stolen', c_admin
    ),
    'row-level security policy'
  );

  -- Stealing the row by updating it is not a path either: the row is invisible,
  -- so the update matches nothing.
  update public.device_tokens set user_id = c_other
   where token = c_admin_token;
  perform pg_temp.assert_true(
    not found, 'another account''s token cannot be reassigned'
  );

  delete from public.device_tokens where token = c_admin_token;
  perform pg_temp.assert_true(
    not found, 'another account''s token cannot be deleted'
  );

  -- The toggle defaults to on, and its owner may switch it off.
  insert into public.user_preferences (user_id, updated_at)
  values (c_other, 0);

  select p.payment_alerts_enabled into v_enabled
    from public.user_preferences p where p.user_id = c_other;
  perform pg_temp.assert_true(
    v_enabled, 'payment alerts default to on for an account that never chose'
  );

  update public.user_preferences set payment_alerts_enabled = false
   where user_id = c_other;
  select p.payment_alerts_enabled into v_enabled
    from public.user_preferences p where p.user_id = c_other;
  perform pg_temp.assert_true(
    v_enabled is not true, 'the owner can switch payment alerts off'
  );

  reset role;

  -- The administrator's token is still there, untouched.
  perform pg_temp.assert_true(
    exists (
      select 1 from public.device_tokens t
       where t.token = c_admin_token and t.user_id = c_admin
    ),
    'the administrator''s own device survived the attempt'
  );

  -- -------------------------------------------------------------------------
  -- 5. The fan-set: administrators only, and the toggle is honoured.
  -- -------------------------------------------------------------------------

  perform pg_temp.assert_true(
    exists (
      select 1 from public.push_alert_targets() g
       where g.user_id = c_admin and g.token = c_admin_token
    ),
    'an administrator with a registered device is a target'
  );
  perform pg_temp.assert_true(
    not exists (
      select 1 from public.push_alert_targets() g where g.user_id = c_other
    ),
    'an ordinary account is never a target, whatever it registered'
  );

  -- The administrator has to *have* a preference row before the toggle can be
  -- switched off — without one the update below would match no row and the
  -- assertion would be about nothing at all (which is how this test first
  -- failed). The row is written with the column's own default.
  insert into public.user_preferences (user_id, updated_at)
  values (c_admin, 0);

  update public.user_preferences set payment_alerts_enabled = false
   where user_id = c_admin;
  perform pg_temp.assert_true(
    not exists (
      select 1 from public.push_alert_targets() g where g.user_id = c_admin
    ),
    'switching the toggle off removes every one of that admin''s devices'
  );
  update public.user_preferences set payment_alerts_enabled = true
   where user_id = c_admin;
  perform pg_temp.assert_true(
    exists (
      select 1 from public.push_alert_targets() g where g.user_id = c_admin
    ),
    'switching it back on brings them back'
  );
  -- An administrator who has never written a preference row is a target too: the
  -- missing row means "never touched it", which is the column's default of true.
  delete from public.user_preferences p where p.user_id = c_admin;
  perform pg_temp.assert_true(
    exists (
      select 1 from public.push_alert_targets() g where g.user_id = c_admin
    ),
    'a missing preference row reads as on, not as absent'
  );

  -- -------------------------------------------------------------------------
  -- 6. A pending submission: the count moves by one, and one request is queued.
  -- -------------------------------------------------------------------------

  -- A secret is needed for the trigger to post at all; here it only has to exist.
  -- Created inside this transaction, so a real one is never disturbed and the
  -- test's own copy disappears with the rollback.
  if not exists (select 1 from vault.secrets s where s.name = 'fcm_webhook_secret')
  then
    perform vault.create_secret('smoke-test-only', 'fcm_webhook_secret');
  end if;

  select public.push_pending_payment_count() into v_before;
  select count(*) into v_queue_before from net.http_request_queue;

  insert into public.payment_submissions (
    user_id, plan_type, amount, mfs_provider, sender_number, transaction_id,
    created_at, updated_at
  )
  values (
    c_other, 'monthly', 100, 'bkash', '01700000000',
    'smoke-fcm-' || gen_random_uuid()::text, v_now_ms, v_now_ms
  );

  select public.push_pending_payment_count() into v_after;
  perform pg_temp.assert_true(
    v_after = v_before + 1,
    format('a pending submission moves the count by one (%s -> %s)',
           v_before, v_after)
  );

  -- The count is asserted as a delta, never as a total: this runs against the
  -- live project, which may hold real pending submissions that are none of this
  -- test's business.
  --
  -- The queue is read inside the same transaction, so the row this test queued is
  -- the only one that can appear — pg_net's worker cannot see an uncommitted
  -- request, and the rollback means it never will.
  select count(*) into v_queue_after from net.http_request_queue;
  perform pg_temp.assert_true(
    v_queue_after = v_queue_before + 1,
    format('the webhook queued exactly one request (%s -> %s)',
           v_queue_before, v_queue_after)
  );

  -- And the submission is still there, i.e. the alarm did not cost the user the
  -- thing it was announcing.
  perform pg_temp.assert_true(
    exists (
      select 1 from public.payment_submissions s
       where s.user_id = c_other and s.status = 'pending'
    ),
    'the submission that fired the alarm is saved'
  );
end;
$$;

rollback;
