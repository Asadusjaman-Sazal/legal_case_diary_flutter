# Task 18 — Sync Engine: Push & Pull

> **Plan references:** Sync Plan §1 "Multi-User/Firm Setup" (delta pull, cursors, micro-batching), §1.1 "The `push_changes` RPC", §2 "Upgrade Readiness & Initial Backlog Push", §4 "Individual Setup", `sync_queue` schema notes (retry policy, FK-safe ordering, compaction), §12.3 "Power & Sync Efficiency" in `docs/implementation_plan.md`.
> **Goal:** The complete push/pull sync engine: the server-side `push_changes` RPC, the client `SyncService` with a serialized FIFO push worker, micro-batched write-through, and crash-safe per-table composite pull cursors.
> **Rules:** Follow the Universal Working Rules in `00_INDEX.md`. Ask, don't guess. Conflict resolution UI and Realtime are Task 19 — this task must still record conflicts correctly (`conflict_pending`, `conflict_log`).

---

## Phase 1 — `push_changes` RPC (Server)

Implement `push_changes(rows jsonb)` as a Postgres migration, following Sync Plan §1.1 exactly:

1. **Optimistic concurrency:** lock the target row; accept update/delete only when incoming `base_version` equals the current server `version`; inserts require no existing row. On acceptance assign `version = current + 1` (or 1 for insert), `last_modified_by = auth.uid()`, and server time. Clients never submit the resulting version.
2. **Structured conflict response:** on mismatch return `status = conflict` with the authoritative row/version, `mutation_id`, and three-way-reconciliation metadata. Never fall back to client timestamps or UUID ordering.
3. **Atomic history:** when an accepted case mutation changes `next_date`, create the immutable `case_history` event **in the same transaction** with `source_mutation_id`, `base_case_version`, `result_case_version`. Rejected mutations create no history.
4. **Deterministic per-mutation results:** one outer transaction, one savepoint per logical mutation, processed in dependency order. Permanent conflict/validation/permission failures roll back only that savepoint; DB/infrastructure errors abort the whole RPC. The response contains exactly one result per submitted `mutation_id`, in input order. Linked domain operations (case update + generated history) share one savepoint.
5. **Permission and premium gates:** re-check current `firm_members` permissions and derived entitlement (`subscription_expiry + 48h grace > now()`) before every applicable mutation; return stable machine-readable rejection codes. **Four firm-mode rules belong here (user rulings):** (a) **while the caller holds a firm, only the firm's expiry counts** — a member's own `subscription_expiry` is ignored, and the app does not offer them a plan at all, so the gate is `firms.subscription_expiry` for a member and their own for an individual; (b) **INSERT is gated on `can_add` and UPDATE on `can_edit`** by the per-table `BEFORE` triggers of Task 16, so a member the owner narrowed is refused even through this RPC; (c) **the scope columns are never taken from the payload** — `firm_id` is written from the caller's own firm when the row is created and may not be changed on an existing row, and `scope_owner_id` is written by the dissolve alone — because the RPC is `SECURITY DEFINER` and strips only `server_updated_at`, `version` and `last_modified_by`, so any column not named in that strip list is client-writable through it; and (d) a **member's reference insert/update is accepted under `can_edit`** while the immutable baseline (`is_custom = false`) is refused.
6. **Idempotency via `mutation_receipts`:** persist a receipt for every terminal result in the same savepoint. Retrying a known `mutation_id` with the same canonical request hash returns the original result; a different hash returns `mutation_id_reused` and applies nothing.
7. **Tombstone semantics:** writes against soft-deleted rows return `status = 'tombstone'` with the current row. Delete requests targeting an existing tombstone return `already_resolved`.
8. **Cascade soft-deletes:** an accepted case delete soft-deletes related `case_history` rows in the same transaction, assigning each child a new version and `server_updated_at`; return the changed parent/child rows to the caller.

**Phase 1 completion:** RPC migration applies; SQL-level tests for accept/conflict/idempotency/tombstone paths pass. Run `flutter analyze` (project stays clean). Update `docs/version_history.md`.

## Phase 2 — Push Worker (Client)

