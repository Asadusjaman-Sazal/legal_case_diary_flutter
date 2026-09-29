-- Phase 3 (6/6) — Column privileges: the fields only the server may write.
--
-- RLS cannot restrict *which columns* an UPDATE touches, so a row policy alone
-- would let its beneficiary write server-authoritative fields. Privileges are
-- the gate, for the shared `authenticated` role and for `anon`.
--
-- A column-level REVOKE alone does not work here, and the first version of this
-- migration proved it against the live project: Supabase grants *table-level*
-- privileges on every table in `public` to `anon` and `authenticated` through
-- its default privileges, and a table-level GRANT is not undone by a
-- column-level REVOKE — `has_column_privilege('authenticated','public.profiles',
-- 'subscription_expiry','UPDATE')` stayed true and `update public.profiles set
-- subscription_expiry = ...` still succeeded as that role.
--
-- The working shape is therefore: drop the table-level UPDATE, then GRANT UPDATE
-- back on the columns a client may legitimately write. Anything not named in a
-- GRANT stays server-only, so a column added by a later migration is closed by
-- default rather than open by default.
--
-- The SECURITY DEFINER RPCs are unaffected: they run as the migration owner,
-- whose own privileges are not touched by a revoke aimed at `authenticated`.

-- Approval state is written only by approve_payment(). A client submits a
-- payment; it never edits one, so it keeps no UPDATE privilege here at all.
revoke update on public.payment_submissions from authenticated, anon;

-- Entitlement and identity are server-managed. `subscription_expiry` and
-- `subscription_status` are the entitlement pair; `role` and `firm_id` are
-- included because RLS cannot stop a user from promoting themselves to owner
-- or relinking themselves to another firm's id, and every policy and guard
-- trusts those two columns. (Deliberate addition beyond the task's literal
-- list — flagged in docs/currentlyWorking.md.) A user may edit their own
-- display name, which is the only self-service write the Phase 4 policy allows.
revoke update on public.profiles from authenticated, anon;
grant update (full_name) on public.profiles to authenticated;

-- The firm's mirrored entitlement, and its owner link, are written by
-- mirror_owner_subscription_to_firm() and by firm administration only. The
-- owner may rename the firm, which is the only write `firms_update_owner`
-- permits that is not server-owned.
revoke update on public.firms from authenticated, anon;
grant update (name) on public.firms to authenticated;
