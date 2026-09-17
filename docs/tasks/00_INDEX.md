# Legal Case Diary — Task File Index & Working Rules

> **Source of truth:** `docs/implementation_plan.md` (Revision 2.4). Every task file below references specific sections of that plan. If a task file and the implementation plan ever disagree, the implementation plan wins — flag the discrepancy to the user instead of guessing.

---

## How the tasks are organized

The build is split into two parts:

- **PART A — Offline-First App (Tasks 01–15):** Build and fully test the complete offline app. Every local write already maintains all sync columns (`version`, `updated_at`, `is_deleted`, `synced_at`, `last_modified_by`) and populates `sync_queue`, so the app is 100% sync-ready from day one (Implementation Plan, Sync Plan §2 "Always Sync-Ready Architecture"). **No Supabase package, no network code, and no auth-server calls are implemented in Part A.**
- **PART B — Supabase & Online Sync (Tasks 16–22):** Add the Supabase backend, auth, sync engine, realtime, firm management, and payments on top of the finished offline app. Because Part A maintained sync metadata from the start, Part B connects the backend without any local data migration.

## Task list

### PART A — Offline-First App
| # | File | Contents |
|---|---|---|
| 01 | `01_project_setup_and_architecture.md` | Flutter project init, dependencies, folder structure, MVVM+Repository scaffolding, docs files |
| 02 | `02_design_system_theming_localization.md` | Justice Ledger colors/typography/spacing, fonts, theme, Bengali/English l10n |
| 03 | `03_local_database_drift_and_encryption.md` | All Drift tables (with global sync columns), `sync_queue`, SQLCipher encryption, key management |
| 04 | `04_preseeded_data_and_seed_migrations.md` | `pre_seeded_data.dart`, court categories/divisions/districts/courts, steps, case types, on-behalfs, versioned idempotent seed migrations |
| 05 | `05_repositories_daos_and_state_management.md` | DAOs, repositories, Riverpod ViewModels, sync-ready local write path, offline compaction |
| 06 | `06_shared_widgets_navigation_and_router.md` | `cases_screen_modal`, navigation drawer, bottom nav bar, case card, custom dropdown, GoRouter, back/exit confirmation |
| 07 | `07_add_edit_case_form.md` | `AddEditCaseSheet` — all fields, cascading court logic, two party-phone fields, persistent notification choices, 50-case free limit, and date-only history from Quick Update |
| 08 | `08_case_list_screens.md` | All Cases, Active Cases, Upcoming Cases, Overdue Dates, Disposed Cases screens |
| 09 | `09_daily_cause_list_and_badge_calendar.md` | Daily Cause List screen + badge calendar picker |
| 10 | `10_case_detail_and_case_history.md` | Case Detail screen, Case History KanBan card, history edit/delete |
| 11 | `11_notes_and_case_reference.md` | Notes screen, Case Reference screen, pinning, search |
| 12 | `12_settings_screens.md` | Settings main + all sub-pages, Edit Court/Steps hierarchy, View Settings, settings search |
| 13 | `13_notification_system.md` | Local notifications, exact alarms, OEM battery-killer guide, boot rescheduling, platform abstraction |
| 14 | `14_print_pdf_action_buttons_and_search.md` | PDF print (Bengali-safe), Phone/Message action buttons, unified search |
| 15 | `15_backup_restore_and_free_tier_gating.md` | Versioned JSON backup/restore, encrypted exports, 50-case paywall gating (local), monthly backup nudge |

### PART B — Supabase & Online Sync
| # | File | Contents |
|---|---|---|
| 16 | `16_supabase_schema_rls_and_triggers.md` | All Supabase tables, RLS policies, triggers, server-internal tables, indexes |
| 17 | `17_auth_profiles_and_firm_onboarding.md` | Login/Signup screens, profiles, `firm_invites`, `join_firm` RPC, offline session handling |
| 18 | `18_sync_engine_push_pull.md` | `push_changes` RPC, `mutation_receipts`, SyncService, push worker, per-table composite pull cursors |
| 19 | `19_realtime_conflicts_and_recovery.md` | Broadcast realtime, connectivity, conflict resolution UI, Sync Status/Diagnostics, extended-offline recovery, logout flows |
| 20 | `20_firm_management_and_delete_requests.md` | Manage Associates, permissions, delete-request workflow |
| 21 | `21_payments_and_subscription.md` | Paywall/Checkout screens, `payment_submissions`, `approve_payment` RPC, entitlement derivation, grace period |
| 22 | `22_verification_plan.md` | Full automated + manual verification suite from the implementation plan |

