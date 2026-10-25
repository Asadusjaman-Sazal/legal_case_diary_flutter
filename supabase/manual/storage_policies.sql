-- ===========================================================================
-- Storage policies — applied through the Supabase Storage policy editor.
--
-- **Why this file is not a migration.** `storage.objects` is owned by
-- `supabase_storage_admin`. The migration role (`postgres`) is neither its owner
-- nor a member of that role, so `create policy` fails in the migrations, in the
-- psql applier and through the MCP's SQL. Supabase's Storage policy editor does
-- run with the required rights, so these eight policies are created there once.
--
-- **When.** After both migrations are applied:
--   20261025120000_firm_logo_storage.sql
--   20261025180000_profile_avatar_storage.sql
-- The migrations create the buckets, the helper functions and the version
-- triggers; these policies are what let the app read and write the objects.
--
-- **How.** Supabase Dashboard → Storage → Policies. For each block below create
-- a policy on `storage.objects` with:
--   * the given name and operation,
--   * role `authenticated`,
--   * the USING and/or WITH CHECK expression shown.
-- A SQL editor that runs with the storage admin's rights can execute the
-- `create policy` statement directly. Each block drops its own name first, so a
-- re-run is safe.
--
-- This file is included in `supabase/AllSupabaseSql.md` as a labelled manual
-- section. It is not applied by `tool/apply_supabase_migrations.dart`.
--
-- **The editor adds a SELECT policy beside each UPDATE and DELETE policy.** The
-- Storage API reads a row before it updates or removes it, so the editor creates
-- a matching SELECT policy (e.g. `... _1`) automatically. Those are permissive
-- and therefore redundant with the bucket's SELECT policy, not a restriction;
-- leave them in place. The live policy names also carry a random suffix, which
-- is cosmetic. Both proofs were run against the live project on 2026-10-25 and
-- printed FIRM LOGO OK and PROFILE AVATAR OK.
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- Chamber logos — bucket `firm-avatars`, object `{firm_id}.jpg`
-- ---------------------------------------------------------------------------

-- 1. firm_logo_select_member — SELECT
--    Any member of the chamber may read its logo; a lapsed chamber keeps it.
drop policy if exists firm_logo_select_member on storage.objects;
create policy firm_logo_select_member on storage.objects
  for select to authenticated
  using (
    bucket_id = 'firm-avatars'
    and name = public.current_firm_id()::text || '.jpg'
  );

-- 2. firm_logo_insert_owner — INSERT
--    Only the owner of a chamber whose plan is live may add its logo.
drop policy if exists firm_logo_insert_owner on storage.objects;
create policy firm_logo_insert_owner on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'firm-avatars'
    and name = public.current_firm_id()::text || '.jpg'
    and public.can_write_firm_logo()
  );

-- 3. firm_logo_update_owner — UPDATE
--    A replace is an UPDATE, so the old and the new row must both satisfy it.
drop policy if exists firm_logo_update_owner on storage.objects;
create policy firm_logo_update_owner on storage.objects
  for update to authenticated
  using (
    bucket_id = 'firm-avatars'
    and name = public.current_firm_id()::text || '.jpg'
    and public.can_write_firm_logo()
  )
  with check (
    bucket_id = 'firm-avatars'
    and name = public.current_firm_id()::text || '.jpg'
    and public.can_write_firm_logo()
  );

-- 4. firm_logo_delete_owner — DELETE
--    Removing the logo stays possible after a lapse, so the owner can clean up.
drop policy if exists firm_logo_delete_owner on storage.objects;
create policy firm_logo_delete_owner on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'firm-avatars'
    and name = public.current_firm_id()::text || '.jpg'
    and public.is_firm_owner(public.current_firm_id())
  );

-- ---------------------------------------------------------------------------
-- Individual profile pictures — bucket `individual-avatars`, object
-- `{user_id}.jpg`
-- ---------------------------------------------------------------------------

-- 5. profile_avatar_select_owner — SELECT
--    The holder reads their own picture, including after a lapse.
drop policy if exists profile_avatar_select_owner on storage.objects;
create policy profile_avatar_select_owner on storage.objects
  for select to authenticated
  using (
    bucket_id = 'individual-avatars'
    and name = auth.uid()::text || '.jpg'
  );

-- 6. profile_avatar_insert_owner — INSERT
--    Only a premium individual or a premium chamber owner may add one.
drop policy if exists profile_avatar_insert_owner on storage.objects;
create policy profile_avatar_insert_owner on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'individual-avatars'
    and name = auth.uid()::text || '.jpg'
    and public.can_write_profile_avatar()
  );

-- 7. profile_avatar_update_owner — UPDATE
--    A replace is an UPDATE; both the old and the new row satisfy the rule.
drop policy if exists profile_avatar_update_owner on storage.objects;
create policy profile_avatar_update_owner on storage.objects
  for update to authenticated
  using (
    bucket_id = 'individual-avatars'
    and name = auth.uid()::text || '.jpg'
    and public.can_write_profile_avatar()
  )
  with check (
    bucket_id = 'individual-avatars'
    and name = auth.uid()::text || '.jpg'
    and public.can_write_profile_avatar()
  );

-- 8. profile_avatar_delete_owner — DELETE
--    The holder can always remove their own picture, including after a lapse.
drop policy if exists profile_avatar_delete_owner on storage.objects;
create policy profile_avatar_delete_owner on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'individual-avatars'
    and name = auth.uid()::text || '.jpg'
  );
