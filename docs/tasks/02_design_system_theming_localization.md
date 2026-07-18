# Task 02 — Design System, Theming & Localization

> **Plan references:** "Screen Analysis & Theming Summary", "Resolved Design Clarifications" (App Name, Typography, Localization, Date Format, Backdrop Blur), §11 "Screen-Organized App Translations", `justiceLedger/DESIGN.md`.
> **Goal:** The complete Justice Ledger design system in code plus working Bengali/English localization.
> **Rules:** Follow the Universal Working Rules in `00_INDEX.md`. Ask, don't guess.

---

## Phase 1 — Color, Spacing & Typography Constants

1. `core/constants/app_colors.dart` — Justice Ledger tokens exactly:
   - Primary `#0F172A` (Ink dark), Secondary `#2563EB` (Action blue), Tertiary `#64748B` (Muted gray), Background `#F8FAFC` (Parchment white), Surface `#FFFFFF` with 1px border `#E2E8F0`, Semantic red `#DC2626` (overdue/urgent), Semantic green `#059669` (active/disposed).
2. `core/constants/app_spacing.dart` — derive semantic spacing tokens from the mandatory mockups first. Use a consistent 4/8-based fallback only where a mockup provides no measurable guidance; never override a mockup to fit the fallback, and document every approximation.
3. `core/constants/app_typography.dart` — text styles:
   - **English:** Manrope (headlines), Inter (body), IBM Plex Sans (labels & data such as case numbers).
   - **Bengali:** Tiro Bangla for all Bengali text; line-height `1.5` for Bengali paragraphs.
4. Download/add the four font files to `assets/fonts/` (TiroBangla-Regular.ttf, Manrope variable, Inter variable, IBMPlexSans-Regular.ttf) and register them in `pubspec.yaml`.

**Phase 1 completion:** `flutter analyze` clean; fonts render in a scratch widget. Update `docs/version_history.md`.

## Phase 2 — App Theme

1. `core/theme/app_theme.dart` — build `ThemeData` from the constants above: app bars, cards (white surface + 1px `#E2E8F0` border, flat/stationery aesthetic, high density), buttons (Action blue CTAs), text theme wiring English fonts by role.
2. **Hard rule:** no `BackdropFilter` anywhere. Where mockups show blur/frost, use `Colors.black54` overlays, pre-rendered assets, or `BoxDecoration` gradients (Resolved Design Clarifications, "Backdrop Blur").
3. Apply the theme in `app.dart`.

**Phase 2 completion:** `flutter analyze` clean. Update `docs/version_history.md`.

## Phase 3 — Localization (Bengali default, English switchable)

1. Configure `flutter_localizations` + `intl` with `.arb` files: `core/l10n/app_en.arb`, `core/l10n/app_bn.arb`. **Bengali is the default locale.**
2. Implement `core/l10n/app_translations.dart` per Plan §11:
   - Central, hierarchical nested-map structure grouped **by screen** (`allCasesScreen`, `caseDetailsScreen`, …), settings submenu (`settingsProfile`, `settingsOnlineSync`, …), and shared dialogs/drawers.
   - Also holds translations for **pre-seeded items** (courts, steps, case types, on-behalfs) keyed by their stable IDs — labels are presentation only, never DB keys (Plan "Canonical category rule").
   - Include the client SMS/WhatsApp message template (Plan §9 "Translation Template").
3. Language selection persisted in `SharedPreferences`; a provider exposes the active locale so Settings > Language (Task 12) can toggle it live.
4. `core/constants/app_strings.dart` holds l10n key references (not raw strings).
5. Font switching: Bengali locale text uses Tiro Bangla automatically (via theme/locale-aware text styles).

**Phase 3 completion:** `flutter analyze` clean; a scratch screen shows a string switching between bn/en. Update `docs/version_history.md`.

## Phase 4 — Date Utilities

1. `core/utils/date_utils.dart` per the plan's Timestamp Convention:
   - Epoch-ms ↔ `DD/MM/YYYY` display conversion.
   - Bangladesh **civil date** handling: `next_date`/`hearing_date` normalized to local start-of-day; compared by calendar date, never as UTC instants.
   - "Today"/"Tomorrow" display rule when the local civil date matches (Resolved Design Clarifications, "Next Date Format Rule").
   - `DD/MM/YY | DDD` (localized 3-letter weekday) formatter for the Daily Cause List calendar control.
   - `DD/MM/YY, HH:MM AM/PM` formatter for note cards.
   - Full-date formatter like "Tuesday, October 24, 2023" for Upcoming Cases group headers (localized).
2. Add unit tests for conversions and day-drift safety (Verification Plan, "Timestamp tests").

**Phase 4 completion:** `flutter analyze` clean, tests pass. Update `docs/version_history.md`.

## Alignment Addendum (Implementation Plan Revision 2.4)

- Derive spacing from mandatory mockups and semantic design tokens. Do not impose an invented fixed 4/8 scale where a mockup differs; document any approximation.
- Language is a durable per-user preference in `user_preferences`, with Bengali as the first-run default. Part A persists locally; premium Part B may sync it only through self-scoped preference storage, never firm-shared storage.
- Verify Bengali rendering, live switching, and responsive mobile layout in Task 22.
