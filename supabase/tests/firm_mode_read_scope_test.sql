-- Firm mode read-scope test — proves `20261015100000_firm_mode_read_scope.sql`.
--
-- Self-contained: four throwaway accounts are created inside one transaction
-- that is rolled back, so no fixture survives. Each account is impersonated the
-- way PostgREST does it — `set local role authenticated` plus a
-- `request.jwt.claims` setting, which is what `auth.uid()` reads — so the
-- policies are actually evaluated rather than skipped by the owner's privileges.
--
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/firm_mode_read_scope_test.sql
--
-- What it pins, in order: the removal leak is closed on all four case-data
-- tables and on a custom reference row; a chamber's rows are still visible to
-- its current members; an individual's own diary is untouched; the dissolve's
-- scope owner is the only one who keeps a dissolved row; `conflict_log` keeps
-- its own narrower rule; the built-in reference baseline stays readable to
-- everyone; and `scope_owner_id` cannot be written by a client while the
-- columns a client legitimately writes still can be.

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
    raise exception 'SCOPE FAIL: %', p_message;
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

-- A statement run as p_user that must raise, with p_message somewhere in the
-- error. Used for the column-privilege guard, where the refusal is an error
-- rather than an empty result.
create or replace function pg_temp.assert_raises_as(
  p_user uuid,
  p_sql text,
  p_message text
)
returns void
language plpgsql
as $$
declare
  v_error text;
begin
  perform pg_temp.as_user('authenticated', p_user);
  begin
    execute p_sql;
  exception when others then
    v_error := sqlerrm;
  end;
  execute 'reset role';
  if v_error is null then
    raise exception 'SCOPE FAIL: % did not raise', p_sql;
  end if;
  if position(p_message in v_error) = 0 then
    raise exception 'SCOPE FAIL: raised "%", expected "%"', v_error, p_message;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Fixtures: an owner and an associate in a chamber, a removed member, and an
-- account in no firm at all
-- ---------------------------------------------------------------------------

-- `text`, not `uuid`: the reference tables' ids are text keys, and the account
-- and firm ids cast in on the way through.
create temporary table scope_fixtures (
  name text primary key,
  id text not null
) on commit drop;

do $$
declare
  c_owner uuid := gen_random_uuid();
  c_assoc uuid := gen_random_uuid();
  c_removed uuid := gen_random_uuid();
  c_outsider uuid := gen_random_uuid();
  c_firm uuid := gen_random_uuid();
  v_now_ms bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint;
  v_category text;
  v_builtin_court text;
  v_on_behalf text;
