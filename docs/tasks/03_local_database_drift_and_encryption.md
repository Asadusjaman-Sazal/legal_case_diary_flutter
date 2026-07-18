# Task 03 — Local Database (Drift) & Encryption

> **Plan references:** "Database Schema" (all tables + global Sync Columns note + Timestamp Convention + Naming Convention Mapping), §12.3.1 "Security, Local Database Encryption & Sensitive Exports", "Folder & File Structure" (`database/`).
> **Goal:** The complete encrypted local Drift database with every table carrying the global sync columns, plus `sync_queue` — making the app sync-ready from day one even though nothing syncs in Part A.
> **Rules:** Follow the Universal Working Rules in `00_INDEX.md`. Ask, don't guess.

---

## Phase 1 — Encrypted Database Backend & Key Management

1. Choose a **maintained SQLCipher-compatible Drift backend** (e.g., `sqlcipher_flutter_libs` with `sqlite3` open flags — verify current ecosystem guidance; confirm the final package choice with the user before locking it in, per Plan §12.3.1 "Validate Android and planned Windows support … before locking the package choice").
2. Key management (Plan §12.3.1):
   - Generate a random per-installation database key on first run.
   - Store it **only** in Android Keystore-backed secure storage (`flutter_secure_storage`). Never in SharedPreferences, source, logs, or synced tables.
   - **Key-loss behavior:** never silently create a new empty DB over an unreadable encrypted file — surface a recovery flow (backup restore; cloud restore arrives in Part B).
3. Write an integration test that opens the encrypted DB with the correct key, rejects a wrong/missing key without replacing data, and confirms raw file bytes don't contain known plaintext fixtures (Verification Plan, "Security tests").

**Phase 1 completion:** `flutter analyze` clean, tests pass. Update `docs/version_history.md`.

## Phase 2 — Core Data Tables

Create Drift table files under `database/tables/` exactly per the Database Schema section. **Every push/pull domain table** (`cases`, `case_history`, `notes`, `case_references`, `court_categories`, `courts`, `steps`, `case_types`, `on_behalfs`, `delete_requests`, `conflict_log`) gets the global sync columns (Plan "Sync Columns" note):
`updated_at` (INTEGER epoch ms), `version` (INTEGER — server-assigned; locally track the last known server version, null/1 semantics per plan), `synced_at` (INTEGER, null = unsynced), `is_deleted` (BOOLEAN, soft delete only — never hard delete), `last_modified_by` (TEXT UUID).
`server_updated_at` exists **only** on Supabase — do NOT add it to Drift tables.

