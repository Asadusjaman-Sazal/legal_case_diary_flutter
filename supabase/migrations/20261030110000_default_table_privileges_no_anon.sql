-- Close future tables to unauthenticated callers.
--
-- Supabase's own default still hands `anon` every table privilege on a new
-- `public` table (`arwdDxtm`: select, insert, update, delete, truncate,
-- references, trigger, maintain). The app never calls the Data API without a
-- session, so that grant is a leftover, not a feature: it is revoked here for
-- tables created by the migration role from now on. Every existing table keeps
-- the grants it already has — a default privilege cannot touch an existing
-- object — and `authenticated` and `service_role` keep the four DML verbs
-- granted by 20261030100000. The full set is revoked rather than the four DML
-- verbs, so no part of the legacy grant survives on a future table.
--
-- Reversible with:
--   alter default privileges for role postgres in schema public
--     grant select, insert, update, delete, truncate, references, trigger,
--       maintain on tables to anon;
alter default privileges for role postgres in schema public
  revoke all on tables from anon;
