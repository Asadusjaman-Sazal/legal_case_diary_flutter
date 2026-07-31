### 2026-07-29 — Current Task: Task 06 Phase 1 (Shared Widgets, Navigation & Router — Router & Shell) — COMPLETE

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
