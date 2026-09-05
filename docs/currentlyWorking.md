### 2026-09-05 — Task 11 Notes detail view (Google Keep full screen) — COMPLETE

- **Pin bug fixed**: `notes_dao.dart` `setPinned` was calling `db.update(db.notes).write(...)` with **no `where` clause**, so pinning toggled `isPinned` on every row — the card's delete still worked because `delete` had its `where`. Added `..where((row) => row.id.equals(id))`.
- Replaced the add/edit bottom sheet with `lib/features/notes/presentation/note_detail_screen.dart`: a full-screen `Scaffold` opened via `Navigator.push(MaterialPageRoute)` (no nav panel / bottom nav), matching the mockup's "View/Edit Note Modal".
- Top bar: Back (`arrow_back`), Pin (`push_pin`, tinted `secondary` when pinned), Delete (`delete_outline`), Check (`check` = save & close). New notes disable Pin/Delete until saved.
- Content: centered (`maxWidth 768`) scrollable Title textarea (`headlineLg`, `primary`) + Note textarea (`bodyLg`, `onSurface`), borderless placeholders "Note title" / "Enter your note here...".
- Bottom bar: "Modified: date time" (`AppDateUtils.formatNoteCardDate`).
- Card tap and FAB now push `NoteDetailScreen`; the card still keeps its inline Delete (with confirm) and Pin buttons. Added l10n keys `notesScreen_noteBodyPlaceholder`, `notesScreen_drafting` (en/bn). `flutter analyze` clean. Version `0.0.142`.

### 2026-09-05 — Task 11 Phase 1 Notes screen — COMPLETE

- Built `lib/features/notes/presentation/notes_screen.dart` (was a "Task 11" stub). Reuses `CasesScreenModal` for the nav panel, search button, and FAB; lists notes via `notesViewModelProvider` (pinned-first, then `created_at` desc).
- Note card mirrors the mandatory mockup `mockup_html_screens/notes/code.html`: modified date + Delete/Pin action row, bold enlarged title, 3-line-clamped body. Hover border (`AppColors.secondary`) + elevation preserves the mockup's selection/hover effect.
- Search toggles an inline field that filters the watched list in-memory over title+body. Add/Edit opens a bottom sheet (`NotesCompanion` via `addNote`/`updateNote`). Pin toggles `setPinned`. Delete shows `showDialog<bool>` confirmation using existing `sharedDialogs_*` keys.
- Added the two editor field keys + empty/no-results/required keys to `app_en.arb`/`app_bn.arb` and regenerated l10n.
- Aligned `notes_dao.dart` `getAll`/`watchAll` secondary sort to `createdAt` (was `updatedAt`) per plan §9.
- `flutter analyze` clean. Version `0.0.141`. Next resume point: **Task 11 Phase 2 (Case Reference screen)**.

### 2026-09-05 — Task 10 Case History date ordering + Step alignment — COMPLETE

- Case Detail **Case History section only**: rows now sort **newest-first by each row's own displayed date** (`hearing_date`) instead of the DAO's stored `next_date` key, so the visible timeline always reads chronologically even when entries were added or edited out of date order (secondary keys: `next_date`, then `updated_at`, keep same-day rows deterministic). The DAO keeps its `next_date` contract for other callers; the screen re-sorts in `_load`.
- Step/Result content text is now **left aligned** (`TextAlign.left`, per request); the Note keeps its justified alignment, and Step keeps the Note's size (14/20) + bold (`w600`) from 0.0.139.
- Tests (in `test/features/case_detail_test.dart`): Step alignment assertions changed `justify` → `left` (Note stays `justify`), and a new test seeds entries whose stored next-dates disagree with their displayed dates to prove the section orders by the row's displayed date. `flutter analyze` clean; full suite 179 passed, 2 skipped. Version `0.0.140`. Known issues: none. Next resume point: **Task 11** (see `docs/tasks/00_INDEX.md` / implementation plan).

### 2026-09-05 — Task 10 Case History Show/Hide + sticky title — COMPLETE