Tables to define (columns exactly as in the plan's schema section):
1. `cases_table.dart` — all columns from the `cases` schema (case_number as single text, petitioner/respondent + lead counsels, on_behalf_id FK, petitioner_phone/respondent_phone, case_title_and_section, case_remarks, next_date epoch ms, last_step, notes_results, created_at, …).
2. `case_history_table.dart` — including denormalized `user_id`/`firm_id`, `hearing_date`, `last_step`, `next_date`, `note_result`, `created_by`, `source_mutation_id`, `base_case_version`, `result_case_version`.
3. `court_categories` table — TEXT PK stable machine keys (`appellate_division`, `high_court_division`, `district_sessions_criminal`, `district_courts_civil`, `chief_judicial_magistrate`, `chief_metropolitan_magistrate`, `executive_magistrate`, `tribunals`), `name_key`, `court_level`, `order_index`, `is_custom`, `user_id`, `firm_id`, `is_deleted`.
4. `courts_table.dart` — court_name, higher_lower_courts, division, district, `court_category_id` FK, is_custom, user_id, firm_id.
5. `steps_table.dart`, `case_types_table.dart`, `on_behalfs_table.dart` — each scoped by `court_category_id`, with is_custom/user_id/firm_id.
6. `notes_table.dart` — title, body, is_pinned, created_at.
7. `references_table.dart` — reference_and_page_no, statute, section_or_article, title_and_description, comments_notes, is_pinned, created_at.
8. `firms_table.dart`, `firm_members_table.dart` — local cache incl. permission flags (`can_add`/`can_edit`/`can_delete`) and `permissions_synced_at`. **No passwords/secrets ever stored locally.**
9. `delete_requests_table.dart` — entity_type/entity_id/entity_snapshot (TEXT), target_base_version, requested_by, status (`pending`/`approved`/`rejected`/`stale_review_required`), reviewed_by, review_note.
10. `conflict_log_table.dart` — local record per the plan's local `conflict_log` schema (mutation_id, base_version, base_payload, submitted_payload, changed_fields, server_version, server_payload, resolution_state, conflict_at, resolved_at, is_dismissed).

Use Drift's snake_case column ↔ camelCase Dart auto-mapping (Naming Convention Mapping). All timestamps are INTEGER epoch ms (Timestamp Convention).

**Phase 2 completion:** `dart run build_runner build` succeeds, `flutter analyze` clean. Update `docs/version_history.md`.

## Phase 3 — Sync Queue & Cursor Storage

1. `sync_queue_table.dart` — exactly per the plan's `sync_queue` schema: auto-increment id, `entity_type` (incl. `conflict_log`, `delete_request`), `entity_id`, `operation`, `mutation_id` (stable client UUID idempotency key), `base_version`, `base_payload`, `changed_fields`, `payload`, `pre_mutation_payload`, `created_at`, `retry_count`, `last_attempt_at` (nullable epoch ms, written immediately before each attempt), `state` (`pending`/`pushing`/`conflict_pending`/`blocked`/`resolved`), `last_error`.
2. Add **per-table composite pull cursor** records to durable `sync_metadata`: `(table_name, server_updated_at, id)` is committed transactionally with imported rows, never stored only in SharedPreferences. The same table stores device `last_successful_sync_at`, clock offset, recovery lock, archive path/checksum/completion state, and atomic recovery checkpoints.
3. Add a `seed_migrations` ledger table (Plan §12.2): `migration_id` PK, `checksum`, `applied_at` — consumed by Task 04.
4. Add pull-only `profiles`, `firms`, and `firm_members` caches; self-scoped `user_preferences`; and `(user_id, case_id)`-keyed `case_notification_preferences`. Convert server `TIMESTAMPTZ` profile fields to epoch ms and invalidate all account-bound caches on logout/account switch.

**Phase 3 completion:** build_runner + `flutter analyze` clean. Update `docs/version_history.md`.

## Phase 4 — AppDatabase & Query Conventions

1. `database/app_database.dart` — assemble all tables, set schema version 1, define the migration strategy skeleton.
2. Standing query rule: **all UI queries filter `WHERE is_deleted = 0`** (Plan, Zombie Data §"UI & Cleanup").
3. Local purge policy stub (implemented fully in Part B): soft-deleted rows purge after 90 days **only if** `synced_at IS NOT NULL AND synced_at >= updated_at`. In Part A (nothing ever syncs), this means unsynced tombstones are **never purged** — implement the guard now so behavior is already correct.
4. Wire `AppDatabase` into `shared/providers/database_provider.dart` with the encrypted executor from Phase 1.
5. Schema verification tests: assert tables/columns/constraints exist as specified (Verification Plan, "Schema verification").

**Phase 4 completion:** `flutter analyze` clean, tests pass. Update `docs/version_history.md`.

## Alignment Addendum (Implementation Plan Revision 2.4)

1. Classify local tables explicitly:
   - Push/pull domain: cases, case_history, notes, case_references, court_categories, courts, steps, case_types, on_behalfs, delete_requests, conflict_log.
   - Pull-only caches: profiles, firms, firm_members.
   - Per-user settings: user_preferences and case_notification_preferences.
   - Local operational: sync_queue, pull_cursors, seed_migrations, sync_metadata.
2. Apply all global sync columns to `court_categories`. Add `is_user_modified` to court_categories/courts/steps/case_types/on_behalfs.
3. Replace `petitioner_phone/respondent_phone` with nullable `petitioner_phone` and `respondent_phone`.
4. Add a profile cache with full_name, role, firm_id, subscription_expiry (epoch ms locally), plus account-switch invalidation.
5. Add `last_attempt_at` to sync_queue.
6. Add `user_preferences` keyed by user identity and `case_notification_preferences` keyed by `(user_id, case_id)`; neither is firm-shared.
7. Add `sync_metadata` for per-table cursors, device last-successful-sync, clock offset, recovery lock, archive path/checksum/state, and atomic checkpoints.
8. Include migrations and schema tests for every correction above.
