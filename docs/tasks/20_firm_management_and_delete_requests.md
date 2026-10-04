# Task 20 — Firm Management & Delete-Request Workflow

> **Plan references:** Sync Plan §1 (Account Mode Detection, Associate Deletion Policy, Online-Only Firm Administration), Database Schema (`firms`, `firm_members`, `firm_invites`, `delete_requests` + notes), Folder & File Structure (`manage_associates_screen.dart` [Design-deferred]) in `docs/implementation_plan.md`.
> **Goal:** The Manage Associates experience (firm creation, invites, permission toggles), permission freshness/rollback behavior, and the full offline-capable delete-request workflow with hardened review.
> **Rules:** Follow the Universal Working Rules in `00_INDEX.md`. Ask, don't guess. Firm administration is **online-only**; case-data operations (including delete requests) remain offline-capable.
> **Firm failures are the firm domain's own (error-log follow-up).** A firm RPC fails for reasons a sign-in never can, so this task no longer borrows `AuthFailure`: `FirmFailureKind`/`FirmFailure`/`mapFirmFailure` in `firm_repository.dart` classify what a call threw — network, server, unauthorized, too many attempts, unavailable, invalid invite code, already a member, owner offline, premium required, unknown — and `firmErrorText`/`failureText` in `auth_widgets.dart` are the one place a screen asks for the sentence. The three kinds the auth wording would misdescribe (server, unauthorized, unavailable) have firm sentences of their own; no connection, too many attempts, the premium gate and the owner being offline stay shared. Every failure the screen catches is recorded (`firm.action`, `firm.members`, `firm.invites`) and a firm failure is logged as `FirmFailure(server)`, never under an auth failure's name. The roster read is recorded in the provider, not in the screen's build, and an unchanged repeat collapses into one line — Riverpod retries a failed provider, and a report wants the fault rather than the retry count.

---

## Phase 1 — Individual → Firm Transition & Manage Associates Screen

1. **Firm creation trigger:** the moment the main user adds their first associate via `Settings > Accounts & Profile > Manage Associates`, the system creates a `firms` record, sets the main user's `role` to `'owner'`, links both profiles to the new `firm_id`, and transitions the account to Firm mode. Implement this as an online-only server operation (RPC or guarded multi-statement call — ask the user if they prefer an RPC; RLS-privileged multi-row writes suggest one).
2. **Premium gate:** Firm mode requires an **active premium subscription** (Resolved Clarifications). Block adding the first associate on a free entitlement and route to the Paywall (Task 21). **As built (0.0.384):** the *entry* is gated, not only the action — the Accounts & Profile menu offers Manage Associates to a **premium individual** and to a firm owner **whatever their plan** (a lapsed owner keeps the firm and the server still lets them manage its roster; only *creating* a firm is refused), and to nobody else. The screen itself keeps its free-account Paywall state for a deep link.
3. Build `manage_associates_screen.dart` — marked **[Design-deferred]** in the plan, so there is no mockup: propose a layout following the Justice Ledger design system and **confirm with the user before building**. Required contents: associate list (name, role), per-associate permission toggles, invite generation entry point, and remove-associate action.
4. **Offline state:** all firm-admin screens show "Connect to the internet to manage your firm" when offline.

**Phase 1 completion:** Run `flutter analyze`, fix all errors. Update `docs/version_history.md` (new version entry + `## Current Version`).

## Phase 2 — Invites & Permission Management

