# Task 18 — Independent Audit (Sync Engine: Push & Pull)

An **independent re-check** of `docs/tasks/18_sync_engine_push_pull.md` Phases 1–4 and
its Revision 2.4 Alignment Addendum, made by re-reading the shipped code and the
migration, then re-running every check myself. This is not a restatement of
`docs/task18_acceptance.md`; where the two disagree, this file is the later
evidence.

Verdicts: **PASS** / **PARTIAL** / **FAIL**.

## Evidence runs (all re-run during this audit)

- `flutter analyze` — **No issues found!**
- `flutter test` — **1,027 passed** (all of them).
- `psql -f supabase/tests/push_changes_smoke_test.sql` — ends
  `SMOKE OK: push_changes behaves as specified.` + `ROLLBACK` (only harmless
  `WarnSendingBroadcastMessage` notices).
- `supabase_migrations.schema_migrations` — both `20260930140000` and
  `20260930150000` recorded (`2`).
- `pg_proc` privileges: `push_changes` `prosecdef=t`, `authenticated=t`, `anon=f`;
  `sync_server_time` `prosecdef=f`, `authenticated=t`, `anon=f`;
  `sync_can_write` / `has_sync_entitlement` `prosecdef=t`, both `f/f`.
- Client and server entity maps diffed mechanically — **identical** (12 domain
  tables, same singular→plural names).
- `dart run tool/generate_all_supabase_sql.dart --check` — clean;
  `python tool/record_version.py --check` — clean; `pubspec.yaml` and
  `app_version.dart` both `0.0.314`; `SyncTriggerScope` mounted inside
  `AccountRefreshScope` in `lib/app.dart`.
- Two throwaway probes in `test/sync/` (deleted after the run) for the two
  findings below.

---

## Phase 1 — `push_changes` RPC — **PASS (8/8)**

| # | Item | Verdict | Independent evidence |
|---|---|---|---|
| 1 | Optimistic concurrency | **PASS** | `for update` on the target; update/delete accepted only on an exact `base_version`; insert requires no existing row; `version`/`last_modified_by` assigned server-side and client-supplied `version`/`server_updated_at`/`last_modified_by` deleted from the payload before write |
| 2 | Structured conflict response | **PASS** | `status='conflict'` + `row` + `version` + `error_code` + `message`; never orders by client timestamp or UUID |
| 3 | Atomic history on changed `next_date` | **PASS** | Inserted in the same savepoint as the parent case mutation, from `provisional_history`, with `source_mutation_id` / `base_case_version` / `result_case_version`; `distinct from` on `next_date` (Addendum beats plan §1.1.3); rejected mutations create none |
| 4 | Deterministic per-mutation results | **PASS** | One outer transaction; one `begin … exception … end` savepoint per mutation; `array_agg(i order by rank, i)` for dependency order; results placed by input index and aggregated `order by k` |
| 5 | Permission + premium gates | **PASS** | `sync_can_write()` (firm-aware, mirrors the Phase 4 policies) and `has_sync_entitlement()` (`own or firm subscription_expiry + 48h`) before every mutation; stable codes `permission_denied` / `entitlement_required` |
| 6 | Idempotency via `mutation_receipts` | **PASS** | `sha256_hex` of the canonical row; same hash → the stored `result_payload`; different hash → `rejected`/`mutation_id_reused` and nothing applied; receipt written for every terminal result |
| 7 | Tombstone semantics | **PASS** | `tombstone` + current row for a write against a soft-deleted row; `already_resolved` for a delete against one |
| 8 | Cascade soft-deletes | **PASS** | Accepted case delete soft-deletes `case_history` in the same savepoint, bumps each child's `version`, returns them as `children` |

Completion: migration applies live (recorded version present), SQL tests and the
rolled-back live smoke test pass, analyze clean, version history `0.0.311`.

Nit (not a failure): the migration's closing comment says the RPC and its two
`SECURITY DEFINER` helpers are unreachable by any client role, but
`sync_entity_table()` and `sync_dependency_rank()` are plain `immutable` functions
and still carry the default `EXECUTE` to `public`/`anon`. They are pure lookups
(a name→table map) with no data exposure, so the claim is stylistically wrong
rather than a hole; a `revoke` would make the comment true.

## Phase 2 — Push Worker — **PARTIAL (5/7 + completion)**

