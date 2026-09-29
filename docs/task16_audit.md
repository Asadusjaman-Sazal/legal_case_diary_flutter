# Task 16 audit — is the Supabase backend what the task file asks for?

**Audited against:** [docs/tasks/16_supabase_schema_rls_and_triggers.md](tasks/16_supabase_schema_rls_and_triggers.md)
(all five phases, item by item) and the plan sections it cites — "Database Schema",
"Row-Level Security (RLS) Strategy", Sync Plan §1.1/§2/§3/§7 — in
[implementation_plan.md](implementation_plan.md) (Revision 2.4).

**Method.** Three independent sources, not one reading:
1. the migration text in `supabase/migrations/` (14 files) for what was *written*;
2. the live catalogue of `lsthasywrdrhuuxnykau` — `pg_class`, `pg_proc`, `pg_policy`,
   `pg_trigger`, `pg_indexes`, `pg_constraint` and `information_schema.columns`
   — for what was actually *created*;
3. the two SQL suites, which prove behaviour rather than shape:
   [rls_matrix_test.sql](../supabase/tests/rls_matrix_test.sql) (39 assertions) and
   [rpc_smoke_test.sql](../supabase/tests/rpc_smoke_test.sql) — both pass against
   the project, both roll back.

**Verdict.** Task 16 is implemented and live. All five phases, all four completion
gates and all seven Addendum items pass. Addendum 3's phone half is **closed by
decision, not outstanding**: the plan's *Resolved Design Clarifications* now
withdraw Revision 2.4's `petitioner_phone`/`respondent_phone` split, because the app
and the server both store the single `cases.party_phone` — the represented client's
number — so nothing is pending and no Part A change is being awaited. The schema
deviates from the plan's per-table column lists in a small, enumerable set of places
— all of them because the server mirrors the **shipped** Drift model, which was the
recorded decision for this task. The remaining deviations are listed at the end with
what closing each one costs.

---

## Phase 1 — Project setup & core synced tables

| # | Requirement | Verdict | Evidence |
|---|---|---|---|
| 1 | Create/link the project; set up the `supabase/` migrations workflow | **PASS** (CLI link unrun) | Project `lsthasywrdrhuuxnykau` is the only writable one, enforced in code by `tool/apply_supabase_migrations.dart` (ref allow-list + name guard). `supabase/config.toml`, `supabase/migrations/` (14 ordered files) and `supabase/README.md` exist; `.temp/` and `.branches/` are git-ignored. `npx supabase link` itself was never run — no CLI on this host — so there is no `.temp/project-ref`; the applier writes the same history table the CLI reads, which is what makes a later `db push` agree. `config.toml`'s `project_id` is the *local* project name by the CLI's own definition, not the ref — correct as it stands. |
| 2 | Create the core tables per the Database Schema section | **PASS** | All 20 Supabase tables the plan defines exist, plus the plan's §1.1/§7 tables (`mutation_receipts`, `app_admins`) and Addendum 4's two preference tables = 23. Every column the plan lists now exists: `profiles.last_successful_sync_at` was added on 2026-09-29 (`20260929105000_profiles_last_successful_sync_at.sql`, see *Deviations* 2); ~~`cases.petitioner_phone`/`respondent_phone`~~ (the split is withdrawn by user decision — `cases.party_phone` is the decided single column, see *Deviations* 1); and the five AD/HCD fields sit on `cases` because the plan was corrected to put them there (see *Deviations* 3). Extra vs the plan: `notes.items`; `court_categories.division`/`district`; `on_behalfs.order_index`. See *Deviations*. |
| 3 | Global sync columns on the push/pull domain class only; TIMESTAMPTZ vs BIGINT convention | **PASS**, with a task-vs-plan discrepancy | `version`, `server_updated_at`, `updated_at`, `synced_at`, `is_deleted`, `last_modified_by` on **12** tables and nowhere else: live trigger/policy audit shows them on the 11 the task lists plus `case_categories`. `profiles`, `firms`, `firm_members`, `firm_invites`, both preference tables, `payment_submissions` and the 3 internal ledgers carry no sync contract. Server instants are `TIMESTAMPTZ`, client display metadata `BIGINT` (e.g. `court_categories.updated_at` is `bigint`, `server_updated_at` is `timestamptz`). |
| 4 | `case_history.source_mutation_id` UNIQUE; `payment_submissions.transaction_id` UNIQUE | **PASS** | Live: `case_history_source_mutation_id_key`, `payment_submissions_transaction_id_key`. |
| 5 | Sign-up trigger creating a `profiles` row (`individual`, `free`, `firm_id = null`) | **PASS** | Live: `on_auth_user_created AFTER INSERT ON auth.users FOR EACH ROW EXECUTE FUNCTION handle_new_user()`. Proven functionally — five throwaway auth users created for the suites each received a profile. |
| 6 | Seed with the same stable deterministic IDs as the Drift seed | **PASS** | `supabase/migrations/20260929100200_phase1_seed_reference_data.sql` is generated from `lib/core/constants/pre_seeded_data.dart`; 1,442 rows (1,016 courts, 209 steps, 160 case types, 40 on-behalfs, 8 court categories, 9 case categories). Compared live: the id sets are identical to the constants, and `test/supabase/seed_parity_test.dart` pins both the bytes and the six counts. |

