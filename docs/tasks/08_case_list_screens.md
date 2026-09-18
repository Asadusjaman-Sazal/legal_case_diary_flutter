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
   - L3: Name of the Court, followed by the `honorable_judges` value (Name of Honorable Judges') when the case is filed in an Appellate or High Court Division court
   - L4: left Next Date (`DD/MM/YYYY`, with Today/Tomorrow rule) | right `last_step` (for lower-court cases) or `result` (for AD/HCD cases, which have no `last_step`)
   - L5: Phone, Message, Update buttons (Update opens the Task 07 Phase 3 pop-up)
7. Card tap → Case Detail screen (Task 10).

**Phase 1 completion:** `flutter analyze` clean. Update `docs/version_history.md`.

### Phase 1 — refinements

- **0.0.132** — Removed the search box that sat between the Active/Disposed count row and the filter options. The Active/Disposed count box (KPI summary) is now ~40% smaller (padding, corner radius, and label/value fonts all scaled by 0.6). The Court filter and Newest/Oldest order dropdown are unchanged. (`all_cases_screen.dart` only.)

## Phase 2 — Active Cases Screen

Exact same screen/logic as All Cases **except**: no KPI summary, no Court Name/Chronology filters, and only cases whose `last_step` is NOT in the disposed-step set from `pre_seeded_data.dart` (disposal is derived — there is no `cases.status` column). For AD/HCD cases, which have no `last_step`, exclude those whose `result` contains a configured disposal term (same derived rule as Phase 5).

**Source of truth:** a sorted-out subset of the All Cases dataset.

**Phase 2 completion:** `flutter analyze` clean. Update `docs/version_history.md`.

## Phase 3 — Upcoming Cases Screen

1. Body from `upcomingCases\code.html`.
2. **Source of truth:** a sorted-out subset of the All Cases dataset.
3. Filter: cases with `next_date` in **tomorrow + `upcoming_cases_period`** (SharedPreferences key `upcoming_cases_period`, set in Settings > View Settings > Upcoming Cases Period, default 7 days).
4. Grouped by date, newest first; group headers formatted like "Tuesday, October 24, 2023" (localized).
5. Card design identical to the All Cases card (exact same fields).

**Phase 3 completion:** `flutter analyze` clean. Update `docs/version_history.md`.

## Phase 4 — Overdue Dates Screen

1. Body from `overdueDates\code.html`.
2. Filter: `next_date` strictly in the past (before today's local civil date).
3. **Last Updated** status follows the plan's status indicator contract: in Part A show an explicit local/offline state rather than inventing an associate-sync timestamp; in Part B show the latest successful server update for the firm dataset, with distinct pending, syncing, paused, and error states when applicable.
4. Grouped by Court Name maintaining the pre-seeded court hierarchy (same logic as Daily Cause List).
5. **Red left border strip** on every card (urgency indicator — only on overdue cards app-wide).
6. **Card lines (exact):** L1 `case_type` & `case_number` | On Behalf; L2 petitioner Vs respondent; L3 Note (`notes_results`); L4 Next Date with `last_step` (lower-court) or `result` (AD/HCD) directly under it; L5 Phone/Message/Update.

**Phase 4 completion:** `flutter analyze` clean. Update `docs/version_history.md`.

### Phase 4 — refinements

- **0.0.201** — The court heading's case count is the number alone, in the active language's digits, matching the Daily Cause List and Upcoming Cases court titles: it was `'${group.cases.length} Cases'` (ASCII count plus a hard-coded English word, no ARB key, so বাংলা read `2 Cases`) and is now `AppDateUtils.formatDigits(group.cases.length, l.localeName)` (`2` in English, `২` in বাংলা). No ARB key was needed because the word is gone. (`overdue_dates_screen.dart` only; grouping, ordering, the court-name seed lookup and the cards are unchanged.)

## Phase 5 — Disposed Cases Screen

1. Body from `disposedCases\code.html`. **No Add Case FAB on this screen** (a disposed case is not created here). The mockup's bottom-right FAB is a **Help FAB** (`help_outline` icon) — see item 5.
2. **Source of truth:** a sorted-out subset of the All Cases dataset.
3. Filter: `last_step` in the disposed-step set from `pre_seeded_data.dart` **or** an AD/HCD `result` containing a configured disposal term (Plan §6 — AD/HCD cases have no `last_step`, so Result is the only disposal signal for them). Sorted by `next_date` descending (latest disposed on top). Do **not** build the mockup's `All Disposed | Settled | Dismissed | Disposed` filter-chip row (explicitly out of scope).
4. **Card layout — match `disposedCases\code.html` exactly (this card is structurally different from the other list cards; do not reuse the standard list card):**
   - **Outcome chip:** a small rounded, tinted status chip above the case number showing the disposal outcome (mockup examples: `SETTLED` green-tinted, `DISMISSED` red/error-tinted). Derived from `last_step` (or AD/HCD `result`); tint by outcome family.
   - **Top-right block:** a `Disposed:` label with the `next_date` (the date the case was disposed) directly beneath it.
   - **Case number:** `case_type` & `case_number` in the case-number style, beneath the chip.
   - **Parties:** `petitioner` vs `respondent` in title style.
   - **Final result / Note box:** `notes_results` shown inside the mockup's styled quote box — italic text with a left accent border (`border-l-4`), rounded, on a subtle container fill.
   - **Case History timeline:** an uppercase `Case History` header, then the **last two** `case_history` entries rendered as a vertical timeline (left rail with ring dots; the latest/top entry emphasized in the secondary color and bold; each entry shows its date and description).
   - **No Phone/Message/Update action row** on this card (unlike All/Active/Upcoming/Overdue).
5. **Help FAB + Guidelines modal (per mockup):** a bottom-right `help_outline` FAB opens a "How to set a case as disposed?" modal explaining that choosing a disposal step while updating a case's date moves it here, that the case remains in the All Cases list, and listing the **Disposed Keywords** as chips (আপোষ মিমাংসা, প্রত্যাহার, খারিজ, নিষ্পত্তি, ২৪৮ ধারায় প্রত্যাহার, সাজা, রিমান্ডে প্রেরণ (R), নথিজাত, অব্যহতি, পদক্ষেপ নেওয়ার প্রয়োজন নেই, খালাস), with a "Got it" dismiss button. No `BackdropFilter` — use a plain scrim per the plan's performance rule.

**Phase 5 completion:** `flutter analyze` clean; manual pass on all five screens against mockups. Update `docs/version_history.md`.

## Phase 6 — Case List Extended View (0.0.203, user-requested)

The header's compact ↔ expanded toggle existed in `cases_screen_modal.dart` but was never wired, and `case_list_display_mode` was stored without a consumer. Both now exist, for the six case-list screens only (**not** Notes or Case Reference, which share the shell but have no case list — the toggle renders only when a host wires it).

1. **One stored preference.** The mode is the existing `case_list_display_mode` (`compact` / `expanded`, default `compact`) inside `user_preferences`; the header writes it and Settings → View Settings → Case List Display reads it, so the two cannot disagree. No new key, no schema change, no ARB change (both toggle tooltips already existed).
2. **Reads vs writes.** Screens read it through `core/providers/settings_providers.dart` (`userSettingsStreamProvider`, the live Drift row) and write through `setCaseListViewMode` in `features/cases/presentation/case_list_view_mode.dart`, which reads the whole row before saving (so no other preference can be lost while the ViewModel state is loading) and then invalidates `settingsViewModelProvider` — View Settings renders that ViewModel, and without the invalidation it would keep showing the mode the app started with. Renders must come from the stream; the ViewModel reports `loading` between a write and its refresh, and a nullable state would flash the compact list mid-toggle.
3. **The row — `shared/widgets/case_table_row.dart`.** `CaseTableRow` takes the same arguments as `CaseCard` (reusing `CaseCardVariant`) and lays them out horizontally in the mockup's `overdueDates\code.html#tableView` chrome: serial cell → bordered Update column → date column → step/result column → the case block (case number, parties, title/section, court · judges, note) → phone/message column. **Full data parity** with the compact card is a deliberate deviation from that mockup's thinner row (user-approved); the row uses the app-wide `cardRadius` token like every other card, and squares its left corners against the overdue strip. The column rules sit on the 8 px gutter rather than 12 px (three of them would cost more width than the case block can spare), and the on-behalf chip in the case block is **width-capped at 104 px** — the role can be a name the user typed themselves, and the case number is the primary label, so the chip ellipsises instead of pushing the number out or overflowing the row on a 360 dp phone.
4. **`CaseTableBody` is the scroll contract.** The mockup's table is `min-w-[600px]` with `overflow-x-auto`, so the extended body is laid out at the wider of the viewport and `CaseTableRow.minWidth` inside a horizontal scroll view. It must wrap the list **outside** `RefreshIndicator` and inside it, in this order: `CaseTableBody → RefreshIndicator → ListView`, so the vertical scroll notification still reaches the refresher at depth 0.
5. **Serial numbers.** Only the flat lists number rows — All Cases, Active Cases, Disposed Cases. The number is the screen's own running order (`index + 1` over the visible, ordered list, so search/filtering/Newest-First renumber from 1), which is how plan line 138's first-come-first-served serial reads in a filtered view; it is rendered with `AppDateUtils.formatDigits(serial, l.localeName)` so বাংলা shows ১. The grouped screens (Daily Cause List, Upcoming Cases, Overdue Dates) keep their date/court headings and carry no serial, and both modes keep the overdue red strip on Overdue Dates.
6. **Empty states, search, sync, pull-to-refresh and the FABs are untouched** in either mode, and each screen's card and row are built in the same file (`_buildCaseCard` next to `_buildCaseRow`) so the two views cannot drift apart unnoticed.

**Phase 6 completion:** `flutter analyze` clean. Covered by `test/features/case_list_view_mode_test.dart` (9), including a 360 dp narrow-phone case that asserts the body scrolls horizontally and nothing overflows.

## Alignment Addendum (Implementation Plan Revision 2.4)

- Every list search is constrained to that screen's existing dataset/filter before applying the text query.
- Active count/listing excludes disposed-step cases; free-tier counts are not sourced from this active count.
- Overdue Last Updated: Part A shows a clear local/offline state. Part B shows latest successful server update for firm data plus explicit pending/error states; never invent a local associate-sync timestamp.
- Phone/message actions resolve the explicitly stored petitioner/respondent phone appropriate to the action target.
- Quick Update history is repository-owned and date-change-only.
- **Serial numbers (0.0.203):** the extended view's serial is the screen's own visible running order, not a stable per-case ordinal — plan line 138's "first, second, third" describes the unfiltered list, and a filtered or Newest-First list is expected to renumber (user-approved). Serials appear on the flat lists only.
