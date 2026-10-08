-- discard_unconfirmed_signup(): the password-checked cleanup behind the Check
-- Your Email screen's **Change Email Address**.
--
-- Why this exists. A user who mistypes their address at sign-up is stuck: the
-- account exists, and Supabase refuses every call that could correct it, because
-- an unconfirmed address can never sign in. Nothing on the device can help
-- either — the address is the account, and it lives only on the server. The
-- app's existing cleanup, `abandon_provisional_account()`, cannot be used here:
-- it works from `auth.uid()`, and this caller has no session by definition.
--
-- What it does, in this order:
--   1. normalizes the address and finds the account by it, case-insensitively;
--   2. verifies the password against that account's own hash (`crypt()` from
--      pgcrypto, which reads the bcrypt `$2a$` hashes this project stores). This
--      is the only proof that the caller is the person who made the account —
--      which is the whole reason a stranger cannot use this to delete other
--      people's pending sign-ups;
--   3. refuses an address that is **already confirmed** (log in instead);
--   4. refuses an account that has done anything, with exactly the guards
--      `abandon_provisional_account()` uses — a firm, a role, a subscription,
--      firm ownership or membership, an issued invite, any authored row, a
--      payment, an approval, administrator rights, a sync receipt;
--   5. removes the `auth.users` row, which cascades the profile, the preference
--      rows, the invite attempts and the sessions.
--
-- The caller may be anonymous — there is no session to have — so it is granted
-- to `anon` as well as `authenticated`, and that is why it is **rate-limited**:
-- five failures per address inside fifteen minutes, recorded in
-- `public.signup_discard_attempts`, and a success clears that address's rows.
-- Nothing in the answer tells a stranger whether an address exists: a missing
-- account, a wrong password and a hash this server cannot read all answer the
-- same `refused`, and only a caller who holds the password learns anything more.
--
-- Table classification (AGENTS.md rule 4): `signup_discard_attempts` is
-- **server-managed** — a rolling rate-limit ledger, exactly like
-- `invite_attempts`. It is never synced, never pulled and never written by a
-- client; RLS is on with no policies, so only this function (which is SECURITY
-- DEFINER) can touch it.
--
-- ponytail: the ledger is keyed by address rather than by account, because the
-- caller has no account id yet, and only this function's own success and its
-- one-day retention purge clear rows. The ceiling is that removing an account
-- through `delete_my_account()` leaves that address's attempt rows behind for up
-- to a day; the upgrade path, if it ever matters, is one more delete line in
-- that function.

create table if not exists public.signup_discard_attempts (
  email text not null,
  attempted_at timestamptz not null default now()
);

comment on table public.signup_discard_attempts is
  'Rolling rate-limit ledger for discard_unconfirmed_signup(): one row per refused proof, keyed by the address it was refused for. Server-managed; no client access.';

create index if not exists signup_discard_attempts_email_attempted_at_idx
  on public.signup_discard_attempts (email, attempted_at desc);

alter table public.signup_discard_attempts enable row level security;

create or replace function public.discard_unconfirmed_signup(
  p_email text,
  p_password text
)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public, extensions
as $$
declare
  -- Five failures per address per quarter hour, and attempts older than a day
  -- are dropped by the purge below — the same shape join_firm() uses.
  c_window constant interval := interval '15 minutes';
  c_max_attempts constant int := 5;
  c_retention constant interval := interval '1 day';

  v_email text := lower(btrim(coalesce(p_email, '')));
  v_attempts int;
  v_user auth.users%rowtype;
  v_reason text;