**Phase 1 gate — "migrations apply cleanly to a fresh project": PASS** (the first
apply ran against an empty project; 14/14 versions recorded).

## Phase 2 — Server-internal tables (no client access)

| # | Requirement | Verdict | Evidence |
|---|---|---|---|
| 1 | `invite_attempts` + deny-all RLS + `(user_id, attempted_at DESC)` index | **PASS** | Table exists with `id`, `user_id`, `attempted_at`; `invite_attempts_user_attempted_at_idx` live; **zero** policies (advisors confirm "RLS enabled, no policy"). |
| 2 | `mutation_receipts` with the plan's columns, no client policies, ≥210-day retention | **PASS** | All eight columns as specified; zero policies; the retention rule and "never purge a referenced receipt" are documented in the migration (no purge job is required by the plan — only that one never purges a referenced receipt). |
| 3 | `app_admins`, immutable, no authenticated INSERT/UPDATE/DELETE | **PASS** | Table + `trg_app_admins_no_update` (UPDATE refused; DELETE deliberately left possible so a grant can be revoked) + zero policies; the RLS matrix proves a client INSERT is refused by RLS. |
| 4 | `payment_approval_events`, one event per submission, owner/admin reads only | **PASS** | Live UNIQUE on `payment_submission_id`; exactly one policy (`SELECT`) for owner-or-admin; `trg_payment_approval_events_immutable` refuses UPDATE and DELETE; the smoke test proves one event per approval and proves the ledger is immutable. |

**Phase 2 gate: PASS.**

## Phase 3 — Triggers & server functions

