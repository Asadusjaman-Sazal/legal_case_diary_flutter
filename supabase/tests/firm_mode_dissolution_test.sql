-- Firm mode dissolution test — proves `20261017110000_firm_mode_dissolution.sql`.
--
-- Self-contained: three throwaway accounts are created inside one transaction
-- that is rolled back, so no fixture survives. The RPCs are called as the role
-- they are granted to (`authenticated`) with `request.jwt.claims` set, which is
-- what `auth.uid()` reads — so the function's own guards, its lock and its
-- policy-visible reads all run for real rather than being simulated.
--
--   psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/firm_mode_dissolution_test.sql
--
-- What it pins, in the order the function does it:
--
--   * **a chamber with members is refused, with the count**, and the refusal
--     writes nothing — not the rows, not the invites, not the profile;
--   * **a member is not the owner** and gets `not_owner`, changing nothing;
--   * once the roster is emptied through the one removal path there is, the
--     dissolve **succeeds**: the owner reads every row his members wrote and
--     those accounts read none, the rows lose their `firm_id` and gain him as
--     their scope owner, and attribution, contents, versions and timestamps are
--     exactly as they were;
--   * **`conflict_log` is the exception**: its `firm_id` is cleared because the
--     foreign key would otherwise refuse the `firms` delete, but no scope owner
--     is written, so its author keeps reading it and the owner never inherits
--     it;
--   * **the chamber is gone**: the `firms` row, the membership rows and the
--     invites — so a code issued before the dissolve no longer joins;
--   * **the account is individual again and its plan is untouched**, and
--     `delete_my_account()` no longer refuses it.

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
    raise exception 'DISSOLVE FAIL: %', p_message;
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

-- Puts the session back the way it was found: the role **and** the claims
-- setting, because `reset role` alone leaves `request.jwt.claims` behind and a
-- fixture staged after an impersonation would then be judged as that member.
create or replace function pg_temp.as_owner()
returns void
language plpgsql
as $$
begin
  perform set_config('request.jwt.claims', '', true);
  execute 'reset role';
end;
$$;

-- Row count p_user can actually see for the given SELECT, under RLS.
create or replace function pg_temp.count_as(p_user uuid, p_sql text)
returns bigint
language plpgsql
as $$
declare
  v_count bigint;
begin
  perform pg_temp.as_user('authenticated', p_user);
  execute 'select count(*) from (' || p_sql || ') t' into v_count;
  perform pg_temp.as_owner();
  return v_count;
end;
$$;

-- Calls the RPCs as p_user, returning their own jsonb answer.
create or replace function pg_temp.dissolve(p_user uuid)
returns jsonb
language plpgsql
as $$
declare
  v_out jsonb;
begin
  perform pg_temp.as_user('authenticated', p_user);
  v_out := public.dissolve_firm();
  perform pg_temp.as_owner();
  return v_out;
end;
$$;

create or replace function pg_temp.remove_member(p_owner uuid, p_user uuid)
returns jsonb
language plpgsql
as $$
declare
  v_out jsonb;
begin
  perform pg_temp.as_user('authenticated', p_owner);
  v_out := public.remove_firm_member(p_user);
  perform pg_temp.as_owner();
  return v_out;
end;
$$;

create or replace function pg_temp.delete_account(p_user uuid)
returns jsonb
language plpgsql
as $$
declare
  v_out jsonb;
begin
  perform pg_temp.as_user('authenticated', p_user);
  v_out := public.delete_my_account();
  perform pg_temp.as_owner();
  return v_out;
end;
$$;

-- ---------------------------------------------------------------------------
-- Fixtures
-- ---------------------------------------------------------------------------

create temporary table dissolve_fixtures (
  name text primary key,
  id text not null
) on commit drop;

do $$
declare
  c_owner uuid := gen_random_uuid();
  c_assoc uuid := gen_random_uuid();
  c_viewer uuid := gen_random_uuid();
  c_stranger uuid := gen_random_uuid();
  v_firm uuid := gen_random_uuid();
  v_now_ms bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint;
  v_plan_expiry timestamptz := now() + interval '30 days';
  v_court text;
  v_on_behalf text;
  v_category text;
  v_result jsonb;
  v_case public.cases%rowtype;
  v_note public.notes%rowtype;
  v_conflict public.conflict_log%rowtype;
