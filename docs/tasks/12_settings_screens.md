# Task 12 — Settings Screens (Main + All Sub-Pages)

> **Plan references:** §8 "Settings — Main Page & Sub-Menu Pages" (structure + Critical Rules), "Court Hierarchy Flow", §10.1 "View Settings Configuration", §12.1 "Settings Search".
> **Design references (mandatory — every sub-page body must match its mockup exactly):** `settings_main`, `settings_profile`, `settings_manageProfileAccount`, `settings_onlineSync`, `settings_backupRestore`, `settings_editCourtSteps`, `settings_editCourtSteps_editCourtNamesCategory`, `courtCategory_lowerCourts-Division`, `courtCategory_lowerCourts-Districts`, `courtCategory_lowerCourts-Districts_listOfCourts`, `settings_courtNamesSteps`, `settings_notifications`, `guidelines`, `settings_about` — all under `mockup_html_screens\`.
> **Goal:** The full Settings surface. Online-dependent pages (Online Sync, Manage Account subscription state) render their UI with offline/placeholder states in Part A and get wired in Part B.
> **Rules:** Follow the Universal Working Rules in `00_INDEX.md`. Ask, don't guess.

---

## Label / Localization Convention (added during implementation, 2026-09-17)

Every user-facing label on the Settings surface (and the rest of the app) lives in `lib/core/l10n/app_en.arb` and `lib/core/l10n/app_bn.arb` — those two files are the only place a label text is written. Code reads them through `AppLocalizations.of(context)`; `flutter gen-l10n` (wired by `l10n.yaml` + `flutter: generate: true`) regenerates `lib/core/l10n/generated/*`.

- **Key naming:** one prefix per screen, in camelCase of the screen: `settingsScreen_*` (main list) `settingsAccountProfile_*` `settingsProfile_*` `settingsManageAccount_*` `settingsOnlineSync_*` `settingsBackupRestore_*` `settingsEditCourtSteps_*` `settingsEditCourtNames_*` `settingsCourtNamesSteps_*` / `settingsEditItems_*` `settingsItemList_*` `settingsCourtList_*` `settingsCourtFlow_*` / `settingsLowerCourtCategories_*`; shared chrome uses `sharedActions_*`, `sharedDialogs_*`, `sharedMessages_*`; the app shell uses `appShell_*` and `databaseRecovery_*`; case screens use `<screen>_*` / `casesContact_*`.
- **Files are grouped by screen:** an `"@@_section_<id>": "<TITLE>  |  <source file>"` row precedes each screen's keys. `flutter gen-l10n` ignores `@`-prefixed keys (verified), and the repo's `generate_l10n.py` / `tool/generate_l10n_dart*.py` skip them as well, so the markers are documentation only. Keep new keys inside their screen's section and in the same relative order in both files — `test/l10n/arb_keys_test.dart` fails if the two files diverge.
- **Both languages are mandatory:** add a Bengali value with the same key in `app_bn.arb`. The guard test also fails if a translation drops a `{placeholder}`.
- Never hard-code a label in a Settings screen, and never pass a literal to `SettingsSubPageModal(title:)`, a dialog title/body, a button label, a tooltip, or an empty/error state. Section headings are stored in sentence case and upper-cased by the widget.

---

## Shared Sub-Menu Sizing Contract (added during implementation)

- `lib/features/settings/presentation/settings_menu_card.dart` (new file; logged in `docs/version_history.md` 0.0.171) is the single source for sub-menu card/button sizing:
  - `SettingsMenuCard` — the shared tappable card (Card, radius 12, 16 px padding, body-lg title / body-sm subtitle, 28 px icon, chevron). Used by the Account & Profile menu (the size reference), the Edit Court/Steps menu, Edit Court Names & Categories, Lower Courts divisions, and Districts.
  - `settingsMenuCardRowHeight` (44 px) — the content-row floor. Rows that keep their own mockup layout (Manage Account items, the Delete Account card, Online Sync's Cases/Notes/References rows) use it so they render at the same height.
  - `settingsPrimaryButtonHeight` (56 px) — every sub-menu primary button: Sync Now, the three Backup & Restore actions, and Profile's Save Profile.
- **Size override, user-approved 2026-09-16:** every sub-menu card renders **76 px** and every sub-menu primary button **56 px** (both measured with a throwaway widget test). This deliberately supersedes the per-mockup sizes — e.g. `settings_backupRestore`'s `h-12` (48 px) buttons are now 56 px, and its `ListTile`-style rows are now the Account & Profile menu card — so those bodies match their mockups in everything except card/button size. Change a size only through the constants above, never with per-screen literals.
- Outside the contract (unchanged): non-tappable content cards (Backup status, profile data card, Quick Tip note, Online Sync status), the Backup schedule's 56 px radio rows, the `settings_courtNamesSteps` KanBan card and its chips, the dense court/item edit rows, and Language's plain `ListTile`s.

---

## Lower Court Categories (added during implementation, 2026-09-16)

The Edit Court/Steps menu carries a third card, **Lower Court Categories**, alongside "Edit Case Types, Step etc" and "Edit Court Names & Categories":

- Flow: **Divisions → Districts → Court Categories** (the category list is the last screen). The Divisions and Districts pickers are the existing `court_category_screen.dart` / `district_list_screen.dart`, routed with `?flow=lower_court_categories` (`AppRoutes.lowerCourtCategoryFlow`); the category list is `edit_court_steps/lower_court_category_list_screen.dart` (`AppRoutes.settingsLowerCourtCategoryList`).
- Membership comes from the **same derivation as the Add/Edit Case form** — `lib/features/settings/data/district_court_categories.dart` (`districtCourtCategories`) is called by both, so the list and the form's Court Category dropdown always agree. A pre-seeded category with no court in the district is hidden; categories the user adds are scoped to that district.
- **User-decided rules (2026-09-16):** the user may reorder categories by drag & drop, rename any category through edit, and delete **only** categories they added (built-ins are refused by the repository, so no delete action is rendered for them). A category added in a district is stored for that district only (`court_categories.division`/`district`, schema v7) and appears in the Add/Edit Case form for that district only.
- The add button is the Add Case button (black FAB, white `+`, size 28, default bottom-right), because the mockup's FAB is that same control.
- **Mockup note:** there is no mockup for the category list itself; it reuses the court-row layout from `courtCategory_lowerCourts-Districts_listOfCourts\code.html` (drag handle, title, edit, delete) per the Critical Rules above, rather than introducing a new card design.

---

## Edit Court Names (added during implementation, 2026-09-17)

User-requested restructure of the second Edit Court/Steps card (Phase 3 item 2) — supersedes that mockup's single "Supreme Court of Bangladesh" card:

- **Header** changed from "Court Category" to **"Edit Court Names"** (the label lives under `settingsEditCourtNames_*`; the key name `settingsEditCourtNames_courtCategory` was kept so hand-edited translations stay addressable, only its value changed). The two keys that named the removed card (`settingsEditCourtNames_supremeCourt`, `settingsEditCourtNames_supremeCourtSubtitle`) were deleted from both ARB files.
- The Supreme Court is **two cards now**: **Appellate Division** and **High Court Division**, each opening that division's court names (`court_list_screen.dart` with `?higherLower=higher_courts&category=<division>`). The card titles reuse the seed category labels (`courtCategory_appellateDivision` / `_highCourtDivision`), i.e. the same strings the Add/Edit Case form shows.
- **Lower Courts → Division → District** no longer lists every court of the district. It opens `district_court_category_screen.dart` (`AppRoutes.settingsDistrictCourtCategories`), which lists the district's court categories as sub-menu cards using the shared `districtCourtCategories` derivation — the same list the Lower Court Categories screen manages and the Add/Edit Case form offers. A category with no court in that district is not listed. Each card opens that category's court names (`court_list_screen.dart` with `?category=<id>`).
- The court list is **category-scoped** and keeps drag & drop reorder, edit, and FAB add (now adding into the category being listed, not always CJM). The add button is the Add Case button — black `FloatingActionButton`, white `Icons.add` size 28, default bottom-right. Seeded court names are read through the seed label lookup, so they follow the active language like the form does. **Delete is rendered only on courts the user added**; pre-seeded courts cannot be deleted (`LocalCourtsRepository.delete` refuses them), so the action previously raised an unhandled `StateError`.
- **New shared helper** `edit_court_steps/court_category_label.dart` (`courtCategoryLabel` / `courtCategoryName`) resolves a category label from either a seed key or a typed name; `lower_court_category_list_screen.dart` and the new picker both use it instead of duplicating the lookup.
- The `categoryNameKey` that names the header is passed with the route (`context.push(..., extra:)`), not as a URL parameter; a restored deep link simply shows the district-level subtitle.

**Implementation note:** the older build of this screen also had `Uri(queryParameters: {})` produce a trailing `?` on the Lower Courts route; the card now only appends a query string when there is one.

---

## Phase 1 — Main Settings Page

1. `settings_main_screen.dart` designed exactly like `settings_main\code.html`, **plus a "Guidelines" item before "About"**.
2. Structure: **General** — Account & Profile (sub-menu: Profile, Manage Account), Online Sync, Backup & Restore. **Preferences** — Edit Court/Steps, Notifications, Language (inline Bengali/English toggle), View Settings. **App Info** — Guidelines, About.
3. **Settings search** (Plan §12.1): a search input dynamically filtering submenu items (e.g., "profile" shows only Profile Settings / Manage Account).
4. All sub-pages use `settings_sub_page_modal.dart` (Task 06) for the header/back button.

**Phase 1 completion:** `flutter analyze` clean. Update `docs/version_history.md`.

## Phase 2 — Account & Profile + Online Sync + Backup & Restore (UI shells)

1. `accounts_profile_menu_screen.dart` (2 buttons: Profile, Manage Account), `profile_screen.dart` (per `settings_profile` mockup), `manage_account_screen.dart` (per `settings_manageProfileAccount` mockup).
   - Part A state: local profile (name) editable locally; subscription/account sections show "free / offline" placeholders. Real data binds in Part B (Tasks 17/21).
2. Online Sync screen per `settings_onlineSync` mockup — Part A shows a disabled/upgrade state (**confirm exact copy with the user**).
3. `backup_restore_screen.dart` per `settings_backupRestore` mockup — buttons wired to Task 15 logic.

**Phase 2 completion:** `flutter analyze` clean. Update `docs/version_history.md`.

## Phase 3 — Edit Court/Steps Hierarchy

Implement the full management flow per §8 and the Court Hierarchy Flow:
1. `edit_court_steps_menu.dart` (per `settings_editCourtSteps` mockup).
2. **Edit Court Names & Categories** (`edit_court_names_category_screen.dart`):
   - Supreme Court of Bangladesh → Appellate Division / High Court Division → list of court names (drag & drop reorder, FAB add, edit, soft-delete).
   - Lower Courts → Divisions (8) → Districts → Court Categories (sessions criminal, civil, CJM, CMM where applicable, executive, tribunals) → List of Courts (drag & drop, FAB add, edit, soft-delete) — screens: `court_category_screen.dart`, `district_list_screen.dart`, `court_list_screen.dart` per their mockups.
3. **Edit Case Types, Steps etc.** (`court_names_steps_screen.dart` per `settings_courtNamesSteps` mockup, **with the Court Names button removed**): all court categories as KanBan cards; under each, **Case Types**, **Steps**, **On Behalf** buttons → list screens with drag & drop, FAB add, edit, delete.
4. Every court resolves to exactly one stable `court_category_id` (Canonical category rule). User-added items get `is_custom = true`; edits to built-ins set `is_user_modified`; deletes are soft.
5. Reordering persists `order_index`.

**Phase 3 completion:** `flutter analyze` clean; manual walkthrough of the full hierarchy. Update `docs/version_history.md`.

## Phase 4 — Notifications, View Settings, Guidelines, About

1. `notification_settings_screen.dart` per `settings_notifications` mockup: `notification_time` and `notification_day_offset` pickers backed by the current user's durable `user_preferences` row; hosts the OEM setup-guide entry + reminder banner (logic in Task 13). Premium Part B synchronizes these through the self-only preference path, never firm-shared storage.
2. `view_settings_screen.dart`: `upcoming_cases_period`, `case_list_display_mode`, `bottom_nav_tabs` (selection + ordering of the 4 tabs), `side_nav_options` toggles, `default_landing_page`.
3. `guidelines_screen.dart` per `guidelines` mockup; `more_about_app_screen.dart` per `settings_about` mockup — About shows the app version read from `docs/version_history.md` `## Current Version` (bundle the value at build time or via an asset — **ask the user which mechanism they prefer**).
4. Language toggle updates the locale provider live (Task 02).

**Phase 4 completion:** `flutter analyze` clean; verify bottom-nav customization and landing-page change take effect. Update `docs/version_history.md`.

## Phase 4 Implementation Notes (added during implementation, 2026-09-17)

- **Storage:** every Phase 4 value is a **per-user preference** in the existing `user_preferences` row (plan §10 + the Addendum: settings are never firm-shared). No schema change; no SharedPreferences. `notificationEnabled` was stored but never read or written, so `UserSettings` and `LocalSettingsRepository` gained it; the day-offset choice is mirrored into `notificationDefaultOffsets`, so Task 13 can read either field.
- **Version mechanism (item 3's open question):** the user chose a **bundled Dart constant**, `core/constants/app_version.dart`. `test/core/app_version_test.dart` fails if it drifts from `pubspec.yaml` or from `## Current Version` in `docs/version_history.md`, so the file stays the single source of truth without an asset read.
- **Approved deviations from the mockups:** the Notifications screen also carries the plan's OEM battery reminder banner and setup-guide row (inert until Task 13, whose guide it points at), and its time row uses Material `showTimePicker` instead of the mockup's custom dial; About shows the version line and uses the bundled `assets/images/dev_profile.jpg` instead of the mockup's remote image (Part A is offline). The mockup's empty "Test Notification" box renders nothing — test notifications are Task 13.
- **Item 2's "4 tabs" wording:** the user approved picking **any number** of bottom tabs, so the bar renders every stored tab and scrolls horizontally above four instead of capping; ordering is drag-based within the same list.
- **Extra screen (user-approved):** About's "More About the App" row opens the uncited `settings_moreAboutTheApp` mockup, implemented as `more_about_the_app_screen.dart` + `AppRoutes.settingsMoreAbout`. Its Rate App, Share App and Check for updates actions only report their Part A state (store links and update checks belong to later tasks), and the About screen's remaining rows (FAQ, Privacy Policy, Terms of Service, Support) do the same.
- **Post-phase follow-up (0.0.179, user-requested):** Settings → **Language** is no longer a two-row list with a blue check. It is a single-line button pair — **English | বাংলা** — where the active language is filled black with white text and the other is white with black text and an outline; each label is pinned to its own script's font (the English label to the app's English family, বাংলা to Tiro Bangla) so the locale switch never re-renders one word in the other script's typeface. Both labels are autonyms, so the English ARB value of `settingsScreen_languageBengali` is now **বাংলা** too. Covered by new `test/features/language_screen_test.dart` (4 tests).
- **Post-phase follow-up (0.0.178, user-requested):** every label on the Notifications screen is title-cased; the day-offset picker gained Before 15 Days and Before 30 Days; and **Settings → Notification Day Offset is now the source of truth for a case's Day Offset** — one shared list (`lib/features/settings/data/notification_day_offsets.dart`) feeds the Settings picker, the Add/Edit Case form and the Quick Update dialog, and the form's field starts on the stored Settings value (`AddEditCaseLookupData.defaultNotificationOffset` + `resolveDefaultNotificationOffsets`), while a case's own stored offsets still win. This deliberately supersedes plan line 182's shorter fixed list for the form, and moves the form's default off "same day".
- **Consequence to revisit:** `case_list_display_mode` is stored but has no consumer yet, and `UserSettings.defaultLandingPage` still defaults to `all_cases` for on-device testing (the plan's default is `daily_cause_list`); the View Settings screen shows and saves whichever value is stored, and its landing-page test seeds `daily_cause_list` explicitly rather than changing that default.

## Alignment Addendum (Implementation Plan Revision 2.4)

- Language, view/navigation configuration, notification defaults, and related settings are durable per-user preferences. Part A persists locally; premium Part B syncs only self-scoped preferences and never shares them across a firm.
- Editable court categories are managed and synchronized with courts/steps/case types/on-behalfs; built-in edits set `is_user_modified`, custom rows set `is_custom`, and all remain correctly user/firm scoped.
- Settings search is constrained to Settings and sub-settings localized labels only.
