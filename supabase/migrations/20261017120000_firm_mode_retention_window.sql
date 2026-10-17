-- Firm mode (12) — the retention window moves to 365, and the recovery window to 335.
--
-- §5.5's ruling, and the pair has to move together. A device that has been away
-- cannot tell a row it never saw from one deleted while it was gone, so it is
-- rebuilt rather than trusted once its own time away passes the recovery
-- threshold. That threshold only works while the server still remembers every
-- deletion the device might have missed, so the tombstone retention has to stay
-- **30 days above** the threshold, whatever the numbers are:
--
--   365 days of tombstones - 30 days of buffer = a 335-day recovery window.
--
-- `create or replace` is the whole change. The scheduled job calls
-- `purge_tombstones()` with no argument, so the number lives in this default and
-- nowhere else. The body — the cutoff, the children-first order, the
-- one-row-at-a-time delete and the skip that keeps a blocked tombstone from
-- failing the whole nightly run — is the shipped one verbatim; only the default
-- and the comments change, which is why the order assertions in
-- `test/supabase/schema_contract_test.dart` still describe this body.
--
-- The same ruling corrects `mutation_receipts`' documented retention. Its
-- invariant was "the maximum supported offline window plus a retry buffer",
-- written while that window was 150 days; at 335 it must read **at least 400
-- days** to stay true. No job purges receipts — they leave with the account — so
-- this is a corrected comment rather than a schedule, and it sits on the table
-- where a later cleanup job would meet it.
--
-- The other places the old number lived are corrected beside this file: the
-- original migration's header comment, `lib/sync/recovery_lock.dart`'s constant
-- and doc block, and the generated ledger's section label. A migration on its
-- own would leave the app and the ledger disagreeing, which is exactly what
-- `dart run tool/generate_all_supabase_sql.dart --check` catches.

create or replace function public.purge_tombstones(p_retention_days integer default 365)
returns integer
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_cutoff timestamptz;
  v_table text;
  v_id text;
  v_deleted integer;
  v_total integer := 0;
  v_skipped integer := 0;
  -- Children before parents: the FK graph is case data -> cases -> the
  -- reference tables that cases point at, with case_categories and
  -- court_categories last. Deleting in this order never trips a foreign key for
  -- a row that is itself purgeable, so the skip below is reserved for the rows
  -- a **live** or not-yet-purgeable dependent still names.
  v_order text[] := array[
    'case_history',
    'delete_requests',
    'conflict_log',
    'notes',
    'case_references',
    'cases',
    'case_types',
    'steps',
    'courts',
    'case_categories',
    'on_behalfs',
    'court_categories'
  ];
begin
  -- server_updated_at is stamped by the delete transition itself, so it is the
  -- tombstone's age.
  v_cutoff := now() - make_interval(days => p_retention_days);

  foreach v_table in array v_order loop
    -- One candidate at a time. A row a dependent still names raises
    -- foreign_key_violation on its own DELETE, and this block skips that row
    -- alone: the shipped set-based statement let one such row abort every other
    -- tombstone's purge on the project.
    for v_id in execute format(
      'select id from public.%1$I where is_deleted = true '
      'and server_updated_at < $1',
      v_table
    ) using v_cutoff loop
      begin
        execute format('delete from public.%1$I where id = $1', v_table)
          using v_id;

        get diagnostics v_deleted = row_count;
        v_total := v_total + v_deleted;
      exception
        when foreign_key_violation then
          v_skipped := v_skipped + 1;
      end;
    end loop;
  end loop;

  -- Say so: the job runs daily from pg_cron, where a silent skip is invisible.
  if v_skipped > 0 then
    raise notice
      'purge_tombstones: % tombstone(s) kept; a dependent row still names them.',
      v_skipped;
  end if;

  return v_total;
end;
$$;

comment on function public.purge_tombstones(integer) is
  'Deletes soft-deleted rows older than the retention (365 days by default, 30 days above the 335-day device recovery window), children first, and skips (rather than fails on) any tombstone a dependent row still names — one blocked row used to abort the whole purge. Returns the number of rows actually deleted; the skipped ones are reported in a notice.';

comment on table public.mutation_receipts is
  'Server-internal. Retain at least 400 days — the 335-day maximum supported offline window plus a retry buffer, and inside the 365-day tombstone retention a device recovering from that window relies on — and never purge a receipt still referenced by case_history, conflict_log or an audit record. mutation_id mirrors the client-generated key so a retry returns the original result.';
