-- Phase 2 — Server-internal tables: no client ever touches these directly.
--
-- Table class: server-managed. They are written and read only by the
-- SECURITY DEFINER RPCs added in Phase 3 (and by service-role/migration
-- operations), so RLS is enabled here with **no policies at all**: with RLS on
-- and no policy, `authenticated` and `anon` are denied every command, while the
-- table owner and the service role continue to work. Phase 4 re-asserts
-- `enable row level security` for every table in the schema, which is
-- idempotent.

-- ---------------------------------------------------------------------------
-- invite_attempts — rolling rate-limit ledger for join_firm()
-- ---------------------------------------------------------------------------

create table if not exists public.invite_attempts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  attempted_at timestamptz not null default now()
);
comment on table public.invite_attempts is
  'Server-internal. attempted_at is server now() only, never client-supplied; rows older than one day are deleted lazily by join_firm().';

-- The rolling-window count in join_firm() is an index-only lookup.
create index if not exists invite_attempts_user_attempted_at_idx
  on public.invite_attempts (user_id, attempted_at desc);

alter table public.invite_attempts enable row level security;

-- ---------------------------------------------------------------------------
-- mutation_receipts — idempotency ledger for push_changes() (Task 18)
-- ---------------------------------------------------------------------------

create table if not exists public.mutation_receipts (
  mutation_id text primary key,
  actor_id uuid not null references auth.users (id),
  entity_type text not null,
  entity_id text not null,
  request_hash text not null,
  terminal_status text not null,
  result_payload jsonb not null,
  created_at timestamptz not null default now()
);
comment on table public.mutation_receipts is
  'Server-internal. Retain at least 210 days (the maximum supported offline window plus retry buffer), and never purge a receipt still referenced by case_history, conflict_log or an audit record. mutation_id mirrors the client-generated key so a retry returns the original result.';

alter table public.mutation_receipts enable row level security;

-- ---------------------------------------------------------------------------
-- app_admins — immutable admin registry
-- ---------------------------------------------------------------------------

create table if not exists public.app_admins (
  user_id uuid primary key references auth.users (id) on delete cascade,
  granted_at timestamptz not null default now(),
  granted_by uuid references auth.users (id)
);
comment on table public.app_admins is
  'Server-internal admin registry. No client policy of any kind; grants and revocations happen only through audited migrations or service-role operations. Ships empty — see supabase/README.md for the bootstrap insert.';

alter table public.app_admins enable row level security;

-- Grant/revoke are INSERT/DELETE by a privileged actor, so only UPDATE is
-- refused: an existing grant is immutable, a revocation stays possible.
create or replace function public.reject_admin_update()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  raise exception 'app_admins rows are immutable; revoke by deleting the row'
    using errcode = '55000';
end;
$$;

drop trigger if exists trg_app_admins_no_update on public.app_admins;
create trigger trg_app_admins_no_update
  before update on public.app_admins
  for each row
  execute function public.reject_admin_update();

-- ---------------------------------------------------------------------------
-- payment_approval_events — immutable approval audit ledger
-- ---------------------------------------------------------------------------

create table if not exists public.payment_approval_events (
  id uuid primary key default gen_random_uuid(),
  payment_submission_id uuid not null unique
    references public.payment_submissions (id) on delete restrict,
  user_id uuid not null references auth.users (id),
  approved_by uuid not null references auth.users (id),
  plan_type text not null,
  amount integer not null,
  previous_expiry timestamptz,
  new_expiry timestamptz not null,
  created_at timestamptz not null default now()
);
comment on table public.payment_approval_events is
  'One immutable event per submission (payment_submission_id is UNIQUE), written only by approve_payment() in the same transaction as the approval itself. Owners may read their own events, admins all of them; there is no update or delete path.';

alter table public.payment_approval_events enable row level security;

-- An audit ledger with no update/delete path: refuse both, for every role that
-- does not first disable the trigger deliberately.
create or replace function public.reject_ledger_mutation()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  raise exception '% is an immutable audit ledger', TG_TABLE_NAME
    using errcode = '55000';
end;
$$;

drop trigger if exists trg_payment_approval_events_immutable
  on public.payment_approval_events;
create trigger trg_payment_approval_events_immutable
  before update or delete on public.payment_approval_events
  for each row
  execute function public.reject_ledger_mutation();
