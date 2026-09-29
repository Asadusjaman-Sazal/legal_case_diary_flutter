-- Phase 1 (1/2) — Core schema: every Supabase table, created up front so later
-- phases only add behaviour. Column names/types mirror the shipped Drift
-- tables one-for-one (Task 03) so push/pull is lossless; the global sync
-- columns are added only to the push/pull domain class.
--
-- Table classes (AGENTS.md rule 4):
--   push/pull domain  : cases, case_history, notes, case_references,
--                       court_categories, case_categories, courts, steps,
--                       case_types, on_behalfs, delete_requests, conflict_log
--   pull-only cache   : profiles, firms, firm_members
--   per-user pref     : user_preferences, case_notification_preferences
--   server-managed    : firm_invites, payment_submissions
--   (payment_approval_events, mutation_receipts, invite_attempts and app_admins
--    are created in Phase 2.)
--
-- Type conventions (implementation_plan.md, "Timestamp Convention" + Revision
-- 2.4): client display metadata stays BIGINT epoch milliseconds — epoch ms does
-- not fit in a 32-bit INTEGER — while server-authoritative instants are
-- TIMESTAMPTZ. Row keys the client generates (cases, notes, …) are TEXT so a
-- client-supplied UUID string is never rejected; identity/scope columns
-- (user_id, firm_id, approved_by, …) are UUID with FKs to auth.users/firms.
-- Reference-data keys are the stable deterministic seed tags shared by Drift,
-- Supabase and backups (Rev 2.4 §1); they stay TEXT.

-- pgcrypto supplies gen_random_uuid() and, through public.sha256_hex() in
-- Phase 3, the SHA-256 hashing join_firm() needs.
create extension if not exists pgcrypto with schema extensions;

-- ---------------------------------------------------------------------------
-- Account & firm scope (pull-only caches on the client)
-- ---------------------------------------------------------------------------

-- Firms first: profiles.firm_id and firm_members.firm_id both reference it.
create table if not exists public.firms (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  owner_id uuid not null references auth.users (id),
  subscription_status text not null default 'free',
  subscription_expiry timestamptz,
  created_at timestamptz not null default now()
);
comment on table public.firms is
  'Pull-only cache. subscription_expiry is written only by mirror_owner_subscription_to_firm() (Phase 3).';

-- One row per authenticated user; created by the sign-up trigger (part 2).
create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text not null default '',
  firm_id uuid references public.firms (id),
  role text not null default 'individual',
  subscription_status text not null default 'free',
  subscription_expiry timestamptz,
  created_at timestamptz not null default now()
);
comment on table public.profiles is
  'Pull-only cache. subscription_expiry is the single source of truth for premium entitlement; subscription_status is display-only.';