- Case Detail **Case History section only**: a compact **Show** button now sits right of "N Entries Total" (only when more than 3 entries); tapping it expands every history entry and the button becomes **Hide** to fold back to the default newest-3 view (the old "View All N History Entries" row remains for the collapsed state and disappears while expanded).
- While fully expanded, the **Case History title row (icon + label + count + Show/Hide) is sticky at the top of the screen** via `PinnedHeaderSliver` on a `CustomScrollView` (screen body converted from `ListView`; visual layout/padding/physics unchanged); collapsed (<all entries) renders the original plain card with a non-sticky title.
- Step/Result content text is now the **same size as the Note content (14/20, `bodyMd`)** but stays **bold** (`w600`); justify alignment from 0.0.138 unchanged.
- New l10n keys (en + bn): `caseDetailsScreen_showHistory` / `caseDetailsScreen_hideHistory`; regenerated `app_localizations*` and registered in `app_strings.dart`/`app_translations.dart`.
- Tests (in `test/features/case_detail_test.dart`): extended the View All expansion test (pin + Hide + fold-back) and added a Show/Hide + sticky-title test and a Step-style test (Note's size, w600). `flutter analyze` clean; full suite 178 passed, 2 skipped. Version `0.0.139`. Known issues: none.

### 2026-09-05 — Task 10 Case History row polish — COMPLETE

- Case Detail **Case History rows** (only section changed): the weekday label is now **centered under the date** in each row's date column, and the Step/Result main content plus the Note now **span the full content width with justified text** (even left/right edges on multi-line text; single-line text reads left-aligned) — replacing the previous right-aligned rendering that looked off with multiple steps.
- Widget test assertions added in `case_detail_test.dart`: weekday `Align` is centered, Step and Note `Text` widgets use `TextAlign.justify`.
- `flutter analyze` clean; full suite 176 passed, 2 skipped. Version `0.0.138`. Known issues: none. Next resume point: **Task 11** (see `docs/tasks/00_INDEX.md` / implementation plan).

### 2026-09-04 — Task 10 Case History refinements — COMPLETE

- Case Detail **Case History rows** (only section changed): hearing dates now render as **DD/MM/YYYY** with the **day of the week underneath** (abbreviated, e.g. "THU", locale-aware); for **AD/HCD cases only**, each row's main content line now shows the hearing's **Result** in the same slot where lower-court rows show Step content.
- `case_history` gained a nullable `result` snapshot column (schema **v5→v6**, Drift regenerated). `LocalCaseRepository._insertProvisionalHistory` now freezes the previous `result` (like it already freezes `last_step`/`note_result`), so AD/HCD rows created by Quick Update carry the outcome; lower-court rows stay untouched (`result` null). Old pre-existing AD/HCD rows have no stored result to show.
- Long-press **Edit History Entry** now shows a Result box for AD/HCD (no-step) categories, saving through `LocalCaseHistoryRepository` (which now tracks the `result` changed-field for sync payloads).
- Tests: 1 new widget test (AD/HCD rows show Result, never a stored Step), 1 new repository test (Quick Update snapshot keeps the AD/HCD result), new `case_history` column assertions in `schema_test.dart`; existing history-row date assertions updated to DD/MM/YYYY + weekday.
- `flutter analyze` clean; full suite 176 passed, 2 skipped. Version `0.0.137`. Known issues: none. Next resume point: **Task 11** (see `docs/tasks/00_INDEX.md` / implementation plan).

### 2026-09-04 — Task 10 Case Detail AD/HCD-specific columns — COMPLETE

- Case Detail now shows the AD/HCD-only fields, gated on court category (`appellateDivisionId` / `highCourtDivisionId`): a judges names line directly under Name of Court in the title (names only, per user decision), and a new "Other Information" card between Case Title & Remark and Case History with Tender Number, Previous Court Case, and District of Origin boxes (empty renders as '—', same style as the description boxes). Card + line appear only for AD/HCD cases (per user decision); lower-court cases unchanged.
- New l10n keys (en + bn): `caseDetailsScreen_otherInformation`, `caseDetailsScreen_tenderNumber`, `caseDetailsScreen_previousCourtCase`, `caseDetailsScreen_districtOfOrigin`; regenerated `app_localizations*`.
- Widget tests (2 new in `test/features/case_detail_test.dart`): AD/HCD case shows judges line + all three Other Information values; lower-court case hides both sections even with the fields populated.
- `flutter analyze` clean; `case_detail_test.dart` 11/11 passed. Version `0.0.136`. Known issues: none. Next resume point: **Task 11** (see `docs/tasks/00_INDEX.md` / implementation plan).

### 2026-09-04 — Task 10 Case Detail header font sizes — COMPLETE

- Case type & case number title text one size smaller (headline-lg -> headline-md) in `case_detail_screen.dart` L1 header; Name of the Court text one size bigger (body-md -> body-lg) in L2. No other changes. `case_detail_screen.dart` only.

Version `0.0.135`. Next resume point: **Task 11** (see `docs/tasks/00_INDEX.md` / implementation plan).

### 2026-09-04 — Task 10 Phase 2: Case History logic — COMPLETE (Task 10 done)

- Long-press on a Case History row opens a bottom-sheet with Edit / Delete (gated by `caseWritePermissionsProvider.canEdit`; inert for read-only members). Edit opens `history_entry_edit_dialog.dart` — a Dialog form that changes the row's Next Date (`hearing_date`, the previous-next-date shown on the left per user decision), category-filtered Step (`last_step`, steps loaded from the case's court category, selector hidden when the category has none), and Note (`note_result`); Delete shows the shared confirm dialog then soft-deletes.
- New `LocalCaseHistoryRepository` (`lib/features/cases/data/case_history_repository.dart` + `caseHistoryRepositoryProvider`): sync-ready `updateHistory`/`deleteHistory` stamping `updated_at`/`last_modified_by` and recording `case_history` rows in `sync_queue` (compaction-aware, base payload/version snapshot). `case_history_dao.dart` gained `getById`/`update`/soft-`delete`. History creation still happens only inside the Quick Update transaction (`LocalCaseRepository.updateCaseInTransaction`).
- Verified end-to-end (new `test/features/case_history_repository_test.dart`, 7 tests): quick update changing `next_date` stores exactly one snapshot entry (previous date/step/note) even with simultaneous step/note changes; step/note-only quick updates and ordinary Add/Edit saves create none; ordering is `next_date` descending; edit updates row + enqueues sync update (insert+update compacts to one insert); delete soft-deletes and cancels an unsynced insert or enqueues a delete when no insert is pending.
- Widget tests (3 new in `test/features/case_detail_test.dart`): long-press options -> Delete confirm removes the entry (0 Entries Total + empty state, soft-deleted in DB); Edit dialog pre-fills and saves note/step (seeded Steps row shows the category-filtered selector with the stored step reselected); long-press inert when `canEdit: false`.
- `flutter analyze` clean; full suite 171 passed, 2 skipped. Version `0.0.134`. Known issues: none.

