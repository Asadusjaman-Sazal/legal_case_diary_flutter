# Supabase backend (Part B — Tasks 16+)

Task 16 owns everything in this folder: the schema, the server-internal tables,
the triggers and RPCs, the RLS policies, the indexes and the scheduled cleanup,
all as ordered, versioned SQL migrations. No Flutter code depends on this yet —
`supabase_flutter` arrives with Task 17 — and nothing in Part A changes.

## Project scope — one project, one that is off-limits

The only project this repo is ever applied to is **`lsthasywrdrhuuxnykau`**
("Legal Case Diary", org `xrjmednwyszriubyjzgb`, `ap-south-1`).
**`ykbwzodadijtiizobehk` ("Swanirvor-23") is live and must never be touched in
any way** — no read, no write, no branch, no log query. AGENTS.md rule 12 makes
this binding for every agent, and every command in this file takes the project
ref as an explicit argument rather than defaulting to "the" project.

## Recording every SQL statement

`AllSupabaseSql.md` is the single ordered record of every SQL statement this
project has ever run against Supabase: one section per migration in
`supabase/migrations/`, in creation order, grouped by the app version that was
current when the phase landed, with a labelled comment above each section's
verbatim SQL. It is **generated** (AGENTS.md rule 13):

```bash
dart run tool/generate_all_supabase_sql.dart          # rewrite the ledger
dart run tool/generate_all_supabase_sql.dart --check  # CI guard
```

Never hand-edit it, and never write server SQL anywhere else — a new statement
becomes a new file in `supabase/migrations/`, then the ledger is rebuilt. The one
section that is not a migration file is the leading **Bootstrap** section: the
bookkeeping SQL `tool/apply_supabase_migrations.dart` runs, generated from that
tool's own constants so it cannot drift either.
`test/supabase/all_supabase_sql_test.dart` fails if the two disagree, if a
migration is missing from the ledger, or if a section loses its label.

## Status of verification

**Applied.** All seventy-eight migrations are live on `lsthasywrdrhuuxnykau` and
recorded in `supabase_migrations.schema_migrations`, applied by
`tool/apply_supabase_migrations.dart`. The first real apply found four defects
that no amount of reading had caught, all fixed and re-applied; later phases
added more the same way (see below):

