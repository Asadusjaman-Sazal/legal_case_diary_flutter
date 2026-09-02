# Legal Case Diary — Version History
This file tracks all modifications made to the **Legal Case Diary** codebase during development. Every edit (even a single-line change) must be logged here immediately with a bumped version number. Update the Current Version section with the latest version and summary after each edit.

### Version Range
- Range: `0.0.1` to `0.0.1000`

### Formatting Rule
- Each change must be logged in the following format:
  `Version: X.Y.Z - [ Brief summary of changes]`

---

## Current Version
Version: 0.0.110 - Upcoming Cases: cases now sort ascending by hearing date (earliest first) and the Tomorrow group header shows "Tomorrow" instead of the full date; all headers keep the thin right-side divider line.

## Version History
Version: 0.0.1 - Finalized implementation plan.
Version: 0.0.2 - Formatted README.md file and initiated the Git.
Version: 0.0.3 - Updated task files.
Version: 0.0.4 - Task 01 Phase 1 complete: Flutter project initialized with Android configuration and minimal entry points.
Version: 0.0.5 - Task 01 Phase 1 (continued): Re-generated Flutter project, added @string/app_name Android labels, created app.dart with ProviderScope, added systemRequirements.md and version_history.md stubs.
Version: 0.0.6 - Task 01 Phase 2 complete: dependencies added (riverpod, go_router, drift, notifications, storage) and resolved; flutter analyze clean.
Version: 0.0.7 - Task 01 Phase 3 complete: folder skeleton created (core, features, shared, database, sync) with 27 stub files; flutter analyze clean.
Version: 0.0.8 - Task 01 Phase 4 complete: database provider and repository interfaces wired; MVVM + Repository architecture scaffolding ready; flutter analyze clean.
Version: 0.0.9 - Task 01 final: complete MVVM+Repository scaffolding with domain-specific repositories, feature data/presentation stubs, database/tables stubs, ViewModel pattern stub, AppDatabase placeholder, and shared widgets; flutter analyze clean.
Version: 0.0.10 - Task 01 Phase 3 complete: exact folder/file skeleton per implementation plan with 41+ stubs; data/presentation structure for all features; shared widgets; tables stubs; flutter analyze clean.
Version: 0.0.11 - Task 01 Phase 3 complete — exact skeleton: 6 widget stubs per plan; 27+ stub files; all features data/presentation; shared widgets; tables stubs; flutter analyze clean.
Version: 0.0.12 - Task 01 Phase 4 complete — AsyncNotifier scaffolding with .select() guidance; MVVM pattern fully wired; flutter analyze clean.
Version: 0.0.13 - Task 02 Phase 1 complete — Justice Ledger color, spacing, and typography constants added; fonts moved to assets/fonts and registered in pubspec.yaml; flutter analyze clean.
Version: 0.0.14 - Task 02 Phase 1 audit fixes — spacing approximations documented; typography scratch widget and test added to verify font rendering; flutter analyze clean, tests pass.
Version: 0.0.15 - Task 02 Phase 2 complete — Justice Ledger ThemeData wired in AppTheme and applied in app.dart (app bars, cards, buttons, text theme); flutter analyze clean, tests pass.
Version: 0.0.16 - Task 02 Phase 3 complete — flutter_localizations + intl wired, ARB files and generated AppLocalizations created, Bengali default locale persisted in SharedPreferences, TiroBangla font switch in AppTheme, localization scratch screen and tests pass.
Version: 0.0.17 - Task 02 Phase 4 complete — Bangladesh-aware date utilities with epoch↔display conversion, civil-date normalization, Today/Tomorrow rule, locale-aware formatters, and unit tests; flutter analyze clean, all tests pass.
Version: 0.0.18 - Bug fix: DateFormat formatting no longer depends on device timezone; bangladeshDateTime() returns a local DateTime so formatters display Bangladesh wall-clock time correctly; flutter analyze clean, all tests pass.
Version: 0.0.19 - Task 03 Phase 1: SQLCipher encrypted Drift backend, key manager with secure storage, DatabaseFactory, and integration tests; flutter analyze clean, all tests pass.
Version: 0.0.20 - Task 03 Phase 1 audit fixes: replaced EOL sqlcipher_flutter_libs with maintained SQLite3MultipleCiphers build hook; wired recovery dialog into DatabaseGuard; flutter analyze clean, all tests pass.
Version: 0.0.21 - Task 03 Phase 2: added per-table Drift definitions for cases, case_history, courts, steps, case_types, on_behalfs, notes, references, sync_queue, court_categories, delete_requests, and conflict_log; fixed data-class name conflicts; flutter analyze clean, all tests pass.
Version: 0.0.22 - Task 03 Phase 2: added per-table Drift definitions for cases, case_history, courts, steps, case_types, on_behalfs, notes, references, sync_queue, court_categories, delete_requests, and conflict_log; fixed data-class name conflicts; added `is_deleted` default false to all push/pull domain tables; flutter analyze clean, all tests pass.
Version: 0.0.23 - Task 03 Phase 2: added per-table Drift definitions for cases, case_history, courts, steps, case_types, on_behalfs, notes, references, sync_queue, court_categories, delete_requests, and conflict_log; fixed data-class name conflicts; added `is_deleted` default false; made required FK and hearing_date non-nullable; added `retry_count` default 0; flutter analyze clean, all tests pass.
Version: 0.0.25 - Task 03 Phase 2 audit fixes: implemented firms_table.dart and firm_members_table.dart (pull-only caches), added missing boolean defaults to conflict_log.isDismissed, notes.isPinned, and references.isPinned; flutter analyze clean, 28 tests pass.
Version: 0.0.24 - Task 03 Phase 2: added per-table Drift definitions for cases, case_history, courts, steps, case_types, on_behalfs, notes, references, sync_queue, court_categories, delete_requests, and conflict_log; fixed data-class name conflicts; added `is_deleted`/`is_custom`/`is_user_modified` defaults; made required FK and hearing_date non-nullable; added `retry_count` default 0; flutter analyze clean, all tests pass.
Version: 0.0.25 - Task 03 Phase 2 audit fixes: implemented firms_table.dart and firm_members_table.dart (pull-only caches), added missing boolean defaults to conflict_log.isDismissed, notes.isPinned, and references.isPinned; flutter analyze clean, 28 tests pass.
Version: 0.0.26 - Task 03 Phase 3 complete: added profiles (pull-only cache), sync_metadata, seed_migrations, user_preferences, and case_notification_preferences tables; registered in AppDatabase; Drift code regenerated; flutter analyze clean, 28 tests pass.
Version: 0.0.27 - Task 03 Phase 4 complete: wired AppDatabase into databaseProvider, added MigrationStrategy skeleton with foreign-key enforcement, standing query helpers filtering is_deleted = 0, purge policy stub, and schema verification tests; flutter analyze clean, 35 tests pass (2 skipped mobile-only).
Version: 0.0.28 - Task 03 Phase 4 audit fixes: added missing activeCourtCategories and activeConflictLog standing query helpers; flutter analyze clean, tests pass (2 skipped mobile-only).
Version: 0.0.29 - Task 04 complete: pre-seeded data with stable deterministic IDs, versioned idempotent seed migration runner, bilingual label maps, 24 seed data tests; flutter analyze clean, all tests pass.
Version: 0.0.30 - Task 04 audit fixes: seed migrations preserve user-modified rows via SQLite UPSERT; in-memory Drift integration tests for runner, idempotency, and preservation; all tests pass.
Version: 0.0.31 - Task 05 Phase 1: implemented 17 DAOs for cases, case history, notes, references, courts, court categories, steps, case types, on-behalfs, profiles, firms, firm members, user preferences, case notification preferences, sync queue, delete requests, and conflict log; soft-delete filtering, search, pagination, watch streams, active/disposed case count heuristic; fixed schema test OnBehalfsCompanion orderIndex fixture; flutter analyze clean, all 63 tests pass.
Version: 0.0.32 - Task 05 Phase 2: implemented local identity placeholder service with localIdentityServiceProvider, SyncWriteHelper with sync column values, offline compaction matrix (insert+update, insert+delete, update+delete, multiple updates), conflict_pending guard, and syncWriteHelperProvider; fixed SyncQueueDao.updateState to use targeted UPDATE ... WHERE; added comprehensive unit tests; flutter analyze clean, 72 tests pass (2 skipped).
Version: 0.0.33 - Task 05 Phase 3: implemented local repositories (Case, Notes, Reference, config courts/categories/steps/case-types/on-behalfs, Settings, DeleteRequests) with sync queue integration, snake_case sync payloads/changed_fields, ownership flags, soft-delete, provisional case_history on nextDate change; fixed DAO update methods to support partial companions; added repository unit tests; flutter analyze clean, 83 tests pass (2 skipped).
Version: 0.0.34 - Task 05 Phase 4: implemented AsyncNotifier-based Riverpod ViewModels for cases, daily cause list, notes, case references, settings, court categories/courts/steps/case types/on-behalfs, and delete requests; added repository providers; created BaseListViewModel; updated auth/payment stubs for Part B; added ViewModel unit tests; flutter analyze clean, 93 tests pass (2 skipped).
Version: 0.0.35 - Task 06 Phase 1: GoRouter wired with ShellRoute for all main screens and top-level routes for case-detail/login/signup/paywall/checkout; AppRoutes constants; landing page resolved from SettingsRepository.defaultLandingPage; back/exit confirmation via PopScope + AlertDialog; all screen stubs converted to minimal StatelessWidgets; app.dart migrated to MaterialApp.router; smoke test updated; flutter analyze clean, 94 tests pass (2 skipped).
Version: 0.0.36 - Task 06 Phase 1 audit fixes: AppShellRoot wired into ShellRoute builder (exit-confirmation was dead code); appRouterProvider changed to FutureProvider so landing page is resolved before GoRouter is constructed; AccountsProfileMenuScreen stub converted to StatelessWidget with route added; OnlineSyncScreen stub file created to replace inline anonymous Scaffold; app.dart updated to handle FutureProvider<GoRouter> with loading state; flutter analyze clean, 94 tests pass (2 skipped).
Version: 0.0.37 - Task 06 Phase 2: implemented AppNavigationDrawer (profile header, grouped nav items with active pill, sideNavOptions visibility, Print/Share callbacks), BottomNavBar (4 configurable tabs from UserSettings.bottomNavTabs, active state highlighting), CasesScreenModal (reusable shell with drawer, header, search/view-toggle/sync buttons, bottom nav, FAB hidden on Disposed Cases); SyncState enum (idle/syncing/success/paused/error); sync button disabled with entitlement tooltip in Part A; new ARB strings for nav labels, sync states, and modal actions in both EN and BN; flutter analyze clean, 94 tests pass (2 skipped).
Version: 0.0.38 - Task 06 Phase 2 audit fixes: (1) sideNavOptions now read from _userSettingsProvider stream and passed to AppNavigationDrawer — drawer visibility is now settings-driven; (2) searchQuery parameter added to CasesScreenModal for Addendum 2.4 scoped-query requirement; (3) _isActive in AppNavigationDrawer now uses item.route instead of item.visibilityKey; (4) replaced per-rebuild FutureBuilder(repo.getSettings()) with _userSettingsProvider StreamProvider — no more tab flash on rebuild; (5) dead _CasesScreenModalInner class removed; (6) drawer profile header now has name/role/subtitle stub slots matching mockup layout. flutter analyze clean, 94 tests pass (2 skipped).
Version: 0.0.39 - Task 06 Phase 3 complete: implemented configurable CaseCard variants with overdue strip and action callbacks, searchable single/multi-select CustomDropdown, plain today-defaulting date picker helper, shared widget barrel exports, localized dropdown strings, and focused widget tests; flutter analyze clean, 100 tests pass (2 skipped).
Version: 0.0.40 - Task 06 Phase 4 complete: implemented the reusable Settings sub-page header/back shell and the Task 09-deferred CalendarPickerDialog boundary with focused widget tests; flutter analyze clean, 103 tests pass (2 skipped).
Version: 0.0.41 - Task 07 complete: implemented the full Add/Edit Case form, cascading court lookups, required-field validation, offline repository save gates, per-user notification preferences, Quick Update history delegation, and regression tests; flutter analyze clean, 107 tests pass (2 skipped).
Version: 0.0.42 - Task 07 audit complete: hardened per-user settings JSON fallback and Quick Update permissions, added regression coverage, and validated 109 tests (2 skipped); CaseCard host wiring deferred to Task 08 stubs.
Version: 0.0.43 - Task 07 remediation complete: atomic Quick Update and form preference saves, localized offsets, explicit On Behalf resolution, All Cases CaseCard wiring, rollback tests, and 113 tests (2 skipped).
Version: 0.0.44 - Task 07 audit fixes: acceptance test 7 now hosts the form via the production modal path (root-route pop crash fixed), acceptance test 9 unmounts the drift watch stream before teardown (pending-timer fixed); premium wording aligned in task file; full suite passes 122 tests (2 skipped).
Version: 0.0.46 - Phone UX fixes: applied app-wide status-bar insets and readable system-bar styling, and deferred the database-driven Add Case form reveal until its modal entrance animation completes; targeted tests pass.
Version: 0.0.47 - Add Case UX refinements: reorganized the form into four sections, improved field ordering and alignment, and added centered searchable single/multi-select pickers.
Version: 0.0.48 - Add Case visual refinements: gray form with white sections, 90% rounded dropdowns, black actions, improved phone/date spacing, and fixed multi-select scrolling.
Version: 0.0.49 - Add Case form refinements: compact title header, larger Save action, state-based input surfaces, grouped party spacing, dependency guidance, and notification icon states.
Version: 0.0.50 - Add/Edit Case form refinements: visible dependency guidance, external field labels, centered section titles, outlined empty fields, and compact weekday dates.
Version: 0.0.51 - Add/Edit Case chrome refinements: black title header and black status bar with white system icons.
Version: 0.0.52 - Add Case court hierarchy defaults: remember each user's latest Higher/Lower Court, Division, and District selections.
Version: 0.0.53 - Add/Edit Case contact and number refinements: single international party phone, split case number/year, date hint, centered dropdown search, and phone/SMS actions.
Version: 0.0.54 - Add/Edit Case refinements: unified case-number input, aligned +88 phone prefix, and compact black calendar actions.
Version: 0.0.55 - Update Window refinements: blank Next Date, immutable Current Next Date, Add Case schedule controls, and matching Save sizing.
Version: 0.0.56 - All Cases Case Card refinements: right-aligned On Behalf labels, Add Case date formatting, stable contact actions, and call target chooser.
Version: 0.0.57 - All Cases Case Card refinements: shared Open with choosers for calls and messages, equal action heights, and slightly smaller party names.
Version: 0.0.58 - All Cases Case Card party names now use the full available card content width so moderately long party names stay on one line when space allows.
Version: 0.0.59 - Task files updated to document the Tiro Bangla fallback requirement and the full-width All Cases party-name layout.
Version: 0.0.60 - Task 07 updated to document Add Case input-box presentation refinements and the current party-phone traceability discrepancy.
Version: 0.0.61 - Task 07 updated to document Update Window behavior and input-control refinements.
t.
Version: 0.0.62 - Task 07 Case Number input now inserts a fixed slash after six digits and limits the suffix to four digits.
Version: 0.0.63 - Task 07 Case Number input now inserts the fixed slash after the first digit and limits the suffix to four digits.
Version: 0.0.64 - Task 07 Case Number input now accepts hyphens and has no suffix-length limit after the fixed slash.
Version: 0.0.65 - Task 07 Case Number caret now remains before the automatic slash until manually moved after i
Version: 0.0.66 - Task 07 Add Case Case Number is now an unrestricted text input.
Version: 0.0.67 - Rev. Task 04/07 Updated Districts & some translations.
Version: 0.0.68 - Task 04 AD/HCD seed replacement with Case Category database support; AD/HCD Steps removed.
Version: 0.0.69 - Clarified AD/HCD-only Case Category scoping; lower Case Types remain court-category scoped.
Version: 0.0.70 - Updated lower-court category seed data and renamed Chattogram display label to Chittagong.
Version: 0.0.71 - Replaced lower-court steps, case types, on-behalfs, and disposed-step seed data from the supplied source.
Version: 0.0.72 - Removed unresolved plain Withdrawal references from four criminal disposed-step lists.
Version: 0.0.73 - Made all lower-court Steps, Case Types, and On Behalfs explicit SeedOption entries.
Version: 0.0.74 - Imported 950 verified lower-court names for eight Dhaka-division districts.
Version: 0.0.75 - Removed invalid Dismissal from district-criminal disposed-step references.
Version: 0.0.76 - Corrected disposed-step tests so Judgement is not treated as disposed.
Version: 0.0.77 - Fixed Exit App confirmation to close the system app instead of popping the root route.
Version: 0.0.79 - Restored Framing of Charge in Sessions and Metropolitan Sessions step seeds.
Version: 0.0.80 - Updated Android, iOS, and web launcher icons from assets/icons/app_logo.png.
Version: 0.0.81 - Task 07 AD/HCD Add/Edit fields, Case Category cascade, Result disposal matching, schema migration, and focused tests.
Version: 0.0.82 - Task 07 localized seed dropdown labels and English development default locale.
Version: 0.0.83 - Task 07 disposal query and AD/HCD regression coverage completed.
Version: 0.0.84 - Task 07 Day Offset and date-picker refinements completed.
Version: 0.0.85 - Task 07 abbreviated calendar header and centered picker actions completed.
Version: 0.0.86 - Task 07 date-picker width aligned with the Update window.
Version: 0.0.87 - Added conditional notes to All Cases card layouts.
Version: 0.0.88 - Enlarged Exit App? Cancel/Exit buttons without bold font.
Version: 0.0.89 - Slightly enlarged Exit App? Cancel/Exit buttons without bold font.
Version: 0.0.90 - Quick Update window shows Result instead of Step for AD/HCD cases.
Version: 0.0.91 - Add/Edit hides Court Categories with no courts for the selected district.
Version: 0.0.92 - Case Card shows Result next to Next Date for AD/HCD cases.
Version: 0.0.93 - Renamed card-only labels to caseCard_ namespace (nextDate, lastStep, disposed).
Version: 0.0.94 - Case card shows "Name of Honorable Judges'" after Name of Court for AD/HCD cases; fixed double-dash (-) in the Quick Update window header.
Version: 0.0.95 - Task 08 complete: built Active, Upcoming, Overdue Dates, and Disposed case-list screens alongside the extended All Cases host (KPI summary, Court Name + Chronology filters, first-come-first-served ordering, scoped search); flutter analyze clean.
Version: 0.0.96 - Overdue Dates card refinements: hide the per-card "Name of Court" column (court is shown in the group header) and relabel the date as "Previous Date" (date value unchanged); added caseCard_previousDate localization (en/bn).
Version: 0.0.97 - Overdue date styling: All/Active cards show a red left stripe and "Previous Date" (red text) when the date is past; the Overdue screen's Case Type/Case Number is black and disposed cards relabel their date "Previous Date"; flutter analyze clean.
Version: 0.0.98 - Disposed Cases card: enabled the Update button (was disabled) so a disposed case can be revived via the Quick Update dialog; flutter analyze clean.
Version: 0.0.99 - Disposed cases now excluded from Upcoming, Overdue, and Daily Cause List: date-range query (getByNextDateRange) filters out disposed cases (only Active and Disposed screens keep them); flutter analyze clean.
Version: 0.0.100 - Disposal detection now matches "Disposed"/"নিষ্পত্তি" as a substring in Steps/Result: a case is disposed even when the step or result text mixes disposal with other steps/words (previously only an exact single-value match counted).
Version: 0.0.101 - Disposal detection now uses the full disposed-step set (Withdrawal, Dismissal, Allowed, Rejected, Acquittal, Conviction, Remand, নিষ্পত্তি, etc.) from pre_seeded_data disposedStepNames instead of only matching the words "disposed"/"নিষ্পত্তি". A case whose Steps contain any disposal step name is now correctly excluded from Active/Upcoming/Overdue and shown in Disposed.
Version: 0.0.102 - Disposed Cases screen now reloads automatically after a Quick Update closes, so reviving a case (removing disposal steps) immediately removes it from the list instead of requiring a manual pull-to-refresh.
Version: 0.0.103 - Disposed Cases screen card rebuilt to a 7-line layout: L1 Step/Result chip + "Disposed:" label, L2 Case Type & Number + last Next Date, L3 Petitioner Vs Respondent, L4 Case Title/Section, L5 Court (judges for higher courts), L6 Note in a quoted box, L7 call/message/update actions. Removed the old history-timeline card variant from this screen.
Version: 0.0.104 - Removed the dead shared `CaseCard.disposed` variant, `CaseCardHistoryEntry`, and `disposedDate`/`historyEntries` params (the Disposed screen uses its own `_DisposedCaseCard`). Updated the widgets test accordingly. flutter analyze clean; phase3 widget tests pass.
Version: 0.0.105 - Disposed Cases card: moved the last Next Date under the "Disposed:" label in line 1 (right side); line 2 now shows only the Case Type & Number (date removed from its right).
Version: 0.0.106 - Fixed Disposed Cases card: the date under the "Disposed:" label now renders as a real DD/MM/YYYY date. The previous code passed "Disposed:" as the today/tomorrow label to formatDisplayDate, so any case disposed today/tomorrow showed the literal "Disposed:" instead of the date.
Version: 0.0.107 - Disposed Cases card: Step/Result chip now hugs its text (removed the Expanded wrapper so the gray background is sized to the text + padding, not the full row), and the date under "Disposed:" uses the same labelMd size as the "Disposed:" label.
Version: 0.0.108 - Disposed Cases card: the "Disposed:" label and its date now sit pinned to the far right of line 1 (added a Spacer between the Step/Result chip and the label column).
Version: 0.0.109 - Disposed Cases: added a Help FAB that opens a "How to set a case as disposed?" dialog listing disposed steps grouped by lower-court category plus the Appellate & High Court Division disposal keywords; dialog content made scrollable.
Version: 0.0.110 - Upcoming Cases: cases now sort ascending by hearing date (earliest first) and the Tomorrow group header shows "Tomorrow" instead of the full date; all headers keep the thin right-side divider line.