1. Replace the Part A `sync/` interface stubs with real implementations: `sync_service.dart` orchestrator and `push_worker.dart`.
2. **Single serialized FIFO** — never parallel fire-and-forget pushes. Order queue entries by **entity dependency first** (config tables `courts`/`steps`/`case_types`/`on_behalfs` → `cases` → `case_history`/`delete_requests`/`conflict_log`), then `created_at` within each group.
3. **Micro-batched write-through:** every local write still lands in Drift first (instant UI), then a **2–3 s coalescing window** batches all queued writes into **one** `push_changes` call (single radio wake-up — the plan's biggest battery win). On failure the batch stays in `sync_queue`.
4. Apply the **Offline Compaction Matrix** before pushing (Task 05 built local compaction — reuse it): preserve earliest `base_version`/`base_payload`, union `changed_fields`, keep the latest payload and stable `mutation_id`. **Never compact across an entity in `conflict_pending`.**
5. **Retry policy:** exponential backoff 30s → 1m → 2m → 4m … capped at 30m. Network/5xx errors are retryable; RLS denial, validation failure, version mismatch, and permanent rejection stop retries immediately and set `state` to `blocked` or `conflict_pending`. After 10 transient failures, mark `blocked`.
6. **Result handling per mutation:** accepted → update local row with server version/`synced_at`, mark queue entry `resolved`; conflict/tombstone → write `conflict_log`, set entity `conflict_pending`, freeze its compaction, preserve later queue entries (review UI in Task 19); permission rejection → roll back using `pre_mutation_payload`, refresh permissions, show *"Your firm permissions changed; this pending action was not applied."*
7. **Premium gate client-side:** the worker runs only when derived entitlement allows sync (Task 21 provides the derivation; use the `SettingsRepository` hook from Task 15 Phase 5 until then).

**Phase 2 completion:** `flutter analyze` clean; queue-ordering and compaction tests pass. Update `docs/version_history.md`.

## Phase 3 — Delta Pull with Per-Table Composite Cursors

1. Pull order on launch/resume: **push pending queue first**, then delta pull per synced table.
2. Cursor query per table: `server_updated_at > cursor.time OR (server_updated_at = cursor.time AND id > cursor.id)`, ordered ascending by both, paged with a fixed limit until a short page. Filter only on trigger-assigned `server_updated_at` — never client `updated_at`.
3. **Crash-safe cursor persistence:** maintain an independent composite `(server_updated_at, id)` cursor per table, stored **in the local database** (transactionally adjacent to imported rows — not only SharedPreferences). Advance the cursor only after the page is fully committed to Drift in one transaction; a crash may replay rows but can never skip them. An empty page completes that table without inventing a device-clock cursor. Initial/full pulls start at the minimum sentinel. A single shared cursor is forbidden.
4. **Pull-side merge:** if a pulled row intersects pending local mutations, do **not** overwrite queued work — run the three-way path (mark `conflict_pending` where fields overlap; details in Task 19). Pulled tombstones (`is_deleted = true`) apply locally and hide the record; if pending edits exist, preserve them and attach the tombstone as `server_payload`.
5. **Clock-skew detection:** on each successful sync, compare device vs server time; if skew > ~2 minutes, record the offset and show the non-intrusive *"Your device clock appears incorrect…"* warning.
6. Per-device `last_successful_sync_at` is updated in local storage after each successful sync (feeds the 150-day check in Task 19).

**Phase 3 completion:** `flutter analyze` clean; delta-pull tests pass (equal-timestamp pagination, crash-between-fetch-and-commit replay, no skipped rows across page/table/reconnect/empty boundaries). Update `docs/version_history.md`.

## Phase 4 — Initial Backlog Push on Upgrade (Free → Premium)

1. When a subscription becomes active (signal from Task 21), the `SyncService`:
   1. Reviews the accumulated `sync_queue` from the free period (the Always Sync-Ready architecture guarantees it is complete).
   2. Compacts only eligible `pending` rows; preserves `conflict_pending` rows for review; surfaces `blocked` rows in Sync Status (Task 19) instead of silently clearing them.
   3. After user-confirmed retry/repair of blocked rows, pushes FK-ordered micro-batches through `push_changes`, then performs a **full pull** (cursors from the minimum sentinel).
2. Permanent validation/permission failures remain visible and are never force-retried as ordinary backlog.
3. Zero local data migration is required — verify sync columns flow through unchanged from Part A writes.

**Phase 4 completion:** `flutter analyze` clean; backlog-push integration test passes. Update `docs/version_history.md`.

## Alignment Addendum (Implementation Plan Revision 2.4)

- The exact SQL signature is `push_changes(rows jsonb)`; `rows` must validate as a JSON array. Flutter serializes one JSON array, not a PostgreSQL jsonb array.
- Task 18 owns the base mutation contract. Task 20 adds delete-review mutation types through a later migration and extends the same tests/receipts.
- Include court_categories in dependency ordering, push/pull, cursors, conflicts, Broadcast repair, and tests.
- Pull-only caches use explicit refresh paths and never generic pushes. User preferences sync only through the dedicated self-scoped preference path.
- Write `sync_queue.last_attempt_at` immediately before every attempt.
- Store last-successful-sync, clock offset, cursors, and recovery checkpoints in durable sync_metadata.
- Base RPC history creation occurs only for an accepted case mutation that changed next_date, reconciling the sole provisional client history event.
- **The user can pause sync, and the engine must obey it (0.0.469, user request).** The Online Sync screen's *Disable Sync* switch sets `syncEnabledProvider` — a deliberate in-memory flag for this app run only, never persisted, so a restart starts with sync on. All three run paths ask it before anything else, `syncNow` (the single entry point every trigger funnels into) included, and `force` does not override it: a paused app builds no transport, sends nothing, arms no backoff and retries nothing. `SyncTriggerScope` does the rest — it closes the Realtime channel on the way in, holds it closed while the flag is off (so nothing arrives from another device either) and skips the recovery check — and on the way back it rejoins the channel, re-runs that check and asks for the delta pull, which is what catches up on the missed window. Tests: a paused service sends nothing (`sync_service_test.dart`) and the channel closes and rejoins (`sync_trigger_scope_test.dart`).
