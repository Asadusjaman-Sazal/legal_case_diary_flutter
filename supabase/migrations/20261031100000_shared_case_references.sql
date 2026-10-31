-- Server-wide case references — Phase 5 of the law-list plan.
--
-- A bar library the app's administrators curate: precedents and citations every
-- signed-in account reads, stored once on the server rather than typed into each
-- phone. The user's own references (`case_references`) are untouched: this is a
-- separate table with no owner columns, so the 50-case wall, the lapse
-- allowance and every firm rule keep applying to the user's own rows only.
--
-- Table class (AGENTS.md rule 4): **server-managed** on the server, **pull-only
-- cache** on the phone. It is never pushed: the phone has no write path to it,
-- which is why it carries no `user_id`, `firm_id`, `version`, `updated_at` or
-- `synced_at` — there is no client mutation to reconcile, and the delta pull's
-- cursor (not a client clock) is what orders it.
--
-- What this file does, in order:
--
--   1. Creates `public.shared_case_references` with the five reference fields
--      the phone's own references carry, plus `is_deleted` and the
--      trigger-stamped `server_updated_at` the delta pull pages on.
--   2. RLS: every signed-in account reads every row (including a tombstone, so a
--      removed citation can disappear from a phone); only `is_app_admin()` may
--      insert, update or delete. There is no owner, so there is no self-or-firm
--      matrix here — the admin check IS the boundary.
--   3. Grants: the default table privileges would give `authenticated` insert,
--      update and delete on a public table (migration 20261030100000). They are
--      revoked, leaving SELECT — the only privilege a client needs — so a
--      non-admin's write is refused by the table privilege before RLS is even
--      consulted.
--   4. Triggers: the server timestamp and the realtime broadcast. No delete
--      transition, resurrection or member-permission guard: each of those reads
--      `firm_id` or a creator, and this table has neither; the RLS admin check
--      is the whole write boundary.
--   5. Indexes: the delta cursor. One composite index is enough because the
--      table has no scope column to slice by.
--
-- Applied to `lsthasywrdrhuuxnykau` ("Legal Case Diary") only — AGENTS.md rule 12.

-- ---------------------------------------------------------------------------
-- 1. The table
-- ---------------------------------------------------------------------------

create table if not exists public.shared_case_references (
  id text primary key,
  reference_and_page_no text not null,
  statute text,
  section_or_article text,
  title_and_description text,
  comments_notes text,
  is_deleted boolean not null default false,
  server_updated_at timestamptz not null default now()
);

comment on table public.shared_case_references is
  'Server-wide case references curated by the app''s administrators. Read by every signed-in account, written only by an admin; the phone keeps them as a pull-only cache and never pushes to this table.';
comment on column public.shared_case_references.server_updated_at is
  'Trigger-stamped on every write. The delta pull pages on (server_updated_at, id); clients never send it.';

-- ---------------------------------------------------------------------------
-- 2. Row-level security — read for everyone signed in, write for an admin
-- ---------------------------------------------------------------------------

alter table public.shared_case_references enable row level security;

drop policy if exists shared_case_references_select_all
  on public.shared_case_references;
create policy shared_case_references_select_all
  on public.shared_case_references
  for select to authenticated
  using (true);

drop policy if exists shared_case_references_insert_admin
  on public.shared_case_references;
create policy shared_case_references_insert_admin
  on public.shared_case_references
  for insert to authenticated
  with check (public.is_app_admin());

drop policy if exists shared_case_references_update_admin
  on public.shared_case_references;
create policy shared_case_references_update_admin
  on public.shared_case_references
  for update to authenticated
  using (public.is_app_admin())
  with check (public.is_app_admin());

drop policy if exists shared_case_references_delete_admin
  on public.shared_case_references;
create policy shared_case_references_delete_admin
  on public.shared_case_references
  for delete to authenticated
  using (public.is_app_admin());

-- ---------------------------------------------------------------------------
-- 3. Grants — read only for a client
-- ---------------------------------------------------------------------------

revoke insert, update, delete on public.shared_case_references
  from authenticated, anon;
grant select on public.shared_case_references to authenticated;

-- ---------------------------------------------------------------------------
-- 4. Triggers
-- ---------------------------------------------------------------------------

drop trigger if exists trg_shared_case_references_server_updated_at
  on public.shared_case_references;
create trigger trg_shared_case_references_server_updated_at
  before insert or update on public.shared_case_references
  for each row execute function public.set_server_updated_at();

drop trigger if exists trg_shared_case_references_broadcast
  on public.shared_case_references;
create trigger trg_shared_case_references_broadcast
  after insert or update on public.shared_case_references
  for each row execute function public.broadcast_row_change();

-- ---------------------------------------------------------------------------
-- 5. Index — the delta pull reads this
-- ---------------------------------------------------------------------------

create index if not exists shared_case_references_delta_idx
  on public.shared_case_references (server_updated_at, id);
