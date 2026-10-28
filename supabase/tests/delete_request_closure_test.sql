-- Delete-request closure proof — proves
-- `20261028100000_delete_request_target_closure.sql`.
--
-- What was wrong: a delete request watched nothing. A member holding
-- `can_delete` could delete the record a colleague had already asked about, and
-- the request stayed `pending` for ever — in every reviewer's queue as something
-- that could never succeed, in the requester's list as "waiting", and the only
-- way to clear it was to reject it, recording a decision that never happened.
-- The fix closes every still-open request for a record the moment that record is
-- tombstoned, in the same transaction, and allows only one open request per
-- record.
--
-- Self-contained: every fixture is created inside one transaction that is rolled
-- back, so no account, request or tombstone survives. It opens its own `begin`,
-- so run it wrapped, like the other probes here:
--
--   printf 'begin;\n' | cat - supabase/tests/delete_request_closure_test.sql \
--     <(echo rollback;) | psql "$URL" -v ON_ERROR_STOP=1 --file=-
--
-- Checks, in order:
--
--   * a case delete through the app's own `push_changes` closes the request for
--     it as `already_deleted`, at the next version, stamped by the deleter;
--   * a case-history row, a note and a reference each close their own request
--     the same way;
--   * a request the server had parked as `stale_review_required` is closed too;
--   * an **approval** still ends `approved`, not `already_deleted`: the approval
--     writes after the tombstone it causes, so the trigger's write is replaced;
--   * a second open request for the same record is refused by the unique index;
--   * the function is internal (`authenticated` cannot execute it).

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
    raise exception 'CLOSURE FAIL: %', p_message;
  end if;
end;
$$;

-- Makes auth.uid() resolve to p_user, as the role the app's calls carry.
create or replace function pg_temp.as_user(p_user uuid)
returns void
language plpgsql
as $$
begin
  perform set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', p_user::text, 'role', 'authenticated')::text,
    true
  );
  execute 'set local role authenticated';
end;
$$;

-- Claims only, without switching role: a direct table write made as the
-- database owner still has to pass the tombstone gate, which reads auth.uid().
create or replace function pg_temp.as_claim(p_user uuid)
returns void
language plpgsql
as $$
begin
  perform set_config(
    'request.jwt.claims',
    jsonb_build_object('sub', p_user::text, 'role', 'authenticated')::text,
    true
  );
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

-- One mutation through the app's own RPC, and its single result back.
create or replace function pg_temp.push(p_mutation jsonb)
returns jsonb
language plpgsql
as $$
begin
  return public.push_changes(jsonb_build_array(p_mutation)) -> 'results' -> 0;
end;
$$;

-- ---------------------------------------------------------------------------
-- Fixture: a chamber with an owner who may delete and an associate who may not
-- ---------------------------------------------------------------------------

do $$
declare
  v_owner uuid := gen_random_uuid();
  v_assoc uuid := gen_random_uuid();
  v_firm uuid := gen_random_uuid();
  v_court text;
  v_on_behalf text;
