### 2026-08-25 — Current Task: App launcher icon update — COMPLETE

Implemented and validated:
- Added `flutter_launcher_icons` configuration using `assets/icons/app_logo.png`.
- Generated Android, iOS, and web launcher icon assets.
- `flutter analyze` is clean.

Version `0.0.80`.

**Next:** Resolve the existing CJM `Allowed` disposed-reference mismatch, reset local app data, and continue Task 07 development.

### 2026-08-25 — Current Task: Restore Sessions step seed — IMPLEMENTED; TEST PARTIAL

Implemented:
- Replaced all lower-court Steps, Case Types, On Behalfs, and Disposed references from `docs/seed_data_test/LowerCourt_Steps_CaseTypes_OnBehalf.txt`.
- Generated stable option IDs from English labels and assigned source-list order indexes.
- Added complete Metropolitan Sessions Judge Court options and updated seed tests.
- Removed plain `Withdrawal` from four criminal disposed lists because those categories define only `Withdrawal under Section 248` as a step.
- Replaced tuple-based lower option lists with explicit `SeedOption` entries containing stable IDs, labels, and order indexes.
- Replaced lower-court name placeholders with 950 source records for eight Dhaka-division districts.
- Derived each court division from its district ID, used scoped stable court IDs, and preserved per-category source order indexes.
- Added a focused test for the imported court count, scope, IDs, and order indexes.
- Removed `Dismissal` from the district-criminal disposed references because it is not a seeded district-criminal step.
- Corrected the focused test so `Judgement` is treated as a normal step, not a disposed marker.
- Restored `Framing of Charge` in Sessions and Metropolitan Sessions step seeds with updated source order indexes.
- Replaced the confirmed-exit root navigator pop with `SystemNavigator.pop()` so the operating system closes the app instead of showing a black screen.
- Added generated `ios`, `windows`, and `web` platform folders using the existing application identity without regenerating `android`.
- Flutter analysis is clean. The focused seed test no longer treats `Judgement` as disposed; it now identifies the separate Chief Judicial Magistrate `Dismissal` reference.
- Focused migration tests and restored step-order checks pass; the seed-data suite still reports the existing CJM `Allowed` disposed-reference mismatch.

Version `0.0.79`.

**Next:** Resolve the existing CJM `Allowed` disposed-reference mismatch, reset local app data, and continue Task 07 development.

### 2026-08-22 — Current Task: Lower-court category seed correction — COMPLETE

Implemented and validated:
- Replaced the lower-court category labels with the requested six categories.
- Removed Tribunal seed data and added Metropolitan Sessions Judge Court with empty options for later completion.
- Updated English/Bengali category labels and changed the visible division label from Chattagram to Chittagong.
- Full Flutter test suite passed; `flutter analyze` is clean.

Version `0.0.70`.

**Next:** Add Metropolitan Sessions Judge Court seed options when the authoritative lists are available.

### 2026-08-21 — Current Task: AD/HCD-only Case Category scoping clarification — COMPLETE

Clarified the data contract: Appellate Division and High Court Division Case Types use `case_category_id` in addition to `court_category_id`; lower-court Case Types remain scoped only by `court_category_id`.

Version `0.0.69`.

**Next:** Implement and validate the Task 07 Add/Edit Case AD/HCD fields and Case Category → Case Type UI flow.

### 2026-08-21 — Current Task: Task 04 AD/HCD reference seed and Case Category database support — COMPLETE

Implemented and validated:
- Replaced Appellate Division and High Court Division seed courts, Case Categories, Case Types, and On Behalf options from `docs/AD_and_HCD.txt`.
- Added the `case_categories` Drift table and `case_types.case_category_id`; AD/HCD Steps are intentionally empty.
- Corrected source spelling errors, preserved deterministic ordering/IDs, and applied the idempotent `seed_v2` replacement migration.
- Focused database tests passed; `flutter analyze` is clean.

Version `0.0.68`.

**Next:** Implement and validate the Task 07 Add/Edit Case AD/HCD fields and Case Category → Case Type UI flow.

### 2026-08-13 — Current Task: Task 07 Add Case Case Number unrestricted text input — COMPLETE

Implemented and validated:
- Add Case Case Number is now a plain text input with no formatter, numeric keyboard restriction, or character filtering; other Add Case controls remain unchanged.
- Focused Add/Edit form and Task 07 acceptance tests pass; `flutter analyze` is clean.

Version `0.0.66`.

**Next:** Retest unrestricted Case Number entry on a physical Android device.

### 2026-08-10 — Current Task: Task-file traceability audit — COMPLETE

