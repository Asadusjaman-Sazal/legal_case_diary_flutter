-- Task 17 follow-up — the lawyer's own details live on `profiles`, not only on
-- one device.
--
-- Why this exists. Settings > Accounts & Profile > Profile has always captured
-- full name, bar association, membership number, office address and mobile
-- number, but it kept all five in `SharedPreferences` on that one install. A
-- re-install, a second phone or a cleared app therefore showed five dashes and
-- asked a lawyer to type their own details again. The user asked for the record
-- to live on the account instead.
--
-- `profiles` is a pull-only cache (AGENTS.md rule 4): the server is its writer
-- for `role`, `firm_id`, `subscription_status` and `subscription_expiry`, and
-- none of those ever move from a client. This migration adds the one documented
-- exception the plan already has for `full_name` — the account holder's own
-- details — and nothing else. The Phase 3 column privileges stay exactly as they
-- are for every server-owned column.
--
-- The write path is the boring one. `profiles_update_self` (Phase 4) already
-- restricts a client UPDATE to its own row (`id = auth.uid()`), and
-- `full_name` has been granted column-wise since Phase 3. The four new detail
-- columns join that grant, so the client PATCHes its own row through PostgREST
-- and needs no new function — and no new `SECURITY DEFINER`, which matters
-- because the project's open hardening item is precisely the number of
-- anon-executable definer functions.
--
-- `email` is deliberately **not** granted: it is the account's login identity,
-- owned by `auth.users`, and a client that could write it could lie about who it
-- is to every firm member who can read the profile. Two triggers keep it exact —
-- `handle_new_user()` fills it at creation (and now also reads the Bar
-- Association the sign-up screen collects), and `handle_user_email_change()`
-- follows an e-mail change on the auth record.

alter table public.profiles
  add column if not exists email text not null default '',
  add column if not exists bar_association text not null default '',
  add column if not exists membership_no text not null default '',
  add column if not exists office_address text not null default '',
  add column if not exists mobile_no text not null default '';

comment on column public.profiles.email is
  'The account''s login e-mail, mirrored from auth.users by handle_new_user() and handle_user_email_change(). Server-owned and never client-writable.';
comment on column public.profiles.bar_association is
  'The bar association the account holder is enrolled in. Self-service: the holder may update this column on their own row.';
comment on column public.profiles.membership_no is
  'The account holder''s bar membership/registration number. Self-service: the holder may update this column on their own row.';
comment on column public.profiles.office_address is
  'The account holder''s chamber/office address. Self-service: the holder may update this column on their own row.';
comment on column public.profiles.mobile_no is
  'The account holder''s mobile number without the +880 prefix, matching the editor''s fixed prefix box. Self-service: the holder may update this column on their own row.';

-- Accounts created before this migration have no e-mail on their profile.
update public.profiles p
   set email = coalesce(u.email, '')
  from auth.users u
 where u.id = p.id
   and p.email = '';

-- The account holder's own details join `full_name` as the only client-writable
-- columns. `role`, `firm_id`, the entitlement pair and `email` keep their
-- Phase 3 revoke, so a permitted UPDATE still cannot move them.
grant update (bar_association, membership_no, office_address, mobile_no)
  on public.profiles to authenticated;

-- The sign-up trigger now also fills the e-mail and the Bar Association the
-- sign-up screen collects, so the row is complete the moment the account exists
-- — even for a sign-up that still has to confirm its address, which has no
-- session to push anything with.
--
-- EXECUTE is deliberately NOT revoked from PUBLIC: PostgreSQL checks the EXECUTE
-- privilege of the role whose statement fires a trigger, and sign-up inserts into
-- auth.users run as the auth service role, so revoking would break account
-- creation. Nothing else is reachable through these functions.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  insert into public.profiles (
    id, email, full_name, bar_association, role, firm_id,
    subscription_status, subscription_expiry, created_at
  )
  values (
    new.id,
    coalesce(new.email, ''),
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    coalesce(new.raw_user_meta_data ->> 'bar_association', ''),
    'individual',
    null,
    'free',
    null,
    now()
  )
  on conflict (id) do nothing;

  return new;
end;
$$;

comment on function public.handle_new_user() is
  'Creates the individual profiles row for a new auth user, including their e-mail and the Bar Association from the sign-up metadata; see Phase 4 for profiles RLS.';

-- An e-mail change on the auth record is mirrored onto the profile, so the two
-- can never disagree about the identity the row belongs to.
create or replace function public.handle_user_email_change()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  update public.profiles
     set email = coalesce(new.email, '')
   where id = new.id;

  return new;
end;
$$;

comment on function public.handle_user_email_change() is
  'Mirrors auth.users.email onto public.profiles.email, so the cached identity is never stale.';

drop trigger if exists on_auth_user_email_changed on auth.users;
create trigger on_auth_user_email_changed
  after update of email on auth.users
  for each row
  when (old.email is distinct from new.email)
  execute function public.handle_user_email_change();