| # | Item | Verdict | Independent evidence |
|---|---|---|---|
| 1 | Real `sync_service.dart` / `push_worker.dart` | **PASS** | Part A `library;` stubs are gone; both files are real implementations |
| 2 | Single serialized FIFO, dependency-first then `created_at` | **PASS** | `_inFlight` claimed synchronously before the first `await`; `_prepare()` sorts by `syncDependencyRank` then `created_at` |
| 3 | Micro-batched write-through, 2–3 s window, one call | **PASS** | `syncCoalescingWindow` = 2,500 ms; one `pushChanges` per batch; a failed batch stays in `sync_queue` |
| 4 | Offline Compaction Matrix applied **before pushing** | **PARTIAL** | Applied at write time (Task 05) and in the backlog pass (Phase 4), but **not** in the ordinary drain — see Finding 2 |
| 5 | Retry policy 30 s → 30 m, ten-failure cap, permanent stops now | **PASS** | `syncBackoffDelay()` pinned by test; non-retryable or `retryCount+1 >= 10` → `blocked` |
| 6 | Result handling per mutation | **PASS** | Accepted → `markSynced` + `resolve`; conflict/tombstone → `conflict_log` + `freezeEntity` (+ tombstone applied so the row hides); permission → rollback from `pre_mutation_payload` + `SyncNotice.permissionsChanged`; everything else permanent → `blocked` with the server message |
| 7 | Premium gate client-side | **PASS** | `premiumAccessProvider` (the Task 15 Phase 5 hook) is the single gate; no client / offline / not entitled ⇒ no run |
| — | **Completion** | **PASS** | analyze clean; 24 push-worker + 5 service tests pass; version history `0.0.312` |