Add Case and Update Window input-box traceability were also reviewed and recorded in Task 07.

Implemented and validated:
- On Behalf labels are aligned to the far right of the Case Card heading line.
- All Cases Next Date uses the Add Case/Update format `dd/MM/yy, EEE`.
- Phone and Message actions remain visible when the party phone is empty.
- Phone and Message actions show matching Open with choosers for WhatsApp or the native Phone/Message app.
- The Update button matches the contact-action height, and party names use a slightly smaller type size.
- Party names use the full available Case Card content width, preserving the existing left padding while avoiding premature wrapping beside the On Behalf label.
- Task 02, Task 06, Task 07, and Task 08 now document the implemented font, Add Case/Update Window input-box, and All Cases party-name requirements.

`flutter analyze` clean; focused Case Card and Task 07 acceptance tests pass.

**Next:** Retest the All Cases Case Card contact choosers and action sizing on a physical Android device.

### 2026-08-10 — Current Task: Task 07 Update Window refinements — COMPLETE

Implemented and validated:
- Quick Update Next Date now starts blank with the Add Case `Pick a date` hint; saving without a new date preserves the existing Current Next Date.
- Added the Add Case-style Notification toggle, multi-select Day Offset controls, matching date formatting/picker actions, and Save button sizing.
- Added focused acceptance coverage for date independence, schedule controls, picker behavior, notification persistence, and Save sizing.

`flutter analyze` clean; focused Task 07 and Add/Edit widget tests: 17 passed.

**Next:** Retest the Update Window on a narrow physical device, especially date selection versus the immutable Current Next Date summary.

### 2026-08-05 — Current Task: Task 07 Add Case contact and number refinements — COMPLETE

Follow-up refinements completed:
- Restored Case Number to one unified input while preserving slash-separated values such as `207/23`.
- Matched the immutable `+88` prefix height to the Party Phone input.
- Styled Add/Edit calendar Cancel/OK actions as slightly smaller black versions of the multi-select actions.

`flutter analyze` clean; focused form and shared-widget tests pass.

**Next:** Retest the unified Case Number field and calendar actions on a narrow physical device.

Implemented and validated:
- Replaced petitioner/respondent phone columns with one nullable `party_phone` column, including v2→v3 migration and legacy value carryover.
- Added immutable `+88` Party Phone prefix with complete international-number storage and real `tel:`/SMS actions from All Cases.
- Split Case Number into editable number/year parts, preserved existing cases using the final two year digits, added the localized Pick a date hint, and vertically centered dropdown Search text.

`flutter analyze` clean; focused schema, form, and repository tests: 32 passed.

**Next:** Retest Add/Edit and All Cases phone/SMS actions on a physical device, then verify the v3 migration against a pre-existing database.

### 2026-08-05 — Current Task: Task 07 Add Case court hierarchy defaults — COMPLETE

Implemented and validated:
- Add-mode forms now remember the latest per-user Higher/Lower Court, Division, and District selections in the existing local settings JSON.
- Restored lower-court Division/District values are checked against the current cascade; edit-mode forms continue to use the case's own court hierarchy.
- Added settings round-trip and Add Case restoration regression coverage.

`flutter analyze` clean; focused Add/Edit and repository tests pass.

**Next:** Retest Add Case on a physical device and verify the remembered hierarchy remains correct after restarting the app.

### 2026-08-01 — Current Task: Task 07 Add Case UX refinements — COMPLETE

Implemented and validated:
- Reorganized the Add Case form into four rounded sections with the requested field order, counsel labels, phone spacing, aligned Case Type/Case Number controls, and Next Date/Notification plus separate Day Offset layout.
- Switched the form to the gray surface with white sections while preserving the existing input fill color; increased the party separation, placed Next Date as an inline field hint, and made action buttons black.
- Replaced dropdown bottom sheets with centered 90%-screen pickers matching the Update dialog radius, top-right close controls, no search clear icons, compact Search text, and distinct single/multi-select actions; Day Offset remains no-search.
- Fixed the multi-select selected-items area to one horizontally draggable line and enlarged Clear/Done buttons; added regression coverage for the revised interactions.

`flutter analyze` clean; full suite: 123 tests passed (2 skipped mobile-only).

**Next:** Retest the revised form and pickers on the physical phone with a fresh `flutter run`, paying particular attention to scroll fluidity, narrow-screen selected-item scrolling, and keyboard-open picker sizing.

### 2026-07-31 — Current Task: Task 07 — COMPLETE

