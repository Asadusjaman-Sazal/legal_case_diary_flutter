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

### Phases 1 & 2 — refinement

- **0.0.260** — The FAB now asks which kind of note to create: **Text Note** (the Phase 1 flow, unchanged) or **To-Do**, whose body is Google Keep's checklist — a tick, an editable item and a remove button per row, plus an **Add Item** row, with Enter on a row opening the next. Ticking an item drops it below the unticked ones (Keep's own rule, applied as a stable partition) and strikes it through; unticking lifts it back into the unticked block. A new to-do opens with one empty row ready to type into, and blank rows are dropped on save. This is a deliberate extension of the plan's `notes` schema (§ `notes`, which defines `title` + `body` only): `notes.items` holds the checklist as a JSON `[{text, done}]` array, and `null` there means a text note — so a note's kind is the presence of that column rather than a second flag to keep in step. `body` mirrors the item texts, one per line, which is what keeps the plan §12.1 title+body search able to find a to-do by its contents with **no query change**. A to-do card shows its first three rows with their ticks and `+N More`, so the two kinds read differently at a glance. **Part B must carry `items` on the server `notes` table**; the local sync payload already does. Files: `notes_table.dart`, `note_items.dart` (new), `note_detail_screen.dart`, `notes_screen.dart`, `notes_repository.dart`; schema v9 + `from < 9` migration. Tests: `test/features/notes_todo_test.dart` (13).

- **0.0.202** — Both libraries' search box now behaves exactly like the case-list one, because it is the same box in the same place: `ScopedSearchBar` is mounted by `CasesScreenModal` (under the header, above the scrolling list) instead of being the first row of the notes/reference `ListView`. It used to scroll away with the cards, sit inside the list's 16 px padding, and vanish entirely when the library had no rows — an empty library could not be searched at all. The screens pass `isSearching` / `searchController` / `onSearchChanged` to the modal and `_NotesList` / `_ReferenceList` lost the controller, the search callback and the `onCloseSearch` they no longer need. Note/reference filtering, the header search icon, the always-on (x) and tap-outside-to-hide-the-keyboard are unchanged. (`notes_screen.dart`, `case_reference_screen.dart`; tests: `test/features/library_search_test.dart`, 3.)
