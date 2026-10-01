-- RPC smoke test — push_changes(rows jsonb).
--
-- Usage (self-contained: it creates its own auth users and rolls back):
--
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 \
--     -f supabase/tests/push_changes_smoke_test.sql
--
-- The whole script runs in one transaction that is rolled back at the end, so
-- no fixture, receipt, row or history event survives. It exercises the
-- contract Task 18 Phase 1 promises: accept, dependency ordering, atomic
-- history on a changed next_date, idempotency, mutation_id_reused, conflict,
-- tombstone/already_resolved, cascade soft-delete, permission and entitlement
-- gates, and the deny for `anon`.
--
-- Every check reports "SMOKE FAIL: ..." through a raised exception, so
-- ON_ERROR_STOP makes a failure exit non-zero.

begin;

-- ---------------------------------------------------------------------------
-- Tiny assertion helpers
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

-- Runs p_sql and requires it to fail with an error mentioning p_message.
create or replace function pg_temp.assert_raises(p_sql text, p_message text)
returns void
language plpgsql
as $$
begin
  begin
    execute p_sql;
  exception
    when others then
      if position(p_message in sqlerrm) = 0 then
        raise exception 'SMOKE FAIL: expected an error mentioning %, got: %',
          p_message, sqlerrm;
      end if;
      return;
  end;
  raise exception
    'SMOKE FAIL: expected an error mentioning %, but the call succeeded',
    p_message;
end;
$$;

-- Makes auth.uid() resolve to p_user for the rest of the transaction.
create or replace function pg_temp.as_user(p_user uuid)
returns void
language sql
as $$
  select set_config(
    'request.jwt.claims',
    json_build_object('sub', p_user::text, 'role', 'authenticated')::text,
    true
  );
$$;

do $$
begin
  if to_regprocedure('public.push_changes(jsonb)') is null then
    raise exception 'SMOKE FAIL: public.push_changes(jsonb) does not exist';
  end if;
  if to_regprocedure('public.sync_entity_table(text)') is null then
    raise exception 'SMOKE FAIL: public.sync_entity_table(text) does not exist';
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Fixtures: three accounts — an entitled owner, a firm associate and a free user
-- ---------------------------------------------------------------------------

do $$
declare
  v_owner uuid := gen_random_uuid();
  v_assoc uuid := gen_random_uuid();
  v_free uuid := gen_random_uuid();
  v_firm uuid := gen_random_uuid();
  v_category text;
  v_on_behalf text;
begin
  insert into auth.users (
    id, instance_id, aud, role, email, email_confirmed_at, created_at, updated_at
  )
  values
    (v_owner, '00000000-0000-0000-0000-000000000000', 'authenticated',
     'authenticated', 'smoke-owner@example.test', now(), now(), now()),
    (v_assoc, '00000000-0000-0000-0000-000000000000', 'authenticated',
     'authenticated', 'smoke-assoc@example.test', now(), now(), now()),
    (v_free, '00000000-0000-0000-0000-000000000000', 'authenticated',
     'authenticated', 'smoke-free@example.test', now(), now(), now());

  -- The sign-up trigger created all three profiles; the owner is premium and a
  -- firm owner, the associate is in that premium firm with can_edit = false, and
  -- the third is a plain free individual. The firm must exist before a profile
  -- can reference it.
  insert into public.firms (id, name, owner_id, subscription_expiry, subscription_status)
  values (v_firm, 'Smoke Chambers', v_owner, now() + interval '30 days', 'premium');

  update public.profiles
     set subscription_expiry = now() + interval '30 days',
         subscription_status = 'premium',
         firm_id = v_firm,
         role = 'owner'
   where id = v_owner;

  update public.profiles
     set firm_id = v_firm, role = 'associate'
   where id = v_assoc;

  insert into public.firm_members (firm_id, user_id, role, can_add, can_edit, can_delete)
  values
    (v_firm, v_owner, 'owner', true, true, true),
    (v_firm, v_assoc, 'associate', true, false, false);

  select id into v_category
    from public.court_categories
   where is_custom = false and is_deleted = false
   order by id limit 1;
  select id into v_on_behalf
    from public.on_behalfs
   where is_custom = false and is_deleted = false
   order by id limit 1;

  perform pg_temp.assert_true(
    v_category is not null and v_on_behalf is not null,
    'the built-in seed data is missing; apply the seed migration first'
  );

  perform set_config('test.owner', v_owner::text, true);
  perform set_config('test.assoc', v_assoc::text, true);
  perform set_config('test.free', v_free::text, true);
  perform set_config('test.firm', v_firm::text, true);
  perform set_config('test.category', v_category, true);
  perform set_config('test.on_behalf', v_on_behalf, true);
