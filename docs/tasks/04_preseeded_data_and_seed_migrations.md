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
   - Steps per category, Case Types per category (e.g., Writ Petition, Civil Suit, Criminal Appeal, Revision) — **ask the user to confirm the complete seed lists and which steps count as "disposed"**.
   - On-Behalf options per category using the **mandatory mapping** in Plan §12.2 (appellate_division → Appellant/Respondent/Petitioner; high_court_division → Petitioner/Respondent/Writ Petitioner/Appellant; district_sessions_criminal → Accused/Complainant/State/Victim; district_courts_civil → Plaintiff/Defendant/Petitioner/Respondent/Applicant; chief_judicial_magistrate & chief_metropolitan_magistrate → Accused/Complainant/State/Informant; executive_magistrate → Defendant/Complainant/Applicant; tribunals → Applicant/Respondent/Claimant/Objector).
2. **Canonical category rule:** every court resolves to exactly one stable `court_category_id`; Appellate/High Court selections assign it implicitly. Persisted relationships use IDs — never English labels. Expose typed `Map<CourtCategoryId, List<SeedOption>>` in Dart.
3. Every built-in row gets a **stable deterministic ID** shared across Drift, (future) Supabase, backups, and releases.
4. The **disposed-step set** must be explicitly defined in `pre_seeded_data.dart` (used by Disposed/Active Cases screens — `cases.status` does not exist; disposal is derived from `last_step`).
5. Bengali + English labels for all seed items go into `app_translations.dart` keyed by stable ID (Task 02 Phase 3 structure).

**Phase 1 completion:** `flutter analyze` clean. Update `docs/version_history.md`.

## Phase 2 — Versioned, Idempotent Seed Migrations

Implement per Plan §12.2 "Versioned, idempotent seed migrations":
1. Ship ordered migrations (`seed_v1`, `seed_v2`, …). Record each successful application in the Drift `seed_migrations` ledger (from Task 03) with `migration_id` PK, `checksum`, `applied_at` — a lone SharedPreferences integer is NOT migration state.
2. On every app/database upgrade, apply only missing migrations, in order, transactionally (ledger row written in the same transaction).
3. Each migration must be **rerunnable**: insert absent IDs with conflict-safe semantics; perform only explicitly listed corrections.
4. Track `is_user_modified` (and soft-delete state) for editable built-ins. Generic corrections skip customized/deleted rows; forced corrections must name IDs, reason, and preservation behavior. **Never resurrect user-deleted rows implicitly.**
5. A database reset is a development tool only, never the production update mechanism.

**Phase 2 completion:** `flutter analyze` clean; fresh install seeds everything; re-running migrations is a no-op (write a test proving idempotency). Update `docs/version_history.md`.

## Phase 3 — Seed Verification

1. Tests: all categories exist with correct stable IDs and `court_level`; each category has its steps/case types/on-behalfs; court hierarchy resolves Division → District → Category → Courts; disposed-step set is non-empty and resolvable.
2. Manual spot check in a debug screen or test: pick a district, list its categories and courts.

**Phase 3 completion:** `flutter analyze` clean, tests pass. Update `docs/version_history.md`.

## Alignment Addendum (Implementation Plan Revision 2.4)

- `court_categories`, courts, steps, case types, and on-behalfs are editable synced reference data. Built-ins use deterministic IDs and `is_user_modified = false`; edits set it true and seed upgrades preserve customized or deleted rows.
- Customizations are firm-shared for firm members and user-scoped for individuals. Seed migrations and tests must cover `court_categories` exactly like the other reference tables.
- Backup/restore includes all custom rows and every user-modified built-in; never silently resurrect deleted seed rows.