begin
  -- Nothing to look up without both halves of the proof.
  if v_email = '' or coalesce(p_password, '') = '' then
    return jsonb_build_object('status', 'refused', 'reason', 'not_provisional');
  end if;

  delete from public.signup_discard_attempts a
   where a.attempted_at < now() - c_retention;

  select count(*)
    into v_attempts
    from public.signup_discard_attempts a
   where a.email = v_email
     and a.attempted_at > now() - c_window;

  if v_attempts >= c_max_attempts then
    return jsonb_build_object('status', 'rate_limited');
  end if;

  select u.* into v_user from auth.users u where lower(u.email) = v_email;

  -- One answer for every way the proof can fail: no such account, no hash, a
  -- wrong password, or a hash this server cannot read (crypt() answers null
  -- then, and `is distinct from` is what keeps that a refusal rather than a
  -- match). The attempt is recorded through a normal `return`, never by raising
  -- after an insert — a raise would roll the attempt back with the statement and
  -- the limit would never fill up.
  if not found
     or v_user.encrypted_password is null
     or crypt(p_password, v_user.encrypted_password)
        is distinct from v_user.encrypted_password
  then
    insert into public.signup_discard_attempts (email) values (v_email);
    return jsonb_build_object('status', 'refused', 'reason', 'not_provisional');
  end if;

  -- A confirmed address is not a waiting sign-up: the account is real, and the
  -- user's way forward is the login they can now pass.
  if v_user.email_confirmed_at is not null then
    return jsonb_build_object('status', 'refused', 'reason', 'confirmed');
  end if;

  -- The account's profile. A missing row is a bug state, not a provisional
  -- account, so nothing is removed.
  select case
           when p.firm_id is not null then 'a firm'
           when p.role <> 'individual' then 'a role'
           when p.subscription_expiry is not null then 'a subscription'
         end
    into v_reason
    from public.profiles p
   where p.id = v_user.id;

  if not found then
    v_reason := 'no profile';
  end if;

  -- Everything the account may have done, exactly as abandon_provisional_account
  -- lists it: the first table with a row refuses the removal. Each statement is
  -- either a row whose loss would be a loss of work, or a reference that does not
  -- cascade from auth.users — which is why the removal below cannot fail on a
  -- foreign key.
  if v_reason is null then
    select t.reason
      into v_reason
      from (
        select 'firm ownership' as reason
          from public.firms f where f.owner_id = v_user.id
        union all select 'firm membership'
          from public.firm_members m where m.user_id = v_user.id
        union all select 'an issued invite'
          from public.firm_invites i where i.created_by = v_user.id
        union all select 'a payment'
          from public.payment_submissions s where s.user_id = v_user.id
        union all select 'an approval'
          from public.payment_approval_events e
         where e.user_id = v_user.id or e.approved_by = v_user.id
        union all select 'administrator rights'
          from public.app_admins a where a.user_id = v_user.id
        union all select 'a sync receipt'
          from public.mutation_receipts r where r.actor_id = v_user.id
        union all select 'cases'
          from public.cases c where c.user_id = v_user.id
        union all select 'case history'
          from public.case_history h where h.user_id = v_user.id
        union all select 'notes'
          from public.notes n where n.user_id = v_user.id
        union all select 'case references'
          from public.case_references r where r.user_id = v_user.id
        union all select 'delete requests'
          from public.delete_requests d
         where d.requested_by = v_user.id or d.reviewed_by = v_user.id
        union all select 'conflict records'
          from public.conflict_log l where l.user_id = v_user.id
        union all select 'custom courts'
          from public.courts x where x.user_id = v_user.id
        union all select 'custom court categories'
          from public.court_categories x where x.user_id = v_user.id
        union all select 'custom case categories'
          from public.case_categories x where x.user_id = v_user.id
        union all select 'custom steps'
          from public.steps x where x.user_id = v_user.id
        union all select 'custom case types'
          from public.case_types x where x.user_id = v_user.id
        union all select 'custom on-behalfs'
          from public.on_behalfs x where x.user_id = v_user.id
      ) t
     limit 1;
  end if;

  if v_reason is not null then
    return jsonb_build_object('status', 'refused', 'reason', 'not_provisional');
  end if;

  -- Provisional, unconfirmed, and the password proved the caller: remove the
  -- account, and forget the attempts it took to get here.
  delete from public.signup_discard_attempts a where a.email = v_email;
  delete from auth.users u where u.id = v_user.id;

  return jsonb_build_object('status', 'removed');
end;
$$;

comment on function public.discard_unconfirmed_signup(text, text) is
  'Removes a sign-up that has never confirmed its address, when the caller proves ownership with the account password: the only way to correct a mistyped address, because an unconfirmed account cannot sign in and abandon_provisional_account() needs a session it can never have. Rate-limited per address. Returns {"status":"removed"}, {"status":"refused","reason":"confirmed"|"not_provisional"} or {"status":"rate_limited"}.';

-- `anon` must be named explicitly: a direct EXECUTE grant from Supabase's default
-- privileges outlives a revoke of PUBLIC, and this caller has no session — which
-- is the same reason join_firm and abandon_provisional_account name their roles.
revoke all on function public.discard_unconfirmed_signup(text, text)
  from public;
grant execute on function public.discard_unconfirmed_signup(text, text)
  to anon, authenticated;
