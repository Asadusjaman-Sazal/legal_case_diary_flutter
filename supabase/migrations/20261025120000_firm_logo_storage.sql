-- ===========================================================================
-- 2026-10-25 — The chamber logo: one private bucket, one small JPEG per firm.
--
-- Why. The side menu said "Legal Case Diary of <member>" with the member's own
-- picture, which credits the chamber's diary to whoever is signed in. A chamber
-- now shows its own logo and name, with the signed-in member and their role
-- underneath. The member's personal picture remains the fallback when the
-- chamber has not set a logo.
--
-- What this file creates, in order:
--
--   1. the **firm-avatars** bucket: private, 50 KB, JPEG only. It is one flat
--      folder; each chamber has exactly one object, `{firm_id}.jpg`.
--   2. two **server-managed columns** on public.firms, `logo_path` and
--      `logo_version`. They are deliberately not in any client UPDATE grant.
--   3. a **trigger** on storage.objects keeping those columns in step, so the
--      client learns that a logo changed without polling the bucket.
--
-- **The policies are manual, and why.** `storage.objects` is owned by
-- `supabase_storage_admin`; the migration role (`postgres`) is neither its
-- owner nor a member of that role, so `create policy` would fail here. The four
-- policies (member read; owner insert/update while the plan is live; owner
-- delete) live in `supabase/manual/storage_policies.sql`, are included in
-- `supabase/AllSupabaseSql.md` as a labelled manual section, and are applied
-- once through Supabase's Storage policy editor. The bucket, the columns and
-- the trigger below need no such step: `postgres` can insert the bucket and
-- holds TRIGGER on storage.objects.
-- ===========================================================================

-- ---------------------------------------------------------------------------
-- 1. Who may write a logo.
--
-- `has_sync_entitlement` had its EXECUTE revoked from every client role (it is
-- a server-side gate, used inside definer functions), so a storage policy
-- cannot call it directly. This helper runs as its definer and carries both
-- halves of the rule: the caller owns the chamber and the chamber's plan is
-- live. `current_firm_id()` and `is_firm_owner()` already resolve for
-- `authenticated` in the existing RLS policies.
-- ---------------------------------------------------------------------------

create or replace function public.can_write_firm_logo()
returns boolean
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select public.is_firm_owner(public.current_firm_id())
     and public.has_sync_entitlement(auth.uid());
$$;

comment on function public.can_write_firm_logo() is
  'True when the caller owns their chamber and the chamber''s plan is live: the firm-logo upload/update gate (used by the storage policies in supabase/manual/storage_policies.sql).';

revoke all on function public.can_write_firm_logo() from public, anon;
grant execute on function public.can_write_firm_logo() to authenticated;

-- ---------------------------------------------------------------------------
-- 2. The bucket.
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'firm-avatars',
  'firm-avatars',
  false,
  51200,
  array['image/jpeg']
)
on conflict (id) do update
  set public = excluded.public,
      file_size_limit = excluded.file_size_limit,
      allowed_mime_types = excluded.allowed_mime_types;

-- ---------------------------------------------------------------------------
-- 3. The server-managed cache fields.
--
-- `firms` is a pull-only cache and the client may UPDATE only its name, so
-- these two columns are unwritable from a device by construction. They are
-- what a member's next profile refresh reads to learn a logo exists and
-- changed.
-- ---------------------------------------------------------------------------

alter table public.firms
  add column if not exists logo_path text,
  add column if not exists logo_version integer not null default 0;

comment on column public.firms.logo_path is
  'Object name of the chamber logo in the firm-avatars bucket, or null. Written only by sync_firm_logo_state().';
comment on column public.firms.logo_version is
  'Bumped on every logo write/delete so a member device knows to download or clear the local copy. Written only by sync_firm_logo_state().';

-- ---------------------------------------------------------------------------
-- 4. The trigger.
--
-- Two triggers rather than one with a coalesce in its WHEN: an INSERT has no
-- OLD row and a DELETE has no NEW row, and each operation's own condition is
-- the clearer statement of what it acts on. `postgres` holds TRIGGER on
-- storage.objects, so no ownership switch is needed.
-- ---------------------------------------------------------------------------

create or replace function public.sync_firm_logo_state()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if tg_op = 'DELETE' then
    update public.firms
       set logo_path = null,
           logo_version = logo_version + 1
     where id::text = split_part(old.name, '.', 1);
    return old;
  end if;

  update public.firms
     set logo_path = new.name,
         logo_version = logo_version + 1
   where id::text = split_part(new.name, '.', 1);
  return new;
end;
$$;

comment on function public.sync_firm_logo_state() is
  'Keeps firms.logo_path/logo_version in step with the firm-avatars bucket.';

revoke all on function public.sync_firm_logo_state() from public, anon, authenticated;

drop trigger if exists trg_firm_logo_write on storage.objects;
create trigger trg_firm_logo_write
after insert or update on storage.objects
for each row
when (new.bucket_id = 'firm-avatars')
execute function public.sync_firm_logo_state();

drop trigger if exists trg_firm_logo_delete on storage.objects;
create trigger trg_firm_logo_delete
after delete on storage.objects
for each row
when (old.bucket_id = 'firm-avatars')
execute function public.sync_firm_logo_state();