| # | Requirement | Verdict | Evidence |
|---|---|---|---|
| 1 | `server_updated_at = now()` BEFORE INSERT/UPDATE on every synced table | **PASS** | 12 `trg_<table>_server_updated_at` triggers live, one per domain table. |
| 2 | Delete-transition trigger verifying `can_delete` | **PASS** | `trg_<table>_delete_transition` on all 12; the matrix test proves a member without `can_delete` is refused and the owner is allowed. |
| 3 | Resurrection guard via a transaction-local flag; no client timestamps | **PASS** | `enforce_no_resurrection` refuses `true → false` unless `current_setting('app.allow_resurrection') = 'true'`; the function comment states it compares no client timestamps, versions or UUIDs; the matrix test asserts resurrection is refused. |
| 4 | Free-tier ceiling: derived entitlement, count ≥ 50, advisory lock first | **PASS** | `enforce_free_case_limit`: `c_free_case_limit := 50`, `public.is_premium(new.user_id)` short-circuit, `pg_advisory_xact_lock(hashtext(...))` before counting; the smoke test drives 51 inserts (rejected) and proves a soft delete frees a slot. |
| 5 | Payment rate limit: overwrite `submitted_at`, 3 per 24h | **PASS** | `c_daily_limit := 3`, 24-hour window on `submitted_at`, `BEFORE INSERT`; the smoke test accepts three and refuses the fourth. |
| 6 | `mirror_owner_subscription_to_firm` in the same migration as `approve_payment` | **PASS** | Both in `20260929102200_phase3_payment_approval.sql`; trigger `trg_profiles_mirror_owner_subscription` fires `after update of subscription_expiry on profiles` for owner rows only; the smoke test asserts the firm mirror. |
| 7 | `approve_payment` per the plan's seven-step contract | **PASS** | `SECURITY DEFINER`, pinned `search_path`, `REVOKE ALL ... FROM PUBLIC` (+ `anon`), `GRANT EXECUTE ... TO authenticated`, `app_admins` gate, `FOR UPDATE`, status/plan/amount validation (prices 100/1000 BDT), `already_approved`/`already_resolved`, `GREATEST(COALESCE(expiry, now()), now()) + 1 month/year`, submission update, mirror, one audit event. Functionally exercised end to end by the smoke test. |
| 8 | `join_firm(code)` per contract | **PASS** | Rate limit 5 per 15 min, sha256 of the normalized code, unused-and-unrevoked match, membership + profile relink + invite consumed in one transaction, failed matches return `{status: 'invalid_code'}` instead of raising, success deletes the caller's attempts, lazy 1-day cleanup. All exercised by the smoke test. |
| 9 | Broadcast triggers + Realtime authorization | **PASS** (one dashboard toggle) | `broadcast_row_change` sends `{table, id}` to `firm:{firm_id}` / `user:{user_id}` (or `requested_by` for `delete_requests`) as a **private** message; the trigger exists on all 12 domain tables; the `realtime_messages_read_own_topics` SELECT policy exists. Realtime Authorization itself is a dashboard setting the user still has to enable. |
| 10 | Revoke ordinary client UPDATE on the server-owned columns | **PASS after correction** | Live: `has_column_privilege('authenticated','public.profiles','subscription_expiry','UPDATE') = false`, same for `role`/`firm_id`/`firms.subscription_expiry`/`firms.owner_id`, and `has_table_privilege('authenticated','public.payment_submissions','UPDATE') = false`; `full_name`/`firms.name` remain writable. The first version did **not** hold — see *Defects found and fixed*. |

**Phase 3 gate — "RPC smoke tests via SQL pass": PASS** (`supabase/tests/rpc_smoke_test.sql`, exit 0).

## Phase 4 — Row-level security

| # | Requirement | Verdict | Evidence |
|---|---|---|---|
| 1 | RLS enabled on all tables | **PASS** | 23 of 23 `public` tables have `relrowsecurity = true`. |
| 2 | The full policy matrix from the RLS Strategy table | **PASS** | 57 policies over 20 tables. `cases`/`case_history`/`notes`/`case_references`/`delete_requests`/`conflict_log` and the 6 reference tables: SELECT, INSERT, UPDATE, **no DELETE**. `profiles`: SELECT + UPDATE only (no INSERT — the sign-up trigger owns creation; no DELETE). `firms`: SELECT/INSERT/UPDATE. `firm_members`: all four including DELETE (owner-only). `firm_invites`: SELECT/INSERT/UPDATE, no DELETE. `payment_submissions`: SELECT + INSERT only. `payment_approval_events`: SELECT only. The 2 preference tables: self-only CRU. `invite_attempts`, `mutation_receipts`, `app_admins`: **zero** policies. |
| 3 | Entitlement always derived as `expiry + 48h > now()`, never `subscription_status` | **PASS** | `is_premium` is the only entitlement read (`subscription_expiry + interval '48 hours' > now()`); grepping the whole migration set for `subscription_status` finds only the column definitions, the writes (`join_firm`, `approve_payment`, the mirror) and comments. |