**Next resume point:** Task 11 (see `docs/tasks/00_INDEX.md` / implementation plan) — nothing left in Task 10.

### 2026-09-04 — Task 10 Phase 1: Case Detail screen layout — COMPLETE

- Built `lib/features/cases/presentation/case_detail/case_detail_screen.dart` (ConsumerStatefulWidget, real data path): L1 big-font `caseType caseNumber`; L2 location icon + localized court name; L3 Delete (confirm dialog -> `CaseRepository.deleteCase` soft delete -> pop; gated by `caseWritePermissionsProvider.canEdit`) / Edit Case (`AddEditCaseSheet` edit mode, reload on return) / Close; L4 Parties KanBan card ("On Behalf Of: <role>" + petitioner/respondent blocks with name, Lead Counsel, and phone + Phone/Message chooser actions **only under the represented client party** — side derived from `on_behalf_id` slug map, never a second phone); L5 Case Title & Remark card; L6 Case History card (time icon, "x Entries Total", date/step/note rows from `hearing_date` desc-by-`next_date`, 3 visible + "View All N History Entries" expander); plus the mockup blue Next Date highlight card (calendar icon, date + weekday, step/result, "{n} Day(s) Remaining" civil-day countdown clamped at 0, Set Reminder -> `QuickUpdateCaseDialog`).
- Card-tap navigation: `CaseCard` and the disposed `_DisposedCaseCard` gained an `onTap` (Material/InkWell shell when present); all six hosts (All/Active/Upcoming/Overdue/Daily Cause List/Disposed) push `AppRoutes.caseDetailPath(id)` via go_router and reload on return.
- New l10n keys (en + bn): no-history, view-all, days-remaining (pluralized), set-reminder, edit-history-entry, case-not-found; regenerated `app_localizations*` and registered in `app_strings.dart`/`app_translations.dart`. `AppRoutes.caseDetailPath()` helper added.
- Per user decision: two-column `petitioner_phone`/`respondent_phone` split remains deferred (Task 07 realignment); the single stored `party_phone` is treated as the client's phone. Per user decision: mockup Next Date card + View All pattern included on mobile.
- Widget tests (`test/features/case_detail_test.dart`, in-memory DB + provider overrides): full layout, client-phone side placement (respondent/petitioner/unknown), View All expansion, delete-confirm pop + soft delete, Edit Case sheet open/close. `flutter analyze` clean; full suite 161 passed, 2 skipped.

Version `0.0.133`. Known issues: none. Next resume point: **Task 10 Phase 2** — Case History logic (long-press Edit/Delete through a new sync-aware history repository; end-to-end verification of the quick-update-only provisional-history rule).

### 2026-09-02 — Task 09 Phase 4: Acceptance tests & completion — COMPLETE

- Verified the `/daily-cause-list` route is wired in `lib/core/router/app_router.dart:167` (initial location) and `DailyCauseListScreen` builds via `CasesScreenModal`.
- `flutter analyze` — no issues. Full `flutter test` — 144 passed, 2 skipped.
- Release `flutter build apk` is blocked by an environmental Gradle error (`java.io.IOException: Unable to establish loopback connection`) unrelated to the changes; the failure occurs before Dart compilation.
- Acceptance against the agreed plan + clarifications: date-filtered court-grouped list via `CaseCardVariant.dailyCauseList`, Today/Tomorrow + `DD/MM/YY | DDD` calendar control, badge calendar (gray hearing badges, black "Today" highlight + white count badge, "Total Hearings:" count, black Close), no Next Date on cards, single instance only on Daily Cause List screen.

Version unchanged at `0.0.113` (Phase 4 added no code changes).

### 2026-09-02 — Task 09 fixes (post-Phase 4, 8): Daily Cause List card shows Next Date — COMPLETE

- The Daily Cause List case card previously rendered Step + Note only via a bespoke `_DailyCauseDetails`. Replaced that branch with the shared `_ListDetails` (used by Active Cases), which shows Next Date, Step, and Note in the same layout. Removed the now-unused `_DailyCauseDetails` class from `case_card.dart`.
- `daily_cause_list_screen._buildCard` now passes `nextDate` (formatted `dd/MM/yy, EEE` via `AppDateUtils.bangladeshDateTime`, null when absent) and `result`, matching `active_cases_screen`. Added the `intl` import to the screen.

Version `0.0.121`. Known issues: none.

### 2026-09-02 — Task 09 fixes (post-Phase 4, 7): header affordance + toggle + year focus — COMPLETE

- Added a `Icons.arrow_drop_down` caret next to the Month and Year text in the header so users see they are tappable.
- Tapping an open Month/Year header now toggles back to the day grid (instead of only selecting a value to close). The chevron `<` `>` still step the focused month.
- `_YearSelector` opens scrolled to the current/focused year via a `ScrollController` with `initialScrollOffset` computed from an approximate row height and the year's row index (1926–2126, 4 columns).
- Note: the Month grid is short (12 items) and shows all of them, so no scroll-to-current-month was needed; the focused month is already highlighted.

Version `0.0.120`. Known issues: none.

### 2026-09-02 — Task 09 fixes (post-Phase 4, 6): year + month pickers — COMPLETE

