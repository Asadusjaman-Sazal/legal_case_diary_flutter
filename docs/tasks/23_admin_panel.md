# Task 23 — Admin Panel (Payment Administration)

> **Plan references:** Sync Plan §7 "Manual MFS Payment Flow" (the approval step that previously had no UI), §6 "Subscription Enforcement", Database Schema (`app_admins`, `payment_submissions`, `payment_approval_events`, `approve_payment` contract), "Resolved Design Clarifications" (Payment Method, Subscription Model) in `docs/implementation_plan.md`.
> **Goal:** the first administrator-facing screen in the app. A registered admin sees every user's payment request, can approve or reject one from the phone, and can place the panel in the bottom bar or the drawer through Settings → View Settings.
> **Rules:** Follow the Universal Working Rules in `00_INDEX.md`. Ask, don't guess. The app **never** grants admin rights to anyone: `app_admins` stays server-managed, has no client policy of any kind, and is changed only by the owner through an audited migration or a service-role operation.

---

## Why this task exists

Task 21 built the payer's half of the MFS flow — a submission, its TrxID, and a visible status. The other half had no home at all. `approve_payment` existed and was admin-gated, but the only way to reach it was for the owner to open the Supabase SQL editor by hand, read the `payment_submissions` table, and run the function for each one. That is workable for the first paying lawyer and untenable for a hundred.

## Phase 1 — Server: who may administer, and what the panel may ask for

Migration `20261002110000_admin_panel.sql`, applied to `lsthasywrdrhuuxnykau` and recorded in `supabase/AllSupabaseSql.md`.

