-- RLS matrix test — proves the Phase 4 policies against a real project.
--
-- Usage (three real auth users; the sign-up trigger must already have created
-- their profiles):
--
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 \
--     -v owner_id=<uuid>        ` a lawyer who will own the firm
--     -v associate_id=<uuid>    ` an associate in that firm (can_edit, no can_delete)
--     -v outsider_id=<uuid>     ` a lawyer in no firm  -f supabase/tests/rls_matrix_test.sql
--
-- Everything happens in one transaction that is rolled back, so no fixture
-- survives. Each user is impersonated the way PostgREST does it: `set local
-- role authenticated` plus a `request.jwt.claims` setting, which is what
-- `auth.uid()` reads. A failure raises "MATRIX FAIL: ...", so ON_ERROR_STOP
-- turns it into a non-zero exit.

begin;

select set_config('test.owner', :'owner_id', true);
select set_config('test.associate', :'associate_id', true);
select set_config('test.outsider', :'outsider_id', true);

do $$
begin
  if coalesce(current_setting('test.owner', true), '') !~* '^[0-9a-f-]{36}$'
     or coalesce(current_setting('test.associate', true), '') !~* '^[0-9a-f-]{36}$'
     or coalesce(current_setting('test.outsider', true), '') !~* '^[0-9a-f-]{36}$'
  then
    raise exception
      'MATRIX FAIL: run with -v owner_id=<uuid> -v associate_id=<uuid> -v outsider_id=<uuid>';
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Helpers: run a query (or a DML statement) as a given user
-- ---------------------------------------------------------------------------

create or replace function pg_temp.assert_true(p_condition boolean, p_message text)
returns void
language plpgsql
as $$
begin
  if p_condition is not true then
    raise exception 'MATRIX FAIL: %', p_message;
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

-- Row count visible to p_user for the given SELECT.
create or replace function pg_temp.count_as(p_user uuid, p_sql text)
returns bigint
language plpgsql
as $$
declare
  v_count bigint;
begin
  perform pg_temp.as_user('authenticated', p_user);
  execute 'select count(*) from (' || p_sql || ') t' into v_count;
  execute 'reset role';
  return v_count;
end;
$$;

-- Rows touched by a statement run as p_user (0 means the policy refused it).
create or replace function pg_temp.rows_as(p_user uuid, p_sql text)
returns bigint
language plpgsql
as $$
declare
  v_rows bigint;
begin
  perform pg_temp.as_user('authenticated', p_user);
  execute p_sql;
  get diagnostics v_rows = row_count;
  execute 'reset role';
  return v_rows;
end;
$$;

-- Runs p_sql as p_user and requires it to fail with a message mentioning
-- p_message.
create or replace function pg_temp.raises_as(p_user uuid, p_sql text, p_message text)
returns void
language plpgsql
as $$
begin
  perform pg_temp.as_user('authenticated', p_user);
  begin
    execute p_sql;
  exception
    when others then
      execute 'reset role';
      if position(p_message in sqlerrm) = 0 then
        raise exception 'MATRIX FAIL: expected an error mentioning %, got: %',
          p_message, sqlerrm;
      end if;
      return;
  end;
  execute 'reset role';
  raise exception
    'MATRIX FAIL: expected an error mentioning %, but the statement succeeded',
    p_message;
end;
$$;

-- ---------------------------------------------------------------------------
-- Fixtures
-- ---------------------------------------------------------------------------

do $$
declare
  v_firm_id uuid;
  v_court_id text;
  v_on_behalf_id text;
begin
  perform pg_temp.assert_true(
    (select count(*) from public.courts where is_deleted = false) > 0,
    'the built-in seed data is missing; apply the seed migration first'
  );

  insert into public.firms (name, owner_id)
  values ('RLS Matrix Chambers', current_setting('test.owner')::uuid)
  returning id into v_firm_id;

  update public.profiles
     set firm_id = v_firm_id, role = 'owner'
   where id = current_setting('test.owner')::uuid;

  update public.profiles
     set firm_id = v_firm_id, role = 'associate', subscription_expiry = null
   where id = current_setting('test.associate')::uuid;

  -- The outsider is a plain individual account.
  update public.profiles
     set firm_id = null, role = 'individual', subscription_expiry = null
   where id = current_setting('test.outsider')::uuid;

  insert into public.firm_members (
    firm_id, user_id, role, can_add, can_edit, can_delete
  )
  values (v_firm_id, current_setting('test.associate')::uuid, 'associate',
          true, true, false);

  select id into v_court_id from public.courts where is_deleted = false limit 1;
  select id into v_on_behalf_id
    from public.on_behalfs where is_deleted = false limit 1;

  -- One firm case owned by the owner, one individual case owned by outsider.
  insert into public.cases (
    id, user_id, firm_id, court_id, case_type, case_number, petitioner,
    respondent, on_behalf_id, created_at, updated_at
  )
  values
    ('matrix-firm-case', current_setting('test.owner')::uuid, v_firm_id,
     v_court_id, 'Matrix Type', 'MATRIX-1', 'P', 'R', v_on_behalf_id, 0, 0),
    ('matrix-outsider-case', current_setting('test.outsider')::uuid, null,
     v_court_id, 'Matrix Type', 'MATRIX-2', 'P', 'R', v_on_behalf_id, 0, 0);

  -- A custom court shared by the firm, and a note owned by the owner.
  insert into public.courts (
    id, court_name, higher_lower_courts, court_category_id, order_index,
    is_custom, user_id, firm_id, updated_at
  )
  values (
    'matrix-firm-court', 'Matrix Firm Court', 'lower_courts',
    'district_courts_civil', 99, true, current_setting('test.owner')::uuid,
    v_firm_id, 0
  );

  insert into public.notes (id, user_id, firm_id, title, body, created_at, updated_at)
  values (
    'matrix-note', current_setting('test.owner')::uuid, v_firm_id,
    'Matrix Note', 'Body', 0, 0
  );

  insert into public.case_history (
    id, case_id, user_id, firm_id, hearing_date, created_by,
    source_mutation_id, base_case_version, result_case_version, updated_at
  )
  values (
    'matrix-history', 'matrix-firm-case', current_setting('test.owner')::uuid,
    v_firm_id, 0, current_setting('test.owner')::uuid,
    'matrix-mutation-1', 1, 2, 0
  );

  insert into public.firm_invites (firm_id, code_hash, created_by, created_at)
  values (
    v_firm_id, public.sha256_hex('MATRIX-INVITE-UNUSED'),
    current_setting('test.owner')::uuid, 0
  );

  insert into public.payment_submissions (
    user_id, plan_type, amount, mfs_provider, sender_number, transaction_id,
    created_at, updated_at
  )
  values (
    current_setting('test.owner')::uuid, 'monthly', 100, 'bkash',
    '01700000000', 'MATRIX-TRX-1', 0, 0
  );

  insert into public.user_preferences (user_id, language, updated_at)
  values (current_setting('test.owner')::uuid, 'en', 0);

  insert into public.delete_requests (
    id, firm_id, entity_type, entity_id, entity_snapshot, target_base_version,
    requested_by, status, created_at, updated_at
  )
  values (
    'matrix-delete-request', v_firm_id, 'case', 'matrix-firm-case', '{}', 1,
    current_setting('test.associate')::uuid, 'pending', 0, 0
  );

  insert into public.invite_attempts (user_id)
  values (current_setting('test.associate')::uuid);

  perform set_config('test.firm_id', v_firm_id::text, true);
end;
$$;

-- ---------------------------------------------------------------------------
-- anon sees nothing at all
-- ---------------------------------------------------------------------------

create or replace function pg_temp.count_anon(p_sql text)
returns bigint
language plpgsql
as $$
declare
  v_count bigint;
begin
  perform set_config(
    'request.jwt.claims',
    jsonb_build_object('role', 'anon')::text,
    true
  );
  execute 'set local role anon';
  execute 'select count(*) from (' || p_sql || ') t' into v_count;
  execute 'reset role';
  return v_count;
end;
$$;

select pg_temp.assert_true(
  pg_temp.count_anon('select 1 from public.cases') = 0,
  'anon must not read cases'
);
select pg_temp.assert_true(
  pg_temp.count_anon('select 1 from public.courts') = 0,
  'anon must not read courts'
);
select pg_temp.assert_true(
  pg_temp.count_anon('select 1 from public.profiles') = 0,
  'anon must not read profiles'
);

-- ---------------------------------------------------------------------------
-- cases / case_history
-- ---------------------------------------------------------------------------

select pg_temp.assert_true(
  pg_temp.count_as(
    current_setting('test.owner')::uuid,
    'select 1 from public.cases'
  ) = 1,
  'the owner must see the firm case and not the outsider''s'
);

select pg_temp.assert_true(
  pg_temp.count_as(
    current_setting('test.associate')::uuid,
    'select 1 from public.cases where id = ''matrix-firm-case'''
  ) = 1,
  'a firm member must see the firm case'
);

select pg_temp.assert_true(
  pg_temp.count_as(
    current_setting('test.outsider')::uuid,
    'select 1 from public.cases where id = ''matrix-firm-case'''
  ) = 0,
  'a non-member must not see the firm case'
);

select pg_temp.assert_true(
  pg_temp.count_as(
    current_setting('test.owner')::uuid,
    'select 1 from public.cases where id = ''matrix-outsider-case'''
  ) = 0,
  'the owner must not see another user''s individual case'
);

-- A member with can_edit may update a firm case...
select pg_temp.assert_true(
  pg_temp.rows_as(
    current_setting('test.associate')::uuid,
    'update public.cases set case_remarks = ''edited by associate'''
    ' where id = ''matrix-firm-case'''
  ) = 1,
  'a member with can_edit must be able to update a firm case'
);

-- ...but the outsider cannot, and a non-member's UPDATE touches nothing.
select pg_temp.assert_true(
  pg_temp.rows_as(
    current_setting('test.outsider')::uuid,
    'update public.cases set case_remarks = ''edited by outsider'''
    ' where id = ''matrix-firm-case'''
  ) = 0,
  'a non-member must not update a firm case'
);

-- Hard DELETE has no policy, so it removes nothing even for the owner.
select pg_temp.assert_true(
  pg_temp.rows_as(
    current_setting('test.owner')::uuid,
    'delete from public.cases'
  ) = 0,
  'cases must be soft-deleted only; no DELETE policy may exist'
);

-- INSERT is own-rows only, scoped to the caller''s firm.
select pg_temp.assert_true(
  pg_temp.rows_as(
    current_setting('test.associate')::uuid,
    'insert into public.cases (id, user_id, firm_id, court_id, case_type, '
    'case_number, petitioner, respondent, on_behalf_id, created_at, updated_at) '
    'values (''matrix-new-case'', '''
    || current_setting('test.associate') || ''', '''
    || current_setting('test.firm_id') || ''', '
    '(select id from public.courts limit 1), ''Matrix Type'', ''MATRIX-3'', '
    '''P'', ''R'', (select id from public.on_behalfs limit 1), 0, 0)'
  ) = 1,
  'a firm member must be able to insert their own case'
);

-- Inserting a case owned by someone else is refused by WITH CHECK.
select pg_temp.raises_as(
  current_setting('test.associate')::uuid,
  'insert into public.cases (id, user_id, firm_id, court_id, case_type, '
  'case_number, petitioner, respondent, on_behalf_id, created_at, updated_at) '
  'values (''matrix-spoofed-case'', ''' || current_setting('test.outsider')
  || ''', null, (select id from public.courts limit 1), ''Matrix Type'', '
  '''MATRIX-4'', ''P'', ''R'', (select id from public.on_behalfs limit 1), 0, 0)',
  'row-level security policy'
);

-- A member without can_delete may edit the case (can_edit) but the delete
-- transition is refused by the Phase 3 trigger, not by RLS.
select pg_temp.raises_as(
  current_setting('test.associate')::uuid,
  'update public.cases set is_deleted = true where id = ''matrix-firm-case''',
  'delete_not_permitted'
);

-- The owner may soft-delete it.
select pg_temp.assert_true(
  pg_temp.rows_as(
    current_setting('test.owner')::uuid,
    'update public.cases set is_deleted = true where id = ''matrix-firm-case'''
  ) = 1,
  'a firm owner must be able to soft-delete a firm case'
);

-- Resurrection is refused for everyone in the ordinary path.
select pg_temp.raises_as(
  current_setting('test.owner')::uuid,
  'update public.cases set is_deleted = false where id = ''matrix-firm-case''',
  'resurrection_not_permitted'
);

-- case_history follows the same scope as its case: the denormalized
-- user_id/firm_id are what the policy reads, with no join.
select pg_temp.assert_true(
  pg_temp.count_as(
    current_setting('test.associate')::uuid,
    'select 1 from public.case_history where id = ''matrix-history'''
  ) = 1,
  'a firm member must see the firm''s history row'
);

select pg_temp.assert_true(
  pg_temp.count_as(
    current_setting('test.outsider')::uuid,
    'select 1 from public.case_history'
  ) = 0,
  'a non-member must not see the firm''s history'
);

select pg_temp.assert_true(
  pg_temp.rows_as(
    current_setting('test.outsider')::uuid,
    'delete from public.case_history'
  ) = 0,
  'history is never hard-deleted'
);

-- ---------------------------------------------------------------------------
-- reference data
-- ---------------------------------------------------------------------------

select pg_temp.assert_true(
  pg_temp.count_as(
    current_setting('test.associate')::uuid,
    'select 1 from public.courts where id = ''matrix-firm-court'''
  ) = 1,
  'a firm member must see a custom court created by the firm'
);

select pg_temp.assert_true(
  pg_temp.count_as(
    current_setting('test.outsider')::uuid,
    'select 1 from public.courts where id = ''matrix-firm-court'''
  ) = 0,
  'a non-member must not see a firm''s custom court'
);

select pg_temp.assert_true(
  pg_temp.count_as(
    current_setting('test.outsider')::uuid,
    'select 1 from public.courts where is_custom = false'
  ) > 0,
  'every authenticated user must see the built-in courts'
);

-- A built-in row has no creator and no firm, so the update rule matches nobody:
-- the plan''s rule is literally "creator or same-firm can_edit".
select pg_temp.assert_true(
  pg_temp.rows_as(
    current_setting('test.owner')::uuid,
    'update public.courts set court_name = ''renamed'' where is_custom = false'
  ) = 0,
  'a built-in reference row must not be editable through RLS'
);

-- A custom firm court is editable by the firm and invisible to outsiders.
select pg_temp.assert_true(
  pg_temp.rows_as(
    current_setting('test.associate')::uuid,
    'update public.courts set court_name = ''Matrix Firm Court II'''
    ' where id = ''matrix-firm-court'''
  ) = 1,
  'a firm member with can_edit must be able to update the firm''s custom court'
);

select pg_temp.assert_true(
  pg_temp.rows_as(
    current_setting('test.outsider')::uuid,
    'update public.courts set court_name = ''stolen'' where id = ''matrix-firm-court'''
  ) = 0,
  'a non-member must not update a firm''s custom court'
);

-- ---------------------------------------------------------------------------
-- account, firm, preference and payment tables
-- ---------------------------------------------------------------------------

select pg_temp.assert_true(
  pg_temp.count_as(
    current_setting('test.owner')::uuid,
    'select 1 from public.profiles'
  ) = 2,
  'a firm member must see exactly the two profiles in their firm'
);

select pg_temp.assert_true(
  pg_temp.count_as(
    current_setting('test.outsider')::uuid,
    'select 1 from public.profiles'
  ) = 1,
  'an individual must see only their own profile'
);

select pg_temp.assert_true(
  pg_temp.count_as(
    current_setting('test.associate')::uuid,
    'select 1 from public.firm_members'
  ) = 1,
  'a firm member must see the firm''s membership rows'
);

select pg_temp.assert_true(
  pg_temp.count_as(
    current_setting('test.associate')::uuid,
    'select 1 from public.firm_invites'
  ) = 0,
  'an associate must not see the firm''s invite codes'
);

select pg_temp.assert_true(
  pg_temp.count_as(
    current_setting('test.owner')::uuid,
    'select 1 from public.firm_invites'
  ) = 1,
  'the firm owner must see the firm''s invite codes'
);

select pg_temp.assert_true(
  pg_temp.count_as(
    current_setting('test.associate')::uuid,
    'select 1 from public.payment_submissions'
  ) = 0,
  'payment submissions are private to their owner'
);

select pg_temp.assert_true(
  pg_temp.count_as(
    current_setting('test.owner')::uuid,
    'select 1 from public.user_preferences'
  ) = 1,
  'preferences are self-only'
);

select pg_temp.assert_true(
  pg_temp.count_as(
    current_setting('test.associate')::uuid,
    'select 1 from public.delete_requests'
  ) = 1,
  'a firm member must see the firm''s delete requests'
);

select pg_temp.assert_true(
  pg_temp.count_as(
    current_setting('test.outsider')::uuid,
    'select 1 from public.delete_requests'
  ) = 0,
  'a non-member must not see the firm''s delete requests'
);

select pg_temp.assert_true(
  pg_temp.rows_as(
    current_setting('test.owner')::uuid,
    'delete from public.delete_requests'
  ) = 0,
  'delete requests are an audit trail and must never be deleted'
);

-- ---------------------------------------------------------------------------
-- server-internal tables stay invisible and unwritable
-- ---------------------------------------------------------------------------

select pg_temp.assert_true(
  pg_temp.count_as(
    current_setting('test.associate')::uuid,
    'select 1 from public.invite_attempts'
  ) = 0,
  'invite_attempts must be invisible to clients even when rows exist'
);

select pg_temp.assert_true(
  pg_temp.count_as(
    current_setting('test.associate')::uuid,
    'select 1 from public.mutation_receipts'
  ) = 0,
  'mutation_receipts must be invisible to clients'
);

select pg_temp.raises_as(
  current_setting('test.owner')::uuid,
  'insert into public.app_admins (user_id) values (auth.uid())',
  'row-level security policy'
);

-- ---------------------------------------------------------------------------
-- Client UPDATE on server-authoritative columns is refused outright
-- ---------------------------------------------------------------------------

select pg_temp.raises_as(
  current_setting('test.owner')::uuid,
  'update public.profiles set subscription_expiry = now() + interval ''10 years'''
  ' where id = auth.uid()',
  'permission denied'
);

select pg_temp.raises_as(
  current_setting('test.owner')::uuid,
  'update public.payment_submissions set status = ''approved''',
  'permission denied'
);

rollback;

\echo 'MATRIX OK: the RLS policy matrix behaves as specified.'