- Added tap targets in the header: the **Month** name (`_PickerMode.month`) and the **Year** (`_PickerMode.year`) each open a dedicated selection view; the chevron `<` `>` buttons still step the focused month.
- `_MonthSelector`: a 3-column grid of the 12 localized month names; the focused month is highlighted (black fill). Tapping selects the month and returns to the day grid.
- `_YearSelector`: a scrollable 4-column grid of years **1926–2126** (201 years); the focused year is highlighted. Tapping selects the year and returns to the day grid.
- Extracted the day grid into `_DayGridView` so the three views share the dialog body via an `Expanded` switch on `_mode`. The day grid still always renders exactly 6 rows (7th empty when unused).
- Added l10n keys `dailyCauseListScreen_selectYear` / `dailyCauseListScreen_selectMonth` (en + bn) — reserved for future labels; the current selectors use localized month/year text.

Version `0.0.119`. Known issues: none.

### 2026-09-02 — Task 09 fixes (post-Phase 4, 5): calendar header spacing — COMPLETE

- Pushed the month/year title row (with the `<` `>` buttons) down from the top edge: changed the header `Padding` from `all(md)` to `fromLTRB(md, lg, md, md)` so the top inset is larger.
- Added more separation between the Month & Year title and the Total Hearings count: inserted `SizedBox(height: md)` between the two `Text` widgets in the centered `Column`.

Version `0.0.118`. Known issues: none.

### 2026-09-02 — Task 09 fixes (post-Phase 4, 4): calendar dialog height -15% — COMPLETE

- Reduced the calendar dialog height by 15% only (`minHeight` 0.665→0.565, `maxHeight` 0.874→0.743 of screen height). Width untouched (360–460). The Expanded grid still fills the dialog, so cells shrink proportionally rather than leaving empty space.

Version `0.0.117`. Known issues: none.

### 2026-09-02 — Task 09 fixes (post-Phase 4, 3): fill calendar height + bigger Close button — COMPLETE

- Replaced the `GridView.count(shrinkWrap)` with an `Expanded` + `LayoutBuilder` whose child `GridView.custom` uses `SliverGridDelegateWithFixedCrossAxisCount` with a computed `mainAxisExtent` (available height / row count). The grid now occupies the full dialog height, removing the ~30% empty bottom space. Cell width is set by `crossAxisCount: 7`; badges/counts unchanged.
- Enlarged the Close button to 52px tall (`SizedBox(height: 52)`) with a rounded shape.

Version `0.0.116`. Known issues: none.

### 2026-09-02 — Task 09 fixes (post-Phase 4, 2): calendar selection off-by-one + dialog height — COMPLETE

- Bug: selecting a date in the calendar picked the previous day (e.g. tapping 03/09/2026 selected 02/09/2026). Root cause: `AppDateUtils.bangladeshCivilDateEpoch` built the civil-day start-of-day from a **local**-midnight `DateTime(year, month, day)`, which on a UTC+6 (Bangladesh) device shifts the epoch back ~6h into the prior UTC day. Fixed to use `DateTime.utc(year, month, day)` so the cell epoch matches the labeled civil date on any device timezone. This also keeps grid cell keys consistent with `normalizeToBangladeshStartOfDay` (used by the badge counts), so badges stay correct.
- Enhancement: reduced the calendar dialog height by ~5% only (`minHeight` 0.70→0.665, `maxHeight` 0.92→0.874 of screen height). Width unchanged (360–460).

Version `0.0.115`. Known issues: none.

### 2026-09-02 — Task 09 fixes (post-Phase 4): badge calendar badges, black screen, dialog size — COMPLETE

- Bug: date tap opened a black screen. Root cause: `_DayCell.onTap` both invoked `widget.onDateSelected(epoch)` (which already pops the dialog with the value) AND called `Navigator.of(context).pop()` again, double-popping the route and sending the app back to a black state. Fixed by removing the redundant `Navigator.pop()` — the dialog closes once via the single pop in the screen's `onDateSelected` callback.
- Bug: badges never showed even on dates with cases. Root cause: `CasesDao.countByNextDateRange` grouped by the raw stored `nextDate` epoch, which only equals `bangladeshCivilDateEpoch(day)` when the device is in Bangladesh timezone. Fixed by normalizing each count key with `AppDateUtils.normalizeToBangladeshStartOfDay`, and normalizing the screen's month range bounds, so grid lookups match on any device timezone.
- Enhancement: enlarged the calendar dialog (`minHeight` 0.7 → `maxHeight` 0.92 of screen height, width 360–460) and made day cells taller (`childAspectRatio` 1 → 1.25) so the month grid is larger. The selected non-today date now uses a visible black ring (was an invisible secondary ring).

Version `0.0.114`. No remaining known issues in the Daily Cause List / badge calendar.

### 2026-09-02 — Task 09 Phase 3: Badge calendar picker — COMPLETE

- Enhanced `CalendarPickerDialog` with per-date hearing-count badges (gray badge when the date has hearings; none otherwise) and a black "Today" highlight cell with a white count badge (white badge only when today has hearings; otherwise just the highlighted cell). Added a "Total Hearings:" count under the month title and made the Close button black with white text (matching app theme).
- Added `CasesDao.countByNextDateRange(start, end)` returning a map of civil-day epoch → hearing count, excluding disposed cases; the screen loads it for the focused month when opening the picker.
- Applied user clarifications: black "Today" highlight (not blue), "Total Hearings:" label in black, and black Close button.

