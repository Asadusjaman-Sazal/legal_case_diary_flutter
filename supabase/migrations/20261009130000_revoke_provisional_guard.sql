-- is_provisional_account() is internal: take back the EXECUTE that Supabase's
-- default privileges handed to `authenticated`.
--
-- Why this exists. The migration that added the Admin Panel's
-- Non-verified Accounts RPCs (`20261009120000`) intends the shared guard to be
-- reachable by **no client role** — only the two SECURITY DEFINER functions
-- above it call it, as the owner. It revoked `public` and `anon`, which is the
-- shape the rest of this project's functions use, and did not grant
-- `authenticated` any more than it granted `anon`.
--
-- That is not enough for a function that is *not* meant to be a client entry
-- point. Supabase's default privileges grant EXECUTE on a new function in
-- `public` **directly** to each client role — including `authenticated` — and a
-- direct grant outlives a revoke aimed at PUBLIC, the note the admin panel's own
-- migration carries. So `authenticated` kept a grant this function was never
-- supposed to have: any signed-in account could call
-- `is_provisional_account(<any uuid>)` and learn, one boolean at a time,
-- whether another account had done anything at all. SECURITY DEFINER means it
-- answers by reading tables that caller cannot read.
--
-- The exposure is a boolean about an account whose id the caller must already
-- know, not the data behind it, but the guard is internal by design and this
-- closes it. The server's own bypass role keeps its grant, as it does on every
-- function in this project, and is deliberately not named here — the ledger
-- test forbids that string in committed SQL.

revoke execute on function public.is_provisional_account(uuid)
  from authenticated;

-- Re-asserted so the file states the whole grant picture in one place: the two
-- admin entry points stay callable by a signed-in account (the function body
-- gates them), and the guard stays internal.
revoke all on function public.admin_list_unconfirmed_accounts()
  from public, anon;
grant execute on function public.admin_list_unconfirmed_accounts()
  to authenticated;

revoke all on function public.admin_delete_unconfirmed_account(uuid)
  from public, anon;
grant execute on function public.admin_delete_unconfirmed_account(uuid)
  to authenticated;
