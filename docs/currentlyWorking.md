### 2026-08-05 — Current Task: Task 07 Add Case form refinements — COMPLETE

Implemented and validated:
- Reduced the Add Case title header's vertical padding and increased the Add Case Save action height.
- Add Case text and dropdown fields now use white empty surfaces and gray filled surfaces while preserving the existing input outline treatment.
- Grouped party fields with an input-sized gap between Petitioner and Respondent groups and before On Behalf.
- Added localized dependency guidance when a disabled cascading field is tapped; notification-off now uses an outlined bell treatment.

`flutter analyze` clean; full suite: 123 tests passed (2 skipped mobile-only).

**Next:** Retest Add Case on a narrow physical device, especially dependency guidance, keyboard scrolling, input-state colors, and notification icon contrast.

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