Version `0.0.113`. Next resume point: **Task 09 Phase 4** — Acceptance tests & final completion (run task-file acceptance checklist, wire nav route if needed, run `flutter analyze`/`flutter test`).

### 2026-09-02 — Task 09 Phase 2: Daily Cause List date controls — COMPLETE

- Added a sticky `_DateSwitcher` above the list: Today / Tomorrow quick filters (highlighted when active) and a `DD/MM/YY | DDD` calendar control (uses `AppDateUtils.formatDailyCauseCalendarDate`). Today/Tomorrow set the selected civil date and reload; the calendar control opens `CalendarPickerDialog`.
- Built `calendar_picker_dialog.dart`: a `Dialog` hosting a `_BadgeCalendarGrid` Stateful month grid with prev/next navigation, Sunday-first localized weekday headers, selectable day cells (selected cell highlighted with `AppColors.secondary`), and a Close button. Tapping a day invokes `onDateSelected` and closes.
- Added `AppDateUtils.bangladeshCivilDateEpoch(year, month, day)` to build civil-date epoch keys for grid cells.

Version `0.0.112`. Next resume point: **Task 09 Phase 3** — Badge Calendar Picker: per-date hearing-count badges (gray = has hearings), black "Today" highlight with white badge count, and a "Total Hearings:" count under the month title (per user clarifications).

### 2026-09-02 — Task 09 Phase 1: Daily Cause List screen body — COMPLETE

- Built `daily_cause_list_screen.dart`: CasesScreenModal shell; loads cases for the selected Bangladesh civil date (default today) via `listByNextDateRange`; groups by court in the pre-seeded court hierarchy order (category `orderIndex`, then court `orderIndex`); per-court hearing-count KPI in the header; cards use the existing `CaseCardVariant.dailyCauseList` layout (L1 case_type+number | On Behalf, L2 petitioner Vs respondent, L3 title/section, L4 step | note, no Next Date, L5 Phone/Message/Update).
- Removed the unused `daily_cause_list_viewmodel.dart` and its barrel export (host loads directly, matching `overdue_dates_screen.dart`).
- Added l10n keys for empty state and contact-action errors (en + bn).

Version `0.0.111`. Next resume point: **Task 09 Phase 2** — Date Controls (Today / Tomorrow quick buttons + `DD/MM/YY | DDD` calendar control opening the badge picker in Phase 3).

### 2026-08-25 — Disposed card: "Disposed:" pinned to right of line 1 — COMPLETE

- Added a `Spacer()` between the Step/Result chip and the "Disposed:"/date column so they sit at the far right of line 1 instead of directly after the chip.

Version `0.0.108`.

### 2026-08-25 — Disposed card: tightened Step/Result chip & date size — COMPLETE

- Removed the `Expanded` wrapper around the Step/Result chip so the gray background hugs the text (with a little horizontal/vertical padding) instead of stretching across the whole row.
- Changed the date under "Disposed:" from `titleMd` to `labelMd`, matching the "Disposed:" label's text size.

Version `0.0.107`.

### 2026-08-25 — Fixed Disposed card date rendering — COMPLETE

- The date under "Disposed:" was showing the literal "Disposed:" text instead of the date for cases disposed today/tomorrow. Cause: `formatDisplayDate` was called with `todayLabel`/`tomorrowLabel` set to `l.caseCard_disposed` ("Disposed:"), so when the next date matched today/tomorrow it returned that label verbatim. Switched to `formatDateDDMMYYYY` so the line always renders the actual date (DD/MM/YYYY).

Version `0.0.106`.

### 2026-08-25 — Disposed card: moved Next Date under "Disposed:" label — COMPLETE

- Per revision: removed the last Next Date from line 2's right side, and instead show it directly beneath the "Disposed:" label in line 1. Line 2 now holds only Case Type & Number.

Version `0.0.105`.

### 2026-08-25 — Removed dead shared CaseCard.disposed variant — COMPLETE

- The dead code flagged earlier (the `disposed` variant of the shared `CaseCard`, plus `CaseCardHistoryEntry` and the `disposedDate`/`historyEntries` params) was still present in `lib/shared/widgets/case_card.dart`. Removed it.
- Updated `test/shared/widgets/phase3_widgets_test.dart`: dropped the disposed-card assertion and fixed the red-border test (it now sets `isOverdue: true`, which was a pre-existing failure unrelated to this change).

Version `0.0.104`.

### 2026-08-25 — Disposed Cases: rebuilt card to 7-line layout — COMPLETE

- Replaced the shared `CaseCard` (disposed variant, which showed a history timeline) with a dedicated `_DisposedCaseCard` matching the required 7-line spec: Step/Result chip + "Disposed:" label (L1), Case Type & Number + last Next Date (L2), Petitioner Vs Respondent (L3), Case Title/Section (L4), Court + judges (L5), Note in a quoted box with secondary left border (L6, per the mockup), and call/message/update actions (L7).
- Removed the now-dead history fetching (`_historyById`, `CaseHistoryDao`) from this screen. The shared `CaseCard.disposed` variant is left in place (unused here) to avoid unrelated churn.

Version `0.0.103`.

### 2026-08-25 — Disposed Cases: auto-reload after Quick Update — COMPLETE

