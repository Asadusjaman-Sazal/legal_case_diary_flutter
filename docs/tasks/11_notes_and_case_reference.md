# Task 11 — Notes & Case Reference Screens

> **Plan references:** §9 "Notes Screen", §10 "Case Reference Screen", `notes` and `case_references` schemas.
> **Design references (mandatory):** `mockup_html_screens\notes\code.html`, `mockup_html_screens\caseReference\code.html` (keep their hover/selection effects intact).
> **Goal:** Both standalone content libraries with add/edit forms, pinning, delete confirmation, and search.
> **Rules:** Follow the Universal Working Rules in `00_INDEX.md`. Ask, don't guess.

---

## Phase 1 — Notes Screen

1. Screen + Add/Edit Note form designed from `notes\code.html`; add a **search button** on the right of the app header (searches note title + body).
2. Header includes the side navigation panel button (same as case screens).
3. Sorting: `created_at` descending (latest on top). (If pinned notes should also float to top like references, **ask the user** — the plan specifies pinned-above-unpinned only for references.)
4. **Note card (exact):**
   - Part 1: modified date/time `DD/MM/YY, HH:MM AM/PM`; right side: Delete button (confirmation dialog) + Pin button.
   - Part 2: bold, slightly bigger title.
   - Part 3: body text.
5. All writes go through `NotesRepository` (sync-ready pipeline).

**Phase 1 completion:** `flutter analyze` clean. Update `docs/version_history.md`.

## Phase 2 — Case Reference Screen

1. Screen + Add/Edit form from `caseReference\code.html`. Header: nav panel button, "Case Reference" title, search button far right.
2. Form fields: `reference_and_page_no`, `statute`, `section_or_article`, `title_and_description`, `comments_notes`.
3. Sorting: `created_at` descending; **pinned items always above non-pinned**.
4. **Card (exact):** L1 `reference_and_page_no` + `statute` left | 3-dot button right (menu: **Pin**, **Delete** with confirmation); L2 `section_or_article`; L3 `title_and_description`; L4 `comments_notes`.
5. Search covers all five text fields (Plan §12.1 — there is no separate citation-title/body or URL field).

**Phase 2 completion:** `flutter analyze` clean; manual check against both mockups. Update `docs/version_history.md`.
