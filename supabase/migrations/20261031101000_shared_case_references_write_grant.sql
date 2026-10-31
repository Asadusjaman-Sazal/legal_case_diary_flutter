-- The admin's write grant on the shared citation library.
--
-- `20261031100000_shared_case_references.sql` revoked INSERT/UPDATE/DELETE from
-- `authenticated` while its RLS policies already restrict every write to
-- `is_app_admin()`. Those two decisions cancel each other out: the policies can
-- never be reached, because the privilege check runs first, so an administrator
-- could not publish a citation either. This migration restores the three write
-- privileges to `authenticated` and leaves the admin policies as the boundary
-- they were meant to be.
--
-- `anon` keeps nothing: the app has no unauthenticated table access, and this
-- table is behind sign-in like every other screen.
--
-- Applied to `lsthasywrdrhuuxnykau` ("Legal Case Diary") only — AGENTS.md rule 12.

grant select, insert, update, delete on public.shared_case_references
  to authenticated;
revoke all on public.shared_case_references from anon;
