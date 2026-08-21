# Task 04 — Pre-Seeded Data & Versioned Seed Migrations

> **Plan references:** §12.2 "Unified Courts, Case Types, Steps & On Behalf of Configuration", "Court Hierarchy Flow", "Canonical category rule", "Settings — Critical Rules".
> **Goal:** `pre_seeded_data.dart` plus versioned, idempotent seed migrations populating the local DB with all built-in court hierarchy and configuration data using **stable deterministic IDs**.
> **Rules:** Follow the Universal Working Rules in `00_INDEX.md`. **The exact lists of Bangladeshi districts, court names, case types, and steps are domain data — where the plan does not enumerate them, ASK THE USER for the definitive lists instead of inventing them.**

---

## Phase 1 — Data Model & Stable IDs

1. Define seed data structures in `core/constants/pre_seeded_data.dart`:
   - `higherLowerCourtCategories` (3 options: Appellate Division, High Court Division, Lower Divisional Courts).
   - `divisions` (the 8 divisions of Bangladesh: Dhaka, Chattogram, Rajshahi, Khulna, Barishal, Sylhet, Rangpur, Mymensingh).
   - `districtsByDivision` — districts nested under each division (**confirm the complete district list with the user**).
   - `lowerCourtCategories` — the stable category IDs: `district_sessions_criminal`, `district_courts_civil`, `chief_judicial_magistrate`, `chief_metropolitan_magistrate` (where applicable), `executive_magistrate`, `tribunals`.
   - `supremeCourtNames[category]` — pre-seeded court names for `appellate_division` and `high_court_division` (e.g., "Annex Building 2, Court No. 5") — **ask the user for the full official lists**.
   - `lowerCourtNamesByDistrict[district][category]` — nested court names (**ask the user for source data**).
   - Steps per court category, including an intentionally empty Step list for Appellate Division and High Court Division until authoritative lists are supplied.
   - Case Categories for Appellate Division and High Court Division, with their Case Types nested under and linked to `case_category_id`; the current source is `docs/AD_and_HCD.txt`. Lower-court Case Types remain scoped directly by `court_category_id` and do not use Case Categories.
   - On-Behalf options per category. The authoritative AD/HCD source currently defines Appellate Division as Petitioner/Respondent and High Court Division as Petitioner/Respondent; lower-court mappings remain the plan defaults until their definitive source lists are supplied.
2. **Canonical category rule:** every court resolves to exactly one stable `court_category_id`; Appellate/High Court selections assign it implicitly. Every seeded AD/HCD case type additionally resolves to exactly one stable `case_category_id`; lower-court case types resolve only to `court_category_id`. Persisted relationships use IDs — never English labels. Expose typed maps for court categories, AD/HCD case categories, and nested AD/HCD case types in Dart.
3. Every built-in row gets a **stable deterministic ID** shared across Drift, (future) Supabase, backups, and releases.
4. The **disposed-step set** must be explicitly defined in `pre_seeded_data.dart` (used by Disposed/Active Cases screens — `cases.status` does not exist; disposal is derived from `last_step`).
5. Bengali + English labels for all seed items go into `app_translations.dart` keyed by stable ID (Task 02 Phase 3 structure).

**Phase 1 completion:** `flutter analyze` clean. Update `docs/version_history.md`.

## Phase 2 — Versioned, Idempotent Seed Migrations

Implement per Plan §12.2 "Versioned, idempotent seed migrations":
1. Ship ordered migrations (`seed_v1`, `seed_v2`, …). Record each successful application in the Drift `seed_migrations` ledger (from Task 03) with `migration_id` PK, `checksum`, `applied_at` — a lone SharedPreferences integer is NOT migration state. The AD/HCD replacement is recorded as `seed_v2`; obsolete built-in AD/HCD courts, Steps, case types, and on-behalf rows are soft-deleted without touching user-modified rows. AD/HCD Steps intentionally remain empty.
2. On every app/database upgrade, apply only missing migrations, in order, transactionally (ledger row written in the same transaction).
3. Each migration must be **rerunnable**: insert absent IDs with conflict-safe semantics; perform only explicitly listed corrections.
4. Track `is_user_modified` (and soft-delete state) for editable built-ins. Generic corrections skip customized/deleted rows; forced corrections must name IDs, reason, and preservation behavior. **Never resurrect user-deleted rows implicitly.**
5. A database reset is a development tool only, never the production update mechanism.

**Phase 2 completion:** `flutter analyze` clean; fresh install seeds everything; re-running migrations is a no-op (write a test proving idempotency). Update `docs/version_history.md`.

## Phase 3 — Seed Verification

1. Tests: all categories exist with correct stable IDs and `court_level`; each category has its applicable steps/case types/on-behalfs, with empty Steps accepted for AD/HCD; AD/HCD case types resolve through `case_category_id`; court hierarchy resolves Division → District → Category → Courts; disposed-step set is non-empty and resolvable.
2. Manual spot check in a debug screen or test: pick a district, list its categories and courts.

**Phase 3 completion:** `flutter analyze` clean, tests pass. Update `docs/version_history.md`.

## Alignment Addendum (Implementation Plan Revision 2.4)

- `court_categories`, `case_categories`, courts, steps, case types, and on-behalfs are editable synced reference data. Built-ins use deterministic IDs and `is_user_modified = false`; edits set it true and seed upgrades preserve customized or deleted rows.
- Customizations are firm-shared for firm members and user-scoped for individuals. Seed migrations and tests must cover `court_categories` and `case_categories` exactly like the other reference tables.
- Backup/restore includes all custom rows and every user-modified built-in; never silently resurrect deleted seed rows.