1. **`app_admins` gains `full_name` and `email`**, filled in by hand by the owner for each later admin, so a revoked admin can still be identified afterwards. Existing rows are backfilled once from `auth.users.email`.
2. **The grant stays immutable, the description does not.** `reject_admin_update()` refused *every* UPDATE, which would have made the two new columns unwritable. It is replaced by `reject_admin_grant_change()`, which refuses any UPDATE touching `user_id`, `granted_at` or `granted_by` and permits the descriptive columns. Revocation stays a DELETE.
3. **`payment_submissions` gains `rejected_by` and `rejected_at`.** `approved_by`/`approved_at` are the approval record and are untouched; these are the same idea for the other outcome, so a refused payment records who turned it down.
4. **`is_app_admin()`** — SECURITY DEFINER, returns whether the *caller* is an admin. The only way a client learns its own status; the registry row behind the answer stays unreadable.
5. **`admin_list_payment_submissions()`** — every submission joined to the payer profile, returning `full_name`, `email`, `bar_association`, `membership_no` and `mobile_no` alongside the TrxID, amount, status and dates, plus `approved_new_expiry` from the immutable event (what *this* approval set, not the account's current expiry).
6. **`admin_reject_payment(id, note)`** — sets the status, stores the optional note, records the rejecting admin. `already_resolved` for an approved or already-rejected submission, so a rejection can never undo an approval.
7. **Approval needs nothing new**: `approve_payment` is reused unchanged, admin-gated and already writing its own immutable audit event.
8. **No RLS is widened.** `payment_submissions` stays `user_id = auth.uid()` and `profiles` stays self-or-firm; the panel reads through the RPC, which is gated in the function body. `anon` cannot execute any of the three functions.

## Phase 2 — Client data layer

`lib/features/admin/data/admin_repository.dart` and `presentation/admin_viewmodel.dart`, matching `payment_viewmodel.dart`.

- `AdminRepository`: `isAdmin()`, `listPaymentRequests()`, `approve()`, `reject()` — all through the RPCs. `UnavailableAdminRepository` reports "not an admin" so a build with no backend shows nothing.
- `AdminActionFailure` maps the server's own `status` strings to the four things the screen can word, and recognises the `admin_required` exception the gate raises.
- `adminStatusProvider` is separate from the list, because **navigation** needs the answer before the panel does: a screen that discovered it was not an admin after opening would flash its contents to everyone.
- An action never mutates the local list — it re-reads from the server, so what the admin sees is always what the server holds.

## Phase 3 — The Admin Panel screen

`lib/features/admin/presentation/admin_panel_screen.dart`.

- **Design reference:** `legal_case_diary_flutter\mockup_html_screens\admin_panel\code.html` (with `screen.png` beside it), written from the shipped screen after the fact — see the recorded departure below.
- Payment Requests, with two collapsible sections: **Pending open** and **Resolved closed** by default, because a resolved submission cannot be acted on and the admin opening the screen has work to do.
- Resolved is sorted by decision time, newest first (the server's own order is by submission time).
- Each row: payer name, status chip, plan and amount worded by the same helpers the paywall uses, the sender's number, the TrxID, the five personal fields, and the submitted date. A resolved row also shows the resulting expiry and any note.
- **Approve** and **Reject** while pending. Reject opens a confirmation carrying an optional note for the payer, because a rejection is a decision the payer may query.
- One outcome banner for the last action, and a load-failure state with a retry.

### Phase 3 follow-up — the panel becomes a menu, and gains Non-verified Accounts (0.0.459, user request)

> The panel now opens as a **menu of two sub-pages**, in the Account & Profile shape:
>
> - **Payment Requests** — everything above, moved to `admin_payment_requests_screen.dart` in a `SettingsSubPageModal`; the *"Payment Requests"* heading is gone (the page header covers it), and each card is **numbered within its section from 1**.
> - **Non-verified Accounts** — new (`admin_unconfirmed_accounts_screen.dart`): the sign-ups that were created and never confirmed, so abandoned ones can be cleaned up. A card carries the account's name, e-mail and **date & time of creation** (and the last sign-in, only when there is one), numbered from 1, with a **Delete** behind a confirmation.
>
> The panel itself keeps the case screens' header (hamburger, Sync Status badge, Sync button) rather than the back arrow a Settings sub-page wears, because it is a **top-level destination** — side menu *and* bottom-nav tab; the two sub-pages are pushed and do wear the back arrow. Routes: `/admin-panel/payment-requests` and `/admin-panel/unverified-accounts`.
>
> **Search** — the header's search button on both sub-pages (`SettingsSubPageModal.actions`, unused until now) filters each card by any text it shows. **A section holding a match is opened** while a query is active, so a result is never hidden inside the closed Resolved list; a query matching nothing says *No Results Found*.
>
> **The badge** — the side-menu Admin row carries a `Badge.count` of what is waiting in the panel: pending payment submissions **plus** the unconfirmed accounts (`adminPendingCountProvider`, which answers 0 while loading or on failure so it can never keep the menu from drawing, and is read only once the account is already known to be an admin).
>
> **Server (new migration `20261009120000_admin_unconfirmed_accounts.sql`).** "Never confirmed" is invisible to clients — `email_confirmed_at` lives in `auth.users`, and the `profiles` row (created by the sign-up trigger) carries no confirmation flag — so the list needs its own admin-gated RPC. Three functions: `is_provisional_account(uuid)`, the shared "has this account done anything?" test lifted from `discard_unconfirmed_signup()`'s guard; `admin_list_unconfirmed_accounts()`, the never-confirmed accounts newest first with their profile's name and mirrored e-mail and a **`can_delete`** flag; and `admin_delete_unconfirmed_account(uuid)`, which re-runs that guard and refuses an unknown, confirmed or used account. The page disables Delete when `can_delete` is false rather than offering an action the server would refuse. Pinned by `supabase/tests/admin_unconfirmed_accounts_test.sql` (a rolled-back smoke test) and, on the client, by the three admin test suites.

## Phase 4 — Navigation

- `AppRoutes.adminPanel` as a **shell route** built with `NoTransitionPage` (the no-motion rule that guards the bottom nav is about how it feels to switch, and the panel is selectable from that bar).
- One entry in `bottomNavTabDefs` carrying `adminOnly: true`, last in the canonical order, and one `_NavItem` in the drawer after Settings. **A single entry is deliberate**: View Settings drives both areas from the same list, so one entry is what makes "appears wherever the admin selected" work with one admin gate.
- `BottomNavTabDef.adminOnly` and `_NavItem.adminOnly` are distinct from `removable`: a non-admin cannot *hide* the panel, they never *see* it, and a `sideNavOptions` entry left over from an earlier admin session cannot reveal it. The bar drops a gated key rather than rendering a dead route.
- Admin status is `false` while it is still loading, so nothing appears before the server has said yes.

## Phase 5 — Records

Recorded in `docs/implementation_plan.md` (Resolved Design Clarifications + the schema/RPC section) and in `docs/tasks/21_payments_and_subscription.md`'s Addendum, since the approval flow it completes is Task 21's.

## Recorded mockup departure (resolved)

**The screen shipped before its mockup, by the user's decision, and the mockup was then written from the shipped screen.** CLAUDE.md rule 9 binds a screen body to a referenced file under `mockup_html_screens/`, and no such file existed when Task 23 was built. The user reviewed that gap and chose to **build the mockup later, as the screen needs some touch** — so the panel shipped on the Justice Ledger patterns it copied (the paywall's collapsible cards and typography), and the mockup was a follow-up from the screen rather than before it, the same shape as the paywall's own recorded departure.

**The follow-up is now done.** `mockup_html_screens/admin_panel/code.html` draws the panel as it ships: the case screens' header without the back arrow, search or view toggle, the *Payment Requests* heading one step above the shared Settings label, and the two sections as the shared Settings sub-menu button — Pending open with its request and the two decisions, Resolved closed — each with its own leading icon and a count where a chevron would sit. The header's sync button is drawn in its **ordinary enabled state** — the shared success cloud (`cloud_done`) in primary ink with the "Sync" tooltip — not the grey free-plan variant with a "Sync Requires a Premium Subscription" label that the case screens' mockups carry, because the panel is reached only by a signed-in admin with sync available. That glyph follows the header's narrowed icon set: the shared `SyncButton` now shows the success cloud for idle or a completed sync, the network-off cloud for offline or paused (count stays on top), and keeps its own mark for a real error. `screen.png` sits beside it at 390 px wide, like every other mockup.

**Drawing the mockup surfaced two values the screen got wrong, and the user chose the mockup as the target.** Recorded here because rule 9 made them a conflict the moment the HTML existed: (1) the sender's number was being wrapped in the amount formatter, so a phone number rendered as `৳01712345678`; (2) the method printed the stored `bkash` rather than the brand the payer chose, even though the checkout already maps the three providers to branded labels. **Both are now fixed on the screen** — the number renders plainly (and falls back to the shared em-dash when absent, like the fields around it), and the method goes through a local `_methodLabel` mapping. The checkout keeps its own copy of that mapping; a third screen needing it is the point at which the two should become one.

**The panel is an account's, not a device's (0.0.394 — reported).** `adminStatusProvider` and `adminPaymentRequestsProvider` are **live reads** held in memory by providers, not rows in the database, so neither the branched logout's wipe nor `signOut` could reach them: after user A logged out and user B signed in on the same device, **B was shown the Admin Panel even when not an admin**, with A's queue in it. They are now dropped by `AuthViewModel._forgetAccount()` whenever the account changes — on the Logout button, and on a sign-in that arrives as a different account id, which is what a revoked or expired session leads to (that path clears nothing on its own, which is why the panel also survived a session the server had ended). A non-admin therefore has no panel entry and no queue on any path. Pinned by `test/features/account_switch_leak_test.dart`; recorded in `docs/implementation_plan.md` and Task 21.

### Phase 3 follow-up — the Payment Requests buttons stay at the top (0.0.463, user request)

> Pending and Resolved were rows at the head of a `ListView`: scroll past the first screenful and nothing on screen said which section the admin was in, which is the wrong answer on a page the user expects to hold **hundreds of cards**. Each section is now one `SliverMainAxisGroup` in that page's `CustomScrollView` — a **pinned** header (the shared `SettingsMenuCard`, in a band that paints the page background across the list's full width so the cards slide underneath it unseen) followed by the section's own cards. The button therefore holds the top of the list while its own cards are being read and is pushed out as the next section's button arrives in its place. The group is load-bearing, exactly as it is for the case screens' pinned court headings: plain consecutive pinned headers in one scroll view pile up at the top and would all stay on screen at once. The **search, the per-section counts, the pull-to-sync and the action banner are unchanged**, and the closed section still contributes its button alone, so the next button comes straight up behind it.

