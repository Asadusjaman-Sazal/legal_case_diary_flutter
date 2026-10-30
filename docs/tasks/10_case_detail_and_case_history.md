# Task 10 — Case Detail Screen & Case History

> **Plan references:** §5 "Case Detail Screen" (layout, history logic), `case_history` schema.
> **Design reference (mandatory):** `mockup_html_screens\caseDetails\code.html`.
> **Goal:** The detail screen opened from any case card, with Parties / Description / Case History KanBan cards and history edit/delete.
> **Rules:** Follow the Universal Working Rules in `00_INDEX.md`. Ask, don't guess.

---

## Phase 1 — Screen Layout

Build exactly per §5:
1. **L1:** `case_type` and `case_number` in big font.
2. **L2:** location icon + court name.
3. **L3 action buttons:** **Delete** (red; soft-deletes with confirmation dialog), **Edit Case** (opens `add_edit_case_sheet.dart` in edit mode), **Close** (pops).
4. **L4 — Parties KanBan card:** "On Behalf Of:" (from `on_behalf_id`); Petitioner title + name + lead counsel + phone with Phone/Message buttons if `petitioner_phone` is present; Respondent title + name + lead counsel + phone buttons if `respondent_phone` is present. Client name is derived at runtime from `petitioner` or `respondent` based on the on-behalf role (Resolved Design Clarifications, "Client Representation & Role").
5. **L5 — Case Description KanBan card:** "Case Title & Remark" title; two text boxes — `case_title_and_section` and `case_remarks`.
6. **L6 — Case History KanBan card:** header "Case History" with a time icon and "x Entries Total"; list showing previous `next_date` (left), `last_step` (right), and `note_result` directly below the step.

**Phase 1 completion:** `flutter analyze` clean. Update `docs/version_history.md`.

## Phase 2 — Case History Logic

1. Only a save from the case-card **Quick Update** popup may create automatic history. When that transaction changes `next_date` (with or without simultaneous step/note changes), `CaseRepository` stores the previous `next_date`, `last_step`, `note_result`, and (for AD/HCD) `result` as exactly one `case_history` entry. Ordinary Add/Edit saves and step/note-only Quick Updates create none; verify this end-to-end without direct UI DAO writes.
2. On the detail screen, entries are ordered newest-first by each row's displayed date (`hearing_date`); the DAO query itself stays `next_date` **descending**.
3. **Long-press** on a history item → two options:
   - **Edit:** form to change Next Date, Step (category-filtered), Note.
   - **Delete:** confirmation dialog, then soft delete.
4. History edits/deletes flow through the sync-ready write pipeline (sync columns + `sync_queue`).

**Phase 2 completion:** `flutter analyze` clean; manual test: update a case's date through the quick Update flow → old values appear in history; long-press edit/delete work. Update `docs/version_history.md`.

## Alignment Addendum (Implementation Plan Revision 2.4)

- Parties display `petitioner_phone` and `respondent_phone` independently when present. The represented-client action derives the correct one from `on_behalf_id`; never infer a second phone.
- Automatic provisional history is created only by the repository transaction for the quick Update popup when `next_date` changes. Ordinary Add/Edit saves and step/note-only edits do not create automatic history. The server reconciles the authoritative event after accepted sync.
- Phone/WhatsApp actions follow Task 14 capability validation and safe fallback rules.

## Post-Phase refinements (Versions 0.0.136 – 0.0.140)

