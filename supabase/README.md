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

**Applied.** All fourteen migrations are live on `lsthasywrdrhuuxnykau` and
recorded in `supabase_migrations.schema_migrations`, applied by
`tool/apply_supabase_migrations.dart`. The first real apply found four defects
that no amount of reading had caught, all fixed and re-applied:

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

What is verified now:

- `supabase/tests/rls_matrix_test.sql` — **passes** against the project: the full
  policy matrix, impersonating three throwaway users.
- `supabase/tests/rpc_smoke_test.sql` — **passes** against the project:
  `approve_payment`, `join_firm`, the rate limits, the free-tier ceiling and the
  ledger's immutability.
- Live state: 23 tables all with RLS on, 57 policies, 21 functions, 14 recorded
  versions, and the 1,442 seeded reference rows (1,016 courts).
- `get_advisors`: three INFO notes for the deny-all server-internal tables (by
  design, no policies) and the `anon`-executable SECURITY DEFINER family — see
  "Known gaps" below. No ERROR-level finding.
- `flutter analyze` clean; `dart run tool/generate_supabase_seed.dart --check` and
  `dart run tool/generate_all_supabase_sql.dart --check` clean;
  `flutter test test/supabase/` green (62 tests, structural invariants plus the
  ledger contracts).

## Known gaps (found by the first apply, not yet closed)

- **`anon` can execute 17 SECURITY DEFINER functions**, `purge_tombstones()`
  among them, because Supabase's default privileges grant EXECUTE on every new
  `public` function directly to `anon`. The two RPCs are locked; the rest need a
  closing migration (`revoke execute on all functions in schema public from anon`
  plus an `alter default privileges` so future ones stay closed).
- **Every RLS policy calls `auth.uid()` per row** (`auth_rls_initplan`, 50
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
stays empty and `db push` would consider all fourteen files unapplied:

```bash
for f in supabase/migrations/*.sql; do psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f "$f"; done
```

`psql` is required for the test scripts as well:

```bash
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/rls_matrix_test.sql
psql "$DATABASE_URL" -v ON_ERROR_STOP=1 -f supabase/tests/rpc_smoke_test.sql
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
(`15 3 * * *`) active. On a project where the extension may not be installed, the
guarded block raises a notice instead and the schedule can be added by hand with
`select cron.schedule('purge-tombstones', '15 3 * * *', 'select public.purge_tombstones()');`.

`app_admins` ships **empty** on purpose: admin membership is granted through an
audited migration or service-role operation, never by a client. Bootstrap with

```sql
insert into public.app_admins (user_id, granted_by) values ('<auth-user-uuid>', '<auth-user-uuid>');
```

## Registering a new admin, and what the RPCs are for

| Object | Purpose |
|---|---|
| `public.approve_payment(submission uuid)` | Admin-only, atomic MFS approval: lock, validate, extend `subscription_expiry`, mirror to the firm, write one audit event. |
| `public.join_firm(code text)` | Redeems a single-use invite: rate limit, hash, membership + profile update, invite consumed. |
| `public.purge_tombstones()` | Deletes soft-deleted rows older than 180 days, in FK-safe order. |
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
