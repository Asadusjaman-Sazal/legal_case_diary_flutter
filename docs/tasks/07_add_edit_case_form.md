# Task 07 — Add/Edit Case Form (`AddEditCaseSheet`)

> **Plan references:** §1.1 "Add/Edit Case Form (`AddEditCaseSheet`)" — the full 18-field table, layout rules, and logic.
> **Design reference (mandatory):** the Add New Case form mockup embedded in `mockup_html_screens\dailyCauseList\code.html`.
> **Goal:** `lib/shared/widgets/add_edit_case_sheet.dart` — a full-screen modal sheet for adding/editing a case.
> **Rules:** Follow the Universal Working Rules in `00_INDEX.md`. Ask, don't guess.

---

## Phase 1 — Form Fields & Layout

Build all 19 fields **in the exact order and with the exact widget types** from the plan's field table:

1. Higher or Lower Court — `CustomDropdown` single-select (3 options).
2. Division — `CustomDropdown`; **hidden** for Appellate/High Court.
3. District — `CustomDropdown` from `districtsByDivision[selectedDivision]`; hidden for Appellate/High Court.
4. Court Category — `CustomDropdown` (lower-court categories); hidden for Appellate/High Court.
5. Name of Court — searchable `CustomDropdown`; Supreme: `supremeCourtNames[category]`; Lower: `lowerCourtNamesByDistrict[district][category]`.
6. Case Category — AD/HCD only; `CustomDropdown` from the selected court category's `case_categories` rows, placed after Name of Court. It is not shown for lower courts because their Case Types remain scoped directly by `court_category_id`.
7. Case Type — `CustomDropdown` from `CaseTypesDao` filtered by the resolved `court_category_id` and, for AD/HCD, the selected `case_category_id`. Placed before Case Number.
8. Case Number — `TextFormField`, RIGHT of Case Type (side-by-side row).
9. Petitioner — `TextFormField` + Lead Counsel sub-field (`petitionerLeadCounsel`) with a line's worth of extra space.
10. Respondent — `TextFormField` + Lead Counsel sub-field (`respondentLeadCounsel`).
11. On Behalf — `CustomDropdown` from `OnBehalfsDao`, same category resolution as Case Type and Step.
12. Petitioner Phone No. and Respondent Phone No. — two nullable `TextFormField`s with numeric keyboards.
13. Case Title & Remarks — two stacked `TextFormField`s: top `caseTitleAndSection`, bottom multi-line `caseRemarks`.
14. Next Date — simple date picker (epoch ms), in a **single row** with 15 & 16.
15. Notification — toggle `IconButton` (filled black when on), same row.
16. Day Offset — multi-select `CustomDropdown` (no search), options from Settings > Notification > Notification Day Offset, same row.
17. Step — multi-select `CustomDropdown` from `StepsDao` filtered by the selected court's category (`lastStep`); hidden/disabled for AD/HCD because their seeded Step lists are intentionally empty.
18. Note — multi-line `TextFormField` (`notesResults`).
19. Save — `ElevatedButton`.

### AD/HCD reference-data contract

For Appellate Division and High Court Division, the Task 07 implementation must resolve the selected court category from field 1, show the seeded Case Category after Name of Court, and filter Case Type by that selected Case Category. Case Categories and Case Types are separate persisted tables/relations; labels are never used as database keys. AD/HCD do not have seeded Steps, so the Step control must not offer placeholder values for those selections.

Layout rules (verbatim from plan): 7–8 side-by-side; 14–15–16 in one row in that exact order; 5–11 cascade (changing Higher/Lower resets & shows/hides Division/District/Court Category/Case Category, which filter Name of Court and Case Type); everything else stacked vertically in order.

**Input presentation refinements:** text-field labels sit above the controls; empty text/date inputs use outlined borders with the surface fill, while populated inputs use the selected-surface fill and underline treatment, with a secondary 2px underline when focused. Empty Next Date shows the localized `Pick a date` hint and a selected date uses `dd/MM/yy, EEE`. Dropdown inputs use the matching outlined empty/selected presentation. The case number is one unified numeric/hyphen input (with no separate year box): the formatter inserts a non-editable `/` after the first digit, keeps the caret before the separator after automatic insertion, permits digits and hyphens on either side without length limits, and lets the user move the caret after `/` manually. The current UI presents one numeric party-phone input beside a fixed `+88` prefix, with both controls sharing height; this differs from the Revision 2.4 two-phone requirement recorded in field 11 and remains a traceability discrepancy to resolve.