## Acceptance checklist

- [x] `app_admins` has `full_name`/`email`; `full_name` is writable, the grant is not.
- [x] `is_app_admin()`, `admin_list_payment_submissions()` and `admin_reject_payment()` exist, are admin-gated, and refuse `anon`.
- [x] `payment_submissions` has `rejected_by`/`rejected_at`; no RLS policy was widened.
- [x] The panel shows Pending open and Resolved closed, and a resolved row is newest-decision-first.
- [x] A non-admin sees no payment data and no navigation entry anywhere — **including** on a device that was used by an admin a moment earlier (0.0.394).
- [x] Approve and reject reach the server, are followed by a reload, and a refusal is reported without clearing the row.
- [x] Both languages render, with Bengali digits.
- [x] `flutter analyze` clean; full `flutter test` green.
- [x] **Follow-up:** `mockup_html_screens/admin_panel/code.html` was written from the shipped screen, with `screen.png` beside it (the user's decision — see the recorded departure above), and the two mismatches it exposed were fixed on the screen.

**0.0.459 — the menu, the badge and Non-verified Accounts (user request).**

- [x] The panel is a **menu** of two sub-pages; it keeps the drawer header, and both sub-pages wear a back arrow.
- [x] Payment Requests moved to its own page, with its inner heading gone and every card **numbered within its section from 1**.
- [x] **Non-verified Accounts** lists the never-confirmed sign-ups (name, e-mail, creation date & time), numbered from 1, with **Delete** behind a confirmation.
- [x] `admin_list_unconfirmed_accounts()` and `admin_delete_unconfirmed_account(uuid)` exist, are admin-gated, SECURITY DEFINER, and refuse `anon`; both share `is_provisional_account()` with `discard_unconfirmed_signup()`, so `can_delete` and the delete cannot disagree.
- [x] The page **disables** Delete when the server says the account may not go, and names why.
- [x] A **search** in both sub-pages' headers filters every card by any text it shows, and **opens a closed section** that holds the match.
- [x] The side-menu Admin row carries a **count badge** of pending payments plus unconfirmed accounts, and none when that is zero.
- [x] Both languages render; `flutter analyze` clean; full `flutter test` green; `generate_all_supabase_sql.dart --check` clean.
- [x] **The migration was applied to the project (0.0.460)** — `dart run tool/apply_supabase_migrations.dart` applied `20261009120000` (1 of 36 pending) and then `20261009130000`. Verified through the Supabase connector: the three functions exist, `SECURITY DEFINER`, owned by `postgres`. `supabase/tests/admin_unconfirmed_accounts_test.sql` **passes against the live project** (it rolls back; a follow-up count confirmed no residue).
- [x] **A grant the default privileges left open is closed (0.0.460).** `20261009120000` revoked `public, anon` on the internal `is_provisional_account()` but not `authenticated` — and Supabase grants a new `public` function directly to `authenticated` too, so it stayed callable by any signed-in account (a one-boolean-at-a-time oracle about an account id it already had to know). `20261009130000_revoke_provisional_guard.sql` takes that EXECUTE back; the two admin RPCs keep theirs and gate themselves in the body. Verified through the connector: the guard now shows only `postgres` and the server's bypass role.
- [x] **The Pending and Resolved buttons stick to the top of the list (0.0.463).** Pinned `SliverPersistentHeader`-style bands inside one `SliverMainAxisGroup` per section, so the button names the section being scrolled and hands over to the next one. Pinned by `admin_payment_requests_screen_test.dart`'s "a section button holds the top of the list for its own cards" (which fails with the pinning removed). `flutter analyze` clean; full `flutter test` green.
- [ ] **`mockup_html_screens/admin_panel/screen.png` is stale** — the HTML is redrawn as the menu, but the PNG still shows the old single-screen panel. **The user has confirmed this does not matter: the HTML is what counts for the app.**

## Not in this version

- **Rejecting after an approval** — the server refuses it (`already_resolved`) and the panel does not offer a refund path.
- **Any page other than the two the panel now holds** (Payment Requests, Non-verified Accounts). The menu takes more; each is new server surface and new policy, so they are added when they are needed rather than scaffolded empty. *(0.0.459 added the second; the earlier wording — "any section other than Payment Requests" — is superseded.)*
- **Sweeping unconfirmed accounts without being asked.** Non-verified Accounts lists them and can delete one at a time; nothing runs on a schedule. A cron sweep would be a decision about deleting people's accounts unattended, which is not this page's to make.
- **Adding or removing admins from the app.** That stays a service-role operation, deliberately: the one thing that must not be reachable from a phone is the decision about who is allowed to decide.