- Root cause: `_openQuickUpdate` opened `QuickUpdateCaseDialog` but did not reload afterward. Reviving a case (removing disposal steps via Quick Update) left it in the Disposed list until a manual pull-to-refresh.
- Fix: added `if (mounted) await _loadCases();` after the dialog closes — matching the existing pattern in `all_cases_screen.dart`. The list now reflects the change immediately.

Version `0.0.102`.

### 2026-08-25 — Disposal detection used wrong label set — COMPLETE

- Root cause: `CasesDao` matched the Steps field against a hardcoded two-word list `['disposed', 'নিষ্পত্তি']` (`_disposedLabels`). But `last_step` stores the actual comma-joined **step names** (e.g. `"Withdrawal,Dismissal"`), so selecting disposal steps like Withdrawal/Dismissal/Allowed/Rejected never matched and the case stayed in Active/Upcoming/Overdue.
- Fix: derived `disposedStepNames` (both languages) from `pre_seeded_data.disposedStepIds` via `stepLabelEn`/`stepLabelBn`, and switched `_stepIsDisposed`/`_stepIsNotDisposed` to match against that full set with substring `LIKE`. Now any case whose Steps contain a disposal step name is correctly treated as disposed.

Version `0.0.101`.

### 2026-08-25 — Disposal detection: match label inside mixed Step/Result — COMPLETE

- Root cause: `CasesDao._isDisposed` matched `lastStep` with `isIn(_disposedLabels)` (exact equality). District-court steps are stored comma-joined (e.g. `"Disposed, Argument"`), so a disposed step mixed with others failed the exact match and the case was treated as active.
- Fix: disposal now uses `LIKE '%disposed%'` / `'%নিষ্পত্তি%'` substring matching for both the Steps field and the AD/HCD Result field. A case is disposed whenever either field *contains* a disposal label, even alongside other steps/words. The active-case count queries were updated to use the new `_stepIsNotDisposed` expression.

Version `0.0.100`.

### 2026-08-25 — Keep disposed cases out of non-disposed screens — COMPLETE

- Root cause: `CasesDao.getByNextDateRange` did not exclude disposed cases, so disposed cases leaked into Upcoming, Overdue, and Daily Cause List screens.
- Fix: added `_isDisposed.not()` to the date-range query. Disposed cases now appear only in Active (excluded) and Disposed (only-source) screens, plus the unfiltered All Cases screen — matching the intended scope.

Version `0.0.99`.

### 2026-08-25 — Disposed Cases card: enable Update button — COMPLETE

- The Disposed Cases card's Update button was disabled (no `onUpdate` handler). Wired `_openQuickUpdate` → `QuickUpdateCaseDialog.show`, so a disposed case can now be revived/edited if needed. Added the `add_edit_case_sheet.dart` import.

Version `0.0.98`.

### 2026-08-25 — Overdue date styling across case cards — COMPLETE

- Added a per-case `CaseCard.isOverdue` flag. All/Active hosts compute it from `nextDate < bangladeshTodayStartOfDay()`; Disposed passes `true` (past by definition).
- When `isOverdue`: All/Active cards show the red left stripe and the date label switches to "Previous Date" with both label and value rendered in red (`AppColors.error`). Disposed cards relabel their date "Previous Date" (also red).
- Overdue screen's Case Type/Case Number is now black (`AppColors.onSurface`) instead of red; stripe, "Previous Date" label, and red date text remain.
- `flutter analyze` clean repo-wide.

Version `0.0.97`.

### 2026-08-25 — Overdue Dates card refinements — COMPLETE

- Per the mockup, the court name sits in the group header above the cards, so the per-card "Name of Court" column is now hidden on the Overdue Dates screen (`courtName: null`).
- For overdue cases the date is a past date, so the card now labels it "Previous Date" (en) / "পূর্ববর্তী তারিখ" (bn) via a new `CaseCard.dateLabelOverride` + `caseCard_previousDate` localization key. The date value is unchanged.

Version `0.0.96`.

### 2026-08-25 — Current Task: Task 08 — Case List Screens — COMPLETE

Implemented and validated:
- Extended the All Cases host with a KPI summary (Active / Disposed counts), Court Name filter (pre-seeded court categories), Chronology (newest/oldest) filter, scoped search, and first-come-first-served ordering by `createdAt` ascending (per user: no serial number rendered in cards; serial numbering is deferred to the later table view).
- Built the Active Cases screen (non-disposed only, via new `CaseRepository.listActive()` / `CasesDao.getActive()` reusing the disposals predicate).
- Built the Upcoming Cases screen: cases whose `next_date` falls within tomorrow through tomorrow + `upcoming_cases_period` days (UserSettings, default 7), grouped under localized date headers, newest group first.
- Built the Overdue Dates screen: `next_date` strictly before today, red left border strip (CaseCardVariant.overdue), Part A local-only "Last Updated" status line, grouped by court hierarchy (category orderIndex then court orderIndex).
- Built the Disposed Cases screen with no FAB; disposed variant card shows disposal date, parties, final note, and the last two `case_history` entries (L5), via a new `CaseCardHistoryEntry` param on `CaseCard`.
- All five list screens reuse the existing `CaseCard` (list/dailyCauseList/overdue/disposed variants) and the shared `CasesScreenModal`.
- `flutter analyze` clean across the repo.

Version `0.0.95`.

**Next:** Task 09 (Daily Cause List) and any table-view work (serial numbers) per the deferred scope above.

### 2026-08-25 — Current Task: All Cases card note display — COMPLETE

