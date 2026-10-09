# Task 06 — Shared Widgets, Navigation & Router

> **Plan references:** "Folder & File Structure" (`shared/widgets/`), Resolved Design Clarifications (Bottom Navigation Bar, FAB, Overdue Indicator, Calendar & Pickers), Development Workflow §6 (Navigation Pop & App Exit Confirmation), §10.1 View Settings keys.
> **Design references (mandatory):** `mockup_html_screens\dailyCauseList\code.html` (drawer + header patterns), each case screen's mockup for the card variants.
> **Goal:** All reusable UI building blocks plus app routing, so screen tasks (07–12) only compose them.
> **Rules:** Follow the Universal Working Rules in `00_INDEX.md`. Ask, don't guess.

---

## Phase 1 — Router & Shell

1. `core/router/app_router.dart` — GoRouter with routes for every screen in the folder structure (stub screens where not yet built).
2. Landing page comes from `SettingsRepository.default_landing_page` (default: Daily Cause List).
3. **Back/exit confirmation** (Dev Workflow §6): intercept the system back gesture on the root screen and show an exit-confirmation dialog; ensure no black screens/accidental pops anywhere. Extended in 0.0.383 from the root screen to every bottom-nav destination — see Phase 2 item 6.

**Phase 1 completion:** `flutter analyze` clean. Update `docs/version_history.md`.

## Phase 2 — `cases_screen_modal.dart` (Reusable Case-Screen Shell)

