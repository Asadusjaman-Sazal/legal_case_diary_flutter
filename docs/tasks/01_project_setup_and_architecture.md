# Task 01 — Project Setup & Architecture Scaffolding

> **Plan references:** "Proposed Architecture & Subscription Enforcement", "Folder & File Structure", "Development Workflow & Coding Standards" in `docs/implementation_plan.md`.
> **Goal:** A compiling Flutter project with the full folder skeleton, core dependencies, MVVM + Repository + Riverpod architecture wiring, and the process/docs files in place.
> **Rules:** Follow the Universal Working Rules in `00_INDEX.md`. Ask the user when anything is unclear — never guess.

---

## Phase 1 — Flutter Project Initialization

1. Create the Flutter project (`legal_case_diary`) targeting **Android first** (iOS config may exist but is not the current focus; Windows comes much later).
2. Set the app display names: **Legal Case Diary** (English) / **লিগ্যাল কেস ডায়েরি** (Bengali) in the Android manifest.
3. Configure `analysis_options.yaml` with `flutter_lints` (or the project's chosen lint set — ask the user if they want stricter lints).
4. Create `docs/version_history.md` (if not already present) exactly matching the format in Development Workflow §4 of the implementation plan, and `docs/currentlyWorking.md` per §7. Also create `docs/systemRequirements.md` as a stub if missing.
5. Create `main.dart` with a `ProviderScope` wrapping a minimal `App` widget in `app.dart` (placeholder `MaterialApp` for now — real theme/router come in Tasks 02 & 06).

**Phase 1 completion:** Run `flutter analyze`, fix all errors. Update `docs/version_history.md` (new version entry + `## Current Version`).

## Phase 2 — Dependencies

Add these dependencies to `pubspec.yaml` (resolve latest stable versions; if a version conflict arises, ask the user before pinning):

- **State management:** `flutter_riverpod`
- **Routing:** `go_router`
- **Local DB:** `drift`, `drift_dev` (dev), `build_runner` (dev), plus the SQLCipher-compatible backend chosen in Task 03 Phase 1 (do **not** add it yet — Task 03 validates the choice first)
- **Preferences:** `shared_preferences`
- **Localization:** `flutter_localizations` (SDK), `intl`
- **Utilities:** `uuid`, `collection`
- **Notifications (used in Task 13, add now for stability):** `flutter_local_notifications`, `android_alarm_manager_plus`, `android_intent_plus`, `device_info_plus`
- **Connectivity (used in Part B, add later — do NOT add now):** `connectivity_plus`
- **PDF/print (used in Task 14, may defer):** `pdf`, `printing`
- **Launcher:** `url_launcher`
- **Secure storage (key management, Task 03):** `flutter_secure_storage`

> **Do NOT add:** `supabase_flutter` or any networking package — those belong to Part B (Task 17+).

**Phase 2 completion:** `flutter pub get` succeeds, `flutter analyze` clean. Update `docs/version_history.md`.

## Phase 3 — Folder Skeleton

Create the exact folder/file structure from the "Folder & File Structure" section of the implementation plan (empty or stub files where the feature isn't built yet):

```
lib/
├── main.dart
├── app.dart
├── core/constants/  (app_colors.dart, app_typography.dart, app_spacing.dart, app_strings.dart, pre_seeded_data.dart)
├── core/theme/app_theme.dart
├── core/router/app_router.dart
├── core/l10n/  (app_translations.dart, app_en.arb, app_bn.arb)
├── core/utils/  (date_utils.dart, pdf_generator.dart)
├── features/auth/ …          # data + presentation stubs (screens built in Task 17)
├── features/cases/ …         # data + presentation stubs per plan structure
├── features/case_reference/ …
├── features/notes/ …
├── features/payments/ …      # stubs only until Task 21 (paywall UI stub used by Task 15)
├── features/settings/ …
├── features/accounts_and_profile/ …
├── shared/widgets/ …
├── shared/providers/database_provider.dart
├── database/  (app_database.dart + tables/ — real definitions in Task 03)
├── sync/  (sync_service.dart, push_worker.dart, realtime_listener.dart, connectivity_monitor.dart — INTERFACE stubs only in Part A)
└── assets/fonts/  (font files added in Task 02)
```

Stub files must contain a one-line doc comment stating their purpose and which task implements them, so `flutter analyze` stays clean.

**Phase 3 completion:** `flutter analyze` clean. Update `docs/version_history.md`.

## Phase 4 — Architecture Wiring (MVVM + Repository)

1. Implement the layering contract from "Proposed Architecture":
   - **UI Layer** (Widgets/Screens) → **ViewModel Layer** (Riverpod `AsyncNotifier`s) → **Repository Layer** → Local Drift data (Part A) / Remote Supabase (Part B).
2. Create `shared/providers/database_provider.dart` exposing the (not-yet-implemented) `AppDatabase` via a Riverpod provider.
3. Define abstract repository interfaces for the major domains (`CaseRepository`, `NotesRepository`, `ReferenceRepository`, `SettingsRepository`, `AuthRepository`, `ProfileRepository`, `FirmRepository`, `PaymentRepository`) — local implementations arrive in Task 05; remote/sync-aware behavior in Part B. Keeping the interface now guarantees the app is "ready for the Supabase section from the very start."
4. Use Riverpod's `.select()` guidance (Plan §12.3 Rendering Optimization) as the standing pattern for ViewModels.

**Phase 4 completion:** `flutter analyze` clean. Update `docs/version_history.md`.