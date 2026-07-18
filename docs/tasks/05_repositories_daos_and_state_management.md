# Task 05 — Repositories, DAOs & State Management (Sync-Ready Write Path)

> **Plan references:** "Proposed Architecture", Sync Plan §2 "Always Sync-Ready Architecture", `sync_queue` schema note ("Offline Compaction Matrix", "FK-Safe Ordering"), §12.3 "Rendering Optimization".
> **Goal:** Every domain gets a DAO + repository + Riverpod ViewModel. Every local write maintains the sync columns and enqueues into `sync_queue` — even though nothing is pushed in Part A. This is the core of "ready for Supabase from the very start."
> **Rules:** Follow the Universal Working Rules in `00_INDEX.md`. Ask, don't guess.

---

## Phase 1 — DAOs

Create DAOs under each feature's `data/local/` (per folder structure) for: cases, case_history, notes, case_references, courts, court_categories, steps, case_types, on_behalfs, firm_members/firms (read-mostly local cache), delete_requests, conflict_log, sync_queue.

Required DAO behaviors:
1. All read queries filter `is_deleted = 0` by default.
2. `CasesDao.getNonDeletedCaseCount()` counts all non-deleted cases for the 50-case free limit; `CasesDao.getActiveCaseCount()` counts non-deleted cases whose step is not disposed for Active Cases/KPIs.
3. Watch (stream) queries for reactive UI lists.
4. Search queries: case-insensitive `LIKE` (or FTS if trivially available) across the fields listed in Plan §12.1 (cases by case_number, petitioner, respondent, lead counsels, client name via on-behalf resolution, petitioner_phone/respondent_phone, remarks, title; notes by title/body; references by all five text fields).
5. Pagination support (`limit`/`offset`) for listings (Plan §12.3).
6. `CaseHistoryDao.insertHistoryEntry()` and history queries ordered by `next_date` descending.

**Phase 1 completion:** `flutter analyze` clean. Update `docs/version_history.md`.

## Phase 2 — Sync-Ready Local Write Pipeline

Implement a shared local-write helper used by all repositories so every insert/update/soft-delete:
1. Writes to Drift **first** (instant UI feedback).
2. Sets sync columns: `updated_at = now (epoch ms)`, `synced_at = null`, `last_modified_by = current local user id` (in Part A, use a locally stored placeholder user UUID created at first run; it becomes the Supabase `auth.uid()` in Part B — confirm this bridging approach with the user), `is_deleted` only ever transitions false→true via soft delete.
3. Enqueues a `sync_queue` row with: `entity_type`, `entity_id`, `operation`, fresh `mutation_id` (UUID), `base_version` (last known server version — null for inserts; stays null throughout Part A), `base_payload` (JSON snapshot of the pre-change row), `changed_fields` (JSON array of intentionally changed fields), `payload` (intended record state), `pre_mutation_payload`, `created_at`, `state = 'pending'`.
4. **Offline Compaction Matrix** (apply on enqueue or via a compaction pass — per `sync_queue` schema note):
   - insert + update(s) → single insert with latest snapshot
   - insert + delete → **both dropped** (server never needs to know)
   - update(s) + delete → single soft-delete update with latest snapshot
   - multiple updates → single update with latest snapshot
   - Preserve earliest `base_version`/`base_payload`, union `changed_fields`, retain latest payload, keep stable logical `mutation_id` rules. **Never compact across an entity in `conflict_pending`** (cannot occur in Part A, but write the guard now).

**Phase 2 completion:** `flutter analyze` clean; unit tests for the compaction matrix outcomes (Verification Plan). Update `docs/version_history.md`.

## Phase 3 — Repositories

Implement the concrete local repositories against the Task 01 interfaces:
1. `CaseRepository` — `insertCase()`, `updateCase()`, soft delete, list/watch/filter queries. In the quick Update transaction only: if `nextDate` changed, save the **previous** date/step/note values as one new `case_history` entry; ordinary Add/Edit saves and step/note-only changes create no automatic history (Plan §1.1 form logic and §5 Case History Logic). Locally this is the provisional history entry; in Part B the server-authoritative history reconciles it (Plan `case_history` "Authoritative history rule") — structure the code so this swap is easy.
2. `NotesRepository`, `ReferenceRepository` — CRUD + pin/unpin + search.
3. Config repositories (`court_categories`/courts/steps/case types/on-behalfs) — CRUD respecting `is_custom`, `is_user_modified`, ordering (`order_index`), category scoping, and user-versus-firm ownership. Custom reference data is firm-shared in firm mode and user-scoped in individual mode.
4. `SettingsRepository` — backed by the Drift `user_preferences` row for the current user (not global SharedPreferences): `isPremium` (Part A: derived stub, default false — real derivation from `subscription_expiry` arrives in Task 21), `upcoming_cases_period` (default 7), `case_list_display_mode` (default 'compact'), `bottom_nav_tabs` (default `['overdue','daily_cause_list','active','upcoming']`), `side_nav_options` (default all true), `default_landing_page` (default 'daily_cause_list'), `notification_time`, `notification_day_offset`, language, and backup-nudge metadata. Task 16 adds a self-only premium sync mirror; preferences are never firm-shared.
5. `DeleteRequestRepository` — local create/list (full firm workflow activates in Part B; in Part A an individual user always has delete rights so requests are not triggered — keep the code path present).

**Phase 3 completion:** `flutter analyze` clean; DAO/repository tests for soft-delete behavior and queue ordering (dependency-then-`created_at`, per FK-Safe Ordering). Update `docs/version_history.md`.

## Phase 4 — ViewModels (Riverpod)

1. Create `AsyncNotifier`-based ViewModels per feature (e.g., `daily_cause_list_viewmodel.dart`, `auth_viewmodel.dart` stub, `payment_viewmodel.dart` stub).
2. Use `.select()` to minimize rebuilds; expose watch streams from DAOs.
3. Establish the standing pattern: UI never touches DAOs directly — always ViewModel → Repository.

**Phase 4 completion:** `flutter analyze` clean. Update `docs/version_history.md`.

## Alignment Addendum (Implementation Plan Revision 2.4)

- Use `getNonDeletedCaseCount()` only for the 50-case limit. `getActiveCaseCount()` excludes disposed steps and serves Active Cases/KPIs.
- Replace all `petitioner_phone/respondent_phone` query/model fields with petitioner_phone and respondent_phone.
- The repository transaction for the Update Case popup is the sole client owner of provisional history creation, and only when `next_date` changes. Ordinary Add/Edit saves never create history for step/note-only changes; UI never calls the history DAO directly for this flow.
- Resolve authenticated identity adoption before normal repository use: atomically rewrite placeholder-owned rows, queue payloads/base snapshots, notification preferences, and ownership into the authenticated user/firm while preserving separate audit provenance.
- SettingsRepository uses durable user_preferences rather than global SharedPreferences. Preferences and case notifications are per-user; premium synchronization is self-scoped, never firm-shared.
- DAO search methods are primitives only; feature repositories constrain searches to each current screen/entity dataset.
- Push ordering includes court_categories before dependent courts/cases. Pull-only caches and local operational tables never enter generic domain pushes.
