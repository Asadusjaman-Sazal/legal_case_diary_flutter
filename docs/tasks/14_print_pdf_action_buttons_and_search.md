# Task 14 — Print (PDF Export), Action Buttons & Unified Search

> **Plan references:** §8 "Print (PDF Export)", §9 "Action Buttons (Phone & Message)", §12.1 "Unified Search Strategy (Global & Contextual)", "Resolved Design Clarifications" (Print vs Share) in `docs/implementation_plan.md`.
> **Goal:** Bengali-safe PDF printing of list screens and case history, Phone/Message action buttons with WhatsApp options, and the unified search experience across cases, notes, references, and settings.
> **Rules:** Follow the Universal Working Rules in `00_INDEX.md`. Ask the user when anything is unclear — never guess. This task is Part A (fully offline): no network code.

---

## Phase 1 — PDF Generator Core (Native Bengali Text Path)

1. Confirm `pdf` and `printing` packages are in `pubspec.yaml` (added in Task 01 Phase 2; if deferred, add them now via `flutter pub add`).
2. Implement `core/utils/pdf_generator.dart`:
   - Load the **Tiro Bangla** font asset (already bundled in Task 02) and register it with the `pdf` package. Also register the English fonts (Manrope/Inter/IBM Plex Sans) for mixed-script lines.
   - **Native-text-first strategy (default path):** produce paginated, searchable/selectable PDF text — small output size. Pagination must use the PDF layout engine's **measured rendered height and natural page breaking — never a fixed row count**.
   - Layouts to support (one generator entry point per screen type):
     - **Daily Cause List:** grouped by court; each row shows Case Number, Parties, Lead Counsel, and Steps.
     - **Active Cases:** clean list of all current (non-disposed) litigation.
     - **Case History:** timeline export of a specific case (hearing date, step, note/result per entry).
   - If the user has not specified additional layouts (e.g., Disposed Cases, Overdue Dates), the same list layout applies — ask the user before inventing a new layout variant.
3. Add automated **golden/text-extraction checks** as `flutter test` fixtures for the native path: Bengali vowels, diacritics, ligatures, conjunct-heavy strings, and mixed Bengali/English lines. These must pass before the native path is considered release-ready.

**Phase 1 completion:** Run `flutter analyze`, fix all errors. Update `docs/version_history.md` (new version entry + `## Current Version`).

## Phase 2 — Bounded Widget-to-Image Raster Fallback

> Use raster output **only** for content/fixtures proven to shape incorrectly in the native path. Never capture an entire long scroll view as one bitmap.

1. Lay out a print-only widget into **bounded page-height chunks** based on measured rendered height (not a fixed row count).
2. Wrap and capture **one PDF-sized page/chunk at a time** with `RepaintBoundary.toImage()`.
3. Cap pixel ratio and output dimensions to a **tested memory budget** — do not blindly use the device pixel ratio. Define and test explicit maximum page width, height, pixel ratio, and estimated RGBA byte budget **before** allocation.
4. Encode/embed each page, then **dispose image/byte buffers before rendering the next page** — keep only the current page buffer alive.
5. Run encoding/PDF assembly in an isolate (or equivalent off-main-thread worker where Flutter/plugin constraints permit). Stream/build incrementally where supported.
6. Show **progress and cancellation UI** for large exports; fail with a recoverable message rather than crashing.
7. Add automated upper-bound tests: page dimensions, peak live buffers, and successful multi-page completion on a large cause-list fixture.

**Phase 2 completion:** `flutter analyze` clean; raster fallback tested against a large cause list without OOM. Update `docs/version_history.md`.

## Phase 3 — Print Integration on Screens

1. Wire the **Print** action (already present in the side navigation panel / `cases_screen_modal` from Task 06) on: Daily Cause List, Active Cases, Disposed Cases, and the other case list screens, plus Case History on the Case Detail screen.
2. Print generates the formatted PDF of the **current screen's data** (respecting active filters/date selection) and presents the **standard OS print dialog** via the `printing` package.
3. **Share stays separate:** the Share option invokes the Android native sharing utility to share the app itself — it does not share the PDF. Do not merge the two.
4. All PDF labels/headers must come from `app_translations.dart` so printed output follows the selected language (Bengali/English).