begin
  insert into auth.users (
    id, instance_id, aud, role, email, email_confirmed_at, created_at, updated_at
  )
  values
    (v_owner, '00000000-0000-0000-0000-000000000000', 'authenticated',
     'authenticated', 'closure-owner@example.test', now(), now(), now()),
    (v_assoc, '00000000-0000-0000-0000-000000000000', 'authenticated',
     'authenticated', 'closure-assoc@example.test', now(), now(), now());

  insert into public.firms (id, name, owner_id, subscription_expiry, subscription_status)
  values (v_firm, 'Closure Chambers', v_owner, now() + interval '30 days', 'premium');

  update public.profiles
     set firm_id = v_firm, role = 'owner', full_name = 'Closure Owner'
   where id = v_owner;

  update public.profiles
     set firm_id = v_firm, role = 'associate', full_name = 'Closure Associate'
   where id = v_assoc;

  insert into public.firm_members (firm_id, user_id, role, can_add, can_edit, can_delete)
  values
    (v_firm, v_owner, 'owner', true, true, true),
    (v_firm, v_assoc, 'associate', true, true, false);

  select id into v_court
    from public.courts
   where is_custom = false and is_deleted = false
   order by id limit 1;
  select id into v_on_behalf
    from public.on_behalfs
   where is_custom = false and is_deleted = false
   order by id limit 1;

  perform pg_temp.assert_true(
    v_court is not null and v_on_behalf is not null,
    'the built-in seed data is missing; apply the seed migration first'
  );

  -- Three cases: one deleted through the app's door, one carrying the history
  -- row under test, and one whose request is approved.
  insert into public.cases (
    id, user_id, firm_id, court_id, case_type, case_number, petitioner,
    respondent, on_behalf_id, next_date, created_at, updated_at,
    last_modified_by, is_deleted, version
  )
  values
    ('closure-case-1', v_owner, v_firm, v_court, 'Civil', 'CLOSE-1',
     'Petitioner', 'Respondent', v_on_behalf, 1000, 0, 0, v_owner::text, false, 1),
    ('closure-case-2', v_owner, v_firm, v_court, 'Civil', 'CLOSE-2',
     'Petitioner', 'Respondent', v_on_behalf, 1000, 0, 0, v_owner::text, false, 1),
    ('closure-case-3', v_owner, v_firm, v_court, 'Civil', 'CLOSE-3',
     'Petitioner', 'Respondent', v_on_behalf, 1000, 0, 0, v_owner::text, false, 1),
    ('closure-case-4', v_owner, v_firm, v_court, 'Civil', 'CLOSE-4',
     'Petitioner', 'Respondent', v_on_behalf, 1000, 0, 0, v_owner::text, false, 1);

  insert into public.case_history (
    id, case_id, user_id, firm_id, hearing_date, last_step, next_date,
    note_result, result, created_by, source_mutation_id, base_case_version,
    result_case_version, updated_at, version, is_deleted, last_modified_by
  )
  values (
    'closure-hist-1', 'closure-case-2', v_owner, v_firm, 1000, 'Step', 2000,
    'Result', 'Result', v_owner, 'closure-hist-mut-1', 1, 2, 0, 1, false,
    v_owner::text
  );

  insert into public.notes (
    id, user_id, firm_id, title, body, items, is_pinned, created_at,
    updated_at, version, is_deleted, last_modified_by
  )
  values (
    'closure-note-1', v_owner, v_firm, 'Note', 'Body', null, false, 0, 0, 1,
    false, v_owner::text
  );

  insert into public.case_references (
    id, user_id, firm_id, reference_and_page_no, statute, section_or_article,
    title_and_description, comments_notes, is_pinned, created_at, updated_at,
    version, is_deleted, last_modified_by
  )
  values (
    'closure-ref-1', v_owner, v_firm, 'Page 1', null, null, 'Title', null,
    false, 0, 0, 1, false, v_owner::text
  );

  -- One pending request per record under test, plus a parked one. The
  -- requester's name is filled by the server's own BEFORE INSERT trigger.
  insert into public.delete_requests (
    id, firm_id, entity_type, entity_id, entity_snapshot, target_base_version,
    requested_by, requester_name, status, created_at, updated_at,
    last_modified_by, is_deleted, version
  )
  values
    ('closure-req-case', v_firm, 'case', 'closure-case-1',
     '{"id":"closure-case-1"}', 1, v_assoc, '', 'pending', 0, 0,
     v_assoc::text, false, 1),
    ('closure-req-hist', v_firm, 'case_history', 'closure-hist-1',
     '{"id":"closure-hist-1"}', 1, v_assoc, '', 'pending', 0, 0,
     v_assoc::text, false, 1),
    ('closure-req-note', v_firm, 'note', 'closure-note-1',
     '{"id":"closure-note-1"}', 1, v_assoc, '', 'pending', 0, 0,
     v_assoc::text, false, 1),
    ('closure-req-ref', v_firm, 'reference', 'closure-ref-1',
     '{"id":"closure-ref-1"}', 1, v_assoc, '', 'pending', 0, 0,
     v_assoc::text, false, 1),
    ('closure-req-stale', v_firm, 'case', 'closure-case-4',
     '{"id":"closure-case-4"}', 1, v_assoc, '', 'stale_review_required', 0, 0,
     v_assoc::text, false, 1),
    ('closure-req-approve', v_firm, 'case', 'closure-case-3',
     '{"id":"closure-case-3"}', 1, v_assoc, '', 'pending', 0, 0,
     v_assoc::text, false, 1);

  perform pg_temp.assert_true(
    (select count(*) from public.delete_requests
      where requester_name = 'Closure Associate') = 6,
    'the requester_name trigger did not derive the name from profiles'
  );

  perform set_config('test.owner', v_owner::text, true);
  perform set_config('test.assoc', v_assoc::text, true);
  perform set_config('test.firm', v_firm::text, true);
