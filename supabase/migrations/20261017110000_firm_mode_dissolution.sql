-- Firm mode (11) — dissolution: the chamber goes, the ledger stays.
--
-- §4.4's ruling, in one function. The owner empties the roster first, using the
-- one removal path there is (§4.1), so every leaving member's device wipes on
-- its own and nothing of the chamber is left on a phone nobody agreed to
-- abandon. Only then does he dissolve, and dissolving transfers the ledger to
-- him rather than deleting it:
--
--   * every row carrying the `firm_id` loses it and gains the owner as its
--     **scope owner**, so his next pull hands him a complete, ordinary diary;
--   * attribution is untouched — `user_id`, `created_by` and `last_modified_by`
--     still say who wrote each row, and `scope_owner_id` is a scope key, not an
--     attribution one;
--   * the `firms` row and its invites go, his account is individual again, and
--     `delete_my_account()` stops refusing him;
--   * his plan is untouched: dissolving is not a cancellation, and the
--     subscription now covers the individual diary.
--
-- Why the scope owner is not optional: with `firm_id` merely nulled, the read
-- policy's individual clause (`user_id = auth.uid()` on a firm-less row) hands
-- every member-authored row back to its author and hides it from the owner —
-- the audit's most serious finding, and the opposite of what a dissolve is for,
-- because under §3.2 the associates write most of a chamber's cases.
--
-- `conflict_log` is the one table that is **not** handed over. A colleague's
-- merge diagnostics are neither the owner's ledger nor its author's to lose, so
-- the dissolve only clears its `firm_id`: the author keeps reading their own
-- rows, the owner never sees them (§4.3). That clear is also load-bearing:
-- `conflict_log.firm_id` references `firms (id)` **without** a cascade, so
-- leaving it in place would make the `firms` delete fail outright.
--
-- Both refusals are decided before the first write, so a refusal changes
-- nothing at all — not even the invites — including the count it reports. The
-- function takes no arguments on purpose: the firm is resolved from the caller,
-- so it can never be aimed at a chamber that is not theirs, and a member gets
-- `not_owner` rather than an error because it is a state the screen can word.

create or replace function public.dissolve_firm()
returns jsonb
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_actor uuid := auth.uid();
  v_firm_id uuid;
  v_members integer;
  v_table text;
  -- The eleven ledger tables — the ones that carry `scope_owner_id`. Read as
  -- §4.4's list: case data, the deletion queue and the editable reference
  -- rows. `conflict_log` is deliberately absent (see above).
  c_ledger constant text[] := array[
    'cases', 'case_history', 'notes', 'case_references', 'delete_requests',
    'court_categories', 'case_categories', 'courts', 'steps', 'case_types',
    'on_behalfs'
  ];
begin
  if v_actor is null then
    raise exception 'unauthenticated' using errcode = '42501';
  end if;

  -- The caller's own firm, and only if they own it. Locked, so a dissolve
  -- cannot race a removal into a half-empty roster: the count below is read
  -- under the same lock that the deletion later relies on.
  select f.id into v_firm_id
    from public.firms f
   where f.owner_id = v_actor
   order by f.created_at
   limit 1
   for update;

  if v_firm_id is null then
    return jsonb_build_object('status', 'not_owner');
  end if;

  -- The precondition, counted before the first write: every seat but the
  -- owner's own must be empty. The refusal carries the number so the screen can
  -- say what is left rather than only "no".
  select count(*) into v_members
    from public.firm_members m
   where m.firm_id = v_firm_id
     and m.user_id <> v_actor;

  if v_members > 0 then
    return jsonb_build_object(
      'status', 'members_remaining',
      'members', v_members
    );
  end if;

  -- Open invites are retired first. The rows themselves leave with the `firms`
  -- row below (the foreign key cascades), so this is the statement that states
  -- the intent rather than the one that cleans up: a code issued before the
  -- dissolve must never be able to create a seat in a chamber that no longer
  -- exists, whichever order the cascade is ever changed to.
  update public.firm_invites i
     set revoked = true
   where i.firm_id = v_firm_id
     and i.revoked = false;

  -- The transfer: `firm_id` out, the owner in as scope owner. Tombstones are
  -- included — they are part of the ledger and their `firm_id` would block the
  -- `firms` delete just as a live row would. The sync columns are left to their
  -- triggers: `server_updated_at` is what the owner's next delta pull filters
  -- on, and version, `updated_at`, `is_deleted` and `synced_at` are not this
  -- function's to invent. The permission trigger steps aside here because the
  -- row being written has no firm afterwards, and because this function runs as
  -- its owner rather than as a client role.
  foreach v_table in array c_ledger loop
    execute format(
      'update public.%1$I set firm_id = null, scope_owner_id = $1 where firm_id = $2',
      v_table
    ) using v_actor, v_firm_id;
  end loop;

  -- The one exception: the chamber column goes, the scope owner does not.
  update public.conflict_log c
     set firm_id = null
   where c.firm_id = v_firm_id;

  -- The account is individual again, which is also what unblocks
  -- `delete_my_account()`. Nulling this before the `firms` delete is what the
  -- profile's plain foreign key requires.
  update public.profiles p
     set firm_id = null,
         role = 'individual'
   where p.id = v_actor;

  -- The chamber itself. `firm_members` and `firm_invites` cascade; no ledger
  -- row does, because none still names it.
  delete from public.firms f where f.id = v_firm_id;

  -- Other devices of the owner refresh through the same route a removal uses: a
  -- `firm_members` ping on the user topic is the client's account refresh, which
  -- re-reads the profile and drops the cached chamber.
  perform realtime.send(
    jsonb_build_object('table', 'firm_members', 'id', v_actor),
    'row_change',
    'user:' || v_actor::text,
    true
  );

  return jsonb_build_object('status', 'dissolved', 'firm_id', v_firm_id);
end;
$$;

comment on function public.dissolve_firm() is
  'Owner-only: dissolves the caller''s chamber once its roster holds nobody else. Every ledger row loses firm_id and gains the owner as scope_owner_id (attribution untouched, conflict_log excepted), open invites are retired, the firms row is removed and the account returns to individual. Writes nothing at all when it refuses, and returns {status:members_remaining,members:N} or {status:not_owner}. Takes no arguments: the firm is resolved from the caller.';

revoke all on function public.dissolve_firm() from public, anon;
grant execute on function public.dissolve_firm() to authenticated;