Implemented and validated:
- Full-screen `AddEditCaseSheet` with all 18 fields, exact stacking/row rules, cascading court hierarchy, searchable court selection, edit prefill, and required-field validation for Higher/Lower Court, lower-court hierarchy, Name of Court, Case Type, Case Number, and Next Date.
- Offline repository-backed add/edit saves, 50-case free-tier paywall gate, per-user case notification preference JSON persistence, and firm-member permission checks with fail-closed cache behavior.
- Mockup-aligned Quick Update dialog delegating date/step/note changes through an atomic `CaseRepository` transaction; ordinary edits do not create history.
- Notification offset labels are localized in English and Bengali.
- On Behalf persistence now accepts an explicit valid selection or infers only a sole available role; multiple roles never default silently.
- The production All Cases host renders repository-backed `CaseCard`s and wires `onUpdate` to `QuickUpdateCaseDialog`; remaining Task 08 list hosts stay deferred stubs.
- Regression tests cover form layout/cascades/permissions, settings JSON fallback, On Behalf resolution, ordinary update history exclusion, quick-update history creation, and atomic rollback on history failure.

`flutter analyze` clean, full suite: 122 tests passed (2 skipped mobile-only).

Dev-testing note: the default landing page is All Cases (not the Task 09 Daily Cause List stub) so the Task 07 Add/Edit form is reachable on-device; revert `defaultLandingPage` to `'daily_cause_list'` when Task 09 lands.

**Next:** Task 08 case-list implementation can extend the shared host pattern to the remaining list screens.

### 2026-07-31 — Current Task: Task 06 Phase 4 — COMPLETE

Implemented and validated:
- `SettingsSubPageModal` reusable mobile-first Settings shell with themed app header, accessible back button, optional trailing actions, and injectable body content.
- `CalendarPickerDialog` Task 09-deferred dialog boundary; badge counts, month navigation, and Daily Cause List date selection remain deferred to Task 09.
- Focused Phase 4 widget tests covering rendering, custom/default back behavior, and calendar-shell composition.

`flutter analyze` clean, focused Phase 4 tests: 3 passed, full suite: 103 tests passed (2 skipped mobile-only).

**Next:** Task 07 Phase 1 — Add/Edit Case form.

### 2026-07-31 — Current Task: Task 06 Phase 3 — COMPLETE

Implemented and validated:
- `CaseCard` variants for list, Daily Cause List, overdue, and disposed layouts; overdue-only red left strip; Phone, Message, and Update callbacks.
- Searchable single-select and multi-select `CustomDropdown` with localized search, empty-state, and confirmation labels; optional field key for forms/tests.
- Plain Material date-picker helper defaulting to today's date, with date-only normalization and invalid-range protection.
- `shared_widgets.dart` converted to a public barrel export; ARB/generated/AppTranslations localization surfaces updated.
- Focused Phase 3 widget tests added.

`flutter analyze` clean, full suite: 100 tests passed (2 skipped mobile-only).

**Next:** Task 06 Phase 4 — `settings_sub_page_modal.dart` and `calendar_picker_dialog.dart` stub.

### 2026-07-29 — Current Task: Task 06 Phase 2 audit fixes — COMPLETE

Fixed 6 issues found in audit:
- (1) `sideNavOptions` now read from `_userSettingsProvider` stream and passed to `AppNavigationDrawer` — drawer item visibility is now settings-driven.
- (2) `searchQuery` parameter added to `CasesScreenModal` — Addendum 2.4 scoped-query requirement met.
- (3) `_isActive` in `AppNavigationDrawer` now uses `item.route` instead of `item.visibilityKey` — latent naming bug fixed.
- (4) Replaced per-rebuild `FutureBuilder(repo.getSettings())` with `_userSettingsProvider` `StreamProvider` backed by `repo.watchSettings()` — no more tab flash on rebuild, stable across widget rebuilds.
- (5) Dead `_CasesScreenModalInner` class removed.
- (6) Drawer profile header now has name/role/subtitle stub slots (`displayName`, `roleLabel` params) matching the mockup layout.

`flutter analyze` clean, 94 tests pass (2 skipped mobile-only).

**Next:** Task 06 Phase 3 — `case_card.dart`, `custom_dropdown.dart`, date picker helper.

