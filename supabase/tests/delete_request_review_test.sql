-- Delete-request review proof — proves
-- `20261027100000_delete_request_review_firm_scope.sql`.
--
-- What was wrong: `push_changes` subtracts the scope columns before handing a row
-- to `sync_can_write` (an existing row keeps the firm it has). Every other table
-- has a trigger for the rule the subtracted firm would have weighed, but
-- `delete_requests` is deliberately left out of the permission boundary — raising
-- a request must stay open to every member — so its update/delete branch was the
-- one rule a null firm decided: **a reviewer's rejection, a requester's snapshot
-- refresh and a withdrawal were all refused with `permission_denied`**, while an
-- approval (which validates the stored row first) worked. The client rolls such a
-- refusal back from its pre-mutation snapshot, so the request returned to the
-- review queue and the app claimed the user's permissions had changed.
--
-- This file drives every decision through `public.push_changes` as an
-- `authenticated` caller — the app's own door — over a two-account chamber in the
-- shape the app builds: an owner who may delete, and an associate who may add and
-- edit but not delete (which is what raises a request at all).
--
-- Self-contained: every fixture is created inside one transaction that is rolled
-- back, so no account, request or tombstone survives. It opens its own `begin`,
-- so run it wrapped, like the other probes here:
--
--   printf 'begin;\n' | cat - supabase/tests/delete_request_review_test.sql \
--     <(echo rollback;) | psql "$URL" -v ON_ERROR_STOP=1 --file=-
--
-- Eight checks, in order:
--
--   * a **rejection** by the reviewer is accepted and records who reviewed it;
--   * an **approval** is accepted *and* tombstones the record the request names,
--     handing the tombstone back as `target` so the reviewer's own device can
--     hide it without waiting for a pull;
--   * the **requester's refresh** of their own pending request is accepted, and
--     the new snapshot and observed version land on the row;
--   * the **requester's withdrawal** (a delete) is accepted and tombstones the
--     request itself;
--   * a **decided request cannot be withdrawn**: the same delete is refused once
--     the request has been answered;
--   * the **requester cannot review**: the same approval payload is refused
--     `permission_denied`, so the fix opens nothing;
--   * a **decided request cannot be re-opened** by its requester, which is the
--     rule the same branch carries;
--   * the function stays **internal** (`authenticated` cannot execute it) and its
--     body carries the stored-firm lookup.

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
    raise exception 'REVIEW FAIL: %', p_message;
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
-- Fixture: a chamber with an owner and an associate who may not delete
-- ---------------------------------------------------------------------------

do $$
declare
  v_owner uuid := gen_random_uuid();
  v_assoc uuid := gen_random_uuid();
  v_firm uuid := gen_random_uuid();
  v_court text;
  v_on_behalf text;
  v_case text := 'review-case-1';
  i integer;
begin
  insert into auth.users (
    id, instance_id, aud, role, email, email_confirmed_at, created_at, updated_at
  )
  values
    (v_owner, '00000000-0000-0000-0000-000000000000', 'authenticated',
     'authenticated', 'review-owner@example.test', now(), now(), now()),
    (v_assoc, '00000000-0000-0000-0000-000000000000', 'authenticated',
     'authenticated', 'review-assoc@example.test', now(), now(), now());

  -- The sign-up trigger created both profiles. The chamber is the plan holder,
  -- which is what entitles a member's pushes (`has_sync_entitlement` reads the
  -- firm's expiry once `profiles.firm_id` is set).
  insert into public.firms (id, name, owner_id, subscription_expiry, subscription_status)
  values (v_firm, 'Review Chambers', v_owner, now() + interval '30 days', 'premium');

  update public.profiles
     set firm_id = v_firm, role = 'owner', full_name = 'Review Owner'
   where id = v_owner;

  update public.profiles
     set firm_id = v_firm, role = 'associate', full_name = 'Review Associate'
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

  -- The record being asked about: the owner's own case inside the chamber, at
  -- version 1 — the state a request records as its `target_base_version`.
  insert into public.cases (
    id, user_id, firm_id, court_id, case_type, case_number, petitioner,
    respondent, on_behalf_id, next_date, created_at, updated_at,
    last_modified_by, is_deleted, version
  )
  values (
    v_case, v_owner, v_firm, v_court, 'Civil', 'REVIEW-1', 'Petitioner',
    'Respondent', v_on_behalf, 1000, 0, 0, v_owner::text, false, 1
  );

  -- Four pending requests by the associate, one per decision below. The
  -- requester's name is left blank on purpose: the BEFORE INSERT trigger fills it
  -- from `profiles`, which is the server's own rule for the column.
  for i in 1..4 loop
    insert into public.delete_requests (
      id, firm_id, entity_type, entity_id, entity_snapshot, target_base_version,
      requested_by, requester_name, status, created_at, updated_at,
      last_modified_by, is_deleted, version
    )
    values (
      'review-req-' || i, v_firm, 'case', v_case,
      jsonb_build_object('id', v_case)::text, 1,
      v_assoc, '', 'pending', 0, 0, v_assoc::text, false, 1
    );
  end loop;

  perform pg_temp.assert_true(
    (select count(*) from public.delete_requests
      where requester_name = 'Review Associate') = 4,
    'the requester_name trigger did not derive the name from profiles'
  );

  perform set_config('test.owner', v_owner::text, true);
  perform set_config('test.assoc', v_assoc::text, true);
  perform set_config('test.firm', v_firm::text, true);
  perform set_config('test.case', v_case, true);
