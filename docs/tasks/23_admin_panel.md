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

- Payment Requests, with two collapsible sections: **Pending open** and **Resolved closed** by default, because a resolved submission cannot be acted on and the admin opening the screen has work to do.
- Resolved is sorted by decision time, newest first (the server's own order is by submission time).
- Each row: payer name, status chip, plan and amount worded by the same helpers the paywall uses, the sender's number, the TrxID, the five personal fields, and the submitted date. A resolved row also shows the resulting expiry and any note.
- **Approve** and **Reject** while pending. Reject opens a confirmation carrying an optional note for the payer, because a rejection is a decision the payer may query.
- One outcome banner for the last action, and a load-failure state with a retry.

## Phase 4 — Navigation

- `AppRoutes.adminPanel` as a **shell route** built with `NoTransitionPage` (the no-motion rule that guards the bottom nav is about how it feels to switch, and the panel is selectable from that bar).
- One entry in `bottomNavTabDefs` carrying `adminOnly: true`, last in the canonical order, and one `_NavItem` in the drawer after Settings. **A single entry is deliberate**: View Settings drives both areas from the same list, so one entry is what makes "appears wherever the admin selected" work with one admin gate.
- `BottomNavTabDef.adminOnly` and `_NavItem.adminOnly` are distinct from `removable`: a non-admin cannot *hide* the panel, they never *see* it, and a `sideNavOptions` entry left over from an earlier admin session cannot reveal it. The bar drops a gated key rather than rendering a dead route.
- Admin status is `false` while it is still loading, so nothing appears before the server has said yes.

## Phase 5 — Records

Recorded in `docs/implementation_plan.md` (Resolved Design Clarifications + the schema/RPC section) and in `docs/tasks/21_payments_and_subscription.md`'s Addendum, since the approval flow it completes is Task 21's.

## Acceptance checklist

- [x] `app_admins` has `full_name`/`email`; `full_name` is writable, the grant is not.
- [x] `is_app_admin()`, `admin_list_payment_submissions()` and `admin_reject_payment()` exist, are admin-gated, and refuse `anon`.
- [x] `payment_submissions` has `rejected_by`/`rejected_at`; no RLS policy was widened.
- [x] The panel shows Pending open and Resolved closed, and a resolved row is newest-decision-first.
- [x] A non-admin sees no payment data and no navigation entry anywhere.
- [x] Approve and reject reach the server, are followed by a reload, and a refusal is reported without clearing the row.
- [x] Both languages render, with Bengali digits.
- [x] `flutter analyze` clean; full `flutter test` green.

## Not in this version

- **Rejecting after an approval** — the server refuses it (`already_resolved`) and the panel does not offer a refund path.
- **Any section other than Payment Requests.** The panel's structure takes more; each is new server surface and new policy, so they are added when they are needed rather than scaffolded empty.
- **Adding or removing admins from the app.** That stays a service-role operation, deliberately: the one thing that must not be reachable from a phone is the decision about who is allowed to decide.