**Phase 3 completion:** `flutter analyze` clean; manual print-preview check on at least Daily Cause List and Case History. Update `docs/version_history.md`.

## Phase 4 — Action Buttons (Phone & Message)

1. Confirm `url_launcher` is present (Task 01 Phase 2).
2. **Phone button** (on case cards / Case Detail): resolve the represented party through `on_behalf_id`; where both parties are valid targets, let the user choose Petitioner or Respondent. Then offer:
   1. **Standard Phone Call:** launch `tel:` with the selected nullable `petitioner_phone` or `respondent_phone`.
   2. **WhatsApp Call:** first capability-check a currently documented installed-platform WhatsApp call mechanism. If none exists, offer WhatsApp contact/chat and the standard phone dialer as explicit fallbacks. Never invent an undocumented URL scheme.
3. **Message button:** use the same explicit party/number selection, then offer:
   1. **Standard SMS:** launch `sms:` with the selected number and pre-populated template.
   2. **WhatsApp Message:** launch `https://wa.me/<normalized-number>?text=<urlencoded_message>`.
4. **Translation template:** the pre-filled message (e.g., *"Dear Client, your case [No] is scheduled for [Date] at [Court]. - [Lawyer Name]"*) lives in `app_translations.dart` (Bengali + English). Substitute case number, formatted next date, court name, and lawyer name.
5. Validate and normalize each number before launching. Disable unavailable party actions and show a localized friendly message; never silently switch to the other party's number.

**Phase 4 completion:** `flutter analyze` clean; manual test of all four launch paths on emulator/device. Update `docs/version_history.md`.

## Phase 5 — Unified Search (Cases, Notes, References, Settings)

1. **Case list search:** every case listing (All, Active, Upcoming, Disposed, Overdue) exposes the prominent search bar already scaffolded in `cases_screen_modal` (Task 06). Search runs **Drift queries** using case-insensitive `LIKE` patterns (or FTS indices if already set up in Task 03 — do not add FTS now without asking).
   - Apply the current screen's dataset predicate first (All/Active/Upcoming/Disposed/Overdue), then text search only within that result. Searchable fields: Case Number, Petitioner, Respondent, both Lead Counsel fields, represented Client Name resolved through `on_behalf_id`, `petitioner_phone`, `respondent_phone`, Remarks, and Case Title.
2. **Notes search:** searchable by Title and Body (search button added to the Notes header in Task 11 — wire it to the DAO query here if not already done).
3. **Case Reference search:** searchable by `reference_and_page_no`, `statute`, `section_or_article`, `title_and_description`, and `comments_notes`. There is **no** separate citation-title/body or URL field.
4. **Settings search:** the main Settings screen search input dynamically filters settings submenu items (e.g., typing "profile" shows only "Profile Settings" and "Manage Account"). Filtering matches against the localized labels from `app_translations.dart`.
5. All search queries must include the standard `WHERE is_deleted = 0` filter and use pagination consistent with Task 05's repository patterns.
6. Add DAO unit tests covering each searchable field set and the client-name extraction rule.

**Phase 5 completion:** `flutter analyze` clean; search tests pass. Update `docs/version_history.md`.

## Alignment Addendum (Implementation Plan Revision 2.4)

- Replace `represented party phone (`petitioner_phone` or `respondent_phone`)` with explicit petitioner_phone/respondent_phone and select the represented party through on_behalf_id.
- Offer WhatsApp call only after validating a documented installed-platform capability. Otherwise fall back safely to WhatsApp contact/chat or the standard phone dialer; never use an undocumented scheme.
- Search ownership: Task 05 supplies query primitives; each feature wires and constrains its own dataset; this task owns shared search UX and final integration tests.
- Android app sharing is implemented behind a dedicated platform service using a maintained share package, content/file-provider URIs, correct MIME types, scoped permissions, user-visible failure fallback, and Android integration tests.
