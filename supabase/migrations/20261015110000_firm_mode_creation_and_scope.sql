-- Firm mode Phase 2 — chamber creation shares the owner's diary, and the scope
-- columns become the server's.
--
-- Two halves of one ruling (docs/firm_mode_blueprint.md §1 and §3.3):
--
--   * **Creation shares.** A lawyer creates a chamber in order to collaborate, so
--     the moment the firm exists the cases, notes, case references, customised
--     reference rows and pending delete requests they already hold **become the
--     chamber's** — stamped with the new `firm_id` exactly as every row written
--     afterwards is. `ensure_firm` therefore stamps them in the same transaction
--     that creates the firm. There is no sharing question and no opt-out; the
--     earlier draft's *"Share your N existing cases?"* prompt is withdrawn.
--     **Tombstones are stamped too** (a deleted row still names the chamber, and
--     a device that never received the deletion must keep receiving it), and so
--     are rows a *dissolve* handed back with a scope owner: they are the owner's
--     ordinary diary now, so a new chamber shares them like any other case.
--     `version` is bumped and `updated_at` refreshed beside it, which is what
--     makes every device converge: the delta pull cursor is `server_updated_at`
--     (stamped by `trg_<table>_server_updated_at`), and a bumped `version` turns
--     the device's own queued edits into ordinary version conflicts instead of
--     silently reverting the chamber's stamp.
--
--   * **The write path carries that scope.** `push_changes` is SECURITY DEFINER,
--     so it bypasses the column privileges that guard direct PostgREST writes,
--     and it stripped only `server_updated_at`, `version` and `last_modified_by`
--     from a payload — which meant **any column added later was client-writable
--     through the RPC**. Two consequences were live:
--
--       1. a member's insert arrived with `firm_id` null (the client's whole-row
--          payload carries its local value, and every repository writes
--          `firmId: null`), so `sync_can_write` let it through and the case
--          landed as a *personal* row inside a chamber — readable by its author
--          alone once Phase 1's read scoping shipped. Firm mode was inert;
--       2. an accepted update could null a row's `firm_id`, removing the case
--          from the chamber's ledger and carrying it into the author's next
--          chamber as their own diary, or set `scope_owner_id` to its author.
--
--     The rule is now the same one the plan states: **`firm_id` is derived from
--     the caller's own firm when the row is created and is never read from a
--     payload, no payload may change it on an existing row, and a caller who
--     holds a firm can never create a firm-less row**; `scope_owner_id` is
--     written by the dissolve (§4.4) and by nothing else.
--
-- Deliberate as-built detail (the shipped client sends the *whole local row* as
-- its payload): the scope columns are **stripped and derived, not rejected**.
-- The client's payload carries `firm_id: null` on every individual write and can
-- carry a stale firm id between a write and the pull that would correct it, so
-- refusing a payload that *names* the column would refuse legitimate writes —
-- and it would buy nothing, because a column the UPDATE never names cannot
-- change. An insert's `firm_id` is the caller's own (null for an individual) and
-- an existing row keeps the firm it has, whatever the payload says.
--
-- Nothing else in either function changes; each is replaced whole because that
-- is the only write path a plpgsql body has.

-- ---------------------------------------------------------------------------
-- ensure_firm — the creation moment stamps the caller's firm-less diary
-- ---------------------------------------------------------------------------

create or replace function public.ensure_firm(p_name text)
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_user_id uuid := auth.uid();
  v_now bigint := (extract(epoch from clock_timestamp()) * 1000)::bigint;
  v_name text := pg_catalog.btrim(coalesce(p_name, ''));
  v_firm public.firms%rowtype;
  v_has_firm boolean;
  -- True only when this call created the firm: the stamping below is the
  -- creation's own act, and an idempotent re-call (a rename, a repair) must not
  -- re-stamp rows a member has since written.
  v_created boolean := false;
  v_table text;
  v_case_tables text[] := array[
    'cases', 'case_history', 'notes', 'case_references'
  ];
  v_reference_tables text[] := array[
    'court_categories', 'case_categories', 'courts', 'steps', 'case_types',
    'on_behalfs'
  ];
