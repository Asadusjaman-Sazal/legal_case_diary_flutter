# Task 08 — Case List Screens (All / Active / Upcoming / Overdue / Disposed)

> **Plan references:** §1 All Cases, §3 Upcoming Cases, §4 Overdue Dates, §6 Disposed Cases, §7 Active Cases.
> **Design references (mandatory):** `mockup_html_screens\allCases\code.html`, `upcomingCases\code.html`, `overdueDates\code.html`, `disposedCases\code.html`. All screens use `cases_screen_modal.dart` for header + bottom nav.
> **Goal:** All five list screens, pixel-faithful to mockups, backed by DAO watch queries.
> **Rules:** Follow the Universal Working Rules in `00_INDEX.md`. Ask, don't guess.

---

## Phase 1 — All Cases Screen

1. Body designed from `allCases\code.html`; shell from `cases_screen_modal.dart`.
2. Primary data source of the app: every case added via the FAB from any case page lands here.
3. **Sorting:** first-come-first-served serial order (first case = serial 1, next = 2, …).
4. **KPI summary:** total Active and Disposed counts at top (per mockup).
5. **Filters:** by Court Name (cases of a selected court category/specific court) and Chronology (newest/oldest first).
6. **Case card lines (exact):**
   - L1: left `case_type` & `case_number` | right On Behalf label
   - L2: `petitioner` Vs `respondent`, using the full available Case Card content width while preserving the existing left inset; the L1 On Behalf label must not consume L2's horizontal space
   - L3: Name of the Court
   - L4: left Next Date (`DD/MM/YYYY`, with Today/Tomorrow rule) | right `last_step`
   - L5: Phone, Message, Update buttons (Update opens the Task 07 Phase 3 pop-up)
7. Card tap → Case Detail screen (Task 10).

**Phase 1 completion:** `flutter analyze` clean. Update `docs/version_history.md`.

## Phase 2 — Active Cases Screen

Exact same screen/logic as All Cases **except**: no KPI summary, no Court Name/Chronology filters, and only cases whose `last_step` is NOT in the disposed-step set from `pre_seeded_data.dart` (disposal is derived — there is no `cases.status` column).

**Phase 2 completion:** `flutter analyze` clean. Update `docs/version_history.md`.

## Phase 3 — Upcoming Cases Screen

1. Body from `upcomingCases\code.html`.
2. Filter: cases with `next_date` in **tomorrow + `upcoming_cases_period`** (SharedPreferences, default 7 days).
3. Grouped by date, newest first; group headers formatted like "Tuesday, October 24, 2023" (localized).
4. Card design identical to the All Cases card.

**Phase 3 completion:** `flutter analyze` clean. Update `docs/version_history.md`.

## Phase 4 — Overdue Dates Screen

1. Body from `overdueDates\code.html`.
2. Filter: `next_date` strictly in the past (before today's local civil date).
3. **Last Updated** status follows the plan's status indicator contract: in Part A show an explicit local/offline state rather than inventing an associate-sync timestamp; in Part B show the latest successful server update for the firm dataset, with distinct pending, syncing, paused, and error states when applicable.
4. Grouped by Court Name maintaining the pre-seeded court hierarchy (same logic as Daily Cause List).
5. **Red left border strip** on every card (urgency indicator — only on overdue cards app-wide).
6. **Card lines (exact):** L1 `case_type` & `case_number` | On Behalf; L2 petitioner Vs respondent; L3 Note (`notes_results`); L4 Next Date with `last_step` directly under it; L5 Phone/Message/Update.

**Phase 4 completion:** `flutter analyze` clean. Update `docs/version_history.md`.

## Phase 5 — Disposed Cases Screen

1. Body from `disposedCases\code.html`. **No FAB on this screen.**
2. Filter: `last_step` in the disposed-step set. Sorted by `next_date` descending (latest disposed on top).
3. **Card lines (exact):** L1 `last_step` | "Disposed:" top-right; L2 `case_type` & `case_number` | `next_date` under "Disposed:"; L3 petitioner vs respondent; L4 Note in the styled box from the mockup; L5 last two `case_history` entries.

**Phase 5 completion:** `flutter analyze` clean; manual pass on all five screens against mockups. Update `docs/version_history.md`.

## Alignment Addendum (Implementation Plan Revision 2.4)

- Every list search is constrained to that screen's existing dataset/filter before applying the text query.
- Active count/listing excludes disposed-step cases; free-tier counts are not sourced from this active count.
- Overdue Last Updated: Part A shows a clear local/offline state. Part B shows latest successful server update for firm data plus explicit pending/error states; never invent a local associate-sync timestamp.
- Phone/message actions resolve the explicitly stored petitioner/respondent phone appropriate to the action target.
- Quick Update history is repository-owned and date-change-only.