Partial on item 6's "refresh permissions": the notice is set, and
`AccountRefreshScope` refreshes on launch/resume/reconnect, but nothing
invalidates the permission/premium providers at the moment of rejection. That is
consistent with the approved split (the surface is Task 19's) — noted, not failed.

## Phase 3 — Delta Pull — **PARTIAL (5/6 + completion)**

| # | Item | Verdict | Independent evidence |
|---|---|---|---|
| 1 | Push the pending queue first, then the delta pull | **PASS** | `_drain()` pushes to empty and only then pulls; a push failure returns before the pull |
| 2 | Composite cursor query, ascending, fixed pages, trigger time only | **PASS** | `syncPullFilter()` = `server_updated_at.gt.T,and(server_updated_at.eq.T,id.gt.id)`, pinned by test; `.order('server_updated_at').order('id').limit(200)`; never reads client `updated_at` |
| 3 | Crash-safe per-table cursors in the local DB | **PASS** | `cursor.<table>` in `sync_metadata`, written inside the page transaction; the crash test proves cursor + rows both roll back and the page replays; an empty page invents no cursor; `fromSentinel` ignores stored cursors; no shared cursor |
| 4 | Pull-side merge | **PASS** | Pending → `writeConflictLog` + `freezeEntity`, local work preserved; `conflict_pending` → never overwritten (and not re-logged); `blocked` → untouched; tombstone always applies and hides the row while the queued edit is kept in `server_payload` |
| 5 | Clock-skew detection | **PASS (deferred rendering)** | Offset stored in `clock_offset_ms`; `SyncNotice.clockSkew` past 2 min; the banner itself is Task 19's, exactly as the two ARB strings (`sync_clockSkewWarning`, Title Case, en+bn) anticipate |
| 6 | `last_successful_sync_at` after **each** successful sync | **PARTIAL** | Written by `_recordSyncHealth()`, which `_drain()` reaches only on a **pull-bearing** run; a successful push-only drain never stamps it — see Finding 3 |
| — | **Completion** | **PASS** | analyze clean; 17 pull + 10 service tests including equal-timestamp pagination, crash replay and empty-page completion; version history `0.0.313` |

## Phase 4 — Initial Backlog Push — **PASS (3/3 + completion)**

| # | Item | Verdict | Independent evidence |
|---|---|---|---|
| 1 | Review the queue, compact only `pending`, preserve `conflict_pending`, surface `blocked`, FK-ordered micro-batches, then a full pull | **PASS** | `runBacklogPush()` → `compactPending()` (reads `pending` only) → ≤20 worker passes → `pullAll(fromSentinel: true)`; the integration test asserts one compaction, `court` before `note`, all rows resolved and 12 sentinel pages that replace a stale cursor |
| 2 | Permanent failures stay visible, never force-retried | **PASS** | A `blocked` row is not attempted (`retryCount` unchanged, nothing sent) and is reported in `BacklogOutcome.blocked`; a rejection during the pass lands as `blocked` with its message |
| 3 | Zero local data migration | **PASS** | A real `SyncWriteHelper` insert reaches the server with `updated_at`/`synced_at`/`is_deleted`/`last_modified_by` unchanged and a null `base_version` |
| — | **Completion** | **PASS** | analyze clean; 12 backlog tests; full suite 1,027; version history `0.0.314` |

## Alignment Addendum (Rev 2.4) — **6 PASS, 1 PARTIAL**

| # | Item | Verdict | Note |
|---|---|---|---|
| 1 | Signature `push_changes(rows jsonb)`, array validated, Flutter sends one array | **PASS** | `jsonb_typeof(rows) <> 'array'` guard; `params: {'rows': rows}` |
| 2 | Task 18 owns the base contract; Task 20 extends | **PASS** | No delete-review mutation types added |
| 3 | `court_categories` in ordering, push/pull, cursors, conflicts, tests | **PASS** | Rank 0 on both sides; the pull's first request is `court_categories` (pinned); its own cursor; conflict-logged like any entity. Broadcast repair is Task 19's, as approved |
| 4 | Pull-only caches never generic-pushed; preferences only via the dedicated path | **PASS** | Client allow-list = the twelve domain tables; `sync_entity_table()` refuses everything else server-side |
| 5 | `sync_queue.last_attempt_at` immediately before every attempt | **PASS** | `markAttempt()` per prepared row before the send; pinned by test |
| 6 | Durable `sync_metadata` for last sync / offset / cursors / checkpoints | **PASS** | All present; `recovery_required` / `atomic_recovery_checkpoint` still have no writer (Task 19's lock), as approved |
| 7 | RPC history only for an accepted `next_date` change, reconciling the **sole** provisional client event | **PARTIAL** | The RPC half is exact, but the client can push the preview on its own — see Finding 1 |

---

## Findings

### Finding 1 — an unpaired provisional history **is** pushed on its own (correctness)

`PushWorker._prepare()` carries the comment *"Drop any prepared entry whose only
purpose was to carry a provisional history that is not attached to a mutation in
this batch."* — and then returns `prepared` without dropping anything. The
attached-row skip only fires for a preview that already got folded
(`attachedHistoryIds`); every other `case_history` **insert** row stays in the
batch and is sent as a standalone mutation.

That path is reachable, because the frozen-entity filter keys on the pair
`(entity_type, entity_id)`, so a preview (`case_history` + its own id) is *not*
frozen when its parent case (`case` + case id) is:

1. a case update conflicts → the entity is frozen (`conflict_pending`);
2. the next Quick Update queues a fresh `case` row **and** its preview — the write
   helper inserts rather than compacts when the entity already carries a
   `conflict_pending` row;
3. the worker correctly skips the frozen case rows and pushes **the preview
   alone** into `case_history`.

Probe (realistic shape: frozen case row + fresh pending case row + preview):
`attempted=1 sent=[case_history]`.

Consequence: a `case_history` event exists on the server for a next-date change
that never applied there. When the case mutation is later repaired and retried,
its preview queue row has already been resolved, so it travels without
`provisional_history` and the RPC mints a **fresh** id
(`gen_random_uuid()`) — two unrelated history events for one change, which is
exactly what the "sole provisional event / one-for-one reconciliation" rule exists
to prevent. (If the preview row had survived, the RPC's insert under the same id
would instead raise `23505`, a permanent code, and block the whole case update.)

`docs/task18_acceptance.md` records Addendum 7 as **PASS** with "never pushed on
its own"; that claim does not hold in this path. A fix is a one-line filter in
`_prepare()` (drop every unattached `case_history` insert — the only history
inserts the client ever queues are previews, so nothing legitimate is lost), plus
a test. Not applied here: it changes push semantics, so it is reported for a
decision.

### Finding 2 — the compaction pass is missing from the ordinary drain (Phase 2 item 4)

`SyncQueueDao.compactPending()` is called only by `runBacklogPush()`. The normal
drain goes straight from `requestSync()` → `_drain()` → `flushBatch()`, so a run
of `pending` rows for one entity can be sent in one batch — precisely the hazard
`queue_compaction.dart`'s own header names (*"sending two mutations for one entity
in one batch would make the second conflict against the version the first one just
produced"*). The write helper leaves exactly such a run behind for "delete, then
edit again" (it deliberately declines to compact that shape).

Probe: two `court/c1` rows, same `base_version`, both `pending` →
`attempted=2 sent=[delete, update] base_versions=[4, 4]`. The server accepts the
first (version 5) and then returns `conflict` for the second, freezing the entity
and writing a `conflict_log` row for a purely self-inflicted conflict.

### Finding 3 — `last_successful_sync_at` is not stamped by a push-only drain (Phase 3 item 6)

`_drain()` returns before `_recordSyncHealth()` when `pull` is false. Every
coalesced write-only drain is therefore a successful sync that never updates the
stamp the 150-day check reads. In practice launch/resume/reconnect always pull, so
the value does get refreshed — but the task says "after each successful sync".

### Carried forward (unchanged, by the approved split)

- The clock-skew and permissions-changed banners are set (`SyncNotice`) with both
  ARB strings present, but nothing renders them — Task 19's Sync Status surface.
- `runBacklogPush()` has no production caller — the activation signal is Task 21's.
- Realtime is not wired — Task 19.
- `recovery_required` / `atomic_recovery_checkpoint` keys are documented but have
  no writer — Task 19's extended-offline lock.

## Verdict

Phase 1 and Phase 4 are complete as specified. Phase 2 and Phase 3 are
substantially complete with one real correctness defect (Finding 1) and two
smaller gaps (Findings 2, 3). No file was modified by this audit; the two probe
tests were deleted after they ran.

All three findings were fixed afterwards, in `0.0.315` — see the resolution
below. The verdicts above are the state the audit found, kept as the record.

---

## Resolution — 0.0.315

Every fix ships with a test, and each of the four behaviour tests was first run
against the reverted code: all four failed there (attempted 2 instead of 1; the
lone preview not empty; two mutations in one batch; the stamp still null), so
they are regression tests rather than decorations.

- **Finding 1 — fixed** (`lib/sync/push_worker.dart`). `_prepare()` now skips
  every `case_history` **insert** outright — the only history insert the client
  ever queues is a provisional preview — so a preview can travel only folded into
  the case update that produced it. An unattached one stays `pending` and is
  never deleted, so a repaired case update still folds it in later, and the
  pairing is now guarded so one preview cannot be attached to two case mutations
  in the same batch. A user's history **edit** (an update) or delete is not an
  insert and still pushes on its own. Tests: the frozen-case path sends only the
  unrelated row (`attempted=1`, `sent=[note]`) and leaves the preview `pending`;
  a lone preview attempts nothing and burns no retry; a history edit is still
  pushed on its own.
- **Finding 2 — fixed** (`lib/sync/sync_service.dart`). `_drain()` now runs
  `SyncQueueDao.compactPending()` before its first batch, so the Offline
  Compaction Matrix applies to the ordinary drain and not only to
  `runBacklogPush()`. It reads `pending` rows only, so a `conflict_pending` or
  `blocked` action is still untouchable. Test: two `pending` updates for one
  entity go as one mutation carrying the latest payload under the first row's
  identity.
  **The one residual shape, deliberately untouched:** a *leading delete* run
  (`delete` then an edit) is declined by `planQueueCompaction()` — Task 05's
  matrix leaves that shape alone rather than guessing which of the two the user
  meant — so it still travels in order, and the second mutation comes back
  `tombstone` (a write against a row the batch's own delete just soft-deleted)
  rather than `conflict`: it is logged and frozen for review, and no silently
  wrong write reaches the server. Extending the matrix is a Task 05 decision, not
  Task 18's, so it was not taken here.
- **Finding 3 — fixed** (`lib/sync/sync_service.dart`). A push-only drain now
  calls `_recordSyncHealth(..., probeClock: false)`, stamping
  `last_successful_sync_at` on **every** successful drain while keeping the
  server-clock probe (and `clock_offset_ms`) on the pull path, so a burst of
  edits costs no extra round trip. Test: a write-coalescing drain pulls nothing
  yet stamps the instant.
