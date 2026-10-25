-- ===========================================================================
-- 2026-10-25 — The profile picture: one private bucket, one 50 KB JPEG each.
--
-- Why. The picture is saved on the phone today, uncapped and unsynced: a photo
-- from the camera can be several megabytes, and another device of the same
-- account never sees it. A private bucket with a hard size and type limit makes
-- it safe to sync, and the 50 KB pipeline on the phone (avatar_image_processor)
-- makes that limit easy to meet.
--
-- Who may upload: a **premium individual** or a **chamber owner**. A chamber
-- member is premium through the chamber but cannot buy for it, and the firm's
-- logo is the workspace identity; a member's own picture stays local-only.
-- Free accounts are local-only too. A lapsed account keeps its picture readable
-- and may delete it, but cannot upload a new one.
--
-- What this file creates, in order:
--
--   1. public.can_write_profile_avatar() — the owner/entitlement predicate,
--      because has_sync_entitlement is revoked from client roles;
--   2. the **individual-avatars** bucket: private, 50 KB, JPEG only, one flat
--      `{user_id}.jpg` per account;
--   3. two server-managed columns on public.profiles, `avatar_path` and
--      `avatar_version`, which no client UPDATE grant reaches;
--   4. a trigger on storage.objects keeping those columns in step.
--
-- **The policies are manual, and why.** `storage.objects` is owned by
-- `supabase_storage_admin`; the migration role (`postgres`) is neither its
-- owner nor a member of that role, so `create policy` would fail here. The four
-- policies (owner read/delete; premium individual or owner insert/update) live
-- in `supabase/manual/storage_policies.sql`, are included in
-- `supabase/AllSupabaseSql.md` as a labelled manual section, and are applied
-- once through Supabase's Storage policy editor. The bucket, the columns and
-- the trigger below need no such step: `postgres` can insert the bucket and
-- holds TRIGGER on storage.objects.
--
-- Account deletion removes the object through the `delete-account` Edge
-- Function, not SQL: Supabase requires the Storage API for a real delete.
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 1. Who may write a profile picture.
-- ---------------------------------------------------------------------------

create or replace function public.can_write_profile_avatar()
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select public.has_sync_entitlement(auth.uid())
     and (
       public.current_firm_id() is null
       or public.is_firm_owner(public.current_firm_id())
     );
$$;

comment on function public.can_write_profile_avatar() is
  'True for a premium individual or a premium chamber owner: the profile-picture upload/update gate (used by the storage policies in supabase/manual/storage_policies.sql).';

revoke all on function public.can_write_profile_avatar() from public, anon;
grant execute on function public.can_write_profile_avatar() to authenticated;

-- ---------------------------------------------------------------------------
-- 2. The bucket.
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'individual-avatars',
  'individual-avatars',
  false,
  51200,
  array['image/jpeg']
)
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- ---------------------------------------------------------------------------
-- 3. The server-managed cache fields. `profiles` is pull-only and the client
--    may UPDATE only its display fields, so both columns are unwritable from a
--    device by construction.
-- ---------------------------------------------------------------------------

alter table public.profiles
  add column if not exists avatar_path text,
  add column if not exists avatar_version integer not null default 0;

comment on column public.profiles.avatar_path is
  'Object name of the profile picture in the individual-avatars bucket, or null. Written only by sync_profile_avatar_state().';
comment on column public.profiles.avatar_version is
  'Bumped on every picture write/delete so a device knows to download or clear its local copy. Written only by sync_profile_avatar_state().';

-- ---------------------------------------------------------------------------
-- 4. The trigger. `postgres` holds TRIGGER on storage.objects, so no
--    ownership switch is needed.
-- ---------------------------------------------------------------------------

create or replace function public.sync_profile_avatar_state()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if tg_op = 'DELETE' then
    update public.profiles
       set avatar_path = null,
           avatar_version = avatar_version + 1
     where id::text = split_part(old.name, '.', 1);
    return old;
  end if;

  update public.profiles
     set avatar_path = new.name,
         avatar_version = avatar_version + 1
   where id::text = split_part(new.name, '.', 1);
  return new;
end;
$$;

comment on function public.sync_profile_avatar_state() is
  'Keeps profiles.avatar_path/avatar_version in step with the individual-avatars bucket.';

revoke all on function public.sync_profile_avatar_state() from public, anon, authenticated;

drop trigger if exists trg_profile_avatar_write on storage.objects;
create trigger trg_profile_avatar_write
after insert or update on storage.objects
for each row
when (new.bucket_id = 'individual-avatars')
execute function public.sync_profile_avatar_state();

drop trigger if exists trg_profile_avatar_delete on storage.objects;
create trigger trg_profile_avatar_delete
after delete on storage.objects
for each row
when (old.bucket_id = 'individual-avatars')
execute function public.sync_profile_avatar_state();
