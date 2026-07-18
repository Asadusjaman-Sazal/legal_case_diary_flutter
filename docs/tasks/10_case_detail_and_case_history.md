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

1. Only a save from the case-card **Quick Update** popup may create automatic history. When that transaction changes `next_date` (with or without simultaneous step/note changes), `CaseRepository` stores the previous `next_date`, `last_step`, and `note_result` as exactly one `case_history` entry. Ordinary Add/Edit saves and step/note-only Quick Updates create none; verify this end-to-end without direct UI DAO writes.
2. Entries ordered by `next_date` **descending** (latest on top).
3. **Long-press** on a history item → two options:
   - **Edit:** form to change Next Date, Step (category-filtered), Note.
   - **Delete:** confirmation dialog, then soft delete.
4. History edits/deletes flow through the sync-ready write pipeline (sync columns + `sync_queue`).

**Phase 2 completion:** `flutter analyze` clean; manual test: update a case's date through the quick Update flow → old values appear in history; long-press edit/delete work. Update `docs/version_history.md`.

## Alignment Addendum (Implementation Plan Revision 2.4)

- Parties display `petitioner_phone` and `respondent_phone` independently when present. The represented-client action derives the correct one from `on_behalf_id`; never infer a second phone.
- Automatic provisional history is created only by the repository transaction for the quick Update popup when `next_date` changes. Ordinary Add/Edit saves and step/note-only edits do not create automatic history. The server reconciles the authoritative event after accepted sync.
- Phone/WhatsApp actions follow Task 14 capability validation and safe fallback rules.
