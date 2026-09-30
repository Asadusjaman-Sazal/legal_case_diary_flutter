# Task 18 — Acceptance Report (Sync Engine: Push & Pull)

Every item of `docs/tasks/18_sync_engine_push_pull.md`, checked against the shipped
code, the live project (`lsthasywrdrhuuxnykau`) and the suites. Verdicts are
**PASS** / **PASS (deferred by the approved plan)**.

Evidence runs, all made after the final phase:

- `flutter analyze` — clean.
- `flutter test` — **1,027 passed**.
- `flutter test test/supabase/` — **74 passed**.
- `psql -f supabase/tests/push_changes_smoke_test.sql` — ends
  `SMOKE OK: push_changes behaves as specified.` and `ROLLBACK`.
- `select public.sync_server_time(), has_function_privilege('authenticated', …),
  has_function_privilege('anon', …)` — `t | t | f`.
- `supabase_migrations.schema_migrations` — **20** versions; `pg_proc` in `public`
  — **30** functions.
- `dart run tool/generate_all_supabase_sql.dart --check` — clean;
  `python tool/record_version.py --check` — clean.

---

## Phase 1 — `push_changes` RPC (Server)

| # | Item | Verdict | Evidence |
|---|---|---|---|
| 1 | Optimistic concurrency: lock, exact `base_version`, server-assigned `version`/`last_modified_by`/time, client values stripped | **PASS** | `20260930140000_push_changes.sql`; smoke test accepts on an exact base and refuses a stale one with `conflict`; a client-supplied `version`/`server_updated_at`/`last_modified_by` is deleted from the row before write |
| 2 | Structured conflict response with the authoritative row and three-way metadata | **PASS** | `status = conflict` + `row` + `version` + `message`; pinned in the smoke test and in `test/supabase/schema_contract_test.dart` |
| 3 | Atomic history in the same transaction when an accepted case mutation changes `next_date` | **PASS** | `provisional_history` is written under the client's id with `source_mutation_id`, `base_case_version`, `result_case_version`; only `next_date` (Addendum over plan §1.1.3); a rejected mutation writes none |
| 4 | Deterministic per-mutation results: one outer transaction, one savepoint each, dependency order, exactly one result per `mutation_id` in input order | **PASS** | `begin … exception … end` per mutation; `jsonb_agg … order by k`; smoke test asserts one result per mutation, in input order |
| 5 | Permission and premium gates re-checked per mutation with stable codes | **PASS** | `sync_can_write()` + `has_sync_entitlement()` (`subscription_expiry + 48h`); `permission_denied` and `entitlement_required` exercised live |
| 6 | Idempotency via `mutation_receipts`, same hash → original result, different → `mutation_id_reused` | **PASS** | Canonical `sha256_hex`; smoke test retries a mutation (nothing changes) and reuses an id with a different payload (refused); 11 receipt rows asserted |
| 7 | Tombstone semantics | **PASS** | Write against a soft-deleted row → `tombstone` with the current row; delete against one → `already_resolved` |
| 8 | Cascade soft-deletes returning the changed parent/child rows | **PASS** | Accepted case delete soft-deletes `case_history` in the same savepoint with new versions, returned as `children` |
| — | **Completion:** migration applies, SQL-level tests for accept/conflict/idempotency/tombstone pass, analyze clean, version history updated | **PASS** | 20 recorded versions; live `SMOKE OK`; analyze clean; `0.0.311` |

## Phase 2 — Push Worker (Client)

| # | Item | Verdict | Evidence |
|---|---|---|---|
| 1 | Real `sync_service.dart` and `push_worker.dart` replace the Part A stubs | **PASS** | The `library;` placeholders are gone |
| 2 | Single serialized FIFO, ordered dependency-first then `created_at` | **PASS** | `PushWorker._prepare()` sorts by `syncDependencyRank` then `created_at`; pinned by test |
| 3 | Micro-batched write-through through one `push_changes` call with a 2–3 s window | **PASS** | `syncCoalescingWindow` = 2,500 ms; one call per batch |
| 4 | Offline Compaction Matrix applied before pushing, never across a `conflict_pending` entity | **PASS** | Write-time compaction is Task 05's; Phase 4 adds the queue-level pass; the worker skips every frozen entity from one query |
| 5 | Retry policy 30 s → 30 m with the ten-failure cap; permanent failures stop immediately | **PASS** | `syncBackoffDelay` pinned by test; `blocked` on a non-retryable failure and at attempt 10 |
| 6 | Result handling: accepted → `markSynced` + resolved; conflict/tombstone → `conflict_log` + `conflict_pending` + `server_payload`; permission → rollback from `pre_mutation_payload` + the ARB notice | **PASS** | 24 push-worker tests cover each path |
| 7 | Premium gate client-side | **PASS** | Single derivation `premiumAccessProvider`; no client, no entitlement or no link ⇒ no run |
| — | **Completion:** analyze clean, queue-ordering and compaction tests pass, version history updated | **PASS** | 992 tests with the phase; `0.0.312` |

## Phase 3 — Delta Pull with Per-Table Composite Cursors