begin
  -- The built-in baseline every install reads, used to make valid rows.
  select id into v_court from public.courts where is_custom = false limit 1;
  select id into v_on_behalf from public.on_behalfs where is_custom = false limit 1;
  select id into v_category
    from public.court_categories where is_custom = false limit 1;

  insert into pg_temp.dissolve_fixtures values
    ('owner', c_owner::text), ('assoc', c_assoc::text),
    ('viewer', c_viewer::text), ('stranger', c_stranger::text),
    ('firm', v_firm::text), ('court', v_court),
    ('on_behalf', v_on_behalf), ('category', v_category);

  -- Accounts. The sign-up trigger writes each profile row.
  insert into auth.users (id, email, email_confirmed_at, created_at, updated_at,
                          is_sso_user, is_anonymous)
  values
    (c_owner, 'dis-owner@test.local', now(), now(), now(), false, false),
    (c_assoc, 'dis-assoc@test.local', now(), now(), now(), false, false),
    (c_viewer, 'dis-viewer@test.local', now(), now(), now(), false, false),
    (c_stranger, 'dis-stranger@test.local', now(), now(), now(), false, false);

  -- A paying owner: the plan is what must survive the dissolve, so it is set
  -- here and asserted again afterwards.
  update public.profiles
     set full_name = 'Owner Name',
         subscription_expiry = v_plan_expiry,
         subscription_status = 'active',
         tier = 'firm'
   where id = c_owner;

  insert into public.firms (id, name, owner_id, subscription_status,
                            subscription_expiry, tier)
  values (v_firm, 'Dissolve Chamber', c_owner, 'active', v_plan_expiry, 'firm');

  insert into public.firm_members
    (firm_id, user_id, role, can_add, can_edit, can_delete)
  values
    (v_firm, c_owner, 'owner', true, true, true),
    (v_firm, c_assoc, 'associate', true, true, false),
    (v_firm, c_viewer, 'viewer', false, false, false);

  update public.profiles set firm_id = v_firm, role = 'owner' where id = c_owner;
  update public.profiles set firm_id = v_firm, role = 'associate' where id = c_assoc;
  update public.profiles set firm_id = v_firm, role = 'viewer' where id = c_viewer;

  -- Two open codes: one observed untouched by the refusal, one observed gone
  -- after the dissolve.
  insert into public.firm_invites (firm_id, code_hash, created_by, created_at)
  values
    (v_firm, public.sha256_hex(upper('DISSOLVE01')), c_owner, v_now_ms),
    (v_firm, public.sha256_hex(upper('DISSOLVE02')), c_owner, v_now_ms);

  -- The ledger, authored by three different accounts so "the owner keeps it,
  -- the authors do not" is a fact about rows rather than about one fixture.
  insert into public.courts (
    id, court_name, higher_lower_courts, court_category_id, order_index,
    is_custom, user_id, firm_id, updated_at, last_modified_by
  )
  values (
    'dis-court', 'Dissolve Test Court', 'lower', v_category, 0,
    true, c_owner, v_firm, v_now_ms, c_owner::text
  );

  insert into public.cases (
    id, user_id, firm_id, is_deleted, case_number, petitioner, respondent,
    case_type, court_id, on_behalf_id, created_at, updated_at,
    last_modified_by
  )
  values
    ('dis-case-assoc', c_assoc, v_firm, false, 'DISS-A', 'Petitioner A',
     'Respondent A', 'civil', v_court, v_on_behalf, v_now_ms, v_now_ms,
     c_assoc::text),
    ('dis-case-owner', c_owner, v_firm, false, 'DISS-O', 'Petitioner O',
     'Respondent O', 'civil', v_court, v_on_behalf, v_now_ms, v_now_ms,
     c_owner::text);

  insert into public.case_history (
    id, case_id, user_id, firm_id, hearing_date, created_by,
    source_mutation_id, base_case_version, result_case_version, updated_at,
    last_modified_by
  )
  values (
    'dis-hist-assoc', 'dis-case-assoc', c_assoc, v_firm, v_now_ms, c_assoc,
    'dis-mutation-1', 1, 2, v_now_ms, c_assoc::text
  );

  insert into public.notes (
    id, user_id, firm_id, title, body, created_at, updated_at, is_deleted,
    last_modified_by
  )
  values
    ('dis-note-assoc', c_assoc, v_firm, 'Associate Note', 'body',
     v_now_ms, v_now_ms, false, c_assoc::text),
    -- A tombstone is part of the ledger and still carries the firm: it must be
    -- unscoped too, or the `firms` delete would refuse it.
    ('dis-note-tomb', c_viewer, v_firm, 'Deleted Note', 'body',
     v_now_ms, v_now_ms, true, c_viewer::text);

  insert into public.case_references (
    id, user_id, firm_id, reference_and_page_no, statute,
    created_at, updated_at, last_modified_by
  )
  values (
    'dis-ref-viewer', c_viewer, v_firm, '29 DLR (AD), P-69-73', 'CRPC',
    v_now_ms, v_now_ms, c_viewer::text
  );

  insert into public.delete_requests (
    id, firm_id, entity_type, entity_id, entity_snapshot, target_base_version,
    requested_by, status, created_at, updated_at
  )
  values (
    'dis-req', v_firm, 'cases', 'dis-case-assoc', '{}', 1,
    c_assoc, 'pending', v_now_ms, v_now_ms
  );

  insert into public.conflict_log (
    id, user_id, firm_id, mutation_id, entity_type, entity_id, base_version,
    base_payload, submitted_payload, changed_fields, server_version,
    server_payload, resolution_state, conflict_at, updated_at
  )
  values (
    'dis-conflict', c_assoc, v_firm, 'dis-mutation-1', 'cases',
    'dis-case-assoc', 1, '{}', '{}', '[]', 2, '{}', 'unresolved', v_now_ms,
    v_now_ms
  );

  -- -------------------------------------------------------------------------
  -- 1. A chamber with members is refused, with the count, writing nothing
  -- -------------------------------------------------------------------------

  v_result := pg_temp.dissolve(c_owner);
  perform pg_temp.assert_true(
    v_result ->> 'status' = 'members_remaining',
    'a chamber with members was not refused: ' || coalesce(v_result::text, 'null')
  );
  perform pg_temp.assert_true(
    (v_result ->> 'members')::int = 2,
    'the refusal did not carry the member count: ' || coalesce(v_result::text, 'null')
  );
  perform pg_temp.assert_true(
    exists (select 1 from public.firms where id = v_firm),
    'the refused dissolve removed the chamber'
  );
  perform pg_temp.assert_true(
    (select count(*) from public.firm_members where firm_id = v_firm) = 3,
    'the refused dissolve changed the roster'
  );
  perform pg_temp.assert_true(
    (select p.firm_id from public.profiles p where p.id = c_owner) = v_firm,
    'the refused dissolve relinked the owner'
  );
  perform pg_temp.assert_true(
    (select count(*) from public.firm_invites
      where firm_id = v_firm and revoked = false) = 2,
    'the refused dissolve retired the open invites'
  );
  perform pg_temp.assert_true(
    (select count(*) from public.cases
      where id = 'dis-case-assoc' and firm_id = v_firm
        and scope_owner_id is null) = 1,
    'the refused dissolve unscoped a row'
  );

  -- -------------------------------------------------------------------------
  -- 2. A member is not the owner and changes nothing
  -- -------------------------------------------------------------------------

  v_result := pg_temp.dissolve(c_assoc);
  perform pg_temp.assert_true(
    v_result ->> 'status' = 'not_owner',
    'a member was not refused with not_owner: ' || coalesce(v_result::text, 'null')
  );
  perform pg_temp.assert_true(
    exists (select 1 from public.firms where id = v_firm),
    'a member''s dissolve removed the chamber'
  );
  perform pg_temp.assert_true(
    (select count(*) from public.firm_members where firm_id = v_firm) = 3,
    'a member''s dissolve changed the roster'
  );

  -- -------------------------------------------------------------------------
  -- 3. The roster is emptied through the one removal path there is (§4.1)
  -- -------------------------------------------------------------------------

  v_result := pg_temp.remove_member(c_owner, c_assoc);
  perform pg_temp.assert_true(
    v_result ->> 'status' = 'removed',
    'the associate could not be removed: ' || coalesce(v_result::text, 'null')
  );
  v_result := pg_temp.remove_member(c_owner, c_viewer);
  perform pg_temp.assert_true(
    v_result ->> 'status' = 'removed',
    'the viewer could not be removed: ' || coalesce(v_result::text, 'null')
  );
  perform pg_temp.assert_true(
    (select count(*) from public.firm_members where firm_id = v_firm) = 1,
    'an emptied roster still holds someone else'
  );

  -- -------------------------------------------------------------------------
  -- 4. The dissolve
  -- -------------------------------------------------------------------------

  v_result := pg_temp.dissolve(c_owner);
  perform pg_temp.assert_true(
    v_result ->> 'status' = 'dissolved',
    'an emptied chamber could not be dissolved: ' || coalesce(v_result::text, 'null')
  );
  perform pg_temp.assert_true(
    (v_result ->> 'firm_id')::uuid = v_firm,
    'the dissolve named the wrong chamber: ' || coalesce(v_result::text, 'null')
  );

  -- The chamber is gone, with its memberships and its invites.
  perform pg_temp.assert_true(
    not exists (select 1 from public.firms where id = v_firm),
    'the dissolve left the firms row behind'
  );
  perform pg_temp.assert_true(
    not exists (select 1 from public.firm_members where firm_id = v_firm),
    'the dissolve left a membership row behind'
  );
  perform pg_temp.assert_true(
    not exists (select 1 from public.firm_invites where firm_id = v_firm),
    'the dissolve left an invite row behind'
  );

  -- The account: individual again, plan untouched.
  perform pg_temp.assert_true(
    (select p.firm_id from public.profiles p where p.id = c_owner) is null
      and (select p.role from public.profiles p where p.id = c_owner) = 'individual',
    'the dissolve did not relink the owner to individual mode'
  );
  perform pg_temp.assert_true(
    (select p.full_name from public.profiles p where p.id = c_owner) = 'Owner Name'
      and (select p.subscription_expiry from public.profiles p where p.id = c_owner)
            = v_plan_expiry
      and (select p.tier from public.profiles p where p.id = c_owner) = 'firm',
    'the dissolve rewrote the owner''s name or plan'
  );

  -- The transfer, row by row: no firm, the owner as scope owner, and every
  -- column that says who wrote it exactly as it was.
  perform pg_temp.assert_true(
    (select count(*) from public.cases
      where firm_id is null and scope_owner_id = c_owner) = 2,
    'the dissolve did not unscoped both cases to the owner'
  );
  select * into v_case from public.cases where id = 'dis-case-assoc';
  perform pg_temp.assert_true(
    v_case.user_id = c_assoc
      and v_case.last_modified_by = c_assoc::text
      and v_case.case_number = 'DISS-A'
      and v_case.petitioner = 'Petitioner A'
      and v_case.created_at = v_now_ms
      and v_case.updated_at = v_now_ms
      and v_case.version = 1
      and v_case.is_deleted = false,
    'the dissolve rewrote a case row''s attribution or contents'
  );

  -- The tombstone is part of the ledger: it is unscoped like the rest.
  select * into v_note from public.notes where id = 'dis-note-tomb';
  perform pg_temp.assert_true(
    v_note.firm_id is null
      and v_note.scope_owner_id = c_owner
      and v_note.is_deleted
      and v_note.user_id = c_viewer,
    'the dissolve skipped or rewrote a tombstone'
  );

  perform pg_temp.assert_true(
    (select count(*) from public.case_history
      where firm_id is null and scope_owner_id = c_owner
        and user_id = c_assoc and created_by = c_assoc) = 1,
    'the dissolve did not hand the case history over with its attribution'
  );
  perform pg_temp.assert_true(
    (select count(*) from public.case_references
      where firm_id is null and scope_owner_id = c_owner
        and user_id = c_viewer) = 1,
    'the dissolve did not hand the case reference over'
  );
  perform pg_temp.assert_true(
    (select count(*) from public.delete_requests
      where firm_id is null and scope_owner_id = c_owner
        and requested_by = c_assoc) = 1,
    'the dissolve did not hand the delete request over'
  );
  perform pg_temp.assert_true(
    (select count(*) from public.courts
      where id = 'dis-court' and firm_id is null and scope_owner_id = c_owner) = 1,
    'the dissolve did not hand the custom court over'
  );

  -- The exception: the column is cleared (the foreign key would refuse the
  -- delete otherwise). `conflict_log` carries no scope column at all — it is
  -- not one of the eleven ledger tables — so "no scope owner" is the schema,
  -- and section 5 is what proves the behaviour it buys: the author keeps the
  -- row and the owner still cannot read it.
  select * into v_conflict from public.conflict_log where id = 'dis-conflict';
  perform pg_temp.assert_true(
    v_conflict.firm_id is null and v_conflict.user_id = c_assoc,
    'the dissolve left the merge diagnostics pointing at a chamber that is gone'
  );

  -- -------------------------------------------------------------------------
  -- 5. What each account can actually read (§4.4's acceptance)
  -- -------------------------------------------------------------------------

  perform pg_temp.assert_true(
    pg_temp.count_as(c_owner, 'select 1 from public.cases') = 2,
    'the owner cannot read every row his members wrote'
  );
  perform pg_temp.assert_true(
    pg_temp.count_as(c_assoc, 'select 1 from public.cases') = 0,
    'a former member still reads his chamber-authored case'
  );
  perform pg_temp.assert_true(
    pg_temp.count_as(c_owner, 'select 1 from public.notes') = 2,
    'the owner cannot read the notes his members wrote'
  );
  perform pg_temp.assert_true(
    pg_temp.count_as(c_viewer, 'select 1 from public.notes') = 0,
    'a former member still reads his chamber-authored note'
  );
  perform pg_temp.assert_true(
    pg_temp.count_as(c_owner, 'select 1 from public.case_references') = 1
      and pg_temp.count_as(c_viewer, 'select 1 from public.case_references') = 0,
    'the case reference did not move from its author to the owner'
  );
  perform pg_temp.assert_true(
    pg_temp.count_as(c_owner, 'select 1 from public.case_history') = 1
      and pg_temp.count_as(c_assoc, 'select 1 from public.case_history') = 0,
    'the case history did not move from its author to the owner'
  );
  perform pg_temp.assert_true(
    pg_temp.count_as(c_owner, 'select 1 from public.courts
      where id = ''dis-court''') = 1
      and pg_temp.count_as(c_viewer, 'select 1 from public.courts
      where id = ''dis-court''') = 0,
    'the custom court did not move from the chamber to the owner'
  );
  perform pg_temp.assert_true(
    pg_temp.count_as(c_owner, 'select 1 from public.delete_requests') = 1
      and pg_temp.count_as(c_assoc, 'select 1 from public.delete_requests') = 0,
    'the delete request did not move from its requester to the owner'
  );
  -- The exception, in both directions: the author keeps it, the owner gets no
  -- access to a colleague's merge diagnostics.
  perform pg_temp.assert_true(
    pg_temp.count_as(c_assoc, 'select 1 from public.conflict_log') = 1,
    'the author lost his own merge diagnostics in the dissolve'
  );
  perform pg_temp.assert_true(
    pg_temp.count_as(c_owner, 'select 1 from public.conflict_log') = 0,
    'the dissolve handed a colleague''s merge diagnostics to the owner'
  );

  -- -------------------------------------------------------------------------
  -- 6. A code issued before the dissolve no longer joins
  -- -------------------------------------------------------------------------

  perform pg_temp.as_user('authenticated', c_stranger);
  v_result := public.join_firm('DISSOLVE01');
  perform pg_temp.as_owner();
  perform pg_temp.assert_true(
    v_result ->> 'status' = 'invalid_code',
    'a pre-dissolve code still joins: ' || coalesce(v_result::text, 'null')
  );

  -- -------------------------------------------------------------------------
  -- 7. `delete_my_account()` no longer refuses the owner
  -- -------------------------------------------------------------------------

  v_result := pg_temp.delete_account(c_owner);
  perform pg_temp.assert_true(
    v_result ->> 'status' = 'removed',
    'the owner could not delete his account after dissolving: '
      || coalesce(v_result::text, 'null')
  );
end;
$$;

rollback;

\echo 'DISSOLVE OK: the roster must be empty, the owner keeps the ledger, attribution and plan are untouched, and the account is individual again.'