Per the folder-structure note, this reusable layout provides for every case screen:
1. Side **navigation panel button** + the panel itself (`app_navigation_drawer.dart` — Daily Cause List drawer template from the mockup; option visibility driven by `side_nav_options`; includes Case screens, Notes, References, Share, Print, etc.). **The panel's last line shows the bundled app version (0.0.408, user request)** — e.g. `V0.0.408`, read from `appVersion` so it can never drift from the build, carried by the `drawer_version` ARB key as a Latin `V{version}` token in both languages (a version identifier is not translated). **(0.0.409)** It is pinned to the very bottom of the panel's available space — a footer below the scrolling list rather than a row inside it — and is left aligned, per the user's follow-up. **(0.0.428, user request; position moved 0.0.429.)** The panel also carries the account's **current plan**, as one row in the **Print/Share** group, directly above **Print** (the user first asked for it under Settings and then moved it here): it names the plan (`Free`, `Premium`, or the paid plan's name) with a **Current Plan** caption, and expands on tap — **not** by navigating — into **Subscription Details** and **Subscription Plans**, each of which opens the screen it names and closes the panel like every other item. The plan comes from `currentPlanProvider` (`features/payments/presentation/current_plan.dart`), the same derivation Subscription Details prints, so the entitlement rule and the *dash until entitlement lands* rule live in one place; the row is always shown (no `side_nav_options` key) and the panel has no mockup to follow. **(0.0.431, user request.)** The panel's **profile icon** — the header avatar, a 48 px `InkWell` with a `Semantics(button: true)` label — now opens the **account sheet**: the address the account signed in with, captioned with the existing `auth_emailLabel`, then **Profile** (→ `/settings/profile`), **Manage Account** (→ `/settings/manage-account`) and **Logout**. The three rows reuse `settingsScreen_profile`, `settingsScreen_manageAccount` and `settingsManageAccount_logout`, so the sheet adds no ARB key; **Logout** runs the app's one branched logout (`runBranchedLogout`) and lands on **Login** explicitly, as Manage Account's card does. The sheet is shown on the **root navigator with the panel still open**, and the chosen row closes the panel, so a dismissed sheet returns the user to the panel and a chosen row to the screen behind it. It is a **widget with its own `ref`** rather than a closure over the panel's, because the logout reads providers and opens windows and the drawer's `ref` dies with the panel — the close-then-act shape was written, tested and rejected (`Using ref when a widget is about to or has been unmounted is unsafe`); the two navigators therefore reach it as state objects. `app_navigation_drawer_test.dart` covers the sheet, the two routes and the logout.
2. Page header with title, **search button**, view toggles, and the real **manual Sync button** at top-right on every case screen. Expose accessible idle, syncing, success, paused, and error states. In Part A or without entitlement, keep the control visible but disabled with a localized entitlement explanation; do not implement placeholder-only behavior or speculative copy. **The view toggle became functional in 0.0.203** — it is rendered only when the host screen wires `onViewToggle` (so it is absent on Notes and Case Reference, which use this shell but have no case list) and it reads/writes a **per-screen** mode (`case_list_display_modes`, a screen the user has never switched falling back to the global `case_list_display_mode` since 0.0.205); the extended view it switches to is specified in `docs/tasks/08_case_list_screens.md` Phase 6 — since 0.0.204 a spreadsheet-style table with one header row (`CaseTableHeader`) over value-only rows, resizable columns stored per user.
3. **Bottom nav bar** (`bottom_nav_bar.dart`): 4 configurable tabs, defaults Overdue Dates / Daily Cause List / Active Cases / Upcoming Cases, customizable via View Settings (`bottom_nav_tabs`).
4. **FAB (Add New Case)** on all main case screens **except Disposed Cases**.
5. **Print** and **Share** are separate actions (Share invokes the Android native share utility to share the app; Print is Task 14).
6. **Back on a destination offers Exit, never a pop (0.0.383).** Every screen built on this shell answers the system back gesture with the `Exit App?` window (`AppShellRoot.requestExit`) rather than returning to the screen the destination was opened from — the drawer and the All Cases summary cards push these routes, so a pop would land somewhere unrelated to the tab. An open drawer still closes on the first back; the window is unchanged, only when it appears. This extends Dev Workflow §6 (Phase 1 item 3) from the root screen to the destinations themselves.
7. **The exit is the host's close, not the framework's pop (0.0.422 — user bug report).** `SystemNavigator.pop()` does **not** finish the Android activity on this Flutter: the engine turns it into an Android back press, and a back press at the root of the task only backgrounds the app — so Exit App? left the app in memory like the home button. `AppShellRoot`'s confirm and `requestExit` now call `closeApp()` (`core/services/app_exit.dart`), which asks `MainActivity.kt` to `finishAndRemoveTask()` over its own channel (`com.legalcasediary.app/app_exit`, finished *and* dropped from recents); `SystemNavigator.pop()` stays as the fallback when no host answers, so the button is never dead. `test/core/app_shell_exit_test.dart` pins both ends: the host channel is called on confirm, and each fallback branch still reaches the framework pop.

**Phase 2 completion:** `flutter analyze` clean. Update `docs/version_history.md`.

## Phase 3 — Case Card & Inputs

1. `case_card.dart` — one widget with per-screen line layouts (variants for All/Active/Upcoming, Daily Cause List, Overdue, Disposed — exact line-by-line content specified in each screen's task file and mockup). Overdue variant gets the **red left border strip** (only on overdue cards). Includes Phone / Message icon-buttons and the **Update** button (quick date+step update pop-up per `dailyCauseList\code.html` — implemented in Task 08/09; expose the callback here). For list variants, keep the On Behalf/status label on the case-number row so the party-name row can use the full available card width without changing its existing left inset.
2. `custom_dropdown.dart` — single & multi-select, optional search, per the Add/Edit form's needs.
3. Simple date picker helper: all pickers other than the Daily Cause List badge calendar are plain pickers defaulting to today.

**Card label naming:** labels used only by `case_card.dart` (Next Date, Last Step/Result, Disposed) live under the `caseCard_` l10n key namespace (`caseCard_nextDate`, `caseCard_lastStep`, `caseCard_disposed`) so they read as widget-scoped rather than screen-scoped when other case-list screens reuse the card.

**Phase 3 completion:** `flutter analyze` clean. Update `docs/version_history.md`.

## Phase 4 — Settings Sub-Page Shell & Calendar Dialog Stub

1. `settings_sub_page_modal.dart` — reusable sub-page layout with app header + back button (used by every Settings sub-page in Task 12).
2. `calendar_picker_dialog.dart` — stub now; full badge-calendar implementation in Task 09 (it is used **only** by the Daily Cause List).

**Phase 4 completion:** `flutter analyze` clean. Update `docs/version_history.md`.

## Alignment Addendum (Implementation Plan Revision 2.4)

- Put the real manual Sync button at the top-right of shared `cases_screen_modal.dart` for every case screen. It exposes accessible idle, syncing, success, paused, and error states; when unavailable it is disabled with a localized entitlement explanation. Remove placeholder-copy behavior. **The "disabled with a localized entitlement explanation" half is now true of the whole control (0.0.399, user request):** the colour, label and tap were already entitlement-aware, but a free account still wore the **success cloud** (`cloud_done_outlined` — a claim that its work is safely in the account, which cannot be true when sync is never active on the free plan) and still saw a red **count** over it, because every write path populates `sync_queue` free accounts included. `lib/shared/widgets/sync_button.dart` — the one control both this shell's header and the Admin Panel's header build — now wears the off cloud for a free account, draws no badge for it, and answers the entitlement in its tooltip before any queue or connection fact. The free-variant headers in the seven case-screen mockups drew the same wrong glyph and now draw `cloud_off`.
- Shared search UI must accept a feature-provided scoped query so each case screen searches only its own filtered dataset.
- Android app sharing is owned by Task 14's platform service; this task only exposes the action callback.