| # | Item | Verdict | Evidence |
|---|---|---|---|
| 1 | Push the pending queue first, then the delta pull per table | **PASS** | `SyncService._drain` pushes to empty, then pulls; the pull is skipped when the push failed on the link |
| 2 | Cursor query `server_updated_at > t OR (= t AND id > id)`, ascending, fixed-limit pages until a short page, trigger-assigned time only | **PASS** | `syncPullFilter()` (pinned) + `order('server_updated_at').order('id').limit(pageSize)`; never reads client `updated_at` |
| 3 | Crash-safe per-table cursors in the local database, transactionally adjacent to the rows, empty page completes the table, no device clock, sentinel for initial/full, never one shared cursor | **PASS** | `SyncCursor` in `sync_metadata`, written inside the page transaction; the crash test leaves the cursor and the rows untouched and replays; 17 pull tests include independent per-table cursors and an empty page that invents none |
| 4 | Pull-side merge: never overwrite queued work, `conflict_pending` on overlap, tombstones apply and hide with the edit preserved as `server_payload` | **PASS** | `PullWorker._applyRow`; five merge tests (pending edit preserved with all three payloads, tombstone hidden with the queued edit kept, frozen not re-logged, `blocked` untouched, resolved no longer blocks) |
| 5 | Clock-skew detection past ~2 minutes: record the offset and show the warning | **PASS (deferred by the approved plan)** | Offset recorded and `SyncNotice.clockSkew` raised, pinned by test; the banner's rendering is Task 19's Sync Status surface, as the approved plan states |
| 6 | Per-device `last_successful_sync_at` in local storage after each successful sync | **PASS** | `sync_metadata.last_successful_sync_at`, per the Addendum (durable metadata rather than `SharedPreferences`) |
| — | **Completion:** analyze clean, delta-pull tests pass (equal-timestamp pagination, crash replay, no skips across page/table/reconnect/empty boundaries), version history updated | **PASS** | 17 pull tests + 5 service tests; analyze clean; `0.0.313` |

## Phase 4 — Initial Backlog Push on Upgrade

| # | Item | Verdict | Evidence |
|---|---|---|---|
| 1 | On activation the service reviews the accumulated queue, compacts eligible `pending` rows, preserves `conflict_pending`, surfaces `blocked` instead of clearing, pushes FK-ordered micro-batches, then full-pulls | **PASS** | `SyncService.runBacklogPush()` + `queue_compaction.dart` + `SyncQueueDao.compactPending()`; the integration test asserts compaction, batch order, the resolved queue and a 12-table sentinel pull that forgets a stale cursor |
| 2 | Permanent validation/permission failures stay visible and are never force-retried | **PASS** | A permanent rejection during the pass lands as `blocked` with its message; a pre-existing `blocked` row is not attempted (retry count unchanged) and joins the backlog only once repaired to `pending` |
| 3 | Zero local data migration: sync columns flow through unchanged from Part A writes | **PASS** | A row written through the real `SyncWriteHelper` reaches the server with its `updated_at`/`synced_at`/`is_deleted`/`last_modified_by` payload unchanged and a null `base_version` |
| — | **Completion:** analyze clean, backlog-push integration test passes, version history updated | **PASS** | 12 new tests; full suite 1,027; `0.0.314` |

## Alignment Addendum (Revision 2.4)

| # | Item | Verdict | Evidence |
|---|---|---|---|
| 1 | Exact signature `push_changes(rows jsonb)`; `rows` must validate as a JSON array; Flutter serializes one array | **PASS** | Migration signature and `jsonb_typeof(rows) <> 'array'` guard; the transport sends `params: {'rows': rows}` from a Dart `List` |
| 2 | Task 18 owns the base mutation contract; Task 20 adds delete-review mutation types later | **PASS** | No delete-review mutation types were added; `delete_requests` is handled only as a domain table |
| 3 | `court_categories` included in dependency ordering, push/pull, cursors, conflicts and tests | **PASS (Broadcast repair is Task 19's)** | Rank 0 in `syncDependencyRank`, first in both push and pull orders (pinned: the pull's first request is `court_categories`), its own cursor, conflict-logged like any entity; the Realtime repair path is Task 19's and will use this same per-table pull |
| 4 | Pull-only caches never use a generic push; preferences sync only through the dedicated self-scoped path | **PASS** | The entity→table allow-list is exactly the twelve push/pull domain tables; `profiles`, `firms`, `firm_members` and `user_preferences` cannot be named by the worker, and `sync_entity_table()` refuses them server-side |
| 5 | Write `sync_queue.last_attempt_at` immediately before every attempt | **PASS** | `markAttempt` is called for every prepared row before the send; pinned by test |
| 6 | Store last-successful-sync, clock offset, cursors and recovery checkpoints in durable `sync_metadata` | **PASS (recovery checkpoints land with Task 19)** | `last_successful_sync_at`, `clock_offset_ms` and one `cursor.<table>` per table are all read and written in `sync_metadata`; the table is also the documented home of the `recovery_required` / `atomic_recovery_checkpoint` keys, whose only writer is Task 19's extended-offline lock (deferred by the approved plan) |
| 7 | Base RPC history creation only for an accepted case mutation that changed `next_date`, reconciling the sole provisional client history event | **PASS** | The client's provisional preview is never pushed on its own; it rides in `provisional_history` and the RPC writes the authoritative event under that id in the same savepoint, returning it |

## Findings carried forward (not failures)

1. **The clock-skew and permissions-changed banners are not rendered yet.** Both
   `SyncNotice` values and both ARB strings exist and are set by the service; the
   surfaces that show them belong to Task 19's Sync Status work, as approved.
2. **`runBacklogPush()` has no caller yet.** The plan gives the activation signal
   to Task 21 ("detects an approved payment … on activation, trigger the Initial
   Backlog Push"), and that task is not built; the method and its integration test
   ship here.
3. **Realtime is not wired.** By design (`Task 19`): no channel, no Broadcast ping,
   no resume throttle. The delta pull already repairs a gap from the last cursor,
   which is what the notification-only ping will trigger.
4. **The pull reads the server through PostgREST directly,** so the real query
   string is pinned by `syncPullFilter()` in a unit test rather than by a live
   round trip; the RPCs it needs (`push_changes`, `sync_server_time`) are both
   verified live.
