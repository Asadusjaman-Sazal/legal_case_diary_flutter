-- ---------------------------------------------------------------------------
-- The requester's name travels inside the request itself
-- ---------------------------------------------------------------------------
--
-- A delete request exists to protect a chamber's owner from a member deleting
-- the chamber's data, and a request nobody can put a face to does not protect
-- anyone. Until now the reviewer's screen had to look the name up out of the
-- `profiles` cache on their own device, which is a pull-only cache and holds the
-- reader's own row — so the line read *A Firm Member* exactly when it mattered
-- most.
--
-- The name therefore becomes part of the request row: one nullable column,
-- written once by the requester and carried to every reviewer's device by the
-- ordinary pull, so it is readable offline from the first review.
--
-- It is **server-derived, not client-trusted**: the trigger below fills it from
-- `public.profiles` for the row's own `requested_by`, whatever the client sent,
-- because a request that names somebody is an attribution inside an audit trail
-- and the app must not be the authority on a colleague's name. A client value is
-- kept only when the profile still holds no name (a brand-new account), which is
-- strictly better than a blank.
--
-- Firm-shared and display-only, so it rides the ordinary push/pull row: nothing
-- in `sync_can_write` or the `delete_requests` policies changes.

alter table public.delete_requests
  add column if not exists requester_name text;

comment on column public.delete_requests.requester_name is
  'Display name of requested_by as the server recorded it when the request was '
  'written; server-derived from profiles by trigger, snapshot of the name at '
  'write time.';

-- Backfill the requests already in the queue: the profile is the only source for
-- a row that predates the column, and a request whose requester has since been
-- hard-deleted keeps the blank it has rather than a made-up name.
update public.delete_requests r
   set requester_name = nullif(btrim(p.full_name), '')
  from public.profiles p
 where p.id = r.requested_by
   and coalesce(r.requester_name, '') = ''
   and nullif(btrim(p.full_name), '') is not null;

-- The value is the server's to decide, on both write paths: `push_changes` writes
-- the row directly and a SECURITY DEFINER function would otherwise be the only
-- writer of a column that is also granted to clients.
create or replace function public.delete_requests_set_requester_name()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_name text;
begin
  select nullif(btrim(p.full_name), '')
    into v_name
    from public.profiles p
   where p.id = new.requested_by;

  -- Definer rights, so this reads the profile regardless of the caller's own
  -- read scope. A missing or still-empty profile leaves whatever arrived in
  -- place, which is the requester's own best guess and never an invention.
  if v_name is not null then
    new.requester_name := v_name;
  end if;

  return new;
end;
$$;

-- Trigger functions can only run as triggers, and the EXECUTE is closed anyway so
-- no signed-in account can reach it through PostgREST's RPC surface.
revoke all on function public.delete_requests_set_requester_name()
  from public, anon, authenticated;

drop trigger if exists delete_requests_set_requester_name
  on public.delete_requests;

create trigger delete_requests_set_requester_name
  before insert or update on public.delete_requests
  for each row
  execute function public.delete_requests_set_requester_name();

-- Column-level parity with the rest of the row: `20261015100000` revoked the
-- table-level write grants and granted back the columns that existed then, so a
-- column added afterwards is writable by name only if it says so here.
grant insert (requester_name), update (requester_name)
  on public.delete_requests
  to authenticated;