Implemented in Phase 2:
- `lib/shared/widgets/app_navigation_drawer.dart` — full drawer with profile header, grouped nav items (Upcoming, Daily Cause List, All Cases, Disposed Cases | Case Reference, Notes, Settings | Print, Share), active item `secondaryContainer` pill, `sideNavOptions`-driven visibility.
- `lib/shared/widgets/bottom_nav_bar.dart` — 4 configurable tabs from `UserSettings.bottomNavTabs`; active tab highlighted; supports all 6 possible tab keys.
- `lib/features/cases/presentation/cases_screen_modal.dart` — reusable shell: drawer + header (title, search, view-toggle, sync button), `BottomNavBar` driven by settings, FAB hidden when `showFab: false` (Disposed Cases), Print/Share callbacks forwarded to drawer.
- `SyncState` enum (idle/syncing/success/paused/error) in `cases_screen_modal.dart`.
- Sync button: 5 accessible states; disabled with `sync_unavailable` tooltip when `isPremium: false`.
- New ARB strings added to `app_en.arb` and `app_bn.arb`: nav labels, sync states, modal actions. `flutter gen-l10n` regenerated.

`flutter analyze` clean, 94 tests pass (2 skipped mobile-only).

**Next:** Task 06 Phase 3 — `case_card.dart`, `custom_dropdown.dart`, date picker helper.

Fixed 3 issues found in audit:
- `AppShellRoot` (containing `PopScope` exit-confirmation) was defined but never wired into `ShellRoute.builder` — fixed by wrapping `AppShellRoot(child: DatabaseGuard(child: child))`.
- `appRouterProvider` was a synchronous `Provider<GoRouter>` where the async `whenData` mutation of `initialLocation` had no effect — changed to `FutureProvider<GoRouter>` that awaits settings before constructing the router.
- `AccountsProfileMenuScreen` was still a bare class stub — converted to `StatelessWidget` and route `/settings/account-profile` added.
- `OnlineSyncScreen` stub file created at `lib/features/settings/presentation/online_sync_screen.dart` to replace the inline anonymous `Scaffold` in the router.
- `app.dart` updated to watch `FutureProvider<GoRouter>` with a `CircularProgressIndicator` loading state.

`flutter analyze` clean, 94 tests pass (2 skipped mobile-only).

**Next:** Task 06 Phase 2 — `cases_screen_modal.dart`, `app_navigation_drawer.dart`, `bottom_nav_bar.dart`.

Implemented in Phase 1:
- `lib/core/router/app_router.dart` — full GoRouter with `ShellRoute` wrapping all main screens (daily-cause-list, all-cases, active-cases, upcoming-cases, overdue-dates, disposed-cases, notes, case-reference, settings tree); top-level routes for case-detail/:caseId, login, signup, paywall, checkout; `AppRoutes` path constants; `AppShellRoot` with `PopScope` exit-confirmation dialog (Dev Workflow §6).
- `lib/app.dart` — migrated from `MaterialApp` + hardcoded home to `MaterialApp.router` wired to `appRouterProvider`; landing page resolved from `SettingsRepository.defaultLandingPage`.
- All 20+ screen stubs converted from bare classes to minimal `StatelessWidget`s so GoRouter can render them.
- `test/widget_test.dart` — smoke test updated to assert router lands on Daily Cause List stub.

`flutter analyze` clean, 94 tests pass (2 skipped mobile-only).

**Next:** Task 06 Phase 2 — `cases_screen_modal.dart`, `app_navigation_drawer.dart`, `bottom_nav_bar.dart`.

### 2026-07-29 — Current Task: Task 05 Phase 4 (Repositories, DAOs & State Management — Riverpod ViewModels) — COMPLETE

Implemented in Phase 4:
- `lib/core/providers/repository_providers.dart` — central FutureProviders for all repositories.
- `lib/core/presentation/base_list_viewmodel.dart` — reusable `AsyncNotifier` base for list-backed ViewModels.
- `lib/features/cases/presentation/case_viewmodel.dart` and `daily_cause_list_viewmodel.dart` — case list/KPI and daily cause list ViewModels.
- `lib/features/notes/presentation/notes_viewmodel.dart`, `lib/features/case_reference/presentation/reference_viewmodel.dart` — notes and case reference ViewModels.
- `lib/features/settings/presentation/settings_viewmodel.dart`, `config_viewmodels.dart`, `delete_requests_viewmodel.dart` — settings and reference-data ViewModels.
- `lib/features/auth/presentation/auth_viewmodel.dart`, `lib/features/payments/presentation/payment_viewmodel.dart` — Part B stubs.
- `test/features/viewmodels_test.dart` — unit tests for Case, Notes, Reference, CourtCategories, and Settings ViewModels.

`flutter analyze` clean, 93 tests pass (2 skipped mobile-only).

**Next:** Task 06 — Shared widgets, navigation, and router.