end;
$$;

-- ---------------------------------------------------------------------------
-- 1. The reviewer's rejection is accepted
-- ---------------------------------------------------------------------------
--
-- This is the reported defect: the reviewer holds can_delete, the row names the
-- associate as requester and the firm only in the stored row, and the verdict was
-- `permission_denied` before the fix.

do $$
declare
  v_owner uuid := current_setting('test.owner')::uuid;
  v_assoc uuid := current_setting('test.assoc')::uuid;
  v_out jsonb;
begin
  perform pg_temp.as_user(v_owner);
  v_out := pg_temp.push(jsonb_build_object(
    'mutation_id', 'review-mut-reject',
    'entity_type', 'delete_request',
    'entity_id', 'review-req-1',
    'operation', 'update',
    'base_version', 1,
    'changed_fields', jsonb_build_array('status', 'review_note', 'reviewed_by', 'updated_at'),
    'payload', jsonb_build_object(
      'id', 'review-req-1',
      'status', 'rejected',
      'review_note', 'Not this one.',
      'reviewed_by', v_owner,
      'updated_at', 5
    )
  ));

  perform pg_temp.assert_true(
    v_out ->> 'status' = 'accepted',
    'a reviewer''s rejection was not accepted (status '
      || coalesce(v_out ->> 'status', 'null') || ', code '
      || coalesce(v_out ->> 'error_code', 'null') || ')'
  );
  perform pg_temp.assert_true(
    (select status from public.delete_requests where id = 'review-req-1') = 'rejected'
      and (select reviewed_by from public.delete_requests where id = 'review-req-1') = v_owner
      and (select version from public.delete_requests where id = 'review-req-1') = 2,
    'the rejection did not land as a reviewed row at version 2'
  );
  perform pg_temp.assert_true(
    (select requester_name from public.delete_requests where id = 'review-req-1')
      = 'Review Associate',
    'a review overwrote the requester''s own name'
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 2. The reviewer's approval tombstones the record it names
-- ---------------------------------------------------------------------------

do $$
declare
  v_owner uuid := current_setting('test.owner')::uuid;
  v_case text := current_setting('test.case');
  v_out jsonb;
begin
  perform pg_temp.as_user(v_owner);
  v_out := pg_temp.push(jsonb_build_object(
    'mutation_id', 'review-mut-approve',
    'entity_type', 'delete_request',
    'entity_id', 'review-req-2',
    'operation', 'update',
    'base_version', 1,
    'changed_fields', jsonb_build_array('status', 'reviewed_by', 'updated_at'),
    'payload', jsonb_build_object(
      'id', 'review-req-2',
      'status', 'approved',
      'reviewed_by', v_owner,
      'updated_at', 6
    )
  ));

  perform pg_temp.assert_true(
    v_out ->> 'status' = 'accepted',
    'an approval was not accepted (status ' || coalesce(v_out ->> 'status', 'null')
      || ', code ' || coalesce(v_out ->> 'error_code', 'null') || ')'
  );
  perform pg_temp.assert_true(
    v_out ->> 'target_entity_type' = 'case'
      and (v_out #>> '{target,is_deleted}')::boolean = true
      and (v_out #>> '{target,id}') = v_case,
    'the approval did not hand the record''s tombstone back as the target'
  );
  perform pg_temp.assert_true(
    (select is_deleted from public.cases where id = v_case) = true
      and (select version from public.cases where id = v_case) = 2,
    'the approved record was not tombstoned at version 2'
  );
  perform pg_temp.assert_true(
    (select status from public.delete_requests where id = 'review-req-2') = 'approved',
    'the approved request was not resolved beside the tombstone'
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. The requester's own refresh is accepted
-- ---------------------------------------------------------------------------

do $$
declare
  v_assoc uuid := current_setting('test.assoc')::uuid;
  v_out jsonb;
begin
  perform pg_temp.as_user(v_assoc);
  v_out := pg_temp.push(jsonb_build_object(
    'mutation_id', 'review-mut-refresh',
    'entity_type', 'delete_request',
    'entity_id', 'review-req-3',
    'operation', 'update',
    'base_version', 1,
    'changed_fields', jsonb_build_array('entity_snapshot', 'target_base_version', 'updated_at'),
    'payload', jsonb_build_object(
      'id', 'review-req-3',
      'entity_snapshot', '{"id":"review-case-1","version":2}',
      'target_base_version', 2,
      'updated_at', 7
    )
  ));

  perform pg_temp.assert_true(
    v_out ->> 'status' = 'accepted',
    'the requester''s refresh was not accepted (status '
      || coalesce(v_out ->> 'status', 'null') || ', code '
      || coalesce(v_out ->> 'error_code', 'null') || ')'
  );
  perform pg_temp.assert_true(
    (select target_base_version from public.delete_requests where id = 'review-req-3') = 2
      and (select entity_snapshot from public.delete_requests where id = 'review-req-3')
            = '{"id":"review-case-1","version":2}',
    'the refresh did not replace the snapshot and the observed version'
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 4. The requester's own withdrawal is accepted
-- ---------------------------------------------------------------------------

do $$
declare
  v_assoc uuid := current_setting('test.assoc')::uuid;
  v_out jsonb;
begin
  perform pg_temp.as_user(v_assoc);
  v_out := pg_temp.push(jsonb_build_object(
    'mutation_id', 'review-mut-cancel',
    'entity_type', 'delete_request',
    'entity_id', 'review-req-4',
    'operation', 'delete',
    'base_version', 1,
    'changed_fields', jsonb_build_array('is_deleted', 'updated_at', 'last_modified_by'),
    'payload', jsonb_build_object(
      'id', 'review-req-4',
      'is_deleted', true,
      'updated_at', 8,
      'last_modified_by', v_assoc
    )
  ));

  perform pg_temp.assert_true(
    v_out ->> 'status' = 'accepted',
    'the requester''s withdrawal was not accepted (status '
      || coalesce(v_out ->> 'status', 'null') || ', code '
      || coalesce(v_out ->> 'error_code', 'null') || ', message '
      || coalesce(v_out ->> 'message', 'null') || ')'
  );
  perform pg_temp.assert_true(
    (select is_deleted from public.delete_requests where id = 'review-req-4') = true,
    'the withdrawn request was not tombstoned'
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 5. A decided request cannot be withdrawn
-- ---------------------------------------------------------------------------
--
-- The withdrawal exit is keyed on the request still being pending, so an
-- answered request stays as the audit record it is.

do $$
declare
  v_assoc uuid := current_setting('test.assoc')::uuid;
  v_out jsonb;
begin
  perform pg_temp.as_user(v_assoc);
  v_out := pg_temp.push(jsonb_build_object(
    'mutation_id', 'review-mut-late-withdraw',
    'entity_type', 'delete_request',
    'entity_id', 'review-req-1',
    'operation', 'delete',
    'base_version', 2,
    'changed_fields', jsonb_build_array('is_deleted', 'updated_at', 'last_modified_by'),
    'payload', jsonb_build_object(
      'id', 'review-req-1',
      'is_deleted', true,
      'updated_at', 11,
      'last_modified_by', v_assoc
    )
  ));

  perform pg_temp.assert_true(
    v_out ->> 'status' = 'rejected'
      and v_out ->> 'error_code' = 'permission_denied',
    'a decided request was withdrawn by its requester (status '
      || coalesce(v_out ->> 'status', 'null') || ', code '
      || coalesce(v_out ->> 'error_code', 'null') || ')'
  );
  perform pg_temp.assert_true(
    (select is_deleted from public.delete_requests where id = 'review-req-1') = false
      and (select status from public.delete_requests where id = 'review-req-1') = 'rejected',
    'a refused withdrawal still erased the decided request'
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 6. The fix opens nothing: the requester still cannot review
-- ---------------------------------------------------------------------------

do $$
declare
  v_assoc uuid := current_setting('test.assoc')::uuid;
  v_out jsonb;
begin
  perform pg_temp.as_user(v_assoc);
  v_out := pg_temp.push(jsonb_build_object(
    'mutation_id', 'review-mut-self-approve',
    'entity_type', 'delete_request',
    'entity_id', 'review-req-3',
    'operation', 'update',
    'base_version', 2,
    'changed_fields', jsonb_build_array('status', 'updated_at'),
    'payload', jsonb_build_object(
      'id', 'review-req-3',
      'status', 'approved',
      'updated_at', 9
    )
  ));

  perform pg_temp.assert_true(
    v_out ->> 'status' = 'rejected'
      and v_out ->> 'error_code' = 'permission_denied',
    'the requester was not refused their own approval (status '
      || coalesce(v_out ->> 'status', 'null') || ', code '
      || coalesce(v_out ->> 'error_code', 'null') || ')'
  );
  perform pg_temp.assert_true(
    (select status from public.delete_requests where id = 'review-req-3') = 'pending',
    'a refused self-approval still moved the request'
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 7. A decided request cannot be re-opened by its requester
-- ---------------------------------------------------------------------------

do $$
declare
  v_assoc uuid := current_setting('test.assoc')::uuid;
  v_out jsonb;
begin
  perform pg_temp.as_user(v_assoc);
  v_out := pg_temp.push(jsonb_build_object(
    'mutation_id', 'review-mut-reopen',
    'entity_type', 'delete_request',
    'entity_id', 'review-req-1',
    'operation', 'update',
    'base_version', 2,
    'changed_fields', jsonb_build_array('entity_snapshot', 'updated_at'),
    'payload', jsonb_build_object(
      'id', 'review-req-1',
      'status', 'rejected',
      'entity_snapshot', '{"id":"review-case-1"}',
      'updated_at', 10
    )
  ));

  perform pg_temp.assert_true(
    v_out ->> 'status' = 'rejected'
      and v_out ->> 'error_code' = 'permission_denied',
    'a decided request was edited by its requester (status '
      || coalesce(v_out ->> 'status', 'null') || ', code '
      || coalesce(v_out ->> 'error_code', 'null') || ')'
  );
  perform pg_temp.assert_true(
    (select version from public.delete_requests where id = 'review-req-1') = 2,
    'the refused edit still bumped the decided request'
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- 8. The helper stays internal, and carries the stored-firm lookup
-- ---------------------------------------------------------------------------

do $$
begin
  perform pg_temp.as_owner();

  perform pg_temp.assert_true(
    not has_function_privilege(
      'authenticated', 'public.sync_can_write(text, jsonb, text)', 'EXECUTE'
    ),
    'authenticated can execute sync_can_write directly'
  );
  perform pg_temp.assert_true(
    position(
      'd.id::text = lower(nullif(p_row ->> ''id'', ''''))'
      in pg_get_functiondef('public.sync_can_write(text, jsonb, text)'::regprocedure)
    ) > 0,
    'the live function does not read the stored request''s firm'
  );
end;
$$;

select 'REVIEW OK: a rejection and an approval land, a requester''s refresh and '
       'withdrawal land, a decided request stays decided, the requester still '
       'cannot review, and the rule reads the stored firm.' as result;