end;
$$;

-- ---------------------------------------------------------------------------
-- 1. A case deleted through the app's door closes the request for it
-- ---------------------------------------------------------------------------

do $$
declare
  v_owner uuid := current_setting('test.owner')::uuid;
  v_out jsonb;
begin
  perform pg_temp.as_user(v_owner);
  v_out := pg_temp.push(jsonb_build_object(
    'mutation_id', 'closure-mut-case-delete',
    'entity_type', 'case',
    'entity_id', 'closure-case-1',
    'operation', 'delete',
    'base_version', 1,
    'changed_fields', jsonb_build_array('is_deleted', 'updated_at', 'last_modified_by'),
    'payload', jsonb_build_object(
      'id', 'closure-case-1',
      'is_deleted', true,
      'updated_at', 20,
      'last_modified_by', v_owner
    )
  ));

  perform pg_temp.assert_true(
    v_out ->> 'status' = 'accepted',
    'the case delete was not accepted (status '
      || coalesce(v_out ->> 'status', 'null') || ', code '
      || coalesce(v_out ->> 'error_code', 'null') || ')'
  );
  perform pg_temp.assert_true(
    (select status from public.delete_requests where id = 'closure-req-case')
      = 'already_deleted',
    'the request outlived the case it named'
  );
  perform pg_temp.assert_true(
    (select version from public.delete_requests where id = 'closure-req-case') = 2,
    'closing the request did not move it to the next version'
  );
  perform pg_temp.assert_true(
    (select last_modified_by from public.delete_requests where id = 'closure-req-case')
      = v_owner::text,
    'the closed request does not name who deleted the record'
  );
  perform pg_temp.assert_true(
    (select updated_at from public.delete_requests where id = 'closure-req-case') > 0,
    'the closed request carries no closing time'
  );
  perform pg_temp.assert_true(
    not exists (
      select 1 from public.delete_requests
       where id = 'closure-req-case' and status = 'pending'
    ),
    'the closed request still reads as pending'
  );

  perform pg_temp.as_owner();
end;
$$;