1. Wire the invite primitives from Task 17 Phase 5 into Manage Associates: generate a code (plaintext shown once, copy-to-clipboard/share), list outstanding unused invites, and revoke unused invites.
2. **Permission toggles:** owner edits `can_add`, `can_edit`, `can_delete` (and role `associate`/`viewer`) per member — online-only writes to `firm_members` under owner-only RLS.
3. **Permission freshness (client side):** refresh `firm_members` on launch, resume, reconnect, and before every online permission-sensitive action; store `permissions_synced_at`. The local cache is advisory — `push_changes` is always authoritative.
4. **Provisional offline actions & rollback:** offline, authorized-looking case operations proceed **provisionally** (queue entries retain the `pre_mutation_payload` snapshot — Task 05/18 plumbing). If the server rejects because permissions changed: restore the authoritative server row (or the pre-mutation snapshot until the pull completes), resolve/remove the rejected queue entry, refresh permissions, and show *"Your firm permissions changed; this pending action was not applied."* Destructive provisional actions must be **visibly marked pending** in the UI.
5. **Removing an associate:** an owner-only online server operation immediately revokes membership, sessions, Realtime topic access, and future app access. Preserve authored records and immutable audit attribution without reassignment. Reject and never merge that member's queued mutations; on the removed device's next connectivity, discard/roll back pending local mutations, force logout, and securely erase all app data. Broadcast membership revocation so connected devices enforce removal immediately.

**Phase 2 completion:** `flutter analyze` clean. Update `docs/version_history.md`.

## Phase 3 — Delete Requests: Creation (Associate Side, Offline-Capable)

1. When an associate **without `can_delete`** attempts to delete a case, note, or reference, create a `delete_requests` row instead of deleting: `entity_type`, `entity_id`, `entity_snapshot` (JSON snapshot at request time), `target_base_version` (target version observed), `requested_by`, `status = 'pending'`.
2. Queue it through `sync_queue` with `entity_type = 'delete_request'` — fully **offline-capable**. Show the toast: *"Deletion request sent to Admin/Owner."*
3. The requester can edit/cancel their **own pending** request (RLS permits requester updates while pending).
4. Localized strings in `app_translations.dart`.

**Phase 3 completion:** `flutter analyze` clean. Update `docs/version_history.md`.

## Phase 4 — Delete Requests: Review (Approver Side)

1. **Notification surface:** pending delete requests appear as a notification/badge in the Settings dashboard (and optionally Manage Associates — confirm placement with the user) for all firm members with `can_delete = true`.
2. Review screen: tapping shows the `entity_snapshot` of the item plus requester and date; actions are **Approve** and **Reject** (with optional `review_note`, e.g., rejection reason). Reviewers may stage decisions offline; the server remains authoritative.
3. **Hardened approval semantics** (server side — extend `push_changes`/a dedicated RPC per the `delete_requests` schema note):
   - Approval submits both the request `base_version` and `target_base_version`, locks request and target, and proceeds only when the request is still pending **and the target is unchanged**.
   - If the target changed: return `target_conflict` with the current snapshot/version, set/show `status = 'stale_review_required'`, and require the reviewer to inspect and **reconfirm** — an old snapshot never authorizes deletion of materially changed data.
   - If the target is already soft-deleted: return `already_resolved` with tombstone metadata and retain the request as audit history.
   - Successful approval **atomically** tombstones the target (with server-side cascade for case children), resolves the request, records reviewer + server time, and produces idempotent receipts.
4. **Reject** keeps the record, sets `status = 'rejected'`, and notifies the requester (badge/toast on their next sync).
5. `delete_requests` rows are never hard-deleted (audit trail; RLS has no DELETE policy).
6. The client never resolves later queue entries merely because a review completed.

**Phase 4 completion:** `flutter analyze` clean; delete-review tests pass (changed target → `target_conflict`/`stale_review_required`; reconfirmed current version deletes atomically; duplicate approvals return the same terminal receipt). Update `docs/version_history.md`.

## Alignment Addendum (Implementation Plan Revision 2.4)

- Removing an associate immediately revokes server/app access. Preserve immutable audit attribution; do not reassign authored records. Reject removed-member mutations, discard/roll back their pending local mutations, broadcast membership revocation, and on next connectivity force logout plus secure app-data erasure on that device.
- Reference customizations remain firm-shared while preferences remain per-user throughout membership changes.
- Extend Task 18's `push_changes(rows jsonb)` in a later migration with delete-review mutation types, idempotent receipts, locking, and concurrency tests. Task 18 owns the base RPC; this task owns only that explicit extension.
