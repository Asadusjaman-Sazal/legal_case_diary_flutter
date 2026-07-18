# Task 12 — Settings Screens (Main + All Sub-Pages)

> **Plan references:** §8 "Settings — Main Page & Sub-Menu Pages" (structure + Critical Rules), "Court Hierarchy Flow", §10.1 "View Settings Configuration", §12.1 "Settings Search".
> **Design references (mandatory — every sub-page body must match its mockup exactly):** `settings_main`, `settings_profile`, `settings_manageProfileAccount`, `settings_onlineSync`, `settings_backupRestore`, `settings_editCourtSteps`, `settings_editCourtSteps_editCourtNamesCategory`, `courtCategory_lowerCourts-Division`, `courtCategory_lowerCourts-Districts`, `courtCategory_lowerCourts-Districts_listOfCourts`, `settings_courtNamesSteps`, `settings_notifications`, `guidelines`, `settings_about` — all under `mockup_html_screens\`.
> **Goal:** The full Settings surface. Online-dependent pages (Online Sync, Manage Account subscription state) render their UI with offline/placeholder states in Part A and get wired in Part B.
> **Rules:** Follow the Universal Working Rules in `00_INDEX.md`. Ask, don't guess.

---

## Phase 1 — Main Settings Page

1. `settings_main_screen.dart` designed exactly like `settings_main\code.html`, **plus a "Guidelines" item before "About"**.
2. Structure: **General** — Account & Profile (sub-menu: Profile, Manage Account), Online Sync, Backup & Restore. **Preferences** — Edit Court/Steps, Notifications, Language (inline Bengali/English toggle), View Settings. **App Info** — Guidelines, About.
3. **Settings search** (Plan §12.1): a search input dynamically filtering submenu items (e.g., "profile" shows only Profile Settings / Manage Account).
4. All sub-pages use `settings_sub_page_modal.dart` (Task 06) for the header/back button.

**Phase 1 completion:** `flutter analyze` clean. Update `docs/version_history.md`.

## Phase 2 — Account & Profile + Online Sync + Backup & Restore (UI shells)

1. `accounts_profile_menu_screen.dart` (2 buttons: Profile, Manage Account), `profile_screen.dart` (per `settings_profile` mockup), `manage_account_screen.dart` (per `settings_manageProfileAccount` mockup).
   - Part A state: local profile (name) editable locally; subscription/account sections show "free / offline" placeholders. Real data binds in Part B (Tasks 17/21).
2. Online Sync screen per `settings_onlineSync` mockup — Part A shows a disabled/upgrade state (**confirm exact copy with the user**).
3. `backup_restore_screen.dart` per `settings_backupRestore` mockup — buttons wired to Task 15 logic.

**Phase 2 completion:** `flutter analyze` clean. Update `docs/version_history.md`.

## Phase 3 — Edit Court/Steps Hierarchy

Implement the full management flow per §8 and the Court Hierarchy Flow:
1. `edit_court_steps_menu.dart` (per `settings_editCourtSteps` mockup).
2. **Edit Court Names & Categories** (`edit_court_names_category_screen.dart`):
   - Supreme Court of Bangladesh → Appellate Division / High Court Division → list of court names (drag & drop reorder, FAB add, edit, soft-delete).
   - Lower Courts → Divisions (8) → Districts → Court Categories (sessions criminal, civil, CJM, CMM where applicable, executive, tribunals) → List of Courts (drag & drop, FAB add, edit, soft-delete) — screens: `court_category_screen.dart`, `district_list_screen.dart`, `court_list_screen.dart` per their mockups.
3. **Edit Case Types, Steps etc.** (`court_names_steps_screen.dart` per `settings_courtNamesSteps` mockup, **with the Court Names button removed**): all court categories as KanBan cards; under each, **Case Types**, **Steps**, **On Behalf** buttons → list screens with drag & drop, FAB add, edit, delete.
4. Every court resolves to exactly one stable `court_category_id` (Canonical category rule). User-added items get `is_custom = true`; edits to built-ins set `is_user_modified`; deletes are soft.
5. Reordering persists `order_index`.

**Phase 3 completion:** `flutter analyze` clean; manual walkthrough of the full hierarchy. Update `docs/version_history.md`.

## Phase 4 — Notifications, View Settings, Guidelines, About

1. `notification_settings_screen.dart` per `settings_notifications` mockup: `notification_time` and `notification_day_offset` pickers backed by the current user's durable `user_preferences` row; hosts the OEM setup-guide entry + reminder banner (logic in Task 13). Premium Part B synchronizes these through the self-only preference path, never firm-shared storage.
2. `view_settings_screen.dart`: `upcoming_cases_period`, `case_list_display_mode`, `bottom_nav_tabs` (selection + ordering of the 4 tabs), `side_nav_options` toggles, `default_landing_page`.
3. `guidelines_screen.dart` per `guidelines` mockup; `more_about_app_screen.dart` per `settings_about` mockup — About shows the app version read from `docs/version_history.md` `## Current Version` (bundle the value at build time or via an asset — **ask the user which mechanism they prefer**).
4. Language toggle updates the locale provider live (Task 02).

**Phase 4 completion:** `flutter analyze` clean; verify bottom-nav customization and landing-page change take effect. Update `docs/version_history.md`.

## Alignment Addendum (Implementation Plan Revision 2.4)

- Language, view/navigation configuration, notification defaults, and related settings are durable per-user preferences. Part A persists locally; premium Part B syncs only self-scoped preferences and never shares them across a firm.
- Editable court categories are managed and synchronized with courts/steps/case types/on-behalfs; built-in edits set `is_user_modified`, custom rows set `is_custom`, and all remain correctly user/firm scoped.
- Settings search is constrained to Settings and sub-settings localized labels only.
