-- Firm mode (1) — the read side is scoped, and `scope_owner_id` is born.
--
-- The leak this closes. `cases_select_scoped` and its nine twins read
-- `user_id = auth.uid() or firm_id = current_firm_id()`, and a member's
-- `user_id` never changes. So a member removed from a chamber kept the read on
-- every row they ever authored in it: `20260930210000` and `20260930220000`
-- closed that hole for **writes** and left reads alone, believing a caller with
-- no firm reads nothing from a firm row — true of the `firm_id` half and false
-- of the `user_id` half standing beside it under `or`. The device wipes itself
-- on removal and its fresh local database starts at the initial cursor
-- sentinel, so the very next full pull (once that account is premium again, on
-- its own plan or in another chamber) pages the old chamber's rows back down.
--
-- The scoped rule, on the eleven ledger tables:
--
--   (user_id = auth.uid() and firm_id is null and scope_owner_id is null)
--     or firm_id = current_firm_id()
--     or scope_owner_id = auth.uid()
--
-- The first disjunct is the individual diary — mine only while it is nobody's
-- chamber's and no dissolve has claimed it. The second is the chamber's ledger,
-- readable only while that chamber is still the caller's. The third is the
-- dissolve's claim (§4.4): a dissolved chamber's rows lose `firm_id` and gain
-- the owner as their **scope owner**, so the owner keeps the ledger and its
-- authors do not get it back. `scope_owner_id` is a scope key, not attribution:
-- `user_id`, `created_by` and `last_modified_by` are never rewritten.
--
-- Two tables are deliberately narrower. `delete_requests` has no `user_id`, so
-- the first disjunct is copied with `requested_by`; without a scope clause a
-- dissolved chamber's request history would be readable by nobody, the member
-- who raised it included. `conflict_log` is not a ledger table — its rows are a
-- device's own merge diagnostics — so it takes the membership condition only
-- and **no** scope owner.
--
-- The column is server-owned from the moment it exists, or this migration would
-- create the hole it closes: an author who set `scope_owner_id` to themselves on
-- their own firm row would keep the read after leaving. Supabase grants
-- table-level INSERT/UPDATE, and a table-level GRANT is not undone by a
-- column-level REVOKE (proved by `20260929102500`), so the table-level grant is
-- dropped and every column except this one is granted back. The SECURITY DEFINER
-- RPCs are unaffected — the dissolve writes it — while a direct PostgREST write
-- cannot name it. `push_changes` bypasses privileges, so it names the column in
-- its strip list in the next migration.

-- ---------------------------------------------------------------------------
-- The column
-- ---------------------------------------------------------------------------

do $$
declare
  v_table text;
  -- The eleven ledger tables. `conflict_log` is not one of them.
  v_tables text[] := array[
    'cases', 'case_history', 'notes', 'case_references', 'delete_requests',
    'court_categories', 'case_categories', 'courts', 'steps', 'case_types',
    'on_behalfs'
  ];
begin
  foreach v_table in array v_tables loop
    execute format(
      'alter table public.%1$I add column if not exists scope_owner_id uuid',
      v_table
    );
    -- %L, not a hand-quoted literal: the comment text is data, and the first
    -- apply proved that nesting its own quotes by hand breaks the statement.
    execute format(
      'comment on column public.%1$I.scope_owner_id is %2$L',
      v_table,
      'Scope key, not attribution: who owns this row once it has no firm. '
      'Null while the row belongs to a private diary or to a chamber; '
      'written only by the dissolve.'
    );
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- SELECT policies
-- ---------------------------------------------------------------------------

-- The four case-data tables: one shape, one loop, so their spellings cannot
-- drift.
do $$
declare
  v_table text;
  v_tables text[] := array['cases', 'case_history', 'notes', 'case_references'];
begin
  foreach v_table in array v_tables loop
    execute format(
      'drop policy if exists %1$s_select_scoped on public.%1$I',
      v_table
    );
    execute format(
      'create policy %1$s_select_scoped on public.%1$I for select to '
      'authenticated using ((user_id = auth.uid() and firm_id is null and '
      'scope_owner_id is null) or firm_id = public.current_firm_id() or '
      'scope_owner_id = auth.uid())',
      v_table
    );
  end loop;
end;
$$;

-- The six reference tables keep the built-in baseline readable to every
-- install; only a *custom* row is scoped.
do $$
declare
  v_table text;
  v_tables text[] := array[
    'court_categories', 'case_categories', 'courts', 'steps', 'case_types',
    'on_behalfs'
  ];
begin
  foreach v_table in array v_tables loop
    execute format(
      'drop policy if exists %1$s_select_scoped on public.%1$I',
      v_table
    );
    execute format(
      'create policy %1$s_select_scoped on public.%1$I for select to '
      'authenticated using (is_custom = false or (user_id = auth.uid() and '
      'firm_id is null and scope_owner_id is null) or firm_id = '
      'public.current_firm_id() or scope_owner_id = auth.uid())',
      v_table
    );
  end loop;
end;
$$;

-- delete_requests: the author column is `requested_by`. The policy is renamed
-- with its new rule, because "select_firm" no longer describes it.
drop policy if exists delete_requests_select_firm on public.delete_requests;
drop policy if exists delete_requests_select_scoped on public.delete_requests;
create policy delete_requests_select_scoped on public.delete_requests
  for select to authenticated
  using (
    (requested_by = auth.uid() and firm_id is null and scope_owner_id is null)
    or firm_id = public.current_firm_id()
    or scope_owner_id = auth.uid()
  );

-- conflict_log: membership condition only, no scope owner. A removed member
-- keeps their own firm-less merge diagnostics and loses the chamber's.
drop policy if exists conflict_log_select_own on public.conflict_log;
create policy conflict_log_select_own on public.conflict_log
  for select to authenticated
  using (
    user_id = auth.uid()
    and (
      firm_id is null
      or firm_id is not distinct from public.current_firm_id()
    )
  );

-- ---------------------------------------------------------------------------
-- The column is server-only
-- ---------------------------------------------------------------------------

do $$
declare
  v_table text;
  v_insert_columns text;
  v_update_columns text;
  v_tables text[] := array[
    'cases', 'case_history', 'notes', 'case_references', 'delete_requests',
    'court_categories', 'case_categories', 'courts', 'steps', 'case_types',
    'on_behalfs'
  ];
begin
  foreach v_table in array v_tables loop
    -- A generated column cannot be named in a write grant, and an
    -- `always as identity` column cannot be inserted; neither exists here
    -- today, and both are excluded so a later one cannot break the apply.
    select string_agg(quote_ident(a.attname), ', ' order by a.attnum)
      into v_insert_columns
      from pg_attribute a
     where a.attrelid = format('public.%I', v_table)::regclass
       and a.attnum > 0
       and not a.attisdropped
       and a.attgenerated = ''
       and a.attidentity <> 'a'
       and a.attname <> 'scope_owner_id';

    select string_agg(quote_ident(a.attname), ', ' order by a.attnum)
      into v_update_columns
      from pg_attribute a
     where a.attrelid = format('public.%I', v_table)::regclass
       and a.attnum > 0
       and not a.attisdropped
       and a.attgenerated = ''
       and a.attname <> 'scope_owner_id';

    execute format(
      'revoke insert, update on public.%I from authenticated, anon',
      v_table
    );
    execute format(
      'grant insert (%s) on public.%I to authenticated',
      v_insert_columns, v_table
    );
    execute format(
      'grant update (%s) on public.%I to authenticated',
      v_update_columns, v_table
    );
  end loop;
end;
$$;
