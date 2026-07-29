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

Implemented in Phase 3:
- `lib/features/cases/data/case_repository.dart` — insert/update/soft-delete with provisional `case_history` creation when `nextDate` changes in quick-update mode.
- `lib/features/notes/data/notes_repository.dart`, `lib/features/case_reference/data/reference_repository.dart` — CRUD, pin/unpin, search, and sync enqueueing.
- `lib/features/settings/data/{court_categories,courts,steps,case_types,on_behalfs}_repository.dart` — config CRUD with ownership (`userId`/`firmId`), `isCustom`/`isUserModified` flags, ordering, and built-in delete guards.
- `lib/features/settings/data/settings_repository.dart` — per-user preferences backed by `user_preferences`; no sync enqueueing by design.
- `lib/features/settings/data/delete_requests_repository.dart` — local create/list for delete requests.
- `lib/core/repositories/base_local_repository.dart` — shared `toSyncPayload` helper that converts Drift camelCase JSON keys to snake_case for sync payloads.
- Updated 10 DAO `update` methods from `.replace()` to targeted `.write()` to support partial companions.
- `test/features/repositories_test.dart` — repository tests covering insert/soft-delete, pin/unpin, search, ownership, queue ordering, snake_case payload/changed_fields, and provisional history.

`flutter analyze` clean, 83 tests pass (2 skipped mobile-only).

**Next:** Task 05 Phase 4 — ViewModels (Riverpod AsyncNotifier).
