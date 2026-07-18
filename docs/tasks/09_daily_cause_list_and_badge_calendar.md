# Task 09 — Daily Cause List & Badge Calendar Picker

> **Plan references:** §2 "Daily Cause List Screen", §2.1 "Badge Calendar Picker", Resolved Design Clarifications ("Calendar & Pickers").
> **Design reference (mandatory):** `mockup_html_screens\dailyCauseList\code.html` (screen body, case card, calendar picker model, Update pop-up).
> **Goal:** The app's flagship screen — today's hearings grouped by court — plus the badge calendar (used ONLY here).
> **Rules:** Follow the Universal Working Rules in `00_INDEX.md`. Ask, don't guess.

---

## Phase 1 — Screen Body & Grouping

1. Body from `dailyCauseList\code.html`; shell from `cases_screen_modal.dart`.
2. Source: All Cases dataset filtered to the selected local civil date (default: today).
3. **Grouping:** by Court Name, strictly in the pre-seeded court hierarchy order (Supreme Court Appellate → High Court → lower courts: sessions, civil, magistrate, executive, tribunals).
4. **KPI:** total case count on the right of each Court Name header.
5. **Card lines (exact):** L1 `case_type` & `case_number` | On Behalf; L2 petitioner Vs respondent; L3 `case_title_and_section`; L4 left `last_step` | right Note (`notes_results`) — **no Next Date on this card**; L5 Phone/Message/Update.

**Phase 1 completion:** `flutter analyze` clean. Update `docs/version_history.md`.

## Phase 2 — Date Controls

1. Quick buttons **Today** and **Tomorrow** filtering `next_date` by those civil dates.
2. To the right: calendar control showing `DD/MM/YY | DDD` (3-letter localized weekday). Tapping it opens the badge calendar picker (Phase 3). Selecting any date filters the list to that date.

**Phase 2 completion:** `flutter analyze` clean. Update `docs/version_history.md`.

## Phase 3 — Badge Calendar Picker (`calendar_picker_dialog.dart`)

Per §2.1 and the mockup's calendar model:
1. Date-cell badges: red/gray badge over each date showing that date's hearing count (confirm with the user the exact red-vs-gray rule if the mockup is ambiguous).
2. Monthly total hearing count under the month title.
3. **Fixed seven-row height:** one weekday-header row + six date rows; fill leading/trailing cells so the dialog never shifts vertically between months.
4. Counts come from an efficient DAO aggregate query (hearings per date for the visible month) — do not load all cases into memory.
5. This calendar is used **only** on the Daily Cause List; every other picker in the app remains a simple picker defaulting to today.

**Phase 3 completion:** `flutter analyze` clean; manual test across month boundaries and Bengali locale. Update `docs/version_history.md`.
