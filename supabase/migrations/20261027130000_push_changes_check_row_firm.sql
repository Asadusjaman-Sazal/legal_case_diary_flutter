-- The permission verdict is weighed on the row as it exists.
--
-- `push_changes_core` subtracts the scope columns from the row it is about to
-- write (§3.3's "an existing row keeps the firm it has"), and handed that same
-- stripped row to `sync_can_write`. Every rule that needs the firm was therefore
-- weighed against a row with no firm: `can_edit_firm(null)` is false, and the
-- authorship clause decided alone — so **a chamber member could not edit a case,
-- note or reference a colleague had authored, including the firm's owner**,
-- while `enforce_member_permission()` allows exactly that, because it reads
-- `new.firm_id` from the stored row. The delete-request rules were the same
-- defect in the other branch (`20261027100000`).
--
-- The fix is that one row: the check is handed the row as it exists, which means
-- the firm the write deliberately omits. The write itself still omits `firm_id`,
-- so no payload can move an existing row between scopes; the tombstone and
-- `can_delete` rules can now weigh the firm too, which is what
-- `enforce_delete_transition()` enforces at the trigger and what this function's
-- own comment claims. This is the newest shipped body (`20261015110000`) with no
-- other change.
--
-- Proven by `supabase/tests/push_changes_smoke_test.sql` (the colleague-edit and
-- removed-member sections pin both directions) and by
-- `supabase/tests/delete_request_review_test.sql`.

create or replace function public.push_changes_core(rows jsonb)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_actor uuid := auth.uid();
  -- Read once: every insert in this batch is scoped to the caller's own firm,
  -- and a profile change mid-batch must not be able to split the batch's scope.
  v_firm_id uuid := public.current_firm_id();
  v_entitled boolean;
  v_n integer;
  v_results jsonb[];
  v_order integer[];
  v_idx integer;
  v_row jsonb;
  v_mutation_id text;
  v_entity_type text;
  v_entity_id text;
  v_operation text;
  v_table text;
  v_payload jsonb;
  v_base_version integer;
  v_existing jsonb;
  v_final jsonb;
  v_new_row jsonb;
  v_old_version integer;
  v_ms bigint;
  v_hash text;
  v_receipt public.mutation_receipts%rowtype;
  v_status text;
  v_error_code text;
  v_message text;
  v_result jsonb;
  v_cols text;
  v_vals text;
  v_bad integer;
  v_has_created_at boolean;
  v_prov jsonb;
  v_hist jsonb;
  v_hist_row jsonb;
  v_child jsonb;
  v_children jsonb;
  v_state text;
  v_msg text;
  -- Delete-review accumulators (Task 20 Phase 4).
  v_target jsonb;
  v_target_type text;
  v_target_table text;
  v_expected integer;
  v_req_status text;
begin
  if v_actor is null then
    raise exception 'unauthenticated' using errcode = '42501';
  end if;

  -- Batch invariant: the Flutter client always sends one JSON array.
  if rows is null or jsonb_typeof(rows) <> 'array' then
    raise exception 'push_changes: rows must be a JSON array'
      using errcode = '22023';
  end if;

  v_n := jsonb_array_length(rows);
  if v_n = 0 then
    return jsonb_build_object('results', '[]'::jsonb);
  end if;

  v_entitled := public.has_sync_entitlement(v_actor);
  v_ms := (extract(epoch from clock_timestamp()) * 1000)::bigint;

  -- One slot per submitted row, so the response is exactly one result per
  -- mutation_id in input order even though processing follows dependency order.
  v_results := array_fill(null::jsonb, array[v_n]);

  select array_agg(i order by r, i)
    into v_order
    from (
      select i,
             public.sync_dependency_rank(
               coalesce(rows -> (i - 1) ->> 'entity_type', '')
             ) as r
        from generate_series(1, v_n) as i
    ) s;

  foreach v_idx in array v_order loop
    v_row := rows -> (v_idx - 1);

    -- Reset every per-mutation accumulator so nothing from the previous
    -- iteration can leak into this one's result.
    v_status := null;
    v_error_code := null;
    v_message := null;
    v_existing := null;
    v_final := null;
    v_new_row := null;
    v_children := null;
    v_hist_row := null;
    v_target := null;
    v_target_type := null;
    v_target_table := null;
    v_expected := null;
    v_req_status := null;

    v_mutation_id := nullif(v_row ->> 'mutation_id', '');
    v_entity_type := nullif(v_row ->> 'entity_type', '');
    v_entity_id := nullif(v_row ->> 'entity_id', '');
    v_operation := nullif(v_row ->> 'operation', '');

    if v_mutation_id is null or v_entity_type is null
       or v_entity_id is null or v_operation is null then
      raise exception
        'push_changes: every row needs mutation_id, entity_type, entity_id and operation'
        using errcode = '22023';
    end if;

    v_table := public.sync_entity_table(v_entity_type);
    v_hash := public.sha256_hex(v_row::text);

    -- Idempotency: a known mutation_id with the same canonical hash returns the
    -- original result and applies nothing; a different hash is refused.
    select * into v_receipt
      from public.mutation_receipts r
     where r.mutation_id = v_mutation_id;
    if found then
      if v_receipt.request_hash = v_hash then
        v_results[v_idx] := v_receipt.result_payload;
      else
        v_results[v_idx] := jsonb_build_object(
          'mutation_id', v_mutation_id,
          'entity_type', v_entity_type,
          'entity_id', v_entity_id,
          'operation', v_operation,
          'status', 'rejected',
          'error_code', 'mutation_id_reused',
          'message', 'This mutation id was already used with a different payload.'
        );
      end if;
      continue;
    end if;

    -- The implicit savepoint for this logical mutation: a permanent failure
    -- rolls back only this block, while a receipt (written after the block) and
    -- every other mutation survive.
    begin
      if not v_entitled then
        v_status := 'rejected';
        v_error_code := 'entitlement_required';
        v_message := 'Online sync requires an active subscription.';
      elsif v_table is null then
        v_status := 'rejected';
        v_error_code := 'unknown_entity';
        v_message := format('Unknown entity type %s.', v_entity_type);
      else
        -- The scope columns are never taken from a payload (§3.3): `scope_owner_id`
        -- belongs to the dissolve, and `firm_id` is derived below on insert and
        -- preserved on an existing row. Stripping here is what makes both true
        -- for every path at once — insert, update, delete and the delete-review
        -- branch all read this one variable.
        v_payload := coalesce(v_row -> 'payload', '{}'::jsonb)
          - 'scope_owner_id' - 'firm_id';

        -- A payload key that is not a real column is a client validation error,
        -- never a silent no-op.
        select count(*) into v_bad
          from jsonb_object_keys(v_payload) k
         where not exists (
           select 1
             from pg_catalog.pg_attribute a
             join pg_catalog.pg_class c on c.oid = a.attrelid
             join pg_catalog.pg_namespace n on n.oid = c.relnamespace
            where n.nspname = 'public'
              and c.relname = v_table
              and a.attname = k
              and a.attnum > 0
              and a.attisdropped = false
         );
        if v_bad > 0 then
          raise exception 'unknown_column'
            using errcode = '42703',
                  hint = 'The payload names a column that does not exist on the server table.';
        end if;

        v_base_version := nullif(v_row ->> 'base_version', '')::int;

        if v_operation = 'insert' then
          -- Inserts require no existing row.
          execute format(
            'select to_jsonb(t) from public.%I t where t.id = $1',
            v_table
          ) into v_existing using v_entity_id;

          if v_existing is not null then
            v_status := 'conflict';
            v_error_code := 'version_conflict';
            v_message := 'A row with this id already exists.';
            v_new_row := v_existing;
          else
            -- Server-owned columns are never taken from the client; the
            -- server_updated_at trigger stamps its own column.
            v_final := v_payload
              - 'server_updated_at' - 'version' - 'last_modified_by';
            if v_table = 'conflict_log' then
              -- The server column is a timestamptz defaulted to server now();
              -- the client's epoch-ms value must not be cast into it.
              v_final := v_final - 'created_at';
            end if;
            v_final := v_final || jsonb_build_object(
              'version', 1,
              'last_modified_by', v_actor::text,
              -- §1: a chamber account holds chamber rows and nothing else, so a
              -- new row's firm is the caller's own — null for an individual, the
              -- chamber for a member. This is what makes firm mode work at all:
              -- the client's whole-row payload carries its local `firm_id`
              -- (null), and without this derivation a member's case landed as a
              -- personal row inside the chamber, invisible to everybody else.
              'firm_id', v_firm_id
            );
            -- Only a table whose `created_at` is an epoch-ms *integer* column may
            -- receive the fallback: the six reference tables have none, and
            -- `conflict_log.created_at` is a server-owned timestamptz that must
            -- take its own default rather than the client's milliseconds.
            select exists (
              select 1
                from pg_catalog.pg_attribute a
                join pg_catalog.pg_class c on c.oid = a.attrelid
                join pg_catalog.pg_namespace n on n.oid = c.relnamespace
               where n.nspname = 'public'
                 and c.relname = v_table
                 and a.attname = 'created_at'
                 and a.attnum > 0
                 and a.atttypid in ('int8'::regtype, 'int4'::regtype)
            ) into v_has_created_at;
            if v_has_created_at and v_final ->> 'created_at' is null then
              v_final := v_final || jsonb_build_object('created_at', v_ms);
            end if;
            if v_final ->> 'updated_at' is null then
              v_final := v_final || jsonb_build_object('updated_at', v_ms);
            end if;
            -- `insert ... select *` reads NULL for an absent key rather than
            -- the column default, so a soft-delete flag must be explicit.
            if v_final ->> 'is_deleted' is null then
              v_final := v_final || jsonb_build_object('is_deleted', false);
            end if;

            if not public.sync_can_write(v_table, v_final, 'insert') then
              v_status := 'rejected';
              v_error_code := 'permission_denied';
              v_message := 'The caller may not create this row.';
            else
              -- Only the columns the snapshot carries are named, so a column
              -- the payload omitted still gets its own default rather than
              -- NULL (jsonb_populate_record does not apply defaults).
              select string_agg(quote_ident(k), ', ' order by k),
                     string_agg('v.' || quote_ident(k), ', ' order by k)
                into v_cols, v_vals
                from jsonb_object_keys(v_final) k;

              execute format(
                'insert into public.%I (%s) select %s from '
                'jsonb_populate_record(null::public.%I, $1) v',
                v_table, v_cols, v_vals, v_table
              ) using v_final;
              execute format(
                'select to_jsonb(t) from public.%I t where t.id = $1',
                v_table
              ) into v_new_row using v_entity_id;
              v_status := 'accepted';
            end if;
          end if;
        else
          -- Lock the target row first, then decide.
          execute format(
            'select to_jsonb(t) from public.%I t where t.id = $1 for update',
            v_table
          ) into v_existing using v_entity_id;

          if v_existing is null then
            v_status := 'rejected';
            v_error_code := 'not_found';
            v_message := 'The row no longer exists on the server.';
          elsif (v_existing ->> 'is_deleted')::boolean = true
                and v_operation = 'update' then
            v_status := 'tombstone';
            v_error_code := 'tombstone';
            v_message := 'The row was deleted on the server.';
            v_new_row := v_existing;
          elsif (v_existing ->> 'is_deleted')::boolean = true
                and v_operation = 'delete' then
            v_status := 'already_resolved';
            v_error_code := 'already_resolved';
            v_message := 'The row was already deleted.';
            v_new_row := v_existing;

          -- -----------------------------------------------------------------
          -- Delete-review approval (Task 20 Phase 4). The request row is the
          -- one locked above; the target is locked next.
          -- -----------------------------------------------------------------
          elsif v_table = 'delete_requests'
                and (v_payload ->> 'status') = 'approved' then
            v_req_status := coalesce(v_existing ->> 'status', '');

            if v_req_status in ('approved', 'rejected') then
              -- Already decided: nothing to do, and no second tombstone.
              v_status := 'already_resolved';
              v_error_code := 'already_resolved';
              v_message := 'This request was already reviewed.';
              v_new_row := v_existing;
            elsif not public.can_delete_firm(
                    nullif(v_existing ->> 'firm_id', '')::uuid) then
              -- The requester cannot approve their own request: only a member
              -- with delete permission may review one.
              v_status := 'rejected';
              v_error_code := 'permission_denied';
              v_message :=
                'Only a member with delete permission may review this request.';
            elsif v_base_version is null
                  or v_base_version <> (v_existing ->> 'version')::int then
              v_status := 'conflict';
              v_error_code := 'version_conflict';
              v_message := 'The request changed since this decision was made.';
              v_new_row := v_existing;
            else
              v_target_type := nullif(v_existing ->> 'entity_type', '');
              v_target_table := public.sync_entity_table(v_target_type);
              v_expected := nullif(v_existing ->> 'target_base_version', '')::int;

              if v_target_table is null or v_target_table not in (
                'cases', 'case_history', 'notes', 'case_references'
              ) then
                v_status := 'rejected';
                v_error_code := 'unsupported_target';
                v_message :=
                  'This request names a record that cannot be deleted here.';
              else
                execute format(
                  'select to_jsonb(t) from public.%I t where t.id = $1 for update',
                  v_target_table
                ) into v_target using (v_existing ->> 'entity_id');

                if v_target is null
                   or coalesce((v_target ->> 'is_deleted')::boolean, false) then
                  -- Nothing left to approve. The request is untouched audit
                  -- history; the tombstone rides back for the reviewer.
                  v_status := 'already_resolved';
                  v_error_code := 'already_resolved';
                  v_message := 'The record was already deleted.';
                  v_new_row := v_existing;
                elsif coalesce(v_target ->> 'firm_id', '')
                      is distinct from coalesce(v_existing ->> 'firm_id', '') then
                  v_status := 'rejected';
                  v_error_code := 'permission_denied';
                  v_message := 'The record is not in this request''s firm.';
                elsif v_expected is null
                      or v_expected <> (v_target ->> 'version')::int then
                  -- The record moved under the request: park the request as
                  -- stale and adopt the version the reviewer just saw, so a
                  -- reconfirm re-decides against the row that exists now.
                  v_final := (v_existing || jsonb_build_object(
                      'status', 'stale_review_required',
                      'target_base_version', (v_target ->> 'version')::int,
                      'updated_at', v_ms,
                      'version', (v_existing ->> 'version')::int + 1,
                      'last_modified_by', v_actor::text
                    )) - 'server_updated_at';

                  if not public.sync_can_write(v_table, v_final, 'update') then
                    v_status := 'rejected';
                    v_error_code := 'permission_denied';
                    v_message := 'The caller may not write this row.';
                  else
                    select string_agg(quote_ident(k), ', ' order by k),
                           string_agg('v.' || quote_ident(k), ', ' order by k)
                      into v_cols, v_vals
                      from jsonb_object_keys(v_final) k
                     where k <> 'server_updated_at';

                    execute format(
                      'update public.%I t set (%s) = (%s) '
                      'from jsonb_populate_record(null::public.%I, $1) v '
                      'where t.id = $2',
                      v_table, v_cols, v_vals, v_table
                    ) using v_final, v_entity_id;

                    execute format(
                      'select to_jsonb(t) from public.%I t where t.id = $1',
                      v_table
                    ) into v_new_row using v_entity_id;
                    v_status := 'target_conflict';
                    v_error_code := 'target_conflict';
                    v_message :=
                      'The record changed since this request was made.';
                  end if;
                else
                  -- Reconfirmed against the row that exists now: tombstone the
                  -- target in this same savepoint.
                  execute format(
                    'update public.%I t set is_deleted = true, '
                    '  version = coalesce(t.version, 1) + 1, '
                    '  last_modified_by = $1, updated_at = $2 '
                    'where t.id = $3 returning to_jsonb(t)',
                    v_target_table
                  ) using v_actor::text, v_ms, (v_existing ->> 'entity_id')
                  into v_target;

                  -- The same cascade an ordinary case delete performs, so an
                  -- approved request cannot leave live children behind. The
                  -- request stores the singular `entity_type` ('case'), so the
                  -- test is against the resolved *table* ('cases').
                  if v_target_table = 'cases' then
                    v_children := '[]'::jsonb;
                    for v_child in execute format(
                      'update public.case_history t '
                      'set is_deleted = true, '
                      '    version = coalesce(t.version, 1) + 1, '
                      '    last_modified_by = $1, '
                      '    updated_at = $2 '
                      'where t.case_id = $3 and t.is_deleted = false '
                      'returning to_jsonb(t)'
                    ) using v_actor::text, v_ms, (v_existing ->> 'entity_id')
                    loop
                      v_children := v_children || jsonb_build_array(v_child);
                    end loop;
                  end if;

                  -- Resolve the request beside the tombstone.
                  v_final := (v_existing || jsonb_build_object(
                      'status', 'approved',
                      'reviewed_by', v_actor::text,
                      'review_note', coalesce(
                        v_payload ->> 'review_note',
                        v_existing ->> 'review_note'),
                      'updated_at', v_ms,
                      'version', (v_existing ->> 'version')::int + 1,
                      'last_modified_by', v_actor::text
                    )) - 'server_updated_at';

                  if not public.sync_can_write(v_table, v_final, 'update') then
                    v_status := 'rejected';
                    v_error_code := 'permission_denied';
                    v_message := 'The caller may not write this row.';
                  else
                    select string_agg(quote_ident(k), ', ' order by k),
                           string_agg('v.' || quote_ident(k), ', ' order by k)
                      into v_cols, v_vals
                      from jsonb_object_keys(v_final) k
                     where k <> 'server_updated_at';

                    execute format(
                      'update public.%I t set (%s) = (%s) '
                      'from jsonb_populate_record(null::public.%I, $1) v '
                      'where t.id = $2',
                      v_table, v_cols, v_vals, v_table
                    ) using v_final, v_entity_id;

                    execute format(
                      'select to_jsonb(t) from public.%I t where t.id = $1',
                      v_table
                    ) into v_new_row using v_entity_id;
                    v_status := 'accepted';
                  end if;
                end if;
              end if;
            end if;
          elsif v_base_version is null
                or v_base_version <> (v_existing ->> 'version')::int then
            v_status := 'conflict';
            v_error_code := 'version_conflict';
            v_message := 'The server version changed since this edit was made.';
            v_new_row := v_existing;
          else
            v_old_version := (v_existing ->> 'version')::int;
            -- `firm_id` is subtracted as well: an existing row keeps the firm it
            -- has, whatever the payload named, so no update can move a case out
            -- of the chamber it belongs to (§3.3).
            v_final := (v_existing || v_payload)
              - 'server_updated_at' - 'version' - 'last_modified_by' - 'firm_id';
            if v_table = 'conflict_log' then
              v_final := v_final - 'created_at';
            end if;
            v_final := v_final || jsonb_build_object(
              'version', v_old_version + 1,
              'last_modified_by', v_actor::text
            );
            if v_operation = 'delete' then
              v_final := v_final || jsonb_build_object('is_deleted', true);
            end if;
            if v_final ->> 'updated_at' is null then
              v_final := v_final || jsonb_build_object('updated_at', v_ms);
            end if;

            -- The verdict is weighed on the row as it exists: `v_final`
            -- has had its firm subtracted for the write below, and a rule
            -- that cannot see the firm cannot weigh `can_edit` — this is
            -- the same row `enforce_member_permission()` sees. A null firm
            -- here is an individual's own row, exactly as before.
            if not public.sync_can_write(
                 v_table,
                 v_final || jsonb_build_object('firm_id', v_existing -> 'firm_id'),
                 v_operation
               ) then
              v_status := 'rejected';
              v_error_code := 'permission_denied';
              v_message := 'The caller may not write this row.';
            else
              -- Update every column the final snapshot carries, except
              -- server_updated_at, which the trigger owns.
              -- Both lists are ordered by the same key, so the columns and
              -- their values can never fall out of step.
              select string_agg(quote_ident(k), ', ' order by k),
                     string_agg('v.' || quote_ident(k), ', ' order by k)
                into v_cols, v_vals
                from jsonb_object_keys(v_final) k
               where k <> 'server_updated_at';

              execute format(
                'update public.%I t set (%s) = (%s) '
                'from jsonb_populate_record(null::public.%I, $1) v '
                'where t.id = $2',
                v_table, v_cols, v_vals, v_table
              ) using v_final, v_entity_id;

              execute format(
                'select to_jsonb(t) from public.%I t where t.id = $1',
                v_table
              ) into v_new_row using v_entity_id;
              v_status := 'accepted';
            end if;
          end if;
        end if;

        -- Atomic history and cascade soft-delete, only on an accepted case
        -- mutation. A delete-request approval whose target is a case performs
        -- its own cascade inside the branch above, so this stays case-only.
        if v_status = 'accepted' and v_table = 'cases' then
          if v_operation = 'delete' then
            -- One accepted case delete soft-deletes its children in this same
            -- savepoint; the changed children ride back to the caller.
            v_children := '[]'::jsonb;
            for v_child in execute format(
              'update public.case_history t '
              'set is_deleted = true, '
              '    version = coalesce(t.version, 1) + 1, '
              '    last_modified_by = $1, '
              '    updated_at = $2 '
              'where t.case_id = $3 and t.is_deleted = false '
              'returning to_jsonb(t)'
            ) using v_actor::text, v_ms, v_entity_id
            loop
              v_children := v_children || jsonb_build_array(v_child);
            end loop;
          elsif v_operation = 'update'
                and (v_final ->> 'next_date') is distinct from
                    (v_existing ->> 'next_date') then
            -- The client's provisional preview supplies its identity so the
            -- authoritative event replaces it one-for-one.
            v_prov := v_row -> 'provisional_history';
            if v_prov is null or jsonb_typeof(v_prov) <> 'object' then
              v_prov := '{}'::jsonb;
            end if;

            v_hist := v_prov || jsonb_build_object(
              'id', coalesce(v_prov ->> 'id', gen_random_uuid()::text),
              'case_id', v_entity_id,
              'user_id', v_new_row -> 'user_id',
              'firm_id', v_new_row -> 'firm_id',
              'source_mutation_id',
                coalesce(v_prov ->> 'source_mutation_id', v_mutation_id),
              'created_by', v_actor,
              'base_case_version',
                coalesce(nullif(v_prov ->> 'base_case_version', '')::int,
                         v_old_version),
              'result_case_version', (v_new_row ->> 'version')::int,
              'version', 1,
              'last_modified_by', v_actor::text,
              'is_deleted', false,
              'updated_at', v_ms
            );
            -- Nothing the client omitted is invented: the previous values come
            -- from the authoritative base row.
            if v_hist ->> 'hearing_date' is null then
              v_hist := v_hist || jsonb_build_object(
                'hearing_date',
                coalesce(nullif(v_existing ->> 'next_date', '')::bigint, v_ms)
              );
            end if;
            if v_hist ->> 'last_step' is null then
              v_hist := v_hist || jsonb_build_object(
                'last_step', v_existing -> 'last_step'
              );
            end if;
            if v_hist ->> 'note_result' is null then
              v_hist := v_hist || jsonb_build_object(
                'note_result', v_existing -> 'notes_results'
              );
            end if;
            if v_hist ->> 'result' is null then
              v_hist := v_hist || jsonb_build_object(
                'result', v_existing -> 'result'
              );
            end if;

            execute format(
              'insert into public.case_history select * from '
              'jsonb_populate_record(null::public.case_history, $1)'
            ) using v_hist;

            -- Hand the authoritative row back so the client can reconcile its
            -- provisional preview (same id) in one write.
            execute format(
              'select to_jsonb(t) from public.case_history t where t.id = $1'
            ) into v_hist_row using v_hist ->> 'id';
          end if;
        end if;
      end if;

      -- Terminal result for this mutation.
      if v_status = 'accepted' then
        v_result := jsonb_build_object(
          'mutation_id', v_mutation_id,
          'entity_type', v_entity_type,
          'entity_id', v_entity_id,
          'operation', v_operation,
          'status', 'accepted',
          'version', (v_new_row ->> 'version')::int,
          'row', v_new_row,
          'children', coalesce(v_children, '[]'::jsonb),
          'history', v_hist_row,
          -- A delete-request approval carries the target it tombstoned, so the
          -- reviewer's client can apply the record's disappearance in one pass.
          'target', v_target,
          'target_entity_type', v_target_type
        );
      elsif v_status = 'target_conflict' then
        -- The request was parked as stale_review_required; hand back both rows
        -- so the reviewer can inspect the record that exists now.
        v_result := jsonb_build_object(
          'mutation_id', v_mutation_id,
          'entity_type', v_entity_type,
          'entity_id', v_entity_id,
          'operation', v_operation,
          'status', 'target_conflict',
          'version', nullif(v_new_row ->> 'version', '')::int,
          'row', v_new_row,
          'target', v_target,
          'target_entity_type', v_target_type,
          'target_version', nullif(v_target ->> 'version', '')::int,
          'error_code', v_error_code,
          'message', v_message
        );
      elsif v_status in ('conflict', 'tombstone', 'already_resolved') then
        v_result := jsonb_build_object(
          'mutation_id', v_mutation_id,
          'entity_type', v_entity_type,
          'entity_id', v_entity_id,
          'operation', v_operation,
          'status', v_status,
          'version', nullif(v_new_row ->> 'version', '')::int,
          'row', v_new_row,
          'target', v_target,
          'target_entity_type', v_target_type,
          'error_code', v_error_code,
          'message', v_message
        );
      else
        v_result := jsonb_build_object(
          'mutation_id', v_mutation_id,
          'entity_type', v_entity_type,
          'entity_id', v_entity_id,
          'operation', v_operation,
          'status', 'rejected',
          'error_code', coalesce(v_error_code, 'validation_failed'),
          'message', coalesce(v_message, 'The mutation was refused.')
        );
      end if;
    exception
      when others then
        get stacked diagnostics
          v_state = returned_sqlstate,
          v_msg = message_text;
        -- A permanent, per-mutation failure is caught and reported; anything
        -- else is infrastructure and aborts the whole RPC.
        if v_state not in (
          '42501', 'P0001', '23502', '23503', '23505', '23514',
          '22P02', '22007', '22003', '42804', '42703'
        ) then
          raise;
        end if;
        v_result := jsonb_build_object(
          'mutation_id', v_mutation_id,
          'entity_type', v_entity_type,
          'entity_id', v_entity_id,
          'operation', v_operation,
          'status', 'rejected',
          'error_code', case v_state
            when '42501' then 'permission_denied'
            when 'P0001' then 'entitlement_required'
            else 'validation_failed'
          end,
          'message', v_msg
        );
    end;

    -- Receipt for every terminal result, in the same transaction. It is written
    -- after the savepoint block so a per-mutation rejection still records one.
    insert into public.mutation_receipts (
      mutation_id, actor_id, entity_type, entity_id, request_hash,
      terminal_status, result_payload
    ) values (
      v_mutation_id, v_actor, v_entity_type, v_entity_id, v_hash,
      v_result ->> 'status', v_result
    )
    on conflict (mutation_id) do nothing;

    v_results[v_idx] := v_result;
  end loop;

  return jsonb_build_object('results', (
    select coalesce(jsonb_agg(v_results[k] order by k), '[]'::jsonb)
      from generate_subscripts(v_results, 1) as k
  ));
end;
$$;

comment on function public.push_changes_core(jsonb) is
  'Single atomic push pipeline: optimistic concurrency, per-mutation savepoints, idempotent receipts, authoritative case history and cascade soft-deletes, and the delete-review approval branch (locking, target_conflict/stale_review_required, already_resolved, atomic tombstone). The scope columns belong to the server: an insert takes its firm_id from current_firm_id(), an existing row keeps the firm it has, and scope_owner_id is never taken from a payload. The permission check beside each write is handed the row as it exists — including the firm the write itself omits — so can_edit and can_delete are weighed against the chamber the row is actually in.';

comment on function public.sync_can_write(text, jsonb, text) is
  'Explicit write re-check for push_changes: same rules as the Phase 4 RLS policies, evaluated on the row that would be written, plus the Phase 5 can_add gate on a create. A firm comparison uses `is not distinct from`, because `=` against a NULL current_firm_id would yield NULL and slip past an `if not`. Authorship of a firm-scoped row is honoured only while the row''s firm is still the caller''s firm, so a removed member cannot merge a queued write. The verdict is weighed on the row as it exists — push_changes hands this function the stored firm for an update or a delete — because a rule that cannot see the firm cannot weigh can_edit or can_delete; and a delete_requests row resolves its firm from the stored request when the row names none, so the rule holds even for a caller that stripped it.';