Implemented and validated:
- Passed `notes_results` into the All Cases card and displayed a full-width `Note: ...` row after Next Date/Last Step and before actions.
- Empty and whitespace-only notes remain hidden, preserving the current card layout.
- `flutter analyze` and the full test suite are clean.

Version `0.0.87`.

**Next:** Continue Task 07 development with the authoritative lower-court data import and resolve the existing CJM disposed-reference mismatch.

### 2026-08-25 — Current Task: Task 07 date-picker width alignment — COMPLETE

Implemented and validated:
- Matched the date-picker surface to the Update window's 16px horizontal inset and 480px maximum width.
- Add/Edit, Quick Update, localization, and date-picker tests pass; `flutter analyze` is clean.

Version `0.0.86`.

**Next:** Continue Task 07 development with the authoritative lower-court data import and resolve the existing CJM disposed-reference mismatch.

### 2026-08-25 — Current Task: Task 07 calendar header and picker action refinements — COMPLETE

Implemented and validated:
- Standardized Add/Edit and Quick Update Day Offset choices to 0, 1, 3, 7, 15, and 30 days.
- Updated English/Bengali calendar-picker headers to the requested abbreviated month and weekday labels; centered Cancel/OK actions and added bottom padding.
- Focused tests pass; `flutter analyze` is clean.

Version `0.0.85`.

**Next:** Continue Task 07 development with the authoritative lower-court data import and resolve the existing CJM disposed-reference mismatch.

### 2026-08-25 — Current Task: Task 07 remaining-gap fixes — COMPLETE

Implemented and validated:
- Added a reusable disposed-case DAO/repository query using seeded disposed Steps and all six AD/HCD Result terms.
- Added regression coverage for every English/Bengali disposal term.
- Added High Court add/edit persistence coverage for all new AD/HCD fields, including leading-zero Tender Number restoration.
- Full Flutter test suite passed: 141 tests, 2 skipped mobile-only; `flutter analyze` is clean.

Version `0.0.83`.

**Next:** Continue Task 07 development with the authoritative lower-court data import and resolve the existing CJM disposed-reference mismatch.

### 2026-08-25 — Current Task: Task 07 AD/HCD Add/Edit localization — COMPLETE

Implemented and validated:
- Added AD/HCD-only Honorable Judges, Case Category, Tender Number, Previous Court Case, District of Origin, and Result controls.
- Scoped AD/HCD Case Types by Case Category, hid Step for AD/HCD, and persisted the new case fields through schema v5 and sync changed-fields tracking.
- Treated Dismissed/Disposed/Discharged English and Bengali result terms as disposed without Step validation.
- Localized seeded District, Court, Case Type, and Step dropdown labels for EN/BN, with English fallback for custom rows; set EN as the development default locale.
- Updated Task 07 and implementation-plan contracts; focused form, schema, result-disposal, and Task 07 acceptance tests pass.

Version `0.0.82`.

**Next:** Continue Task 07 development with the authoritative lower-court data import and resolve the existing CJM disposed-reference mismatch.

### 2026-08-25 — Current Task: App launcher icon update — COMPLETE

Implemented and validated:
- Added `flutter_launcher_icons` configuration using `assets/icons/app_logo.png`.
- Generated Android, iOS, and web launcher icon assets.
- `flutter analyze` is clean.

Version `0.0.80`.

**Next:** Resolve the existing CJM `Allowed` disposed-reference mismatch, reset local app data, and continue Task 07 development.

### 2026-08-25 — Current Task: Restore Sessions step seed — IMPLEMENTED; TEST PARTIAL

Implemented:
- Replaced all lower-court Steps, Case Types, On Behalfs, and Disposed references from `docs/seed_data_test/LowerCourt_Steps_CaseTypes_OnBehalf.txt`.
- Generated stable option IDs from English labels and assigned source-list order indexes.
- Added complete Metropolitan Sessions Judge Court options and updated seed tests.
- Removed plain `Withdrawal` from four criminal disposed lists because those categories define only `Withdrawal under Section 248` as a step.
- Replaced tuple-based lower option lists with explicit `SeedOption` entries containing stable IDs, labels, and order indexes.
- Replaced lower-court name placeholders with 950 source records for eight Dhaka-division districts.
- Derived each court division from its district ID, used scoped stable court IDs, and preserved per-category source order indexes.
- Added a focused test for the imported court count, scope, IDs, and order indexes.
- Removed `Dismissal` from the district-criminal disposed references because it is not a seeded district-criminal step.
- Corrected the focused test so `Judgement` is treated as a normal step, not a disposed marker.
- Restored `Framing of Charge` in Sessions and Metropolitan Sessions step seeds with updated source order indexes.
- Replaced the confirmed-exit root navigator pop with `SystemNavigator.pop()` so the operating system closes the app instead of showing a black screen.
- Added generated `ios`, `windows`, and `web` platform folders using the existing application identity without regenerating `android`.
- Flutter analysis is clean. The focused seed test no longer treats `Judgement` as disposed; it now identifies the separate Chief Judicial Magistrate `Dismissal` reference.
- Focused migration tests and restored step-order checks pass; the seed-data suite still reports the existing CJM `Allowed` disposed-reference mismatch.

Version `0.0.79`.

**Next:** Resolve the existing CJM `Allowed` disposed-reference mismatch, reset local app data, and continue Task 07 development.

### 2026-08-22 — Current Task: Lower-court category seed correction — COMPLETE