**Phase 4 gate — "scripted anon/authenticated queries prove the matrix": PASS**
(`supabase/tests/rls_matrix_test.sql`, 39 assertions, exit 0, impersonating three
real users the way PostgREST does).

## Phase 5 — Indexes & scheduled cleanup

| # | Requirement | Verdict | Evidence |
|---|---|---|---|
| 1 | `payment_submissions_user_submitted_at_idx` + the `invite_attempts` index | **PASS** | Both live. |
| 2 | Delta-pull indexes on every synced table | **PASS** | 12 tables × `(server_updated_at, id)` plus `(firm_id, server_updated_at, id)` and `(user_id, server_updated_at, id)` (`delete_requests` uses `requested_by`; it has no `user_id`). |
| 3 | Tombstone purge at 180 days, scheduled | **PASS** | `purge_tombstones(p_retention_days integer default 180)`, children before parents; `pg_cron 1.6.4` installed by the migration and the job `purge-tombstones` active on `15 3 * * *`. |
| 4 | A short header comment on every migration file | **PASS** | Enforced by `test/supabase/schema_contract_test.dart`. |

**Phase 5 gate — "full clean-slate migration run succeeds end-to-end": PASS**
(14 files applied to an empty project in filename order, each in one transaction
with its history row; the one audit-closure migration added on 2026-09-29 brings
the recorded set to 15).

## Alignment Addendum (Revision 2.4)

| # | Requirement | Verdict |
|---|---|---|
| 1 | Domain class = the 11 listed tables; sync columns/triggers/indexes only there | **PASS with a flag** — implemented on 12: `case_categories` is treated as domain too, because the plan's own Sync Columns note lists it and the plan's `case_categories` definition carries `version`/`synced_at`/`last_modified_by`. The task file and this Addendum omit it. AGENTS.md rule "the plan wins — flag the discrepancy" is what was applied; the Addendum should be amended or `case_categories` demoted. |
| 2 | profiles/firms/firm_members are pull-only caches; others don't inherit the contract | **PASS** — none of them has a `server_updated_at`/sync trigger, and none is in the delta-index or broadcast loops. |
| 3 | `is_user_modified` on all editable reference tables; `cases.petitioner_phone`/`respondent_phone` | **PASS** — `is_user_modified` is present on all six editable reference tables (`court_categories`, `case_categories`, `courts`, `steps`, `case_types`, `on_behalfs`). The phone half is **closed by decision, not failed**: the user has withdrawn the two-column split, so `cases.party_phone` — the represented client's number — is the final and only phone column. The decision is recorded in the plan's *Resolved Design Clarifications* ("Party Phone — one column only, final") and mirrored by the `cases` table comment in `20260929100000_phase1_core_schema.sql`. Nothing is pending. |
| 4 | Self-only preference tables for premium cross-device preferences and notifications | **PASS** — `user_preferences` and `case_notification_preferences`, self-only on SELECT/INSERT/UPDATE, no DELETE, firm-shared nowhere. |
| 5 | Explicit `court_categories` RLS, guards, broadcast trigger, delta index | **PASS** — 3 policies (built-ins to every authenticated user, custom rows to creator/firm), 4 triggers including the broadcast one, 3 delta indexes. |
| 6 | Reference data firm-shared in firm mode, user-scoped individually | **PASS** — the reference-table policy is `is_custom = false or user_id = auth.uid() or firm_id = current_firm_id()`, with firm-shared INSERT/UPDATE through `can_edit_firm()`; the matrix test proves both directions. |
| 7 | `push_changes` stays in Task 18; only its prerequisites here | **PASS** — no `push_changes` function exists (21 `public` functions, none of them it); `mutation_receipts` and the conflict/tombstone columns it needs are in place. |

## Completion gates and process