**Phase 1 completion:** `flutter analyze` clean. Update `docs/version_history.md`.

## Phase 2 — Save Logic

1. **Add mode:** generate a new UUID → `CaseRepository.insertCase()` (which runs the sync-ready write pipeline from Task 05).
2. **Edit mode:** pre-fill every field from the `Case` data class → `CaseRepository.updateCase()`.
3. **50-case free limit:** in add mode, before insert, call `CasesDao.getNonDeletedCaseCount()`; if count ≥ 50 AND the user has no premium entitlement, block the save and navigate to `PaywallScreen` (stub screen until Task 15/21). Premium entitlement is derived from the cached subscription expiry via `resolvePremiumAccess` (profile expiry for individuals, firm expiry for firm members, 48-hour grace); the display-only `settings.isPremium` flag is never the authority.
4. **Case history:** ordinary Add/Edit saves create no automatic history. The quick Update flow delegates to one atomic repository transaction, which creates one previous-value entry only when `nextDate` changes; UI code never calls the history DAO directly. The case row, history row, and their sync-queue records must roll back together if any write fails.
5. Validation: required fields — the confirmed mandatory fields are Higher or Lower Court; Division, District, and Court Category for lower courts; Name of Court; Case Type; Case Number; and Next Date. On Behalf remains optional at the validation layer, but because the local FK is non-nullable, saving requires an explicit role when multiple roles exist or uses the sole role when exactly one exists; it never silently chooses the first of multiple roles.

**Phase 2 completion:** `flutter analyze` clean; manual test add + edit + limit block. Update `docs/version_history.md`.

## Phase 3 — Quick Update Pop-up

Implement the **Update button pop-up** (quick date & step update window styled after `dailyCauseList\code.html`): edits `next_date`, `last_step` (category-filtered steps), and `notes_results`; runs the same case-history-preservation logic on save. Wire it to the production `case_card.dart` Update callback in the All Cases host (Task 06). The remaining Task 08 list screens may remain stubs until their own implementation phases.

**Update Window refinements:** show the case type/number and immutable Current Next Date summary separately from the editable controls. The editable Next Date starts blank with the localized `Pick a date` hint; leaving it blank preserves the stored date and creates no date-history entry. Use the Add Case-style date presentation (`dd/MM/yy, EEE`), Notification toggle, multi-select Day Offset and Step controls, state-based outlined/underline input surfaces, and a black Save action with the matching 52px minimum height. Persist notification enablement and offsets with the same per-user preference rules as Add Case.

**Phase 3 completion:** `flutter analyze` clean. Update `docs/version_history.md`.

## Alignment Addendum (Implementation Plan Revision 2.4)

- Replace field 11 with two nullable fields, Petitioner Phone No. and Respondent Phone No.; preserve the remaining field order/cascade rules and update the documented field-count verification accordingly. The current implementation instead exposes one `partyPhone` field with a fixed `+88` prefix, so this mismatch must be explicitly resolved before Task 07 is considered fully aligned.
- Persist the Notification toggle and selected offsets in per-user `case_notification_preferences`, not transient form state or firm-shared settings.
- The free-tier check calls `getNonDeletedCaseCount()`.
- Ordinary Add/Edit Case saves do not create case history. The quick Update popup delegates one atomic repository transaction that updates the case, records the provisional previous-value history row only when `next_date` changed, and enqueues both writes; any failure rolls the unit of work back. Remove every direct UI call to `CaseHistoryDao.insertHistoryEntry()`.
- Notification offset labels are localized through AppLocalizations for both English and Bengali.
- The All Cases production host renders repository-backed CaseCards and connects `onUpdate` to `QuickUpdateCaseDialog`; the other Task 08 list hosts remain explicitly deferred stubs.