create table if not exists public.firm_members (
  id uuid primary key default gen_random_uuid(),
  firm_id uuid not null references public.firms (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  role text not null,
  can_add boolean not null default false,
  can_edit boolean not null default false,
  can_delete boolean not null default false,
  synced_at bigint,
  permissions_synced_at bigint,
  unique (firm_id, user_id)
);
comment on table public.firm_members is
  'Pull-only cache of membership and permission flags; the authoritative permission source for RLS and triggers.';

-- Single-use onboarding codes. Redeemed only inside join_firm() (Phase 3).
create table if not exists public.firm_invites (
  id uuid primary key default gen_random_uuid(),
  firm_id uuid not null references public.firms (id) on delete cascade,
  code_hash text not null unique,
  created_by uuid not null references auth.users (id),
  used_by uuid references auth.users (id),
  used_at bigint,
  revoked boolean not null default false,
  created_at bigint not null
);
comment on table public.firm_invites is
  'Plaintext codes are never stored; code_hash is sha256 hex of the normalized code (see public.sha256_hex).';

-- ---------------------------------------------------------------------------
-- Push/pull domain: editable reference data (stable deterministic TEXT keys)
-- ---------------------------------------------------------------------------

-- Global sync columns for every domain table:
--   updated_at       bigint      client edit time, never used for authorization
--   version          integer     server-assigned revision (1 on insert)
--   server_updated_at timestamptz trigger-maintained; the only delta-pull cursor
--   synced_at        bigint      device mirror metadata
--   is_deleted       boolean     soft delete; rows are never hard-deleted
--   last_modified_by text        server-assigned editor id

create table if not exists public.court_categories (
  id text primary key,
  name_key text not null,
  court_level text not null,
  order_index integer not null,
  division text,
  district text,
  is_custom boolean not null default false,
  is_user_modified boolean not null default false,
  user_id uuid references auth.users (id),
  firm_id uuid references public.firms (id),
  updated_at bigint not null,
  version integer not null default 1,
  server_updated_at timestamptz not null default now(),
  synced_at bigint,
  is_deleted boolean not null default false,
  last_modified_by text
);
comment on table public.court_categories is
  'Stable machine keys (appellate_division, …). Built-ins are global; custom rows are user- or firm-scoped.';

create table if not exists public.case_categories (
  id text primary key,
  court_category_id text not null references public.court_categories (id),
  name text not null,
  order_index integer not null,
  is_custom boolean not null default false,
  is_user_modified boolean not null default false,
  user_id uuid references auth.users (id),
  firm_id uuid references public.firms (id),
  updated_at bigint not null,
  version integer not null default 1,
  server_updated_at timestamptz not null default now(),
  synced_at bigint,
  is_deleted boolean not null default false,
  last_modified_by text
);

create table if not exists public.courts (
  id text primary key,
  court_name text not null,
  higher_lower_courts text not null,
  division text,
  district text,
  court_category_id text not null references public.court_categories (id),
  order_index integer not null default 0,
  is_custom boolean not null default false,
  is_user_modified boolean not null default false,
  user_id uuid references auth.users (id),
  firm_id uuid references public.firms (id),
  updated_at bigint not null,
  version integer not null default 1,
  server_updated_at timestamptz not null default now(),
  synced_at bigint,
  is_deleted boolean not null default false,
  last_modified_by text
);

create table if not exists public.steps (
  id text primary key,
  court_category_id text not null references public.court_categories (id),
  step_name text not null,
  order_index integer not null,
  is_custom boolean not null default false,
  is_user_modified boolean not null default false,
  user_id uuid references auth.users (id),
  firm_id uuid references public.firms (id),
  updated_at bigint not null,
  version integer not null default 1,
  server_updated_at timestamptz not null default now(),
  synced_at bigint,
  is_deleted boolean not null default false,
  last_modified_by text
);

create table if not exists public.case_types (
  id text primary key,
  court_category_id text not null references public.court_categories (id),
  case_category_id text references public.case_categories (id),
  name text not null,
  order_index integer not null,
  is_custom boolean not null default false,
  is_user_modified boolean not null default false,
  user_id uuid references auth.users (id),
  firm_id uuid references public.firms (id),
  updated_at bigint not null,
  version integer not null default 1,
  server_updated_at timestamptz not null default now(),
  synced_at bigint,
  is_deleted boolean not null default false,
  last_modified_by text
);

create table if not exists public.on_behalfs (
  id text primary key,
  court_category_id text not null references public.court_categories (id),
  name text not null,
  order_index integer not null,
  is_custom boolean not null default false,
  is_user_modified boolean not null default false,
  user_id uuid references auth.users (id),
  firm_id uuid references public.firms (id),
  updated_at bigint not null,
  version integer not null default 1,
  server_updated_at timestamptz not null default now(),
  synced_at bigint,
  is_deleted boolean not null default false,
  last_modified_by text
);

-- ---------------------------------------------------------------------------
-- Push/pull domain: case data
-- ---------------------------------------------------------------------------

create table if not exists public.cases (
  id text primary key,
  user_id uuid not null references auth.users (id),
  firm_id uuid references public.firms (id),
  court_id text not null references public.courts (id),
  case_type text not null,
  case_category_id text references public.case_categories (id),
  case_number text not null,
  honorable_judges text,
  tender_number text,
  previous_court_case text,
  district_of_origin text,
  petitioner text not null,
  petitioner_lead_counsel text,
  respondent text not null,
  respondent_lead_counsel text,
  on_behalf_id text not null references public.on_behalfs (id),
  party_phone text,
  case_title_and_section text,
  case_remarks text,
  next_date bigint,
  last_step text,
  notes_results text,
  result text,
  created_at bigint not null,
  updated_at bigint not null,
  version integer not null default 1,
  server_updated_at timestamptz not null default now(),
  synced_at bigint,
  is_deleted boolean not null default false,
  last_modified_by text
);
comment on table public.cases is
  'Mirrors the shipped client model, including its single party_phone column (Rev 2.4''s separate petitioner_phone/respondent_phone land with a Part A change).';

-- Immutable hearing timeline. source_mutation_id is the idempotency key of the
-- accepted mutation that created the row; retries cannot duplicate it.
create table if not exists public.case_history (
  id text primary key,
  case_id text not null references public.cases (id) on delete cascade,
  user_id uuid not null references auth.users (id),
  firm_id uuid references public.firms (id),
  hearing_date bigint not null,
  last_step text,
  next_date bigint,
  note_result text,
  result text,
  created_by uuid not null references auth.users (id),
  source_mutation_id text not null unique,
  base_case_version integer not null,
  result_case_version integer not null,
  updated_at bigint not null,
  version integer not null default 1,
  server_updated_at timestamptz not null default now(),
  synced_at bigint,
  is_deleted boolean not null default false,
  last_modified_by text
);

create table if not exists public.notes (
  id text primary key,
  user_id uuid not null references auth.users (id),
  firm_id uuid references public.firms (id),
  title text not null,
  body text not null,
  items text,
  is_pinned boolean not null default false,
  created_at bigint not null,
  updated_at bigint not null,
  version integer not null default 1,
  server_updated_at timestamptz not null default now(),
  synced_at bigint,
  is_deleted boolean not null default false,
  last_modified_by text
);
comment on column public.notes.items is
  'To-do checklist as a JSON array of {text, done}; null on a plain text note.';

create table if not exists public.case_references (
  id text primary key,
  user_id uuid not null references auth.users (id),
  firm_id uuid references public.firms (id),
  reference_and_page_no text not null,
  statute text,
  section_or_article text,
  title_and_description text,
  comments_notes text,
  is_pinned boolean not null default false,
  created_at bigint not null,
  updated_at bigint not null,
  version integer not null default 1,
  server_updated_at timestamptz not null default now(),
  synced_at bigint,
  is_deleted boolean not null default false,
  last_modified_by text
);

-- Deletion request queue for associates without can_delete.
create table if not exists public.delete_requests (
  id text primary key,
  firm_id uuid references public.firms (id),
  entity_type text not null,
  entity_id text not null,
  entity_snapshot text not null,
  target_base_version integer not null,
  requested_by uuid not null references auth.users (id),
  status text not null,
  reviewed_by uuid references auth.users (id),
  review_note text,
  created_at bigint not null,
  updated_at bigint not null,
  version integer not null default 1,
  server_updated_at timestamptz not null default now(),
  synced_at bigint,
  is_deleted boolean not null default false,
  last_modified_by text
);
comment on column public.delete_requests.entity_snapshot is
  'Snapshot of the target at request time, stored as TEXT so a JSON string cannot silently become a JSON string value.';

-- Mirror of the local rejected-mutation log, pulled on a new device for
-- portability. user_id/firm_id are ownership columns the local table does not
-- carry: RLS and the Realtime topic both need them.
create table if not exists public.conflict_log (
  id text primary key,
  user_id uuid not null references auth.users (id),
  firm_id uuid references public.firms (id),
  mutation_id text not null,
  entity_type text not null,
  entity_id text not null,
  base_version integer not null,
  base_payload text not null,
  submitted_payload text not null,
  changed_fields text not null,
  server_version integer not null,
  server_payload text not null,
  resolution_state text not null,
  conflict_at bigint not null,
  resolved_at bigint,
  is_dismissed boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at bigint not null,
  version integer not null default 1,
  server_updated_at timestamptz not null default now(),
  synced_at bigint,
  is_deleted boolean not null default false,
  last_modified_by text
);

-- ---------------------------------------------------------------------------
-- Per-user preferences (never firm-shared)
-- ---------------------------------------------------------------------------

-- Server side of the premium cross-device preference sync (Rev 2.4 §4). Rows
-- are self-only under RLS.
create table if not exists public.user_preferences (
  user_id uuid primary key references auth.users (id) on delete cascade,
  language text,
  theme text,
  view_settings_json text,
  notification_enabled boolean not null default false,
  notification_time bigint,
  notification_default_offsets text,
  updated_at bigint not null
);

create table if not exists public.case_notification_preferences (
  user_id uuid not null references auth.users (id) on delete cascade,
  case_id text not null references public.cases (id) on delete cascade,
  enabled boolean not null default true,
  offsets text,
  time_minutes integer,
  updated_at bigint not null,
  primary key (user_id, case_id)
);

-- ---------------------------------------------------------------------------
-- Server-managed: payment submissions (no Drift counterpart; per the plan)
-- ---------------------------------------------------------------------------

create table if not exists public.payment_submissions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id),
  plan_type text not null,
  amount integer not null,
  mfs_provider text not null,
  sender_number text not null,
  transaction_id text not null unique,
  status text not null default 'pending',
  admin_notes text,
  created_at bigint not null,
  submitted_at timestamptz not null default now(),
  approved_at timestamptz,
  approved_by uuid references auth.users (id),
  updated_at bigint not null
);
comment on column public.payment_submissions.submitted_at is
  'Authoritative server submission time; the BEFORE INSERT trigger overwrites any client value and the 3-per-24h limit counts it.';

-- ---------------------------------------------------------------------------
-- Row-level security is switched on with the tables, not later
-- ---------------------------------------------------------------------------

-- Supabase grants `anon` and `authenticated` table privileges by default, so a
-- table is only protected once RLS is on: with RLS on and no policy yet, every
-- client command is denied. Enabling it here means a migration run that stops
-- half-way can never leave a reachable table behind; Phase 4 adds the policies
-- (and re-asserts the same statements, which is idempotent).

alter table public.profiles enable row level security;
alter table public.firms enable row level security;
alter table public.firm_members enable row level security;
alter table public.firm_invites enable row level security;
alter table public.court_categories enable row level security;
alter table public.case_categories enable row level security;
alter table public.courts enable row level security;
alter table public.steps enable row level security;
alter table public.case_types enable row level security;
alter table public.on_behalfs enable row level security;
alter table public.cases enable row level security;
alter table public.case_history enable row level security;
alter table public.notes enable row level security;
alter table public.case_references enable row level security;
alter table public.delete_requests enable row level security;
alter table public.conflict_log enable row level security;
alter table public.user_preferences enable row level security;
alter table public.case_notification_preferences enable row level security;
alter table public.payment_submissions enable row level security;
