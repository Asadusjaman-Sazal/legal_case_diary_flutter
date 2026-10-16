-- Firm mode Phase 6 — the in-use guard for reference rows.
--
-- §3.2 rules that a reference row a **live** case still names cannot be deleted,
-- and §10.6 that the nightly purge must not be the thing that discovers the
-- collision. Two halves, and nothing else:
--
--   1. `enforce_reference_not_in_use()` — a BEFORE UPDATE trigger function on the
--      reference tables that have dependents, refusing the tombstone transition
--      (`is_deleted false -> true`) while a live dependent row still names the
--      row. The dependency graph is **nine foreign keys over four parents**, all
--      declared in `20260929100000_phase1_core_schema.sql`, and it is not what an
--      older one-line summary implied:
--
--        court_categories  <- case_categories.court_category_id
--                          <- courts.court_category_id
--                          <- steps.court_category_id
--                          <- case_types.court_category_id
--                          <- on_behalfs.court_category_id
--        case_categories   <- case_types.case_category_id
--                          <- cases.case_category_id
--        courts            <- cases.court_id
--        on_behalfs        <- cases.on_behalf_id
--
--      `steps` and `case_types` are deliberately **not** attached: nothing
--      references either by id — `cases.case_type` and `cases.last_step` are free
--      text, not foreign keys — so no server guard can protect them and a trigger
--      that could never fire would be noise. The proof asserts that limit rather
--      than claiming a guard the server cannot have.
--
--      Only a **live** dependent blocks. A dependent that is itself a tombstone
--      does not hold its parent back, because it is on its way out — which is why
--      this check is not simply the foreign key, and why the purge half below
--      still has work to do when a dependent is too young to have been purged.
--
--      The function is SECURITY DEFINER with a pinned search_path, like
--      `enforce_delete_transition()` beside it, so the rule is about the **data**
--      and not about what the caller happens to be allowed to read: it must answer
--      the same way for a member, for the owner and for a maintenance script. It
--      is keyed on nothing else — no role, no `auth.uid()` — because the rule has
--      nothing to do with who is writing. `DELETE` never fires it, which is
--      exactly why a purge needs its own half.
--
--      The refusal is raised as errcode `23503` (foreign key violation) rather
--      than `42501`: it is a referential-integrity refusal, and `push_changes`
--      already catches `23503` per mutation, so a queued tombstone comes back as a
--      clean `rejected` / `validation_failed` result carrying this message
--      instead of aborting the batch.
--
--   2. `purge_tombstones()` skips a blocked row instead of failing whole. The
--      shipped body deleted each table's tombstones in one set-based statement,
--      so a single row a live dependent still named raised
--      `foreign_key_violation` and aborted the **entire** purge — every other
--      tombstone on the project stayed. It now walks one table's candidate rows
--      at a time and deletes them one by one inside an exception block that skips
--      only a foreign-key violation. The predicate is therefore the database's own
--      answer to "is this row still referenced?", so the purge cannot drift from
--      the real foreign keys. The deletion order, the retention argument, the
--      cutoff and the returned count are unchanged, and the kept rows are reported
--      in a notice so the daily `pg_cron` run is not silent.
--
-- Table class (rule 4): the guard and the purge touch the push/pull domain class
-- only, and the reference tables are its firm-shared half.

-- ---------------------------------------------------------------------------
-- 1. The in-use guard
-- ---------------------------------------------------------------------------

create or replace function public.enforce_reference_not_in_use()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  -- The child table and column of one of the nine foreign keys above, as a
  -- '<child table>.<child column>' pair.
  v_pair text;
  v_pairs text[];
  v_child_table text;
  v_child_column text;
  v_found integer;
begin
  -- Only the tombstone transition is guarded; every other update is somebody
  -- else's business (the permission boundary, the resurrection guard).
  if not (old.is_deleted = false and new.is_deleted = true) then
    return new;
  end if;

  -- Every parent's primary key is `id` and every one of the nine foreign keys
  -- targets it, so the value to match is the row's own id.
  v_pairs := case tg_table_name
    when 'court_categories' then array[
      'case_categories.court_category_id',
      'courts.court_category_id',
      'steps.court_category_id',
      'case_types.court_category_id',
      'on_behalfs.court_category_id'
    ]
    when 'case_categories' then array[
      'case_types.case_category_id',
      'cases.case_category_id'
    ]
    when 'courts' then array[
      'cases.court_id'
    ]
    when 'on_behalfs' then array[
      'cases.on_behalf_id'
    ]
    else array[]::text[]
  end;

  foreach v_pair in array v_pairs loop
    v_child_table := split_part(v_pair, '.', 1);
    v_child_column := split_part(v_pair, '.', 2);

    execute format(
      'select 1 from public.%I d where d.%I = $1 and d.is_deleted = false '
      'limit 1',
      v_child_table,
      v_child_column
    ) into v_found using new.id;

    if v_found is not null then
      raise exception 'reference_in_use'
        using errcode = '23503',
              hint = format(
                '%s still names this row, so it cannot be deleted yet.',
                v_child_table
              );
    end if;
  end loop;

  return new;
end;
$$;

comment on function public.enforce_reference_not_in_use() is
  'BEFORE UPDATE on the reference tables that have dependents: refuses the tombstone transition (is_deleted false -> true) while a live dependent row still names the row, raising reference_in_use as 23503 so push_changes rejects that one mutation rather than aborting the batch. SECURITY DEFINER, and unkeyed on role or auth.uid(), so the answer is the same for a member, the owner and a maintenance script. steps and case_types take no trigger: cases.case_type and cases.last_step are free text, so nothing references them. A dependent that is itself a tombstone does not block.';

-- ---------------------------------------------------------------------------
-- 2. Attach the trigger to the four parents that have dependents
-- ---------------------------------------------------------------------------
--
-- One loop over an explicit array, the shape Phase 3 and Phase 5 use. The
-- four names are the parents of the nine foreign keys listed above; the proof
-- enumerates the same four by name and asserts that the other two reference
-- tables carry no guard.

do $$
declare
  v_table text;
  v_tables text[] := array[
    'court_categories', 'case_categories', 'courts', 'on_behalfs'
  ];
begin
  foreach v_table in array v_tables loop
    execute format(
      'drop trigger if exists trg_%1$s_in_use_guard on public.%1$I',
      v_table
    );
    execute format(
      'create trigger trg_%1$s_in_use_guard before update on public.%1$I '
      'for each row execute function public.enforce_reference_not_in_use()',
      v_table
    );
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. purge_tombstones: skip a blocked row instead of failing as a whole
-- ---------------------------------------------------------------------------
--
-- Only this function's inner loop changes. The retention argument and its
-- default, the `now() - make_interval(...)` cutoff, the children-first order and
-- the returned count of deleted rows are the shipped ones verbatim, so the
-- scheduled call keeps its meaning and `schema_contract_test.dart`'s order
-- assertions still describe the body.

create or replace function public.purge_tombstones(p_retention_days integer default 180)
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
  'Deletes soft-deleted rows older than the retention (180 days by default), children first, and skips (rather than fails on) any tombstone a dependent row still names — one blocked row used to abort the whole purge. Returns the number of rows actually deleted; the skipped ones are reported in a notice.';
