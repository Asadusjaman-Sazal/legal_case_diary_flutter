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

### Phase 3 — Layout refinements

- **0.0.118** — Picker header pushed down from the top (top padding md→lg); added md spacing between the Month & Year title and the "Total Hearings" count.
- **0.0.119** — Tappable Year and Month selectors: tapping Year opens a scrollable 1926–2126 year grid, tapping Month opens a 12-month grid; selecting either updates the focused date and returns to the day grid (which keeps its fixed 6 rows).
- **0.0.120** — Year/Month headers show a dropdown caret (tappable affordance); tapping an open header closes it back to the day grid. Year list opens scrolled to the current year.
- **0.0.121** — Daily Cause List case card now matches the Active Cases card: added Next Date (alongside Step and Note) via the shared `_ListDetails` layout; removed the now-unused `_DailyCauseDetails`.
- **0.0.122** — Bug fix: AD/HCD cases (Appellate & High Court Division) were missing from every disposal-filtered screen (Active, Upcoming, Overdue, Daily Cause List, Disposed) — they only appeared in All Cases. Root cause: `_stepIsDisposed` left the NULL `lastStep` check unguarded, so `NULL OR resultCheck` propagated NULL through `_isDisposed` and its negation, hiding every higher-court case. Guarded the step check with `lastStep IS NOT NULL`, so higher-court cases are now disposed only when their free-text `result` contains a disposal term (e.g. "Disposed"/"নিষ্পত্তি"). Added regression tests in `test/features/adhcd_disposal_test.dart`. (`cases_dao.dart` only.)
- **0.0.123** — Badge calendar now shows hearing counts for ALL dates (every case with a next date), not just the focused month. Added `CasesDao.countAllByNextDate()` (full-range) and switched the picker to use it; "Total Hearings:" summed the full range across past and future months. (Reverted in 0.0.128 — see below.)
- **0.0.127** — Added left/right swipe on the day grid to change month (Google Calendar style), matching the Add/Edit date picker.
- **0.0.128** — "Total Hearings:" now counts the visible month only (e.g. 10 for January, 25 for February) instead of summing all dates; the all-dates map still drives the per-date hearing badges. This replaces the 0.0.123 all-dates total.
- **0.0.131** — Day cells are now circles (like the Add/Edit & Quick Update pickers). Today when unselected shows a black ring on white with black text; the selected date (today or not) shows black fill + white text, so today no longer stays filled after picking another date. The selected date now persists across screen navigation via a new in-memory Riverpod provider (`dailyCauseListSelectedDateProvider`), defaulting to today on fresh app start.