- **0.0.136 — AD/HCD-only columns:** a judges names line under Name of Court, and an "Other Information" card (Tender Number, Previous Court Case, District of Origin) between Case Title & Remark and Case History; both only for Appellate/High Court Division cases.
- **0.0.137 — History rows & Result:** dates render as DD/MM/YYYY with the weekday underneath; `case_history` gained a nullable `result` snapshot column (schema v6) frozen by the Quick Update transaction; AD/HCD rows show the hearing's Result in the Step slot; the long-press Edit form can edit Result for AD/HCD.
- **0.0.138 — Row polish:** weekday centered under the date; Step/Result and Note span the full content width with justified multi-line text.
- **0.0.139 — Show/Hide + sticky title:** a Show/Hide button right of "N Entries Total" (only when >3 entries) expands all entries or folds back to the newest 3; while fully expanded, the Case History title row is sticky at the top (PinnedHeaderSliver); Step/Result uses the Note's size (14/20) but stays bold.
- **0.0.140 — Ordering & alignment:** history rows sort newest-first by each row's displayed date (`hearing_date`, screen-level re-sort; DAO `next_date` contract unchanged); Step/Result reads left aligned (Note keeps justified).
- **0.0.539 — Added By, inside a chamber (firm-mode §9.9, Phase 14):** every history entry now carries one attribution line under its note — a 14 px `person_outline` beside `bodySm` text in `AppColors.tertiary`, the same shape the Review Conflict screen's editor line uses — read from the row's own `created_by`, which the server writes as the authenticated account (`push_changes` strips `last_modified_by` from the payload and writes the actor, and a `case_history` row's `created_by` likewise). It is drawn **only inside a chamber**: on an individual device every entry is this account's own, so the line would repeat one name down the whole list — the same reason the roster and the delete-request requester are chamber-only surfaces. The name comes from the new shared `accountDisplayNameProvider(id)` (`lib/features/accounts_and_profile/data/account_mode.dart`), which answers from this device's own cached `profiles` row and never from the network, so a case stays readable offline; a colleague's id, whose name the device does not hold, reads *A Chamber Member* rather than a wrong name or a raw id. Two ARB keys (en + bn, `caseDetailsScreen_historyAddedBy` and the shared `sharedLabels_chamberMember`). Pinned by `test/features/case_detail_test.dart`'s *who added a history entry* group: this account's own name, a colleague's label, and no line at all outside a chamber.
- **0.0.540 — one owner for that line:** the History entry's *Added By* and the Review Conflict screen's editor line now draw the same widget, `AttributionLine` (`lib/shared/widgets/attribution_line.dart`) — icon, gap, `bodySm` and the tertiary tint live there once. The conflict screen's icon came down from 18 px to the app's 14 px, the one rendered difference, so the app has one attribution style rather than two near-identical ones. Wording and fallback stay at each call site, because they genuinely differ: the History line is chamber-only and names a colleague *A Chamber Member*, while a conflict outside a chamber keeps *Another Device*. Both behaviours stay pinned by their existing cases; nothing was weakened and no case was added.
- **0.0.722 — the Next Date card reads the court and the past (user request).** The highlight card's title row now wears the **courthouse glyph** (`Icons.account_balance`) the Overdue Dates court title uses, in place of the calendar icon; the size and opacity stay. When the case's `next_date` is behind the Bangladesh today, the title reads **Previous Date** (`caseCard_previousDate`) and the count reads **N Days Ago** (new key `caseDetailsScreen_daysAgo`, 1 Day Ago / N Days Ago) instead of the remaining-days countdown, whose helper no longer clamps negatives to zero. Today and future dates keep **Next Date** and the countdown; the date line, step, blue fill and Set Reminder are untouched. The mockup's card was updated (rule 9). Proof: `case_detail_test.dart` **22 cases** — the card asserts the new icon, and a new case seeds a date three days ago and finds **Previous Date** and **3 Days Ago** with neither **Next Date** nor a remaining count; `flutter analyze` clean; full `flutter test` **2,210 passed**.
- **0.0.723 — the card's calendar and the court's icon (user request).** The Next Date/Previous Date card is back on its own **calendar glyph** (`Icons.calendar_today`), and the **courthouse glyph** (`Icons.account_balance`) moved to the header's court line, replacing the location pin (`Icons.location_on`). On a **Previous Date** card the action reads **Update** (`sharedActions_update`) instead of **Set Reminder** — same button, same Quick Update window — while a **Next Date** card keeps **Set Reminder**. The mockup was updated to match (rule 9). Proof: `case_detail_test.dart` **22 cases** — the card asserts the calendar glyph, the header asserts the courthouse glyph and no location pin, the future card asserts **Set Reminder**, and the past card asserts **Update** with no **Set Reminder**; `flutter analyze` clean; full `flutter test` **2,210 passed**.
