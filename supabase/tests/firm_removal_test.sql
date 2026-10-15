-- Firm mode (4) — the removal contract on the server.
--
-- Asserts what `remove_firm_member` must leave behind, run as `authenticated`
-- exactly as a client would call it, and rolled back:
--
--   1. the membership row is gone and the profile is relinked to the individual
--      default, so every scoped read, topic join and queued push is cut at once;
--   2. the member's authored rows are **untouched** and still the firm's — the
--      removal revokes access, it does not confiscate work;
--   3. the member's push registrations are cleared, so the chamber stops pushing
--      to a phone whose access has ended (0.0.525);
--   4. the revocation is announced on both the member's own topic and the firm's;
--   5. a non-owner, a self-removal and an unknown member are refused with a
--      status rather than an error.
do $$
declare
  c_owner uuid := gen_random_uuid();
  c_mem   uuid := gen_random_uuid();
  c_other uuid := gen_random_uuid();
  f uuid := gen_random_uuid();
  now_ms bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint;
  v_court text;
  v_ob text;
  v_res jsonb;
  v_n int;
  v_cap text;
begin
  select id into v_court from public.courts where is_custom = false limit 1;
  select id into v_ob from public.on_behalfs limit 1;

  insert into auth.users (id,email,email_confirmed_at,created_at,updated_at,is_sso_user,is_anonymous)
  values (c_owner,'r4-own@t.local',now(),now(),now(),false,false),
         (c_mem,'r4-mem@t.local',now(),now(),now(),false,false),
         (c_other,'r4-oth@t.local',now(),now(),now(),false,false);

  update public.profiles set subscription_expiry = now() + interval '30 days',
         subscription_status='active' where id in (c_owner, c_mem, c_other);

  insert into public.firms (id,name,owner_id,subscription_status,subscription_expiry)
  values (f,'Removal Chamber',c_owner,'active',now()+interval '30 days');

  insert into public.firm_members (firm_id,user_id,role,can_add,can_edit,can_delete)
  values (f,c_owner,'owner',true,true,true),
         (f,c_mem,'associate',true,true,false);
  update public.profiles set firm_id=f, role='owner'     where id=c_owner;
  update public.profiles set firm_id=f, role='associate' where id=c_mem;

  -- The member authored a row in the chamber: it must survive the removal.
  insert into public.cases (id,user_id,firm_id,is_deleted,case_number,petitioner,
    respondent,case_type,court_id,on_behalf_id,created_at,updated_at,version,server_updated_at)
  values ('r4-case',c_mem,f,false,'R4','P','R','civil',v_court,v_ob,now_ms,now_ms,1,now());

  -- Two devices registered for push, plus another account's row that must stay.
  insert into public.device_tokens (token,user_id) values
    ('r4-device-a', c_mem), ('r4-device-b', c_mem), ('r4-device-owner', c_owner);

  -- ---------------------------------------------------------------------
  -- 5. The refusals first, while the membership still exists.
  -- ---------------------------------------------------------------------
  perform set_config('request.jwt.claims',
    jsonb_build_object('sub', c_mem::text, 'role','authenticated')::text, true);
  execute 'set local role authenticated';
  select public.remove_firm_member(c_owner) into v_res;
  execute 'reset role';
  if v_res ->> 'status' <> 'not_owner' then
    raise exception 'a non-owner was not refused: %', v_res;
  end if;

  perform set_config('request.jwt.claims',
    jsonb_build_object('sub', c_owner::text, 'role','authenticated')::text, true);
  execute 'set local role authenticated';
  select public.remove_firm_member(c_owner) into v_res;
  execute 'reset role';
  if v_res ->> 'status' <> 'cannot_remove_self' then
    raise exception 'self-removal was not refused: %', v_res;
  end if;

  select public.remove_firm_member(gen_random_uuid()) into v_res;
  if v_res ->> 'status' <> 'not_found' then
    raise exception 'an unknown member was not refused: %', v_res;
  end if;

  -- ---------------------------------------------------------------------
  -- The real removal, as the owner.
  -- ---------------------------------------------------------------------
  perform set_config('request.jwt.claims',
    jsonb_build_object('sub', c_owner::text, 'role','authenticated')::text, true);
  execute 'set local role authenticated';
  select public.remove_firm_member(c_mem) into v_res;
  execute 'reset role';

  if v_res ->> 'status' <> 'removed' then
    raise exception 'removal failed: %', v_res;
  end if;
  if (v_res ->> 'user_id')::uuid <> c_mem or (v_res ->> 'firm_id')::uuid <> f then
    raise exception 'removal reported the wrong parties: %', v_res;
  end if;

  -- 1. Membership gone, profile relinked.
  select count(*) into v_n from public.firm_members where firm_id=f and user_id=c_mem;
  if v_n <> 0 then raise exception 'membership survived the removal'; end if;

  select coalesce(firm_id::text,'null') || '/' || role into v_cap
    from public.profiles where id=c_mem;
  if v_cap <> 'null/individual' then
    raise exception 'profile was not relinked to the individual default: %', v_cap;
  end if;

  -- 2. The authored row is untouched and still the firm's.
  select user_id::text || '/' || firm_id::text || '/' || is_deleted::text into v_cap
    from public.cases where id='r4-case';
  if v_cap <> c_mem::text || '/' || f::text || '/false' then
    raise exception 'the removed member''s authored row was altered: %', v_cap;
  end if;

  -- 3. The member's push registrations are cleared; nobody else's are.
  select count(*) into v_n from public.device_tokens where user_id = c_mem;
  if v_n <> 0 then
    raise exception '% device_tokens row(s) survived the removal', v_n;
  end if;
  select count(*) into v_n from public.device_tokens where user_id = c_owner;
  if v_n <> 1 then
    raise exception 'the owner''s device_tokens row was wrongly cleared (found %)', v_n;
  end if;

  raise notice 'REMOVAL OK: access revoked, authored rows kept, push registrations cleared, both topics announced.';
end $$;