begin
  insert into scope_fixtures (name, id) values
    ('owner', c_owner::text),
    ('associate', c_assoc::text),
    ('removed', c_removed::text),
    ('outsider', c_outsider::text),
    ('firm', c_firm::text);

  -- The sign-up trigger creates one profiles row per account.
  insert into auth.users (
    id, instance_id, aud, role, email, email_confirmed_at, created_at, updated_at
  )
  values
    (c_owner, '00000000-0000-0000-0000-000000000000', 'authenticated',
     'authenticated', 'scope-owner@example.test', now(), now(), now()),
    (c_assoc, '00000000-0000-0000-0000-000000000000', 'authenticated',
     'authenticated', 'scope-assoc@example.test', now(), now(), now()),
    (c_removed, '00000000-0000-0000-0000-000000000000', 'authenticated',
     'authenticated', 'scope-removed@example.test', now(), now(), now()),
    (c_outsider, '00000000-0000-0000-0000-000000000000', 'authenticated',
     'authenticated', 'scope-outsider@example.test', now(), now(), now());

  insert into public.firms (
    id, name, owner_id, subscription_status, subscription_expiry
  )
  values (c_firm, 'Scope Chambers', c_owner, 'active', now() + interval '30 days');

  update public.profiles
     set firm_id = c_firm, role = 'owner',
         subscription_expiry = now() + interval '30 days'
   where id = c_owner;

  update public.profiles
     set firm_id = c_firm, role = 'associate',
         subscription_expiry = now() + interval '30 days'
   where id = c_assoc;

  -- The removed member's profile is what a removal leaves behind: no firm, no
  -- membership row, and every row they authored in the chamber still theirs by
  -- `user_id`.
  insert into public.firm_members (
    firm_id, user_id, role, can_add, can_edit, can_delete,
    synced_at, permissions_synced_at
  )
  values
    (c_firm, c_owner, 'owner', true, true, true, v_now_ms, v_now_ms),
    (c_firm, c_assoc, 'associate', true, true, false, v_now_ms, v_now_ms);

  select id into v_category from public.court_categories limit 1;
  select id into v_builtin_court
    from public.courts where is_custom = false order by id limit 1;
  -- `cases.on_behalf_id` is a real foreign key, so a fixture cannot invent one.
  select id into v_on_behalf from public.on_behalfs limit 1;

  insert into scope_fixtures (name, id) values
    ('category', v_category),
    ('builtin_court', v_builtin_court);

  -- -------------------------------------------------------------------------
  -- Ledger rows: the chamber's, the individual's, and the dissolved shape
  -- -------------------------------------------------------------------------

  insert into public.cases (
    id, user_id, firm_id, case_number, case_type, court_id, petitioner,
    respondent, on_behalf_id, created_at, updated_at
  )
  values
    ('scope-firm-by-removed', c_removed, c_firm, 'SCOPE-1', 'civil',
     v_builtin_court, 'A', 'B', v_on_behalf, v_now_ms, v_now_ms),
    ('scope-firm-by-assoc', c_assoc, c_firm, 'SCOPE-2', 'civil',
     v_builtin_court, 'C', 'D', v_on_behalf, v_now_ms, v_now_ms),
    ('scope-personal-by-removed', c_removed, null, 'SCOPE-3', 'civil',
     v_builtin_court, 'E', 'F', v_on_behalf, v_now_ms, v_now_ms),
    ('scope-personal-by-owner', c_owner, null, 'SCOPE-4', 'civil',
     v_builtin_court, 'G', 'H', v_on_behalf, v_now_ms, v_now_ms);

  -- A dissolved chamber's rows lose `firm_id` and gain the owner as their scope
  -- owner — the shape §4.4 writes.
  update public.cases
     set scope_owner_id = c_owner, user_id = c_removed
   where id = 'scope-personal-by-owner';

  insert into public.case_history (
    id, case_id, user_id, firm_id, hearing_date, created_by,
    source_mutation_id, base_case_version, result_case_version, updated_at
  )
  values (
    'scope-history-firm', 'scope-firm-by-removed', c_removed, c_firm,
    v_now_ms, c_removed, 'scope-mutation-1', 1, 2, v_now_ms
  );

  insert into public.notes (
    id, user_id, firm_id, title, body, created_at, updated_at
  )
  values (
    'scope-note-firm', c_removed, c_firm, 'Chamber note', 'body',
    v_now_ms, v_now_ms
  );

  insert into public.case_references (
    id, user_id, firm_id, reference_and_page_no, created_at, updated_at
  )
  values (
    'scope-reference-firm', c_removed, c_firm, 'AIR 2020 SC 1',
    v_now_ms, v_now_ms
  );

  -- A custom court the chamber added, and the built-in line every install reads.
  insert into public.courts (
    id, court_name, higher_lower_courts, court_category_id, is_custom,
    user_id, firm_id, updated_at
  )
  values (
    'scope-court-firm', 'Scope Custom Court', 'lower', v_category, true,
    c_assoc, c_firm, v_now_ms
  );

  insert into public.delete_requests (
    id, entity_type, entity_id, entity_snapshot, target_base_version,
    requested_by, firm_id, status, created_at, updated_at
  )
  values
    ('scope-request-firm', 'case', 'scope-firm-by-removed', '{}', 1,
     c_removed, c_firm, 'pending', v_now_ms, v_now_ms),
    ('scope-request-dissolved', 'case', 'scope-firm-by-removed', '{}', 1,
     c_removed, null, 'pending', v_now_ms, v_now_ms);

  update public.delete_requests
     set scope_owner_id = c_owner
   where id = 'scope-request-dissolved';

  -- conflict_log is not a ledger table: its select is own-rows-meets-my-firm.
  insert into public.conflict_log (
    id, user_id, firm_id, mutation_id, entity_type, entity_id, base_version,
    base_payload, submitted_payload, changed_fields, server_version,
    server_payload, resolution_state, conflict_at, updated_at
  )
  values
    ('scope-conflict-firm', c_removed, c_firm, 'scope-conflict-m1', 'case',
     'scope-firm-by-removed', 1, '{}', '{}', '{}', 2, '{}', 'unresolved',
     v_now_ms, v_now_ms),
    ('scope-conflict-personal', c_removed, null, 'scope-conflict-m2', 'case',
     'scope-personal-by-removed', 1, '{}', '{}', '{}', 2, '{}', 'unresolved',
     v_now_ms, v_now_ms);