begin
  if v_user_id is null then
    return jsonb_build_object('status', 'unauthenticated');
  end if;

  select * into v_firm
    from public.firms f
   where f.owner_id = v_user_id
   order by f.created_at
   limit 1;
  -- Captured immediately: `FOUND` belongs to the most recent SQL statement, and
  -- the membership guard below runs one of its own.
  v_has_firm := found;

  -- Membership guard: refuse to become the owner of a new firm while the
  -- caller's profile points at a firm they do not own. Returned rather than
  -- raised so the answer is a value the client can report; nothing is written.
  if exists (
    select 1
      from public.profiles p
     where p.id = v_user_id
       and p.firm_id is not null
       and (not v_has_firm or p.firm_id is distinct from v_firm.id)
  ) then
    return jsonb_build_object('status', 'member_of_another_firm');
  end if;

  if not v_has_firm then
    -- The transition to firm mode is the premium-gated step (Phase 1 item 2).
    if not public.is_premium(v_user_id) then
      return jsonb_build_object('status', 'premium_required');
    end if;

    -- `created_at` is a server instant (`timestamptz`) and takes the column
    -- default: the bigint `v_now` below is epoch ms for the client-facing
    -- `firm_members` stamps only.
    insert into public.firms (
      name, owner_id, subscription_status, subscription_expiry
    )
    select
      v_name,
      v_user_id,
      p.subscription_status,
      p.subscription_expiry
      from public.profiles p
     where p.id = v_user_id
    returning * into v_firm;

    if not found then
      -- No profile row: the sign-up trigger creates one, so this is a bug state,
      -- never something to explain to a user. Raising here rolls the firm back.
      raise exception 'ensure_firm: no profiles row for the caller'
        using errcode = 'P0001';
    end if;

    v_created := true;
  elsif v_name is distinct from v_firm.name then
    update public.firms f
       set name = v_name
     where f.id = v_firm.id
    returning * into v_firm;
  end if;

  -- The conversion itself: firm scope for every policy, owner role for the app.
  update public.profiles p
     set firm_id = v_firm.id,
         role = 'owner'
   where p.id = v_user_id;

  -- The owner holds every permission explicitly, so `can_edit_firm` /
  -- `can_delete_firm` and the client's cached flags agree with the role.
  insert into public.firm_members (
    firm_id, user_id, role, can_add, can_edit, can_delete,
    synced_at, permissions_synced_at
  )
  values (
    v_firm.id, v_user_id, 'owner', true, true, true, v_now, v_now
  )
  on conflict (firm_id, user_id) do update
    set role = 'owner',
        can_add = true,
        can_edit = true,
        can_delete = true,
        synced_at = excluded.synced_at,
        permissions_synced_at = excluded.permissions_synced_at;

  -- Sharing the diary: every ledger row the owner authored while firm-less
  -- becomes the chamber's (§1). The four case-data tables first, then the six
  -- reference tables — custom rows only, because a built-in row (`is_custom =
  -- false`) has no author and is the globally shared baseline every install
  -- reads — and finally the owner's pending delete requests.
  if v_created then
    foreach v_table in array v_case_tables loop
      execute format(
        'update public.%I t '
        '   set firm_id = $1, '
        '       version = coalesce(t.version, 1) + 1, '
        '       updated_at = $3 '
        ' where t.user_id = $2 '
        '   and t.firm_id is null',
        v_table
      ) using v_firm.id, v_user_id, v_now;
    end loop;

    foreach v_table in array v_reference_tables loop
      execute format(
        'update public.%I t '
        '   set firm_id = $1, '
        '       version = coalesce(t.version, 1) + 1, '
        '       updated_at = $3 '
        ' where t.user_id = $2 '
        '   and t.firm_id is null '
        '   and t.is_custom = true',
        v_table
      ) using v_firm.id, v_user_id, v_now;
    end loop;

    -- A resolved request is audit history rather than a ledger row, so only a
    -- pending one follows the owner into his chamber.
    update public.delete_requests t
       set firm_id = v_firm.id,
           version = coalesce(t.version, 1) + 1,
           updated_at = v_now
     where t.requested_by = v_user_id
       and t.firm_id is null
       and t.status = 'pending';
  end if;

  return jsonb_build_object(
    'status', 'ready',
    'firm_id', v_firm.id,
    'name', v_firm.name
  );
end;
$$;

comment on function public.ensure_firm(text) is
  'Idempotent owner-side firm establishment: creates the caller''s firm (premium-gated at the creation moment), relinks profiles.firm_id/role, upserts the owner''s firm_members row, and shares the caller''s firm-less diary into the new firm (cases, case history, notes, case references, custom reference rows and pending delete requests — tombstones included — each with a version bump and a refreshed updated_at/server_updated_at so every device converges). Refuses a member of another firm. The invite generator (and therefore the app) has no other way to reach firm scope.';

revoke all on function public.ensure_firm(text) from public, anon;
grant execute on function public.ensure_firm(text) to authenticated;

-- ---------------------------------------------------------------------------
-- push_changes — the scope columns are the server's
-- ---------------------------------------------------------------------------

create or replace function public.push_changes(rows jsonb)
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

            if not public.sync_can_write(v_table, v_final, v_operation) then
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

comment on function public.push_changes(jsonb) is
  'Single atomic push pipeline: optimistic concurrency, per-mutation savepoints, idempotent receipts, authoritative case history and cascade soft-deletes, and the delete-review approval branch (locking, target_conflict/stale_review_required, already_resolved, atomic tombstone). The scope columns belong to the server: an insert takes its firm_id from current_firm_id(), an existing row keeps the firm it has, and scope_owner_id is never taken from a payload.';

-- Same surface as before: `anon` and `public` stay refused.
revoke all on function public.push_changes(jsonb) from public, anon;
grant execute on function public.push_changes(jsonb) to authenticated;
