-- Phase 3 (1/6) — Access helpers.
--
-- Every guard, RPC and RLS policy asks the same handful of questions, and none
-- of them may be answered with a plain subquery:
--
--   * `profiles` RLS allows same-firm reads, so a policy on `profiles` that
--     reads `firm_members` and a policy on `firm_members` that reads
--     `profiles` would recurse forever;
--   * the delete-transition trigger must read permissions for a row the caller
--     may not SELECT;
--   * `approve_payment` and `join_firm` must not depend on the caller's own
--     table privileges at all.
--
-- So each question is one SECURITY DEFINER STABLE function: it reads the base
-- tables as the owner (RLS is not FORCEd, so the owner bypasses it) and returns
-- a plain boolean. Entitlement is always DERIVED from `subscription_expiry`
-- plus the 48-hour grace window — never from `subscription_status`, which is
-- display-only and goes stale because nothing fires at the expiry instant.
--
-- EXECUTE stays granted to PUBLIC on purpose: RLS policy expressions run with
-- the *caller's* privileges, so revoking would break the policies that use
-- them.

-- SHA-256 hex of a normalized invite code. join_firm() hashes the input with
-- this, and the client's invite generator (Task 20) must hash the normalized
-- code the same way: trim, uppercase, then sha256 hex.
create or replace function public.sha256_hex(p_input text)
returns text
language sql
immutable
set search_path = pg_catalog, public, extensions
as $$
  -- digest() lives in the schema pgcrypto was installed into (extensions).
  select pg_catalog.encode(digest(p_input, 'sha256'), 'hex');
$$;

comment on function public.sha256_hex(text) is
  'sha256 hex of the input; the single hashing convention for invite codes.';

-- The caller's firm, or null for an individual account.
create or replace function public.current_firm_id()
returns uuid
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select p.firm_id from public.profiles p where p.id = auth.uid();
$$;

-- True when the caller owns the firm.
create or replace function public.is_firm_owner(p_firm_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select exists (
    select 1 from public.firms f
     where f.id = p_firm_id and f.owner_id = auth.uid()
  );
$$;

-- True when the caller may edit ordinary fields of a firm-scoped row: the firm
-- owner, or a member whose `can_edit` flag is on. A null firm (individual
-- account) is never firm-scoped, so this is false for it.
create or replace function public.can_edit_firm(p_firm_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select p_firm_id is not null
     and (
       exists (select 1 from public.firms f
                where f.id = p_firm_id and f.owner_id = auth.uid())
       or exists (select 1 from public.firm_members m
                   where m.firm_id = p_firm_id
                     and m.user_id = auth.uid()
                     and m.can_edit)
     );
$$;

-- True when the caller may delete (soft-delete) a firm-scoped row.
create or replace function public.can_delete_firm(p_firm_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select p_firm_id is not null
     and (
       exists (select 1 from public.firms f
                where f.id = p_firm_id and f.owner_id = auth.uid())
       or exists (select 1 from public.firm_members m
                   where m.firm_id = p_firm_id
                     and m.user_id = auth.uid()
                     and m.can_delete)
     );
$$;

-- Derived premium entitlement: expiry + 48h grace, both server-side instants.
create or replace function public.is_premium(p_user_id uuid)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select exists (
    select 1 from public.profiles p
     where p.id = p_user_id
       and p.subscription_expiry is not null
       and p.subscription_expiry + interval '48 hours' > now()
  );
$$;

comment on function public.is_premium(uuid) is
  'Premium entitlement = subscription_expiry + 48h grace > now(). Never reads subscription_status.';

-- True when the caller is a registered admin (app_admins registry).
create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select exists (
    select 1 from public.app_admins a where a.user_id = auth.uid()
  );
$$;

-- True when the caller may subscribe to a Realtime topic: their own user topic,
-- or their firm's topic. Used by the `realtime.messages` policy only.
create or replace function public.can_read_topic(p_topic text)
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select p_topic = 'user:' || coalesce(auth.uid()::text, '')
      or (
        public.current_firm_id() is not null
        and p_topic = 'firm:' || public.current_firm_id()::text
      );
$$;