1. **`approve_payment` would not compile** — an unparenthesized `CASE` in an `IF`
   condition, which plpgsql ends at the CASE's own `then` (`syntax error at end
   of input`).
2. **`approve_payment` was ambiguous at run time** — the parameter
   `payment_submission_id` shares its name with a column of
   `payment_approval_events`, so the lookup needed qualifying.
3. **Column privileges did not hold** — Supabase grants *table-level* UPDATE on
   every `public` table to `anon`/`authenticated`, and a table-level GRANT is not
   undone by a column-level REVOKE. The migration now drops the table privilege
   and grants UPDATE back only on the columns a client may write
   (`profiles.full_name`, `firms.name`, none on `payment_submissions`).
4. **`anon` could execute both RPCs** — its own default-privilege EXECUTE grant
   outlives `REVOKE ALL ... FROM PUBLIC`, so `anon` is now named in the revoke.
5. **`ensure_firm` wrote a bigint into a `timestamptz`** (Task 17 Phase 5) —
   `firms.created_at` is a server instant while `firm_members.synced_at` is
   client-facing epoch ms, and the function used one `v_now` for both. Caught by
   executing the function for the first time, not by reading it: the fix lets
   `firms.created_at` take its column default and keeps the bigint for the
   member stamps.
6. **`push_changes` defaulted nothing on an insert** (Task 18 Phase 1) — the
   first version inserted `select *` from `jsonb_populate_record`, so a column
   the payload omitted became NULL instead of taking its column default; and its
   `created_at` fallback was added to the six reference tables, which have no
   such column. Both were caught by running
   `supabase/tests/push_changes_smoke_test.sql`, not by reading it: the insert
   now names only the columns the snapshot carries, and the fallback is guarded
   by a real column check.
7. **`push_changes` cast epoch milliseconds into `conflict_log.created_at`**
   (Task 19 Phase 3) — the insert branch strips the client's `created_at` for
   `conflict_log` (the column is a server `timestamptz` defaulted to `now()`),
   and the generic fallback then put the client's milliseconds straight back
   whenever the table had a `created_at` column at all, raising `22007`. The
   per-mutation handler turned that into a permanent `rejected` result, so **no
   conflict mirror could ever land** — a conflict raised on one device was never
   reviewable on another. Caught by adding a `conflict_log` row to
   `supabase/tests/push_changes_smoke_test.sql` and running it, not by reading
   the function; the fallback now also requires the column's **type** to be an
   epoch-ms integer (`20260930170000_push_changes_created_at_guard.sql`).
8. **`firm_seat_cap` left a Pro chamber uncapped** (firm mode, phase 7) — its
   branch for the stored `pro` tier fell through to the `null` every gate reads
   as "no ceiling at all", so a chamber whose owner held Pro could sell seats
   instead of refusing joins. `pro` now answers `0`, and the phase 7 proof pins
   it alongside Firm's 5 and Firm Plus's 20, so the branch cannot fall through
   again without a red run.
9. **The stored tier was never backfilled** (firm mode, phase 7) —
   `20261016120000_firm_mode_stored_tier.sql` added `profiles.tier` and
   `firms.tier`, but an account that had **already** paid for Pro — with an
   approved Pro purchase in `payment_submissions`, or inside a paid period with
   the grace window still open — would have kept reading the column default
   `free`, because the tier is only written when an approval lands. The
   migration now reconstructs every such account's tier from its own approved
   rows and period, and the phase 7 proof asserts the rule across the project's
   own rows, not just a fixture.

What is verified now:

- `supabase/tests/rls_matrix_test.sql` — **passes** against the project: the full
  policy matrix, impersonating three throwaway users.
- `supabase/tests/rpc_smoke_test.sql` — **passes** against the project:
  `approve_payment`, `join_firm`, the rate limits, the free-tier ceiling and the
  ledger's immutability.
- `public.ensure_firm(text)` (Task 17 Phase 5) — **verified by running it**
  against the project inside a rolled-back transaction: signed out it answers
  `{"status":"unauthenticated"}`, an empty name raises without creating
  anything, a real call returns `ready` and relinks `profiles.firm_id`/`role`,
  creates the firm with the caller as owner and upserts the owner's
  `firm_members` row with all three permission flags, and a second call is
  idempotent — one firm, one member row, rename respected. `anon` and `public`
  are refused the EXECUTE grant.
- `public.abandon_provisional_account()` (Task 17's audit closure) — **verified
  by running it**: signed out it answers `{"status":"unauthenticated"}`; a fresh
  account with no firm, no authored rows and no activity is **removed** (the
  `auth.users` row and, by cascade, its profile, per-user preferences and
  `invite_attempts` ledger); and every account that has been used for anything is
  refused with the reason it was refused — firm ownership, a firm on the profile,
  firm membership, cases, notes, custom courts, administrator rights, a payment,
  a subscription. Nine of ten fixtures survived the run, and `anon`/`public` are
  refused the EXECUTE grant.
- `profiles`' own-detail columns (Task 17 follow-up) — **verified by running
  them**: the sign-up trigger now fills `email` and the Bar Association from the
  sign-up metadata (and leaves the other three blank), an e-mail change on
  `auth.users` follows onto `profiles.email`, the account holder can UPDATE
  `bar_association`/`membership_no`/`office_address`/`mobile_no` on their **own**
  row and nothing else — another account's row is invisible to RLS, `email` is
  refused by the column grant, and `role`, `firm_id` and `subscription_expiry`
  keep the Phase 3 revoke, for `authenticated` and for `anon` alike.
- `public.push_changes(rows jsonb)` (Task 18 Phase 1) — **passes** against the
  project in `supabase/tests/push_changes_smoke_test.sql`, a self-contained
  rolled-back run: a free account is refused `entitlement_required` and writes
  nothing; a batch listing a case before its court is accepted in dependency
  order; an accepted date-changing update writes the authoritative
  `case_history` under the client's provisional id and a retry changes nothing
  while a reused `mutation_id` with a different payload is refused; a stale
  `base_version` returns `conflict` with the authoritative row; an associate
  without `can_edit` is refused `permission_denied`; a case delete
  cascade-soft-deletes its history and returns the changed child, then a later
  update returns `tombstone` and a later delete `already_resolved`; and the
  response carries exactly one result per `mutation_id`, in input order, each
  with a `mutation_receipts` row; and a `conflict_log` row pushes like any
  other entity — the insert carries `mergeable_conflict` to the mirrored row and
  a later update by `id` lands the resolution, which is what makes a conflict
  raised on one device readable on another (Task 19 Phase 3). `anon` is refused
  EXECUTE.
- `public.sync_server_time()` (Task 18 Phase 3) — **passes**, re-checked against
  the project: the call returns an instant, `has_function_privilege` is true for
  `authenticated` and false for `anon`, and it touches no table, so it is not
  SECURITY DEFINER (the client compares it with its own clock on every successful
  pull to record `clock_offset_ms`).- `20261015100000_firm_mode_read_scope.sql` (firm mode, phase 1) — **passes**
  against the project in `supabase/tests/firm_mode_read_scope_test.sql`, a
  self-contained rolled-back run: a member who has left a chamber no longer
  reads the rows they authored in it, on all four case-data tables, while the
  chamber's current members still do; an individual's own firm-less row is
  untouched; a dissolve's scope owner keeps the ledger and its author does not;
  `delete_requests` carries the same rule on `requested_by`; `conflict_log`
  keeps the membership condition only; the built-in reference baseline stays
  readable to everyone; and `scope_owner_id` is refused to a client INSERT and
  UPDATE as an error, with its counterpart proven in the same transaction —
  restoring the superseded policy on a scratch copy hands the row straight back.
  Live afterwards: `has_column_privilege('authenticated','public.cases',
  'scope_owner_id','UPDATE')` is false while `case_remarks` is still true.
- `20261015110000_firm_mode_creation_and_scope.sql` (firm mode, phase 2) —
  **passes** against the project in `supabase/tests/firm_mode_creation_scope_test.sql`,
  a self-contained rolled-back run: `ensure_firm` stamps every firm-less ledger
  row its creator authored — all four case-data tables, all six reference
  tables' custom rows, a pending delete request, tombstones included — with the
  new `firm_id` and a version bump, while a row of the creator's that already
  belonged to another firm, the built-in baseline and a resolved delete request
  are left alone and a second call (an idempotent rename) stamps nothing again;
  and `push_changes` makes the scope columns the server's — a member's insert
  whose payload says `firm_id` null (what the shipped client sends) lands in the
  chamber, a payload naming another firm is corrected rather than obeyed, a
  payload naming a scope owner is ignored, an update cannot move a row out of its
  chamber, and an individual's row stays personal. **Both halves were proven to
  bite:** with the superseded bodies restored on a scratch copy the run fails at
  `cases scope2-case did not follow the creator into the chamber` and, with only
  the old `push_changes`, at `a member's insert did not take the chamber's
  scope`. Live afterwards: `pg_get_functiondef` carries the creation flag and
  the `firm_id` derivation, `anon` still cannot EXECUTE either RPC and
  `authenticated` can.
- `20261015120000_firm_mode_join_gate.sql` (firm mode, phase 3) — **passes**
  against the project in `supabase/tests/firm_mode_join_gate_test.sql`, a
  self-contained rolled-back run: the gate refuses an account holding its own
  individual case (`has_own_diary`, quoting the count) and a chamber past its
  tier's seats (`seats_full`, quoting the cap), and **writes nothing on either
  refusal** — no membership, no profile relink, no consumed code; an
  already-member redemption answers `already_member` with the code `revoked`
  rather than `used_by`; a join lands `associate` with `can_add`/`can_edit` true,
  `can_delete` false and both freshness stamps; a lapsed chamber past the grace
  window has no cap and stays joinable; and the rate limiter still raises `Too
  many attempts` after five failures. Live afterwards: `pg_get_functiondef`
  carries both gates, and `has_function_privilege` is true for `authenticated`
  and false for `anon` on `holds_own_diary`, `individual_diary_cases`,
  `firm_seat_cap` and `join_firm`. **The first apply of this migration left all
  three helpers unexecutable — by every role, including the app's own.** The
  revokes named `authenticated` alongside `public` and `anon` and no grant
  followed, so a client could not read the two facts the screen's sentences need;
  `join_firm` itself was unaffected, which is why the gate's own test passed and
  only a direct `has_function_privilege` check found it. The grants are now
  issued to `authenticated` after the revokes, and the check above is what the
  re-apply was verified against.
- `20261015160000_firm_removal_clears_device_tokens.sql` (firm mode, phase 4) —
  **passes** against the project in `supabase/tests/firm_removal_test.sql`:
  `remove_firm_member` clears the removed member's `device_tokens` in the same
  transaction as the membership, the rows they authored and their attribution
  stay, the profile is relinked, both topics are announced, and the three
  refusal cases are still refused — printing `REMOVAL OK: access revoked,
  authored rows kept, push registrations cleared, both topics announced.`
  **This file opens its own transaction, so it must be run wrapped** — a bare
  `psql -f` commits its fixtures to the live project; the wrapper is
  `printf 'begin;\n' | cat - supabase/tests/firm_removal_test.sql <(echo rollback;) | psql "$DATABASE_URL" -v ON_ERROR_STOP=1 --file=-`.
- `20261016100000_firm_mode_permission_boundary.sql` (firm mode, phase 5) —
  **passes** against the project in
  `supabase/tests/firm_mode_permission_boundary_test.sql`, one rolled-back run
  over six throwaway accounts, printing `PERMISSION OK: can_add gates a create
  and can_edit every non-tombstone update on all ten tables through both doors,
  the owner is unaffected, and the scope columns are the server's.` It
  enumerates the ten gated tables **by name** and drives every refusal through
  both the direct-PostgREST door and `push_changes`, and pins the two deliberate
  postures (`enforce_member_permission` SECURITY INVOKER, `can_add_firm`
  DEFINER) plus all twenty triggers as `BEFORE … FOR EACH ROW`.