- `flutter analyze` clean — re-verified now.
- `docs/version_history.md` recorded through `tool/record_version.py` for every
  phase (`0.0.289`–`0.0.293`, plus `0.0.294`–`0.0.297` for the apply, its fixes
  and the seed checker). `python tool/record_version.py --check` clean.
- No Flutter source changed except `lib/core/constants/app_version.dart`, which the
  version script owns — the task's "no Flutter code changes" holds.
- Dart-side guards: 63 tests in `test/supabase/`, plus
  `dart run tool/generate_supabase_seed.dart --check` and
  `dart run tool/generate_all_supabase_sql.dart --check` — all clean.

## Deviations, gaps and what closing each costs

| # | Finding | Severity | To close |
|---|---|---|---|
| 1 | ~~**Addendum 3's `cases.petitioner_phone`/`respondent_phone` are missing**~~ **Closed by decision, 2026-09-29:** the plan now withdraws the split, so the single `cases.party_phone` is the decided model — this is no longer a deviation from anything | Resolved | Nothing. The clarifying note lives in the plan's *Resolved Design Clarifications* and is mirrored by the `cases` table comment in `20260929100000_phase1_core_schema.sql`; do not raise it again. |
| 2 | ~~**`profiles.last_successful_sync_at` is missing**~~ **Closed, 2026-09-29:** added by `20260929105000_profiles_last_successful_sync_at.sql` (nullable `timestamptz`, documented by a column comment) and applied to the live project, which now records **15** migrations. The app deliberately gets no mirror: the extended-offline reset is per-*device* and reads the local `sync_metadata`, and the app's `profiles` cache holds only `full_name`/`role`/`firm_id`/`subscription_expiry`. | Resolved | Nothing. Never read the column for the offline check, and do not report the absent Drift column as a gap. |
| 3 | **AD/HCD fields live on `cases`, not `case_history`** — **not a deviation; the plan was wrong and is corrected, 2026-09-29.** `case_category_id`, `honorable_judges`, `tender_number`, `previous_court_case` and `district_of_origin` belong to the case (as the shipped Drift `Cases` row proves), so the plan's schema tables now list them — plus `cases.result` — under `cases`, and `case_history.result` remains a per-hearing snapshot. | Resolved | Nothing. The corrected placement is also a *Resolved Design Clarification* in the plan; do not report their absence from `case_history` as a gap. |
| 4 | **Columns the plan does not list**: `notes.items`, `court_categories.division`/`district` (documented app feature — user-created lower-court categories scoped to a division+district), `on_behalfs.order_index` | Plan divergence | Update the plan's schema section, or drop the columns. |
| 5 | **`case_categories` classified as domain** although the task and Addendum 1 omit it | Documentation | Amend the Addendum (recommended — the plan's own note and table support it). |
| 6 | `anon` can execute 17 SECURITY DEFINER functions, `purge_tombstones()` among them | Security WARN | One migration: `revoke execute on all functions in schema public from anon` + `alter default privileges`. |
| 7 | 50 policies re-evaluate `auth.uid()` per row; 24 foreign keys lack covering indexes; 24 delta indexes unused (nothing queried yet) | Performance WARN/INFO | Wrap the policy calls as `(select auth.uid())`; add FK indexes if the workload needs them. The unused-index notes are expected on an empty project. |
| 8 | `npx supabase link` has never been run, so the CLI path itself is untested end to end | Process | `npx supabase link --project-ref lsthasywrdrhuuxnykau` then `npx supabase migration list` — it should report 15 local / 15 remote and no pending files. |

**Also recorded earlier and still standing:** the reference-data IDs are the stable
TEXT tags the app already uses rather than the plan's literal UUID PKs (user
approved; the plan wording is superseded), client-generated row ids are TEXT rather
than UUID, `delete_requests.entity_snapshot` and `conflict_log` payloads are TEXT
rather than JSONB, `case_history.source_mutation_id`/`conflict_log.mutation_id` are
TEXT, and `profiles.role`/`firm_id` plus `app_admins`' UPDATE-only lock are
deliberate additions beyond the task's literal list.
