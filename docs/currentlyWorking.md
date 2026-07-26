# Current Work

### 2026-07-26 17:05 — Current Task: Task 03 Phase 2 audit fixes complete — implemented firms and firm_members tables (pull-only caches), added missing boolean defaults to conflict_log.isDismissed, notes.isPinned, and references.isPinned; flutter analyze clean, 28 tests pass (2 skipped mobile-only)
### 2026-07-26 16:05 — Current Task: Task 03 Phase 2 complete — added per-table Drift definitions for cases, case_history, courts, steps, case_types, on_behalfs, notes, references, sync_queue, court_categories, delete_requests, and conflict_log; fixed data-class name conflicts; flutter analyze clean, 28 tests pass (2 skipped mobile-only)
### 2026-07-26 15:25 — Current Task: Task 03 Phase 1 audit fixes complete — replaced EOL sqlcipher_flutter_libs with maintained SQLite3MultipleCiphers build hook; wired recovery dialog into DatabaseGuard; flutter analyze clean, 28 tests pass (2 skipped mobile-only)
### 2026-07-26 13:45 — Current Task: Task 02 Phase 4 complete — Bangladesh-aware date utilities with epoch↔display conversion, civil-date normalization, Today/Tomorrow rule, locale-aware formatters, and unit tests; flutter analyze clean, all tests pass
### 2026-07-26 — Hotfix: DateFormat timezone bug fixed; bangladeshDateTime() now returns a local DateTime to ensure formatters display Bangladesh wall-clock time regardless of device timezone

## Completed
- Phase 1: Flutter project init, Android bilingual label, main/app entry points, docs files (Task 01)
- Phase 2: All permitted dependencies added and resolved successfully (Task 01)
- Phase 3: Complete folder skeleton with core/features/shared/database/sync stubs (Task 01)
- Phase 4: MVVM + Repository architecture fully wired with AppDatabase placeholder, repositories, ViewModels, shared widgets, and typed provider (Task 01)
- Phase 1: Justice Ledger color, spacing, and typography constants; fonts registered (Task 02)
- Phase 2: ThemeData wired in AppTheme and applied in app.dart (Task 02)
- Phase 3: flutter_localizations + intl wired, ARB files and generated AppLocalizations, Bengali default locale persisted, TiroBangla font switch (Task 02)
- Phase 4: Bangladesh-aware date utilities with epoch↔DD/MM/YYYY conversion, civil-date normalization, Today/Tomorrow display rule, locale-aware formatters, and unit tests (Task 02)

## Active contracts
- Date utilities use Bangladesh timezone (UTC+6, no DST) for all civil-date logic.
- `next_date`/`hearing_date` are normalized to Bangladesh start-of-day and compared by calendar date.
- All date formatters are locale-aware (en/bn) via `intl`.
- `initializeDateFormatting()` is called before `runApp` to support non-English date symbols.
- All tests pass; `flutter analyze` is clean.

## Files currently involved
- lib/core/utils/date_utils.dart (Task 02 Phase 4)
- lib/main.dart (intl date formatting initialization)
- test/core/utils/date_utils_test.dart (Task 02 Phase 4 tests)
- docs/version_history.md (v0.0.18)
- docs/currentlyWorking.md (this file)
- pubspec.yaml (version bump to 0.0.18)

## Next actions
- Task 03: Local database with Drift and SQLCipher encryption

## Last checks
- flutter analyze: CLEAN ✓
- flutter test: ALL PASS (21 tests) ✓
- Bangladesh civil-date boundary (UTC 18:00): verified ✓
- Locale-aware date formatting (en/bn): verified ✓

## Blockers
None