-- ---------------------------------------------------------------------------
-- 2. A case step, a note and a reference close their own requests
-- ---------------------------------------------------------------------------
-- The tombstone is written directly here: the trigger is a table rule, and this
-- half of the proof is about the rule, not the RPC (step 1 already drove the
-- app's own door).

do $$
declare
  v_ms bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint;
begin
  perform pg_temp.as_claim(current_setting('test.owner')::uuid);

  update public.case_history
     set is_deleted = true, version = version + 1,
         updated_at = v_ms, last_modified_by = 'closure-deleter'
   where id = 'closure-hist-1';

  update public.notes
     set is_deleted = true, version = version + 1,
         updated_at = v_ms, last_modified_by = 'closure-deleter'
   where id = 'closure-note-1';

  update public.case_references
     set is_deleted = true, version = version + 1,
         updated_at = v_ms, last_modified_by = 'closure-deleter'
   where id = 'closure-ref-1';

  perform pg_temp.assert_true(
    (select status from public.delete_requests where id = 'closure-req-hist')
      = 'already_deleted',
    'the case-step request outlived its step'
  );
  perform pg_temp.assert_true(
    (select status from public.delete_requests where id = 'closure-req-note')
      = 'already_deleted',
    'the note request outlived its note'
  );
  perform pg_temp.assert_true(
    (select status from public.delete_requests where id = 'closure-req-ref')
      = 'already_deleted',
    'the reference request outlived its reference'
  );

  perform pg_temp.as_owner();
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. A parked (stale) request closes the same way
-- ---------------------------------------------------------------------------

do $$
declare
  v_ms bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint;
begin
  perform pg_temp.as_claim(current_setting('test.owner')::uuid);

  update public.cases
     set is_deleted = true, version = version + 1,
         updated_at = v_ms, last_modified_by = 'closure-deleter'
   where id = 'closure-case-4';

  perform pg_temp.assert_true(
    (select status from public.delete_requests where id = 'closure-req-stale')
      = 'already_deleted',
    'a parked request was left in the queue after its record was deleted'
  );

  perform pg_temp.as_owner();
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. Only one open request per record
-- ---------------------------------------------------------------------------
-- `closure-req-approve` is still open on `closure-case-3`; a second one must be
-- refused by the partial unique index rather than queueing a row that can only
-- end in a pointless approval.

do $$
declare
  v_assoc uuid := current_setting('test.assoc')::uuid;
  v_firm uuid := current_setting('test.firm')::uuid;
  v_refused boolean := false;
begin
  begin
    insert into public.delete_requests (
      id, firm_id, entity_type, entity_id, entity_snapshot, target_base_version,
      requested_by, requester_name, status, created_at, updated_at,
      last_modified_by, is_deleted, version
    )
    values (
      'closure-req-duplicate', v_firm, 'case', 'closure-case-3',
      '{"id":"closure-case-3"}', 1, v_assoc, '', 'pending', 0, 0,
      v_assoc::text, false, 1
    );
  exception when unique_violation then
    v_refused := true;
  end;

  perform pg_temp.assert_true(
    v_refused,
    'a second open request for one record was allowed'
  );
  perform pg_temp.assert_true(
    not exists (select 1 from public.delete_requests
                 where id = 'closure-req-duplicate'),
    'the refused duplicate was stored anyway'
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 5. An approval still ends approved — the trigger does not win
-- ---------------------------------------------------------------------------
-- Approving tombstones the target, which fires the closure trigger; the approval
-- then writes `approved` on the request, and that must be the last word.

do $$
declare
  v_owner uuid := current_setting('test.owner')::uuid;
  v_out jsonb;
begin
  perform pg_temp.as_user(v_owner);
  v_out := pg_temp.push(jsonb_build_object(
    'mutation_id', 'closure-mut-approve',
    'entity_type', 'delete_request',
    'entity_id', 'closure-req-approve',
    'operation', 'update',
    'base_version', 1,
    'changed_fields', jsonb_build_array('status', 'reviewed_by', 'updated_at'),
    'payload', jsonb_build_object(
      'id', 'closure-req-approve',
      'status', 'approved',
      'reviewed_by', v_owner,
      'updated_at', 30
    )
  ));

  perform pg_temp.assert_true(
    v_out ->> 'status' = 'accepted',
    'the approval was not accepted (status '
      || coalesce(v_out ->> 'status', 'null') || ', code '
      || coalesce(v_out ->> 'error_code', 'null') || ')'
  );
  perform pg_temp.assert_true(
    (select status from public.delete_requests where id = 'closure-req-approve')
      = 'approved',
    'the closure trigger overwrote the approval with already_deleted'
  );
  perform pg_temp.assert_true(
    (select is_deleted from public.cases where id = 'closure-case-3') = true,
    'the approval did not delete the record it named'
  );
  perform pg_temp.assert_true(
    (select count(*) from public.delete_requests
      where id = 'closure-req-approve'
        and reviewed_by = v_owner
        and version = 2) = 1,
    'the approved request lost its reviewer or its version'
  );

  perform pg_temp.as_owner();
end;
$$;

-- ---------------------------------------------------------------------------
-- 6. The rule stays internal
-- ---------------------------------------------------------------------------

do $$
begin
  perform pg_temp.as_owner();

  perform pg_temp.assert_true(
    not has_function_privilege(
      'authenticated',
      'public.close_delete_requests_for_deleted_target()',
      'EXECUTE'
    ),
    'authenticated can execute the closure function directly'
  );
  perform pg_temp.assert_true(
    (select count(*) from pg_trigger
      where tgname in (
        'cases_close_delete_requests',
        'case_history_close_delete_requests',
        'notes_close_delete_requests',
        'case_references_close_delete_requests'
      )
        and not tgisinternal) = 4,
    'the closure rule is not attached to all four tables a request may name'
  );
end;
$$;

select 'CLOSURE OK: a deleted record closes its request as already_deleted, '
       'all four kinds do it, a parked request closes too, an approval still '
       'ends approved, one open request per record is enforced, and the rule '
       'stays internal.' as result;
