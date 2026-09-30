-- Task 18 Phase 3 — sync_server_time(): the server's own clock, for skew detection.
--
-- The plan's clock-skew rule compares the device's time against the server's on
-- every successful sync and, past ~2 minutes, records the offset and shows the
-- non-intrusive warning. The delta pull returns rows, not a clock, so this is the
-- one small read the client needs.
--
-- Table class: none — it reads no table, only `now()`. It is granted to
-- `authenticated` alone (Supabase's default privileges would otherwise hand it
-- to `anon` directly), and it is deliberately not SECURITY DEFINER because it
-- touches nothing that would need to bypass RLS.

create or replace function public.sync_server_time()
returns timestamptz
language sql
stable
set search_path = pg_catalog, public
as $$
  select now();
$$;

comment on function public.sync_server_time() is
  'The server clock, used by the client to detect and record device clock skew on a successful sync.';

revoke all on function public.sync_server_time() from public, anon;
grant execute on function public.sync_server_time() to authenticated;
