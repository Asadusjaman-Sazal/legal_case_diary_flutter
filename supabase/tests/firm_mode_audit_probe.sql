-- Adversarial audit probe for firm mode phases 1–3. Rolled back; writes nothing.
--
-- This does not re-run the phases' own tests (which assert the intended
-- behaviour). It tries to *defeat* each guarantee as a real client would.
--
-- Every assertion first proves the fixture is what it claims: a "removed"
-- member has had their `firm_members` row deleted *and* their `profiles.firm_id`
-- cleared, because `current_firm_id()` reads the profile — a probe that skips
-- that step measures a member who is still a member, not a removed one.
begin;

-- Runs p_sql as the given user, returning 'CAUGHT: <err>' or 'ALLOWED'.
create or replace function pg_temp.attempt(p_user uuid, p_sql text)
returns text language plpgsql as $$
begin
  perform set_config('request.jwt.claims',
    jsonb_build_object('sub', p_user::text, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  execute p_sql;
  execute 'reset role';
  return 'ALLOWED';
exception when others then
  begin execute 'reset role'; exception when others then null; end;
  perform set_config('request.jwt.claims', null, true);
  return 'CAUGHT: ' || sqlerrm;
end $$;

-- Reads a single value as the given user, or '(filtered)' when RLS hides the row.
create or replace function pg_temp.probe(p_user uuid, p_sql text)
returns text language plpgsql as $$
declare r text;
begin
  perform set_config('request.jwt.claims',
    jsonb_build_object('sub', p_user::text, 'role', 'authenticated')::text, true);
  execute 'set local role authenticated';
  execute p_sql into r;
  execute 'reset role';
  perform set_config('request.jwt.claims', null, true);
  return coalesce(r, '(no row / null)');
exception when others then
  begin execute 'reset role'; exception when others then null; end;
  perform set_config('request.jwt.claims', null, true);
  return '(CAUGHT: ' || sqlerrm || ')';
end $$;

do $$
declare
  c_owner uuid := gen_random_uuid();
  c_mem   uuid := gen_random_uuid();
  c_out   uuid := gen_random_uuid();   -- never a member: the foreign caller
  f uuid := gen_random_uuid();
  f2 uuid := gen_random_uuid();        -- a second chamber
  o2 uuid := gen_random_uuid();        -- its owner
  now_ms bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint;
  v_court text;
  v_ob text;
  v_fid uuid;
  v_val text;
  r text;
begin
  select id into v_court from public.courts where is_custom = false limit 1;
  select id into v_ob from public.on_behalfs limit 1;

  insert into auth.users (id,email,email_confirmed_at,created_at,updated_at,is_sso_user,is_anonymous)
  values (c_owner,'p-own@t.local',now(),now(),now(),false,false),
         (c_mem,'p-mem@t.local',now(),now(),now(),false,false),
         (c_out,'p-out@t.local',now(),now(),now(),false,false),
         (o2,'p-own2@t.local',now(),now(),now(),false,false);

  -- Both owners premium; the member and the outsider premium too.
  update public.profiles set subscription_expiry = now() + interval '30 days',
         subscription_status='active' where id in (c_owner,o2,c_mem,c_out);

  insert into public.firms (id,name,owner_id,subscription_status,subscription_expiry)
  values (f,'Chamber A',c_owner,'active',now()+interval '30 days'),
         (f2,'Chamber B',o2,'active',now()+interval '30 days');

  insert into public.firm_members (firm_id,user_id,role,can_add,can_edit,can_delete)
  values (f,c_owner,'owner',true,true,true),
         (f,c_mem,'associate',true,true,false),
         (f2,o2,'owner',true,true,true);
  update public.profiles set firm_id=f,      role='owner'     where id=c_owner;
  update public.profiles set firm_id=f,      role='associate' where id=c_mem;
  update public.profiles set firm_id=f2,     role='owner'     where id=o2;
  -- c_out has no firm at all (individual).

  -- A chamber row authored by the member.
  insert into public.cases (id,user_id,firm_id,is_deleted,case_number,petitioner,
    respondent,case_type,court_id,on_behalf_id,created_at,updated_at,version,server_updated_at)
  values ('p-case',c_mem,f,false,'P-C','P','R','civil',v_court,v_ob,now_ms,now_ms,1,now());

  -- Fixture proof: current_firm_id() must be the chamber for each party.
  raise notice '--- fixture proof ---';
  perform pg_temp.attempt(c_owner, 'select 1');
  raise notice 'owner current_firm_id = % (want Chamber A)', public.current_firm_id();
  perform pg_temp.attempt(c_mem, 'select 1');
  raise notice 'member current_firm_id = % (want Chamber A)', public.current_firm_id();
  perform pg_temp.attempt(c_out, 'select 1');
  raise notice 'outsider current_firm_id = % (want null)', coalesce(public.current_firm_id()::text,'null');

  raise notice '=========== PHASE 1: the read scope ===========';

  -- 1a. The other chamber's owner must not read Chamber A's row.
  r := pg_temp.probe(o2, $q$select count(*)::text from public.cases where id='p-case'$q$);
  raise notice '1a a rival chamber owner reads p-case: % (want 0)', r;

  -- 1b. A never-member must not read it either.
  r := pg_temp.probe(c_out, $q$select count(*)::text from public.cases where id='p-case'$q$);
  raise notice '1b a non-member reads p-case: % (want 0)', r;

  -- 1c. The removal itself: delete the membership AND clear the profile.
  delete from public.firm_members where firm_id=f and user_id=c_mem;
  update public.profiles set firm_id=null, role='individual' where id=c_mem;
  perform pg_temp.attempt(c_mem, 'select 1');
  raise notice '1c after removal, member current_firm_id = % (want null)',
    coalesce(public.current_firm_id()::text,'null');
  r := pg_temp.probe(c_mem, $q$select count(*)::text from public.cases where id='p-case'$q$);
  raise notice '1c removed author reads their old chamber row: % (want 0) -- THE PHASE 1 GUARANTEE', r;
  r := pg_temp.probe(c_mem, format($q$select count(*)::text from public.cases where id='p-case' and firm_id=%L$q$, f::text));
  raise notice '1c removed author reads it while naming the old firm: % (want 0)', r;

  -- 1d. THE ORACLE: is scope_owner_id readable to a client that can see the row?
  update public.cases set firm_id=null, scope_owner_id=c_owner where id='p-case';
  v_val := pg_temp.probe(c_owner, $q$select scope_owner_id::text from public.cases where id='p-case'$q$);
  raise notice '1d the scope owner reads scope_owner_id from a visible row: % (their own uuid)', v_val;
  raise notice '1d has_column_privilege(authenticated, cases.scope_owner_id, SELECT) = %',
    has_column_privilege('authenticated','public.cases','scope_owner_id','SELECT');
  -- An author whose row the dissolve took reads nothing, so the column leaks nothing there.
  r := pg_temp.probe(c_mem, $q$select count(*)::text from public.cases where id='p-case'$q$);
  raise notice '1d the dissolved row''s author reads it: % (want 0)', r;

  -- 1e/1f. scope_owner_id is write-protected directly and through the RPC.
  raise notice '1e member sets scope_owner_id directly: % (want CAUGHT)',
    pg_temp.attempt(c_owner, format($q$update public.cases set scope_owner_id=%L where id='p-case'$q$, c_mem::text));
  raise notice '1f member sets scope_owner_id via push_changes: %',
    pg_temp.attempt(c_owner, format($q$select public.push_changes(jsonb_build_array(jsonb_build_object(
      'mutation_id',gen_random_uuid(),'entity_type','case','entity_id','p-case',
      'operation','update','base_version',1,
      'payload',jsonb_build_object('id','p-case','scope_owner_id',%L))))$q$, c_mem::text));
  raise notice '1f after the RPC, scope_owner_id = % (want the dissolve owner, unchanged)',
    coalesce((select scope_owner_id::text from public.cases where id='p-case'),'null');

  raise notice '=========== PHASE 2: creation and the scope columns ===========';

  -- Restore the member to the chamber for the phase-2 probes.
  insert into public.firm_members (firm_id,user_id,role,can_add,can_edit,can_delete)
  values (f,c_mem,'associate',true,true,false);
  update public.profiles set firm_id=f, role='associate' where id=c_mem;

  -- 2a. A member's insert whose payload says firm_id null (what the client sends).
  r := pg_temp.attempt(c_mem, format($q$select public.push_changes(jsonb_build_array(jsonb_build_object(
    'mutation_id',gen_random_uuid(),'entity_type','case','entity_id','p-new',
    'operation','insert','base_version',null,
    'payload',jsonb_build_object('id','p-new','user_id',%L,'case_number','P-N','firm_id',null,
      'petitioner','P','respondent','R','case_type','civil','court_id',%L,'on_behalf_id',%L,
      'created_at',%s,'updated_at',%s,'is_deleted',false))))$q$, c_mem::text, v_court, v_ob, now_ms, now_ms));
  select firm_id into v_fid from public.cases where id='p-new';
  raise notice '2a member insert (firm_id null) lands as firm=% (want Chamber A) [%]', coalesce(v_fid::text,'NULL'), r;

  -- 2b. A member's insert naming ANOTHER firm must not land there.
  r := pg_temp.attempt(c_mem, format($q$select public.push_changes(jsonb_build_array(jsonb_build_object(
    'mutation_id',gen_random_uuid(),'entity_type','case','entity_id','p-foreign',
    'operation','insert','base_version',null,
    'payload',jsonb_build_object('id','p-foreign','user_id',%L,'case_number','P-F','firm_id',%L,
      'petitioner','P','respondent','R','case_type','civil','court_id',%L,'on_behalf_id',%L,
      'created_at',%s,'updated_at',%s,'is_deleted',false))))$q$, c_mem::text, f2::text, v_court, v_ob, now_ms, now_ms));
  select firm_id into v_fid from public.cases where id='p-foreign';
  raise notice '2b member insert naming Chamber B lands as firm=% (want Chamber A, never B) [%]',
    coalesce(v_fid::text,'NULL'), r;

  -- 2c. An update must not move a row out of the chamber, nor rewrite scope_owner_id.
  r := pg_temp.attempt(c_mem, $q$select public.push_changes(jsonb_build_array(jsonb_build_object(
    'mutation_id',gen_random_uuid(),'entity_type','case','entity_id','p-new',
    'operation','update','base_version',1,
    'payload',jsonb_build_object('id','p-new','firm_id',null,'scope_owner_id',null))))$q$);
  select firm_id into v_fid from public.cases where id='p-new';
  raise notice '2c member nulls firm_id via update: firm after=% (want Chamber A) [%]', coalesce(v_fid::text,'NULL'), r;

  raise notice '=========== PHASE 3 ============';
  raise notice 'covered by firm_mode_join_gate_test.sql; the audit re-runs it separately';
end $$;

rollback;