---

## Universal Working Rules (apply to EVERY task file)

1. **Never guess.** If any requirement, UI detail, data rule, or edge case is not clearly described in the task file or `docs/implementation_plan.md`, **stop and ask the user for clarification** before implementing. Do not invent behavior.
2. **Phase completion protocol.** At the end of **every phase** in every task file:
   1. Run `flutter analyze` and fix **all** reported errors and warnings introduced by your changes.
   2. Only after `flutter analyze` is clean is the phase considered complete.
   3. Update `docs/version_history.md`: append a new entry under `## Version History` in the format `Version: X.Y.Z - [Brief summary of changes]` (bump sequentially per Development Workflow §4), and update the `## Current Version` section with the latest version and a brief completion note (e.g., "Task 03 Phase 2 complete: …").
3. **Mockup HTML files are mandatory design references, not optional.** Screen bodies must match the referenced files under `legal_case_diary_flutter\mockup_html_screens\` exactly.
4. **Comment preservation rule** (Development Workflow §2): every file and major section gets short, precise intent comments; never delete existing comments unless they conflict with new logic.
5. **File modification scope** (Development Workflow §3): only touch files/sections the current task instructs you to.
6. **Naming conventions** (Development Workflow §1): DB columns `snake_case`, Dart/JSON `camelCase`, Drift auto-mapping between them.
7. **Progress tracker:** start every session by reading `docs/currentlyWorking.md`; update it as tasks begin and complete (format: `### [Date Time] — Current Task: [brief description]`).
8. **No `BackdropFilter` anywhere** — use the performance-safe alternatives described in the plan (Resolved Design Clarifications).
9. **Mobile-first only** for now (Plan §12.4). Tablet/desktop optimization comes after mobile is complete.
10. **Part A is strictly offline.** Do not add the `supabase_flutter` dependency, network calls, or server code until Part B. But every table, repository, and write path must maintain the sync columns and `sync_queue` exactly as specified, so Part B requires zero local-data migration.
11. **Revision 2.4 scope contract:** editable court categories/courts/steps/case types/on-behalfs are domain-synced and firm-shared in firm mode; language, view, navigation, notification, backup-nudge, and related settings are always per-user.
12. **Table classes are mandatory:** task implementations must distinguish push/pull domain tables, pull-only caches, per-user preference data, local operational state, and server-managed tables. Never apply generic synchronization behavior across classes.
13. **Corrections are authoritative:** every task's Revision 2.4 Alignment Addendum overrides contradictory earlier wording in that task and must be included in its acceptance tests.
14. **Every user-visible label must live in the ARB files — never hard-code strings in Dart.** All labels, titles, hints, error messages, and dialog text must exist in **`lib/core/l10n/app_en.arb` and `lib/core/l10n/app_bn.arb`**, and screens must read them through `AppLocalizations` (`l10n.<key>`). Adding a new label means adding ARB keys — not a literal in a widget.
    - **Keys are grouped per screen.** Each screen's keys form one contiguous block, introduced by a section comment key in this exact shape:
      `"@@_section_<screenName>": "<SCREEN NAME>  |  <path/to/screen.dart>"`
      This is the layout already used in both files (e.g. `@@_section_settingsBackupRestore` → `SETTINGS - BACKUP & RESTORE  |  lib/features/settings/presentation/backup_restore_screen.dart`). Add each new key inside the block of the screen it belongs to, ordered the way it appears on that screen (top to bottom).
    - **New sections go at the end** of the current list, keeping the app-order flow (app-wide → navigation → case screens → shared widgets → settings cluster). Never renumber, rename, or reorder existing keys or sections.
    - **Both languages in the same edit.** `app_en.arb` and `app_bn.arb` must always contain exactly the same keys in exactly the same order; every new key needs a Bengali value carrying the same `{placeholders}`.
    - **Regenerate and verify.** Run `flutter gen-l10n` after any ARB edit (the checked-in generated `app_localizations*.dart` files must be regenerated) and keep `test/l10n/arb_keys_test.dart` green — it fails if the two files diverge in keys or order, if a value is empty, if a Bengali message drops a placeholder, or if a section marker disappears.
    - Seed/domain labels (`pre_seeded_data.dart`) follow the same rule through their `seed*` sections; text that is genuinely seed data rather than a UI label stays as data.