- `20261016110000_firm_mode_reference_in_use_guard.sql` (firm mode, phase 6) —
  **passes** against the project in
  `supabase/tests/firm_mode_reference_in_use_guard_test.sql`, a rolled-back run
  printing `INUSE OK`: `enforce_reference_not_in_use()` refuses a tombstoned
  reference row a live dependent still names with `reference_in_use` (23503) off
  the nine foreign-key pairs, the owner is refused exactly as a fully-permitted
  member (the member's queued case deliberately names a court the member
  authored, because `push_changes` subtracts `firm_id` before `sync_can_write`
  sees an update or a delete), a refused tombstone leaves the row live, and
  `purge_tombstones` **skips** the blocked row instead of failing as a whole —
  the run prints `NOTICE: purge_tombstones: 1 tombstone(s) kept; a dependent row
  still names them.` Four `trg_<table>_in_use_guard` triggers cover the four
  guardable parents; `steps` and `case_types` have no referencing column, so the
  device-side refusal in the repositories is the only protection they can have.
- `20261016120000_firm_mode_stored_tier.sql` with
  `20261016130000_firm_mode_seat_cap_and_creation_gate.sql` (firm mode, phase 7,
  phases 7 and 8's server halves) — **passes** against the project in
  `supabase/tests/firm_mode_stored_tier_test.sql`, one rolled-back run printing
  `TIER OK`: the backfilled tiers hold over the project's live rows, all ten
  ladder keys approve at their own amount and store their own tier, a key off
  the ladder answers `invalid_plan` and a real key at the wrong amount answers
  `invalid_amount` with nothing written, a chamber answers 0 / 5 / 20 by the tier
  its owner bought (through the mirror at Pro and Firm, and at creation for Firm
  and Firm Plus), a Pro purchase bought by a Firm owner waits as the pending
  pair and takes effect on its own date with no approval while the cap holds at
  Firm until then, the next upgrade clears that pending pair, a lapse keeps the
  tier and the ceiling the account paid for, the creation gate refuses free and
  Pro callers with `firm_tier_required` and writes nothing, and `authenticated`
  can neither write `tier` nor find an off-ladder value storable nor approve a
  payment. Each of the ten keys is bought by its own account, because
  `enforce_payment_rate_limit()` allows five submissions per account per day and
  a refused approval still counts as one — the first run of this proof failed on
  exactly that, not on the SQL. `supabase/tests/firm_mode_join_gate_test.sql` was
  re-run green over the re-pointed cap as well.
- `20261017110000_firm_mode_dissolution.sql` (firm mode, phase 11) — **passes**
  against the project in `supabase/tests/firm_mode_dissolution_test.sql`, one
  rolled-back run printing `DISSOLVE OK`: a chamber holding two members is
  refused with the count in the answer and **nothing written** — not a row, not
  the open invites, not the profile; a member gets `not_owner`; once the roster
  is emptied through `remove_firm_member` the dissolve succeeds, and the owner
  reads every case, note, reference, history row, custom court and delete
  request his former members wrote while those accounts read none of them — with
  each row's `user_id`, `created_by`, `last_modified_by`, contents, version and
  timestamps exactly as they were. `conflict_log` is the exception: its `firm_id`
  is cleared (without that the `firms` delete is refused by a non-cascading
  foreign key) and **no scope owner** is written, so its author still reads it
  and the owner still reads none of it. The `firms`, `firm_members` and
  `firm_invites` rows are gone, a code issued before the dissolve answers
  `invalid_code`, the owner's profile is individual again with his name, expiry
  and tier untouched,  and `delete_my_account()` answers `removed`.
- `20261027100000_delete_request_review_firm_scope.sql`,
  `20261027110000_delete_request_withdrawal_exit.sql`,
  `20261027120000_delete_request_withdrawal_field_guard.sql` and
  `20261027130000_push_changes_check_row_firm.sql` (delete-request review fix,
  user report) — **pass** against the project in
  `supabase/tests/delete_request_review_test.sql`, a rolled-back run printing
  `REVIEW OK`: a reviewer's rejection, a requester's snapshot refresh and a
  withdrawal all reach the server, an approval lands and hands the record's
  tombstone back as `target`, a decided request can be neither withdrawn nor
  reopened, the requester still cannot review, and `sync_can_write` stays
  internal and reads the stored request's firm when the row names none. The
  first two migrations make that rule read the **stored** request's `firm_id`
  (`push_changes` strips `firm_id` before the check, and `delete_requests`
  carries no permission trigger) and except a requester's own still-pending
  request from the ordinary tombstone gate; the third is the correction the
  proofs caught a minute after that apply (one condition asked every other
  table for a column only `delete_requests` has, which would have broken every
  delete in the app); the fourth weighs the permission verdict on the row **as
  it exists**, so a firm row the caller did not author can still be edited or
  deleted. **This file opens its own transaction, so it must be run wrapped:**
  `printf 'begin;\n' | cat - supabase/tests/delete_request_review_test.sql <(echo rollback;) | psql "$DATABASE_URL" -v ON_ERROR_STOP=1 --file=-`.
- `supabase/tests/delete_request_closure_test.sql` — **passes** (`CLOSURE OK`): a
  request never outlives its record. Tombstoning a case (through the app's own
  `push_changes`), a case step, a note or a case reference closes every still-open
  request for it as `already_deleted`, at the next version, stamped by the
  deleter; a request parked as `stale_review_required` closes the same way; an
  approval still ends `approved` rather than `already_deleted`, because it writes
  after the tombstone it causes; a second open request for one record is refused
  by `delete_requests_one_open_per_target`; and the function is internal and
  attached to all four tables. **Opens its own transaction, so run it wrapped:**
  `printf 'begin;\n' | cat - supabase/tests/delete_request_closure_test.sql <(echo rollback;) | psql "$DATABASE_URL" -v ON_ERROR_STOP=1 --file=-`.
- Live state: 28 tables all with RLS on, 63 policies, 96 functions in `public`,
  78 recorded versions — the newest `20261028100000` — and the 1,442 seeded
  reference rows (1,016 courts).
- `get_advisors`: three INFO notes for the deny-all server-internal tables (by
  design, no policies) and the `anon`-executable SECURITY DEFINER family — see
  "Known gaps" below. No ERROR-level finding.
- `flutter analyze` clean; `dart run tool/generate_supabase_seed.dart --check` and
  `dart run tool/generate_all_supabase_sql.dart --check` clean;
  `flutter test test/supabase/` green (75 tests, structural invariants plus the
  ledger contracts); `flutter test` green overall (1,084 tests).

## Known gaps (found by the first apply, not yet closed)

- **`anon` can execute 17 SECURITY DEFINER functions**, `purge_tombstones()`
  among them, because Supabase's default privileges grant EXECUTE on every new
  `public` function directly to `anon`. The four RPCs (`approve_payment`,
  `join_firm`, `ensure_firm`, `abandon_provisional_account`) are locked; the rest
  need a closing migration (`revoke execute on all functions in schema public
  from anon` plus an `alter default privileges` so future ones stay closed).
- **Every RLS policy calls `auth.uid()` per row** (`auth_rls_initplan`, 55
  policies). Wrapping the calls as `(select auth.uid())` is the documented fix and
  is mechanical.
- **24 foreign keys have no covering index**, and the 24 delta indexes are unused
  so far — expected on a project nothing has queried yet.

## Applying the migrations

One command, no CLI and no link needed:

```bash
dart run tool/apply_supabase_migrations.dart --dry-run   # the plan, no database
dart run tool/apply_supabase_migrations.dart             # apply for real
```

`tool/apply_supabase_migrations.dart` reads `SUPABASE_DB_URL` from
`supabase/.env.local` (git-ignored; the Session pooler URI of
`lsthasywrdrhuuxnykau`), applies `supabase/migrations/*.sql` in filename order
through `psql`, and records each version in
`supabase_migrations.schema_migrations` — created with the Supabase CLI's own
DDL — so a later `supabase db push` reports the whole set as applied rather than
trying it again. Its properties:

- **One transaction per file, shared with its version row.** A file that fails
  half-way is rolled back whole and is never recorded as applied.
- **Already-recorded versions are skipped,** so a second run applies only new
  files and the command is safe to repeat.
- **It refuses to run** unless the connection string resolves to
  `lsthasywrdrhuuxnykau`, so a stale or mis-pasted URL cannot reach the live
  project of AGENTS.md rule 12.
- **`statements` is recorded as NULL** — the CLI reads only `version` to decide
  what is pending.

The equivalent CLI workflow, if the CLI is preferred:

```bash
npx supabase link --project-ref <project-ref>   # asks for the database password
npx supabase db push                            # applies every unapplied migration
npx supabase migration list                     # what is applied on the project
```

Applying by hand with a plain loop also works, but then `supabase_migrations`
stays empty and `db push` would consider all fifty files unapplied:

```bash
for f in supabase/migrations/*.sql; do psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f "$f"; done
```

`psql` is required for the test scripts as well:

```bash
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/rls_matrix_test.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/rpc_smoke_test.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/push_changes_smoke_test.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/admin_payment_alerts_test.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/firm_mode_read_scope_test.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/firm_mode_creation_scope_test.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/firm_mode_join_gate_test.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/firm_mode_stored_tier_test.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/firm_mode_member_no_plan_test.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/firm_mode_dissolution_test.sql
```

The delete-request review proof opens its own transaction, so it is run wrapped:

```bash
printf 'begin;\n' | cat - supabase/tests/delete_request_review_test.sql <(echo rollback;) | psql "$DATABASE_URL" -v ON_ERROR_STOP=1 --file=-
```

## Project settings this repo cannot set

One thing lives in the Supabase dashboard, not in SQL, and the Realtime half of
Task 16 does not work until it is on:

1. **Realtime Authorization** must be enabled for the project; the policies on
   `realtime.messages` (Phase 3) only take effect once private channels are
   authorized.

**pg_cron needed nothing**: the last migration installs it (`create extension if
not exists pg_cron`) and schedules the purge itself, and the apply confirmed it —
the project runs `pg_cron 1.6.4` with a job named `purge-tombstones`
(`15 3 * * *`) active. A second job, `prune-user-devices` (`45 3 * * *`),
prunes revoked `user_devices` rows older than six months while keeping the
newest revoked row per account/device key. On a project where the extension may
not be installed, the guarded block raises a notice instead and the schedule can
be added by hand with
`select cron.schedule('purge-tombstones', '15 3 * * *', 'select public.purge_tombstones()');`
and
`select cron.schedule('prune-user-devices', '45 3 * * *', 'select public.prune_user_devices()');`.

`app_admins` ships **empty** on purpose: admin membership is granted through an
audited migration or service-role operation, never by a client. Bootstrap with

```sql
insert into public.app_admins (user_id, granted_by) values ('<auth-user-uuid>', '<auth-user-uuid>');
```

## Admin payment alerts — the secrets this repository cannot hold

The admin push notification is the first thing here that is not only SQL:
`supabase/functions/send-admin-payment-alerts/` is an Edge Function (deployed
through the Supabase connector, `verify_jwt` off because a webhook has no user to
sign in), and the webhook that calls it lives in
`20261012120000_admin_payment_alerts.sql` — pg_net, installed into `extensions`
so the advisor's "extension in public" warning stays away.

Two secrets must exist before a notification can be delivered, and **both hold the
same value** — a random string generated once and pasted into both places, never
into this repository:

| Where | Name | Why |
|---|---|---|
| Supabase → Project Settings → **Vault** | `fcm_webhook_secret` | the trigger reads it and sends it as `x-webhook-secret` |
| Supabase → Project Settings → **Edge Functions → Secrets** | `FCM_WEBHOOK_SECRET` | the function compares the header with it, and answers 401 otherwise |

The third is the service-account key, `FCM_SERVICE_ACCOUNT` — the whole downloaded
JSON file, set the same way (`docs/firebase_fcm_setup.md` §6).

Neither missing value is silent, deliberately. With no Vault secret the trigger
raises a warning and sends nothing, so a payment submission is never failed by the
notification side being unarmed; with no function secret the function answers 500
`missing_fcm_webhook_secret`, and a wrong header answers 401, so a misconfiguration
can never look like a delivered notification.

## Registering a new admin, and what the RPCs are for

| Object | Purpose |
|---|---|
| `public.push_changes(rows jsonb)` | The single atomic push pipeline (Task 18): optimistic concurrency, per-mutation savepoints, idempotent `mutation_receipts`, authoritative `case_history` on a changed `next_date`, and cascade soft-deletes. |
| `public.approve_payment(submission uuid)` | Admin-only, atomic MFS approval: lock, validate, extend `subscription_expiry`, mirror to the firm, write one audit event. |
| `public.join_firm(code text)` | Redeems a single-use invite: rate limit, hash, membership + profile update, invite consumed. |
| `public.purge_tombstones()` | Deletes soft-deleted rows older than 365 days (30 days above the 335-day device recovery window), in FK-safe order. |
| `public.is_premium(user uuid)` | Derived entitlement — `subscription_expiry + 48h > now()`. Never reads `subscription_status`. |

## Table classes (never apply one class's behaviour to another)

| Class | Tables | Server contract |
|---|---|---|
| Push/pull domain | `cases`, `case_history`, `notes`, `case_references`, `court_categories`, `case_categories`, `courts`, `steps`, `case_types`, `on_behalfs`, `delete_requests`, `conflict_log` | Global sync columns, `server_updated_at` trigger, delete/resurrection guards, Broadcast trigger, `(server_updated_at, id)` delta indexes |
| Pull-only cache | `profiles`, `firms`, `firm_members` | Refreshed from the server; no client INSERT/UPDATE except through RPCs |
| Per-user preference | `user_preferences`, `case_notification_preferences` | Self-only RLS, never firm-shared |
| Server-managed | `firm_invites`, `payment_submissions`, `payment_approval_events`, `mutation_receipts`, `invite_attempts`, `app_admins` | No client writes; RPC/service-role only |

## Regenerating the built-in reference data

`supabase/migrations/20260929100200_phase1_seed_reference_data.sql` is generated
from the app's own seed constants so Drift, Supabase and backups agree on every
built-in ID:

```bash
dart run tool/generate_supabase_seed.dart          # rewrite it
dart run tool/generate_supabase_seed.dart --check  # CI guard
```

Never hand-edit that file, and never change an existing ID: seeded rows are
referenced by `cases.court_id`, `cases.on_behalf_id` and friends on every device.

## Checking that the server holds the whole seeded list

```bash
dart run tool/check_supabase_seed.dart     # read-only, whole-table counts
```

Prints the app-side count and the Supabase count for each of the six seeded
tables — `court_categories`, `case_categories`, `courts`, `steps`, `case_types`,
`on_behalfs` — and exits non-zero if any pair disagrees. **Counting by eye in the
dashboard misleads**: the Table Editor shows 100 rows per page, and a single
PostgREST response stops at the project's `max_rows` (1000 by default), so the two
biggest tables — 1,016 courts and 160 case types — are exactly the two that look
truncated. As of the first apply all six match, and the ids match one for one, not
just the totals; `test/supabase/seed_parity_test.dart` pins the six sizes.
