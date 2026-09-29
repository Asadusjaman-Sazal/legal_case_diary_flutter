-- Phase 1 (2/2) — Sign-up trigger: every new auth.users row gets a profiles row.
--
-- The profile starts as an individual account (`role = 'individual'`,
-- `firm_id = null`, free entitlement) exactly as the plan describes. It is a
-- pull-only cache on the client, so this trigger is the only INSERT path.
--
-- EXECUTE is deliberately NOT revoked from PUBLIC here: PostgreSQL checks the
-- EXECUTE privilege of the role whose statement fires a trigger, and sign-up
-- inserts into auth.users run as the auth service role, so revoking would break
-- account creation. Nothing else is reachable through this function.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  insert into public.profiles (
    id, full_name, role, firm_id,
    subscription_status, subscription_expiry, created_at
  )
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
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
  'Creates the individual profiles row for a new auth user; see Phase 4 for profiles RLS.';

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row
  execute function public.handle_new_user();
