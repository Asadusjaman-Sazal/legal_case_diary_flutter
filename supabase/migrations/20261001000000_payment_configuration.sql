-- Task 21 Phase 1 — the MFS receiving numbers are server configuration, not
-- build constants.
--
-- Task 16 shipped `payment_submissions` and the admin `approve_payment` RPC, but
-- nothing that holds *where* a user sends money. The Addendum (Rev 2.4 §5)
-- requires the payments configuration service to take its numbers from
-- "validated build environment or authenticated remote configuration" so a
-- number can rotate without a release. Build-time defaults can bootstrap a
-- build, but a release is the wrong unit of change for a receiving number: the
-- number belongs to the firm's MFS account and can change at any moment.
--
-- This migration is the remote half. It stores one row per supported provider
-- (`bkash`, `nagad`, `rocket`), readable by any authenticated client and
-- writable by no client at all:
--
--   * SELECT policy for `authenticated`: the numbers are meant to be shown to
--     the user, so they are readable; they are not secret.
--   * No INSERT/UPDATE/DELETE policy: a receiving number is set by an admin
--     (a controlled migration or a service-role/Studio operation), never by the
--     app. `anon` reads nothing: RLS is on and only `authenticated` has a policy,
--     so the default table grant is not a read path.
--   * `receiving_number <> ''` and the provider allow-list keep a malformed row
--     from ever being created, so the client's validation only has to defend
--     against a genuinely old/absent row, not against a bad one.
--
-- The table is intentionally **not seeded**: the real bKash/Nagad/Rocket numbers
-- are not invented here. An empty table is a valid state and the service falls
-- back to its validated build defaults (`--dart-define`); once an admin inserts
-- or updates a row, the remote value is authoritative and rotates the number
-- without a release.

create table if not exists public.payment_configuration (
  provider text primary key
    check (provider in ('bkash', 'nagad', 'rocket')),
  receiving_number text not null
    check (receiving_number <> ''),
  is_active boolean not null default true,
  updated_at timestamptz not null default now()
);

alter table public.payment_configuration enable row level security;

-- Read-only to authenticated clients: display-only data that rotates centrally.
drop policy if exists payment_configuration_select_authenticated
  on public.payment_configuration;
create policy payment_configuration_select_authenticated
  on public.payment_configuration
  for select to authenticated
  using (true);

-- No write policies on purpose: this is server-managed configuration. The
-- absence of a policy is the rule, not an omission — the same shape as the
-- server-internal ledgers.