end;
$$;

-- `anon` may not execute the RPC.
set local role anon;
select pg_temp.assert_raises(
  'select public.push_changes(''[]''::jsonb)',
  'permission denied'
);
reset role;

-- ---------------------------------------------------------------------------
-- Entitlement: a free individual is refused per mutation, and nothing is written
-- ---------------------------------------------------------------------------

do $$
declare
  v_free uuid := current_setting('test.free')::uuid;
  v_out jsonb;
begin
  perform pg_temp.as_user(v_free);
  v_out := public.push_changes(jsonb_build_array(jsonb_build_object(
    'mutation_id', gen_random_uuid()::text,
    'entity_type', 'court',
    'entity_id', 'smoke-court-denied',
    'operation', 'insert',
    'payload', jsonb_build_object(
      'id', 'smoke-court-denied',
      'court_name', 'Denied Court',
      'higher_lower_courts', 'Lower Court',
      'court_category_id', current_setting('test.category'),
      'order_index', 0,
      'is_custom', true,
      'is_user_modified', false,
      'user_id', v_free,
      'updated_at', 0
    )
  )));

  perform pg_temp.assert_true(
    v_out #>> '{results,0,status}' = 'rejected'
      and v_out #>> '{results,0,error_code}' = 'entitlement_required',
    'a free account was not refused with entitlement_required'
  );
  perform pg_temp.assert_true(
    (select count(*) from public.courts where id = 'smoke-court-denied') = 0,
    'a refused mutation still wrote a row'
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Accept + dependency ordering: the case is first in the batch, its court last
-- ---------------------------------------------------------------------------

do $$
declare
  v_owner uuid := current_setting('test.owner')::uuid;
  v_firm uuid := current_setting('test.firm')::uuid;
  v_out jsonb;
begin
  perform pg_temp.as_user(v_owner);
  v_out := public.push_changes(jsonb_build_array(
    jsonb_build_object(
      'mutation_id', 'smoke-mut-case-insert',
      'entity_type', 'case',
      'entity_id', 'smoke-case-1',
      'operation', 'insert',
      'payload', jsonb_build_object(
        'id', 'smoke-case-1',
        'user_id', v_owner,
        'firm_id', v_firm,
        'court_id', 'smoke-court-new',
        'case_type', 'Civil',
        'case_number', 'SMOKE-1',
        'petitioner', 'Petitioner',
        'respondent', 'Respondent',
        'on_behalf_id', current_setting('test.on_behalf'),
        'next_date', 1000,
        'created_at', 0,
        'updated_at', 0,
        'is_deleted', false
      )
    ),
    jsonb_build_object(
      'mutation_id', 'smoke-mut-court-insert',
      'entity_type', 'court',
      'entity_id', 'smoke-court-new',
      'operation', 'insert',
      'payload', jsonb_build_object(
        'id', 'smoke-court-new',
        'court_name', 'Smoke Court',
        'higher_lower_courts', 'Lower Court',
        'court_category_id', current_setting('test.category'),
        'order_index', 1,
        'is_custom', true,
        'is_user_modified', false,
        'user_id', v_owner,
        'firm_id', v_firm,
        'updated_at', 0
      )
    )
  ));

  -- Both accepted even though the case listed first, because the RPC applies
  -- dependency order: versions are server-assigned as 1.
  perform pg_temp.assert_true(
    v_out #>> '{results,0,status}' = 'accepted'
      and (v_out #>> '{results,0,version}')::int = 1,
    'the case insert was not accepted at version 1'
  );
  perform pg_temp.assert_true(
    v_out #>> '{results,1,status}' = 'accepted'
      and (v_out #>> '{results,1,version}')::int = 1,
    'the court insert was not accepted at version 1'
  );
  perform pg_temp.assert_true(
    (select server_updated_at from public.cases where id = 'smoke-case-1') is not null,
    'the server_updated_at trigger did not stamp the case'
  );
  perform pg_temp.assert_true(
    (select last_modified_by from public.cases where id = 'smoke-case-1')
      = v_owner::text,
    'last_modified_by was not server-assigned to the actor'
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- History: created in the same transaction only when next_date changed
-- ---------------------------------------------------------------------------

do $$
declare
  v_owner uuid := current_setting('test.owner')::uuid;
  v_out jsonb;
begin
  perform pg_temp.as_user(v_owner);

  -- An update that changes only case_number must NOT create history.
  v_out := public.push_changes(jsonb_build_array(jsonb_build_object(
    'mutation_id', 'smoke-mut-case-nodate',
    'entity_type', 'case',
    'entity_id', 'smoke-case-1',
    'operation', 'update',
    'base_version', 1,
    'payload', jsonb_build_object('id', 'smoke-case-1', 'case_number', 'SMOKE-1B', 'updated_at', 5)
  )));
  perform pg_temp.assert_true(
    v_out #>> '{results,0,status}' = 'accepted'
      and (v_out #>> '{results,0,version}')::int = 2,
    'the non-date update was not accepted at version 2'
  );
  perform pg_temp.assert_true(
    (select count(*) from public.case_history where case_id = 'smoke-case-1') = 0,
    'a case edit that did not change next_date created history'
  );

  -- The date-changing update carries the provisional preview's identity.
  v_out := public.push_changes(jsonb_build_array(jsonb_build_object(
    'mutation_id', 'smoke-mut-case-date',
    'entity_type', 'case',
    'entity_id', 'smoke-case-1',
    'operation', 'update',
    'base_version', 2,
    'payload', jsonb_build_object('id', 'smoke-case-1', 'next_date', 2000, 'updated_at', 6),
    'provisional_history', jsonb_build_object(
      'id', 'smoke-hist-1',
      'source_mutation_id', 'smoke-mut-history-1',
      'hearing_date', 1000,
      'next_date', 2000,
      'base_case_version', 2,
      'updated_at', 6
    )
  )));
  perform pg_temp.assert_true(
    v_out #>> '{results,0,status}' = 'accepted'
      and (v_out #>> '{results,0,version}')::int = 3,
    'the date-changing update was not accepted at version 3'
  );
  perform pg_temp.assert_true(
    (select count(*) from public.case_history
      where id = 'smoke-hist-1'
        and source_mutation_id = 'smoke-mut-history-1'
        and base_case_version = 2
        and result_case_version = 3
        and is_deleted = false) = 1,
    'the authoritative history event was not written as specified'
  );
  perform pg_temp.assert_true(
    v_out #>> '{results,0,history,id}' = 'smoke-hist-1'
      and (v_out #>> '{results,0,history,version}')::int = 1,
    'the authoritative history row was not returned to the caller'
  );

  -- Retrying the identical mutation returns the original result and applies
  -- nothing twice.
  v_out := public.push_changes(jsonb_build_array(jsonb_build_object(
    'mutation_id', 'smoke-mut-case-date',
    'entity_type', 'case',
    'entity_id', 'smoke-case-1',
    'operation', 'update',
    'base_version', 2,
    'payload', jsonb_build_object('id', 'smoke-case-1', 'next_date', 2000, 'updated_at', 6),
    'provisional_history', jsonb_build_object(
      'id', 'smoke-hist-1',
      'source_mutation_id', 'smoke-mut-history-1',
      'hearing_date', 1000,
      'next_date', 2000,
      'base_case_version', 2,
      'updated_at', 6
    )
  )));
  perform pg_temp.assert_true(
    v_out #>> '{results,0,status}' = 'accepted'
      and (v_out #>> '{results,0,version}')::int = 3,
    'a retry did not return the original accepted result'
  );
  perform pg_temp.assert_true(
    (select count(*) from public.case_history where case_id = 'smoke-case-1') = 1
      and (select version from public.cases where id = 'smoke-case-1') = 3,
    'a retry duplicated history or advanced the version'
  );

  -- The same mutation_id with a different payload applies nothing.
  v_out := public.push_changes(jsonb_build_array(jsonb_build_object(
    'mutation_id', 'smoke-mut-case-date',
    'entity_type', 'case',
    'entity_id', 'smoke-case-1',
    'operation', 'update',
    'base_version', 3,
    'payload', jsonb_build_object('id', 'smoke-case-1', 'next_date', 9999, 'updated_at', 7)
  )));
  perform pg_temp.assert_true(
    v_out #>> '{results,0,status}' = 'rejected'
      and v_out #>> '{results,0,error_code}' = 'mutation_id_reused',
    'a reused mutation id with a different payload was not refused'
  );
  perform pg_temp.assert_true(
    (select next_date from public.cases where id = 'smoke-case-1') = 2000,
    'a reused mutation id still changed the row'
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Conflict: an update against a stale base_version is refused with the row
-- ---------------------------------------------------------------------------

do $$
declare
  v_owner uuid := current_setting('test.owner')::uuid;
  v_out jsonb;
begin
  perform pg_temp.as_user(v_owner);
  v_out := public.push_changes(jsonb_build_array(jsonb_build_object(
    'mutation_id', 'smoke-mut-conflict',
    'entity_type', 'case',
    'entity_id', 'smoke-case-1',
    'operation', 'update',
    'base_version', 1,
    'payload', jsonb_build_object('id', 'smoke-case-1', 'case_remarks', 'stale', 'updated_at', 8)
  )));
  perform pg_temp.assert_true(
    v_out #>> '{results,0,status}' = 'conflict'
      and (v_out #>> '{results,0,version}')::int = 3
      and v_out #>> '{results,0,row,id}' = 'smoke-case-1',
    'a stale base_version did not return a conflict with the authoritative row'
  );
  perform pg_temp.assert_true(
    (select case_remarks from public.cases where id = 'smoke-case-1') is null,
    'a conflicting mutation still changed the row'
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Permission: an associate without can_edit may not write the firm's case
-- ---------------------------------------------------------------------------

do $$
declare
  v_assoc uuid := current_setting('test.assoc')::uuid;
  v_out jsonb;
begin
  -- The associate is entitled through the firm's mirrored expiry.
  perform pg_temp.assert_true(
    public.has_sync_entitlement(v_assoc),
    'a premium firm associate is not entitled'
  );

  perform pg_temp.as_user(v_assoc);
  v_out := public.push_changes(jsonb_build_array(jsonb_build_object(
    'mutation_id', 'smoke-mut-perm',
    'entity_type', 'case',
    'entity_id', 'smoke-case-1',
    'operation', 'update',
    'base_version', 3,
    'payload', jsonb_build_object('id', 'smoke-case-1', 'case_remarks', 'associate edit', 'updated_at', 9)
  )));
  perform pg_temp.assert_true(
    v_out #>> '{results,0,status}' = 'rejected'
      and v_out #>> '{results,0,error_code}' = 'permission_denied',
    'an associate without can_edit was not refused'
  );
  perform pg_temp.assert_true(
    (select case_remarks from public.cases where id = 'smoke-case-1') is null,
    'a refused mutation still changed the row'
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Delete: cascade soft-delete, then tombstone / already_resolved
-- ---------------------------------------------------------------------------

do $$
declare
  v_owner uuid := current_setting('test.owner')::uuid;
  v_out jsonb;
begin
  perform pg_temp.as_user(v_owner);

  v_out := public.push_changes(jsonb_build_array(jsonb_build_object(
    'mutation_id', 'smoke-mut-case-delete',
    'entity_type', 'case',
    'entity_id', 'smoke-case-1',
    'operation', 'delete',
    'base_version', 3,
    'payload', jsonb_build_object('id', 'smoke-case-1', 'is_deleted', true, 'updated_at', 10)
  )));
  perform pg_temp.assert_true(
    v_out #>> '{results,0,status}' = 'accepted'
      and (v_out #>> '{results,0,version}')::int = 4,
    'the case delete was not accepted at version 4'
  );
  perform pg_temp.assert_true(
    jsonb_array_length(v_out #> '{results,0,children}') = 1
      and v_out #>> '{results,0,children,0,id}' = 'smoke-hist-1',
    'the cascade did not return the soft-deleted child history row'
  );
  perform pg_temp.assert_true(
    (select is_deleted from public.case_history where id = 'smoke-hist-1') = true
      and (select version from public.case_history where id = 'smoke-hist-1') = 2,
    'the child history row was not soft-deleted with a new version'
  );

  -- A write against the tombstone returns it instead of applying.
  v_out := public.push_changes(jsonb_build_array(jsonb_build_object(
    'mutation_id', 'smoke-mut-tombstone',
    'entity_type', 'case',
    'entity_id', 'smoke-case-1',
    'operation', 'update',
    'base_version', 4,
    'payload', jsonb_build_object('id', 'smoke-case-1', 'case_remarks', 'after delete', 'updated_at', 11)
  )));
  perform pg_temp.assert_true(
    v_out #>> '{results,0,status}' = 'tombstone'
      and (v_out #>> '{results,0,version}')::int = 4,
    'an update against a tombstone did not return the tombstone'
  );

  -- A delete against the tombstone is already resolved.
  v_out := public.push_changes(jsonb_build_array(jsonb_build_object(
    'mutation_id', 'smoke-mut-already-resolved',
    'entity_type', 'case',
    'entity_id', 'smoke-case-1',
    'operation', 'delete',
    'base_version', 4,
    'payload', jsonb_build_object('id', 'smoke-case-1', 'is_deleted', true, 'updated_at', 12)
  )));
  perform pg_temp.assert_true(
    v_out #>> '{results,0,status}' = 'already_resolved',
    'a delete against a tombstone did not report already_resolved'
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Receipts: one per terminal result, and the batch returned in input order
-- ---------------------------------------------------------------------------

do $$
declare
  v_owner uuid := current_setting('test.owner')::uuid;
  v_out jsonb;
  v_receipts integer;
begin
  perform pg_temp.as_user(v_owner);
  v_out := public.push_changes(jsonb_build_array(
    jsonb_build_object(
      'mutation_id', 'smoke-mut-order-a',
      'entity_type', 'note',
      'entity_id', 'smoke-note-a',
      'operation', 'insert',
      'payload', jsonb_build_object(
        'id', 'smoke-note-a', 'user_id', v_owner,
        'title', 'Note A', 'body', 'Body', 'created_at', 0, 'updated_at', 0
      )
    ),
    jsonb_build_object(
      'mutation_id', 'smoke-mut-order-b',
      'entity_type', 'reference',
      'entity_id', 'smoke-ref-a',
      'operation', 'insert',
      'payload', jsonb_build_object(
        'id', 'smoke-ref-a', 'user_id', v_owner,
        'reference_and_page_no', '1', 'created_at', 0, 'updated_at', 0
      )
    )
  ));

  perform pg_temp.assert_true(
    jsonb_array_length(v_out -> 'results') = 2
      and v_out #>> '{results,0,mutation_id}' = 'smoke-mut-order-a'
      and v_out #>> '{results,1,mutation_id}' = 'smoke-mut-order-b',
    'the response is not exactly one result per mutation in input order'
  );

  select count(*) into v_receipts
    from public.mutation_receipts
   where mutation_id in (
     'smoke-mut-order-a', 'smoke-mut-order-b', 'smoke-mut-case-insert',
     'smoke-mut-court-insert', 'smoke-mut-case-nodate', 'smoke-mut-case-date',
     'smoke-mut-conflict', 'smoke-mut-perm', 'smoke-mut-case-delete',
     'smoke-mut-tombstone', 'smoke-mut-already-resolved'
   );
  perform pg_temp.assert_true(
    v_receipts = 11,
    'a terminal mutation did not persist exactly one receipt (got '
      || v_receipts || ')'
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- The conflict mirror: a conflict_log row pushes like any other entity, and the
-- detecting client's verdict travels with it (Task 19 Phase 3)
-- ---------------------------------------------------------------------------

do $$
declare
  v_owner uuid := current_setting('test.owner')::uuid;
  v_id text := 'smoke-conflict-1';
  v_out jsonb;
  v_version integer;
begin
  perform pg_temp.as_user(v_owner);
  v_out := public.push_changes(jsonb_build_array(jsonb_build_object(
    'mutation_id', 'smoke-mut-conflict-log',
    'entity_type', 'conflict_log',
    'entity_id', v_id,
    'operation', 'insert',
    'payload', jsonb_build_object(
      'id', v_id,
      'user_id', v_owner,
      'mutation_id', 'smoke-mut-rejected',
      'entity_type', 'note',
      'entity_id', 'smoke-note-a',
      'base_version', 1,
      'base_payload', '{}',
      'submitted_payload', '{}',
      'changed_fields', '["title"]',
      'server_version', 2,
      'server_payload', '{}',
      'resolution_state', 'unresolved',
      'mergeable_conflict', true,
      'conflict_at', 0,
      'is_dismissed', false,
      'is_deleted', false,
      'updated_at', 0,
      'last_modified_by', v_owner
    )
  )));

  perform pg_temp.assert_true(
    v_out #>> '{results,0,status}' = 'accepted',
    'a conflict_log mirror insert was not accepted'
  );
  v_version := (v_out #>> '{results,0,version}')::integer;

  perform pg_temp.assert_true(
    (select mergeable_conflict from public.conflict_log where id = v_id) is true
      and (select resolution_state from public.conflict_log where id = v_id)
          = 'unresolved',
    'the mergeable_conflict verdict did not reach the mirrored row'
  );

  -- The answer travels the same way: one update on the same id, so a second
  -- device reads the conflict as answered instead of recomputing a verdict.
  v_out := public.push_changes(jsonb_build_array(jsonb_build_object(
    'mutation_id', 'smoke-mut-conflict-log-resolve',
    'entity_type', 'conflict_log',
    'entity_id', v_id,
    'operation', 'update',
    'base_version', v_version,
    'payload', jsonb_build_object(
      'id', v_id,
      'user_id', v_owner,
      'mutation_id', 'smoke-mut-rejected',
      'entity_type', 'note',
      'entity_id', 'smoke-note-a',
      'base_version', 1,
      'base_payload', '{}',
      'submitted_payload', '{}',
      'changed_fields', '["title"]',
      'server_version', 2,
      'server_payload', '{}',
      'resolution_state', 'user_resolved',
      'resolved_at', 1,
      'mergeable_conflict', true,
      'conflict_at', 0,
      'is_dismissed', false,
      'is_deleted', false,
      'updated_at', 1,
      'last_modified_by', v_owner
    )
  )));

  perform pg_temp.assert_true(
    v_out #>> '{results,0,status}' = 'accepted'
      and (select resolution_state from public.conflict_log where id = v_id)
          = 'user_resolved',
    'the conflict resolution did not reach the mirrored row'
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- Delete review: approval locks the target and decides against its current
-- version — a changed target becomes target_conflict/stale_review_required, an
-- already-deleted one already_resolved, and only an unchanged one is tombstoned
-- atomically with its case-history cascade (Task 20 Phase 4)
-- ---------------------------------------------------------------------------

do $$
declare
  v_owner uuid := current_setting('test.owner')::uuid;
  v_assoc uuid := current_setting('test.assoc')::uuid;
  v_firm uuid := current_setting('test.firm')::uuid;
  v_out jsonb;
  v_approved jsonb;
begin
  -- A live case with one history child: the target the cascade must reach.
  perform pg_temp.as_user(v_owner);
  v_out := public.push_changes(jsonb_build_array(
    jsonb_build_object(
      'mutation_id', 'smoke-mut-review-case-insert',
      'entity_type', 'case',
      'entity_id', 'smoke-review-case',
      'operation', 'insert',
      'payload', jsonb_build_object(
        'id', 'smoke-review-case',
        'user_id', v_owner,
        'firm_id', v_firm,
        'court_id', 'smoke-court-new',
        'case_type', 'Civil',
        'case_number', 'SMOKE-REV',
        'petitioner', 'Petitioner',
        'respondent', 'Respondent',
        'on_behalf_id', current_setting('test.on_behalf'),
        'created_at', 0,
        'updated_at', 0,
        'is_deleted', false
      )
    ),
    jsonb_build_object(
      'mutation_id', 'smoke-mut-review-hist-insert',
      'entity_type', 'case_history',
      'entity_id', 'smoke-review-hist',
      'operation', 'insert',
      'payload', jsonb_build_object(
        'id', 'smoke-review-hist',
        'case_id', 'smoke-review-case',
        'user_id', v_owner,
        'firm_id', v_firm,
        'hearing_date', 0,
        'created_by', v_owner,
        'source_mutation_id', 'smoke-mut-review-hist-src',
        'base_case_version', 1,
        'result_case_version', 1,
        'updated_at', 0,
        'is_deleted', false
      )
    )
  ));
  perform pg_temp.assert_true(
    v_out #>> '{results,0,status}' = 'accepted'
      and v_out #>> '{results,1,status}' = 'accepted',
    'the review fixtures (case + history child) were not created'
  );

  -- The associate, who has no delete permission, raises three requests: one for
  -- a note that will change, one for the case that will not, and one for a case
  -- that is already a tombstone.
  perform pg_temp.as_user(v_assoc);
  v_out := public.push_changes(jsonb_build_array(
    jsonb_build_object(
      'mutation_id', 'smoke-mut-req-insert-note',
      'entity_type', 'delete_request',
      'entity_id', 'smoke-req-note',
      'operation', 'insert',
      'payload', jsonb_build_object(
        'id', 'smoke-req-note',
        'firm_id', v_firm,
        'entity_type', 'note',
        'entity_id', 'smoke-note-a',
        'entity_snapshot', '{}',
        'target_base_version', 1,
        'requested_by', v_assoc,
        'status', 'pending',
        'created_at', 0,
        'updated_at', 0,
        'is_deleted', false,
        'last_modified_by', v_assoc
      )
    ),
    jsonb_build_object(
      'mutation_id', 'smoke-mut-req-insert-case',
      'entity_type', 'delete_request',
      'entity_id', 'smoke-req-case',
      'operation', 'insert',
      'payload', jsonb_build_object(
        'id', 'smoke-req-case',
        'firm_id', v_firm,
        'entity_type', 'case',
        'entity_id', 'smoke-review-case',
        'entity_snapshot', '{}',
        'target_base_version', 1,
        'requested_by', v_assoc,
        'status', 'pending',
        'created_at', 0,
        'updated_at', 0,
        'is_deleted', false,
        'last_modified_by', v_assoc
      )
    ),
    jsonb_build_object(
      'mutation_id', 'smoke-mut-req-insert-gone',
      'entity_type', 'delete_request',
      'entity_id', 'smoke-req-gone',
      'operation', 'insert',
      'payload', jsonb_build_object(
        'id', 'smoke-req-gone',
        'firm_id', v_firm,
        'entity_type', 'case',
        'entity_id', 'smoke-case-1',
        'entity_snapshot', '{}',
        'target_base_version', 4,
        'requested_by', v_assoc,
        'status', 'pending',
        'created_at', 0,
        'updated_at', 0,
        'is_deleted', false,
        'last_modified_by', v_assoc
      )
    )
  ));
  perform pg_temp.assert_true(
    v_out #>> '{results,0,status}' = 'accepted'
      and v_out #>> '{results,1,status}' = 'accepted'
      and v_out #>> '{results,2,status}' = 'accepted',
    'the associate could not raise the three delete requests'
  );

  -- The requester may not approve their own request: only can_delete may.
  v_out := public.push_changes(jsonb_build_array(jsonb_build_object(
    'mutation_id', 'smoke-mut-req-self-approve',
    'entity_type', 'delete_request',
    'entity_id', 'smoke-req-note',
    'operation', 'update',
    'base_version', 1,
    'payload', jsonb_build_object(
      'id', 'smoke-req-note', 'status', 'approved', 'updated_at', 1
    )
  )));
  perform pg_temp.assert_true(
    v_out #>> '{results,0,status}' = 'rejected'
      and v_out #>> '{results,0,error_code}' = 'permission_denied',
    'the requester approved their own request'
  );
  perform pg_temp.assert_true(
    (select status from public.delete_requests where id = 'smoke-req-note') = 'pending'
      and (select is_deleted from public.notes where id = 'smoke-note-a') = false,
    'a refused self-approval changed the request or the target'
  );

  -- The record moves under the request: the note is edited to version 2.
  perform pg_temp.as_user(v_owner);
  v_out := public.push_changes(jsonb_build_array(jsonb_build_object(
    'mutation_id', 'smoke-mut-note-edit',
    'entity_type', 'note',
    'entity_id', 'smoke-note-a',
    'operation', 'update',
    'base_version', 1,
    'payload', jsonb_build_object(
      'id', 'smoke-note-a', 'firm_id', v_firm,
      'title', 'Note A v2', 'updated_at', 2
    )
  )));
  perform pg_temp.assert_true(
    v_out #>> '{results,0,status}' = 'accepted'
      and (v_out #>> '{results,0,version}')::int = 2,
    'the note edit to version 2 did not apply'
  );

  -- Approving against the stale target is refused, and the request is parked as
  -- stale_review_required with the version the reviewer just saw.
  v_out := public.push_changes(jsonb_build_array(jsonb_build_object(
    'mutation_id', 'smoke-mut-req-approve-stale',
    'entity_type', 'delete_request',
    'entity_id', 'smoke-req-note',
    'operation', 'update',
    'base_version', 1,
    'payload', jsonb_build_object(
      'id', 'smoke-req-note', 'status', 'approved', 'updated_at', 3
    )
  )));
  perform pg_temp.assert_true(
    v_out #>> '{results,0,status}' = 'target_conflict'
      and (v_out #>> '{results,0,target_version}')::int = 2
      and v_out #>> '{results,0,target,id}' = 'smoke-note-a',
    'a changed target was not reported as target_conflict with its current row'
  );
  perform pg_temp.assert_true(
    v_out #>> '{results,0,row,status}' = 'stale_review_required'
      and (v_out #>> '{results,0,row,target_base_version}')::int = 2
      and (v_out #>> '{results,0,row,version}')::int = 2,
    'the stale request was not parked with the version the reviewer saw'
  );
  perform pg_temp.assert_true(
    (select status from public.delete_requests where id = 'smoke-req-note')
        = 'stale_review_required'
      and (select target_base_version from public.delete_requests
            where id = 'smoke-req-note') = 2,
    'the parked request was not persisted'
  );
  perform pg_temp.assert_true(
    (select is_deleted from public.notes where id = 'smoke-note-a') = false,
    'a target_conflict tombstoned the record anyway'
  );

  -- ReconFIRMED at the version that exists now: one atomic tombstone.
  v_approved := public.push_changes(jsonb_build_array(jsonb_build_object(
    'mutation_id', 'smoke-mut-req-approve',
    'entity_type', 'delete_request',
    'entity_id', 'smoke-req-note',
    'operation', 'update',
    'base_version', 2,
    'payload', jsonb_build_object(
      'id', 'smoke-req-note', 'status', 'approved',
      'review_note', 'Approved after reconfirmation.', 'updated_at', 4
    )
  )));
  perform pg_temp.assert_true(
    v_approved #>> '{results,0,status}' = 'accepted',
    'the reconfirmed approval was not accepted'
  );
  perform pg_temp.assert_true(
    (select is_deleted from public.notes where id = 'smoke-note-a') = true
      and (select version from public.notes where id = 'smoke-note-a') = 3,
    'the approved request did not tombstone the note at version 3'
  );
  perform pg_temp.assert_true(
    v_approved #>> '{results,0,target,is_deleted}' = 'true'
      and v_approved #>> '{results,0,target_entity_type}' = 'note',
    'the accepted approval did not return the tombstoned target'
  );
  perform pg_temp.assert_true(
    (select status from public.delete_requests where id = 'smoke-req-note') = 'approved'
      and (select reviewed_by from public.delete_requests where id = 'smoke-req-note')
          = v_owner
      and (select review_note from public.delete_requests where id = 'smoke-req-note')
          = 'Approved after reconfirmation.',
    'the approval did not resolve the request with reviewer and note'
  );

  -- A duplicate submission of the same mutation returns the stored receipt and
  -- tombstones nothing a second time.
  v_out := public.push_changes(jsonb_build_array(jsonb_build_object(
    'mutation_id', 'smoke-mut-req-approve',
    'entity_type', 'delete_request',
    'entity_id', 'smoke-req-note',
    'operation', 'update',
    'base_version', 2,
    'payload', jsonb_build_object(
      'id', 'smoke-req-note', 'status', 'approved',
      'review_note', 'Approved after reconfirmation.', 'updated_at', 4
    )
  )));
  perform pg_temp.assert_true(
    v_out = v_approved,
    'duplicate approval did not return the same terminal receipt'
  );
  perform pg_temp.assert_true(
    (select version from public.notes where id = 'smoke-note-a') = 3,
    'duplicate approval extended the tombstone twice'
  );

  -- Approving the case request tombstones the case and cascades to its children.
  v_out := public.push_changes(jsonb_build_array(jsonb_build_object(
    'mutation_id', 'smoke-mut-req-approve-case',
    'entity_type', 'delete_request',
    'entity_id', 'smoke-req-case',
    'operation', 'update',
    'base_version', 1,
    'payload', jsonb_build_object(
      'id', 'smoke-req-case', 'status', 'approved', 'updated_at', 5
    )
  )));
  perform pg_temp.assert_true(
    v_out #>> '{results,0,status}' = 'accepted'
      and (select is_deleted from public.cases where id = 'smoke-review-case') = true,
    'approving the case request did not tombstone the case'
  );
  perform pg_temp.assert_true(
    jsonb_array_length(v_out #> '{results,0,children}') = 1
      and v_out #>> '{results,0,children,0,id}' = 'smoke-review-hist'
      and (select is_deleted from public.case_history
            where id = 'smoke-review-hist') = true,
    'the approved case delete did not cascade to its history child'
  );

  -- A target that is already a tombstone: already_resolved, request untouched.
  v_out := public.push_changes(jsonb_build_array(jsonb_build_object(
    'mutation_id', 'smoke-mut-req-approve-gone',
    'entity_type', 'delete_request',
    'entity_id', 'smoke-req-gone',
    'operation', 'update',
    'base_version', 1,
    'payload', jsonb_build_object(
      'id', 'smoke-req-gone', 'status', 'approved', 'updated_at', 6
    )
  )));
  perform pg_temp.assert_true(
    v_out #>> '{results,0,status}' = 'already_resolved'
      and v_out #>> '{results,0,target,is_deleted}' = 'true',
    'an already-deleted target did not report already_resolved with its tombstone'
  );
  perform pg_temp.assert_true(
    (select status from public.delete_requests where id = 'smoke-req-gone') = 'pending'
      and (select reviewed_by from public.delete_requests where id = 'smoke-req-gone') is null
      and (select version from public.delete_requests where id = 'smoke-req-gone') = 1,
    'already_resolved recorded a decision that never happened'
  );

  -- Reject needs no special branch: it is an ordinary update that keeps the
  -- record and leaves the target alone.
  v_out := public.push_changes(jsonb_build_array(jsonb_build_object(
    'mutation_id', 'smoke-mut-req-reject',
    'entity_type', 'delete_request',
    'entity_id', 'smoke-req-gone',
    'operation', 'update',
    'base_version', 1,
    'payload', jsonb_build_object(
      'id', 'smoke-req-gone', 'status', 'rejected',
      'review_note', 'The record is gone.', 'updated_at', 7
    )
  )));
  perform pg_temp.assert_true(
    v_out #>> '{results,0,status}' = 'accepted'
      and (select status from public.delete_requests where id = 'smoke-req-gone')
          = 'rejected',
    'a rejection did not resolve the request'
  );
  perform pg_temp.assert_true(
    (select is_deleted from public.cases where id = 'smoke-case-1') = true,
    'a rejection deleted the record'
  );
end;
$$;

-- Nothing above is kept: no account, firm, case, history or receipt survives.
rollback;

\echo 'SMOKE OK: push_changes behaves as specified.'