Implemented and validated:
- Replaced the lower-court category labels with the requested six categories.
- Removed Tribunal seed data and added Metropolitan Sessions Judge Court with empty options for later completion.
- Updated English/Bengali category labels and changed the visible division label from Chattagram to Chittagong.
- Full Flutter test suite passed; `flutter analyze` is clean.

Version `0.0.70`.

**Next:** Add Metropolitan Sessions Judge Court seed options when the authoritative lists are available.

### 2026-08-21 — Current Task: AD/HCD-only Case Category scoping clarification — COMPLETE

Clarified the data contract: Appellate Division and High Court Division Case Types use `case_category_id` in addition to `court_category_id`; lower-court Case Types remain scoped only by `court_category_id`.

Version `0.0.69`.

**Next:** Implement and validate the Task 07 Add/Edit Case AD/HCD fields and Case Category → Case Type UI flow.

### 2026-08-21 — Current Task: Task 04 AD/HCD reference seed and Case Category database support — COMPLETE

Implemented and validated:
- Replaced Appellate Division and High Court Division seed courts, Case Categories, Case Types, and On Behalf options from `docs/AD_and_HCD.txt`.
- Added the `case_categories` Drift table and `case_types.case_category_id`; AD/HCD Steps are intentionally empty.
- Corrected source spelling errors, preserved deterministic ordering/IDs, and applied the idempotent `seed_v2` replacement migration.
- Focused database tests passed; `flutter analyze` is clean.

Version `0.0.68`.

**Next:** Implement and validate the Task 07 Add/Edit Case AD/HCD fields and Case Category → Case Type UI flow.

### 2026-08-13 — Current Task: Task 07 Add Case Case Number unrestricted text input — COMPLETE

Implemented and validated:
- Add Case Case Number is now a plain text input with no formatter, numeric keyboard restriction, or character filtering; other Add Case controls remain unchanged.
- Focused Add/Edit form and Task 07 acceptance tests pass; `flutter analyze` is clean.

Version `0.0.66`.

**Next:** Retest unrestricted Case Number entry on a physical Android device.

### 2026-08-10 — Current Task: Task-file traceability audit — COMPLETE

Add Case and Update Window input-box traceability were also reviewed and recorded in Task 07.

Implemented and validated:
- On Behalf labels are aligned to the far right of the Case Card heading line.
- All Cases Next Date uses the Add Case/Update format `dd/MM/yy, EEE`.
- Phone and Message actions remain visible when the party phone is empty.
- Phone and Message actions show matching Open with choosers for WhatsApp or the native Phone/Message app.
- The Update button matches the contact-action height, and party names use a slightly smaller type size.
- Party names use the full available Case Card content width, preserving the existing left padding while avoiding premature wrapping beside the On Behalf label.
- Task 02, Task 06, Task 07, and Task 08 now document the implemented font, Add Case/Update Window input-box, and All Cases party-name requirements.

`flutter analyze` clean; focused Case Card and Task 07 acceptance tests pass.

**Next:** Retest the All Cases Case Card contact choosers and action sizing on a physical Android device.

### 2026-08-10 — Current Task: Task 07 Update Window refinements — COMPLETE

Implemented and validated:
- Quick Update Next Date now starts blank with the Add Case `Pick a date` hint; saving without a new date preserves the existing Current Next Date.
- Added the Add Case-style Notification toggle, multi-select Day Offset controls, matching date formatting/picker actions, and Save button sizing.
- Added focused acceptance coverage for date independence, schedule controls, picker behavior, notification persistence, and Save sizing.

`flutter analyze` clean; focused Task 07 and Add/Edit widget tests: 17 passed.

**Next:** Retest the Update Window on a narrow physical device, especially date selection versus the immutable Current Next Date summary.

### 2026-08-05 — Current Task: Task 07 Add Case contact and number refinements — COMPLETE

Follow-up refinements completed:
- Restored Case Number to one unified input while preserving slash-separated values such as `207/23`.
- Matched the immutable `+88` prefix height to the Party Phone input.
- Styled Add/Edit calendar Cancel/OK actions as slightly smaller black versions of the multi-select actions.

`flutter analyze` clean; focused form and shared-widget tests pass.

**Next:** Retest the unified Case Number field and calendar actions on a narrow physical device.

Implemented and validated:
- Replaced petitioner/respondent phone columns with one nullable `party_phone` column, including v2→v3 migration and legacy value carryover.
- Added immutable `+88` Party Phone prefix with complete international-number storage and real `tel:`/SMS actions from All Cases.
- Split Case Number into editable number/year parts, preserved existing cases using the final two year digits, added the localized Pick a date hint, and vertically centered dropdown Search text.

`flutter analyze` clean; focused schema, form, and repository tests: 32 passed.

**Next:** Retest Add/Edit and All Cases phone/SMS actions on a physical device, then verify the v3 migration against a pre-existing database.

### 2026-08-05 — Current Task: Task 07 Add Case court hierarchy defaults — COMPLETE

Implemented and validated:
- Add-mode forms now remember the latest per-user Higher/Lower Court, Division, and District selections in the existing local settings JSON.
- Restored lower-court Division/District values are checked against the current cascade; edit-mode forms continue to use the case's own court hierarchy.
- Added settings round-trip and Add Case restoration regression coverage.

`flutter analyze` clean; focused Add/Edit and repository tests pass.

**Next:** Retest Add Case on a physical device and verify the remembered hierarchy remains correct after restarting the app.

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