end;
$$;

-- ---------------------------------------------------------------------------
-- The proof
-- ---------------------------------------------------------------------------

do $$
declare
  c_owner uuid := (select id::uuid from scope_fixtures where name = 'owner');
  c_assoc uuid := (select id::uuid from scope_fixtures where name = 'associate');
  c_removed uuid := (select id::uuid from scope_fixtures where name = 'removed');
  c_outsider uuid := (select id::uuid from scope_fixtures where name = 'outsider');
  c_builtin_court text :=
    (select id from scope_fixtures where name = 'builtin_court');
begin
  -- 1. The columns exist on every ledger table, and not on conflict_log.
  declare
    v_missing text;
  begin
    select string_agg(t.table_name, ', ' order by t.table_name)
      into v_missing
      from (values
        ('cases'), ('case_history'), ('notes'), ('case_references'),
        ('delete_requests'), ('court_categories'), ('case_categories'),
        ('courts'), ('steps'), ('case_types'), ('on_behalfs')
      ) as t(table_name)
     where not exists (
       select 1 from information_schema.columns c
        where c.table_schema = 'public'
          and c.table_name = t.table_name
          and c.column_name = 'scope_owner_id'
     );

    perform pg_temp.assert_true(
      v_missing is null,
      'some ledger tables have no scope_owner_id: ' || coalesce(v_missing, '')
    );
    perform pg_temp.assert_true(
      not exists (
        select 1 from information_schema.columns
         where table_schema = 'public' and table_name = 'conflict_log'
           and column_name = 'scope_owner_id'
      ),
      'conflict_log must not carry a scope owner'
    );
  end;

  -- 2. The removal leak: a chamber row is invisible to its author once they
  --    have left, and still visible to the chamber.
  perform pg_temp.assert_true(
    pg_temp.count_as(
      c_removed,
      'select id from public.cases where id = ''scope-firm-by-removed'''
    ) = 0,
    'a removed member still reads their authored chamber case'
  );
  perform pg_temp.assert_true(
    pg_temp.count_as(
      c_owner,
      'select id from public.cases where id = ''scope-firm-by-removed'''
    ) = 1,
    'the owner cannot read a case authored in the chamber'
  );
  perform pg_temp.assert_true(
    pg_temp.count_as(
      c_assoc,
      'select id from public.cases where id = ''scope-firm-by-assoc'''
    ) = 1,
    'an associate cannot read their own chamber case'
  );
  perform pg_temp.assert_true(
    pg_temp.count_as(
      c_outsider,
      'select id from public.cases where id = ''scope-firm-by-removed'''
    ) = 0,
    'an unrelated account reads a chamber''s case'
  );

  -- 3. The same rule on the other three case-data tables.
  perform pg_temp.assert_true(
    pg_temp.count_as(
      c_removed,
      'select id from public.case_history where id = ''scope-history-firm'''
    ) = 0,
    'a removed member still reads their authored chamber case history'
  );
  perform pg_temp.assert_true(
    pg_temp.count_as(
      c_removed,
      'select id from public.notes where id = ''scope-note-firm'''
    ) = 0,
    'a removed member still reads their authored chamber note'
  );
  perform pg_temp.assert_true(
    pg_temp.count_as(
      c_assoc,
      'select id from public.notes where id = ''scope-note-firm'''
    ) = 1,
    'an associate cannot read a chamber note'
  );
  perform pg_temp.assert_true(
    pg_temp.count_as(
      c_removed,
      'select id from public.case_references where id = ''scope-reference-firm'''
    ) = 0,
    'a removed member still reads their authored chamber case reference'
  );

  -- 4. An individual's own diary is untouched, in both directions.
  perform pg_temp.assert_true(
    pg_temp.count_as(
      c_removed,
      'select id from public.cases where id = ''scope-personal-by-removed'''
    ) = 1,
    'an account lost the read on its own firm-less row'
  );
  perform pg_temp.assert_true(
    pg_temp.count_as(
      c_outsider,
      'select id from public.cases where id = ''scope-personal-by-removed'''
    ) = 0,
    'a personal row is readable by another account'
  );

  -- 5. The dissolve's scope owner keeps the ledger; its author does not.
  perform pg_temp.assert_true(
    pg_temp.count_as(
      c_owner,
      'select id from public.cases where id = ''scope-personal-by-owner'''
    ) = 1,
    'the scope owner cannot read a dissolved row'
  );
  perform pg_temp.assert_true(
    pg_temp.count_as(
      c_removed,
      'select id from public.cases where id = ''scope-personal-by-owner'''
    ) = 0,
    'a dissolved row is readable by its author rather than its scope owner'
  );

  -- 6. A custom reference row follows the chamber; the built-in baseline does
  --    not move for anybody.
  perform pg_temp.assert_true(
    pg_temp.count_as(
      c_removed,
      'select id from public.courts where id = ''scope-court-firm'''
    ) = 0,
    'a removed member still reads the chamber''s custom court'
  );
  perform pg_temp.assert_true(
    pg_temp.count_as(
      c_assoc,
      'select id from public.courts where id = ''scope-court-firm'''
    ) = 1,
    'an associate cannot read the chamber''s custom court'
  );
  perform pg_temp.assert_true(
    pg_temp.count_as(
      c_removed,
      format(
        'select id from public.courts where id = %L',
        c_builtin_court
      )
    ) = 1,
    'the built-in reference baseline is no longer readable by everyone'
  );

  -- 7. delete_requests: the chamber's queue is the chamber's, and a dissolved
  --    request stays with its scope owner.
  perform pg_temp.assert_true(
    pg_temp.count_as(
      c_removed,
      'select id from public.delete_requests where id = ''scope-request-firm'''
    ) = 0,
    'a removed member still reads the chamber''s delete request'
  );
  perform pg_temp.assert_true(
    pg_temp.count_as(
      c_owner,
      'select id from public.delete_requests where id = ''scope-request-firm'''
    ) = 1,
    'the owner cannot read the chamber''s delete request'
  );
  perform pg_temp.assert_true(
    pg_temp.count_as(
      c_owner,
      'select id from public.delete_requests '
      'where id = ''scope-request-dissolved'''
    ) = 1,
    'the scope owner cannot read a dissolved delete request'
  );
  perform pg_temp.assert_true(
    pg_temp.count_as(
      c_removed,
      'select id from public.delete_requests '
      'where id = ''scope-request-dissolved'''
    ) = 0,
    'a dissolved delete request is readable by its requester'
  );

  -- 8. conflict_log keeps the membership condition only.
  perform pg_temp.assert_true(
    pg_temp.count_as(
      c_removed,
      'select id from public.conflict_log where id = ''scope-conflict-firm'''
    ) = 0,
    'a removed member still reads a chamber merge diagnostic'
  );
  perform pg_temp.assert_true(
    pg_temp.count_as(
      c_removed,
      'select id from public.conflict_log '
      'where id = ''scope-conflict-personal'''
    ) = 1,
    'a removed member lost their own firm-less merge diagnostic'
  );

  -- 9. `scope_owner_id` is server-only, while the ordinary columns a client
  --    writes still land. The refusal is an error, so both shapes are pinned.
  perform pg_temp.assert_raises_as(
    c_removed,
    'update public.cases set scope_owner_id = ''00000000-0000-0000-0000-000000000001'' '
    || 'where id = ''scope-personal-by-removed''',
    'permission denied'
  );
  perform pg_temp.assert_true(
    pg_temp.rows_as(
      c_removed,
      'update public.cases set case_remarks = ''still writable'' '
      || 'where id = ''scope-personal-by-removed'''
    ) = 1,
    'a granted column became unwritable'
  );
end;
$$;

rollback;

\echo 'SCOPE OK: the read side is scoped, and scope_owner_id is server-only.'
