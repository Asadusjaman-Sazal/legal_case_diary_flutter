-- Future public tables keep the Data API access this app relies on.
--
-- Supabase stops granting new tables in `public` to the API roles on
-- 2026-10-30: from then on a table created by a migration is reachable only
-- after an explicit grant, and a preview branch or a replayed schema would be
-- missing those grants. These two statements restore the old automatic
-- behaviour under the project's own control, for tables created from now on by
-- the migration role (`postgres`):
--
--   * `authenticated` — the app's only client role (every screen is behind
--     sign-in). Row-level security still scopes each row; this only restores the
--     table privileges the app already holds on the existing tables.
--   * `service_role` — the server's own role, for any future server-side write.
--
-- `anon` is deliberately left out: this app has no unauthenticated table
-- access, and granting it would only widen what an anonymous caller can reach.
-- These defaults change no existing table: each keeps the privileges it has
-- today, and a new table that needs narrower privileges (column-level grants or
-- a closed `anon` grant) still states them in its own migration.
alter default privileges for role postgres in schema public
  grant select, insert, update, delete on tables to authenticated;

alter default privileges for role postgres in schema public
  grant select, insert, update, delete on tables to service_role;
