# Task 07 — Add/Edit Case Form (`AddEditCaseSheet`)

> **Plan references:** §1.1 "Add/Edit Case Form (`AddEditCaseSheet`)" — the full 18-field table, layout rules, and logic.
> **Design reference (mandatory):** the Add New Case form mockup embedded in `mockup_html_screens\dailyCauseList\code.html`.
> **Goal:** `lib/shared/widgets/add_edit_case_sheet.dart` — a full-screen modal sheet for adding/editing a case.
> **Rules:** Follow the Universal Working Rules in `00_INDEX.md`. Ask, don't guess.

---

## Phase 1 — Form Fields & Layout

Build all 18 fields **in the exact order and with the exact widget types** from the plan's field table:

1. Higher or Lower Court — `CustomDropdown` single-select (3 options).
2. Division — `CustomDropdown`; **hidden** for Appellate/High Court.
3. District — `CustomDropdown` from `districtsByDivision[selectedDivision]`; hidden for Appellate/High Court.
4. Court Category — `CustomDropdown` (lower-court categories); hidden for Appellate/High Court.
5. Name of Court — searchable `CustomDropdown`; Supreme: `supremeCourtNames[category]`; Lower: `lowerCourtNamesByDistrict[district][category]`.
6. Case Type — `CustomDropdown` from `CaseTypesDao` filtered by resolved `court_category_id` (implicit from field 1 for Appellate/High Court; from field 4 for lower courts). Placed LEFT of Case Number.
7. Case Number — `TextFormField`, RIGHT of Case Type (side-by-side row).
8. Petitioner — `TextFormField` + Lead Counsel sub-field (`petitionerLeadCounsel`) with a line's worth of extra space.
9. Respondent — `TextFormField` + Lead Counsel sub-field (`respondentLeadCounsel`).
10. On Behalf — `CustomDropdown` from `OnBehalfsDao`, same category resolution as fields 6/16.
11. Petitioner Phone No. and Respondent Phone No. — two nullable `TextFormField`s with numeric keyboards.
12. Case Title & Remarks — two stacked `TextFormField`s: top `caseTitleAndSection`, bottom multi-line `caseRemarks`.
13. Next Date — simple date picker (epoch ms), in a **single row** with 14 & 15.
14. Notification — toggle `IconButton` (filled black when on), same row.
15. Day Offset — multi-select `CustomDropdown` (no search), options from Settings > Notification > Notification Day Offset, same row.
16. Step — multi-select `CustomDropdown` from `StepsDao` filtered by the selected court's category (`lastStep`).
17. Note — multi-line `TextFormField` (`notesResults`).
18. Save — `ElevatedButton`.

Layout rules (verbatim from plan): 6–7 side-by-side; 13–14–15 in one row in that exact order; 5–10 cascade (changing Higher/Lower resets & shows/hides Division/District/Category which filter Name of Court); everything else stacked vertically in order.

**Phase 1 completion:** `flutter analyze` clean. Update `docs/version_history.md`.

## Phase 2 — Save Logic

1. **Add mode:** generate a new UUID → `CaseRepository.insertCase()` (which runs the sync-ready write pipeline from Task 05).
2. **Edit mode:** pre-fill every field from the `Case` data class → `CaseRepository.updateCase()`.
3. **50-case free limit:** in add mode, before insert, call `CasesDao.getNonDeletedCaseCount()`; if count ≥ 50 AND `isPremium == false`, block the save and navigate to `PaywallScreen` (stub screen until Task 15/21).
4. **Case history:** ordinary Add/Edit saves create no automatic history. The quick Update flow delegates to the repository transaction, which creates one previous-value entry only when `nextDate` changes; UI code never calls the history DAO directly.
5. Validation: required fields — the plan does not enumerate which fields are mandatory beyond structure; **ask the user which fields are required before implementing validation.**

**Phase 2 completion:** `flutter analyze` clean; manual test add + edit + limit block. Update `docs/version_history.md`.

## Phase 3 — Quick Update Pop-up

Implement the **Update button pop-up** (quick date & step update window styled after `dailyCauseList\code.html`): edits `next_date`, `last_step` (category-filtered steps), and `notes_results`; runs the same case-history-preservation logic on save. Wire it to the `case_card.dart` Update callback (Task 06).

**Phase 3 completion:** `flutter analyze` clean. Update `docs/version_history.md`.

## Alignment Addendum (Implementation Plan Revision 2.4)

- Replace field 11 with two nullable fields, Petitioner Phone No. and Respondent Phone No.; preserve the remaining field order/cascade rules and update the documented field-count verification accordingly.
- Persist the Notification toggle and selected offsets in per-user `case_notification_preferences`, not transient form state or firm-shared settings.
- The free-tier check calls `getNonDeletedCaseCount()`.
- Ordinary Add/Edit Case saves do not create case history. The quick Update popup delegates one repository transaction that creates a provisional previous-value history row only when `next_date` changed. Remove every direct UI call to `CaseHistoryDao.insertHistoryEntry()`.
