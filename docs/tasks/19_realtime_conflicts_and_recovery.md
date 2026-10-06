# Task 19 — Realtime, Conflict Resolution & Recovery Flows

> **The bundle carries the app's errors.** `buildDiagnosticBundle` gained an `errors` section (bundle format version 2), filled from `ErrorLog`, so an export answers the questions the sync queue cannot: a refused sign-in, a failed payment, a framework assertion. It is metadata by construction — an `ErrorLogEntry` holds a time, an area and a redacted label, never a case field and never a raw server message — so the metadata-unless-payloads-are-consented rule is unaffected. A user who cannot work out what went wrong can also **Copy Diagnostics**, which writes a plaintext report — app version, generation time, then one `time | area | label` line per failure — to the clipboard, and the Support screen's WhatsApp and e-mail message carries that same report. The bundle itself is still the encrypted, passphrase-gated artefact it always was; the copy is the fast, no-file path beside it.
>
> **Plan references:** Sync Plan §1 (Broadcast from Database, WebSocket reconnection, resume throttle, conflict resolution), §3 "Preventing Deleted Data Resurrection" (incl. Extended Offline Period Reset), §5 "Local Database Security & Account Switching" (logout branches), `sync_queue` schema note (Sync Status/Diagnostics screen), `conflict_log` schema notes, §12.3 "Power & Sync Efficiency" in `docs/implementation_plan.md`.
> **Goal:** Foreground Realtime notifications, connectivity handling, the full conflict-resolution experience, the Sync Status/Diagnostics screen, extended-offline recovery, and the branched logout flows.
> **Rules:** Follow the Universal Working Rules in `00_INDEX.md`. Ask, don't guess.

---

## Phase 1 — Realtime "Broadcast from Database" (Foreground Only)

1. Implement `sync/realtime_listener.dart`: the client keeps exactly **one** channel open, subscribed to its private topic — `firm:{firm_id}` for firm members, `user:{user_id}` for individuals. Do **not** use `postgres_changes` subscriptions.
2. On receiving a `{table, id}` ping, perform a **micro delta pull** via REST for just the changed row(s), merging through the same pull-side logic as Task 18 Phase 3.
3. **Lifecycle bounds:** open the channel on foreground resume (`WidgetsBindingObserver.didChangeAppLifecycleState == resumed`); close it **immediately** when backgrounded or the screen locks. Zero radio usage when idle. Background isolates still make no network calls (Task 13 enforced rule).
4. Track a monotonically increasing local **connection generation** for the continuity checks below.

**Phase 1 completion:** Run `flutter analyze`, fix all errors. Update `docs/version_history.md` (new version entry + `## Current Version`).

## Phase 2 — Connectivity & Reconnection Strategy

1. Implement `sync/connectivity_monitor.dart` on the **`connectivity_plus` stream** — event-driven only, never polling.
2. WebSocket reconnection: immediate attempt on foreground resume; on failure retry with exponential backoff 1s → 2s → 4s → 8s → 16s → 32s (max). After 6 failed retries (~63 s), stop active retrying and rely on the connectivity stream.
3. **User-visible indicator:** after 3 consecutive failures, show a subtle "Sync paused" icon in the app header; tapping forces an immediate retry and resets the backoff.
4. **Gap repair:** after every reconnection or connectivity restoration, push pending changes and then force a per-table delta pull before declaring sync healthy.
5. **Continuity-aware 60 s resume throttle:** skip a resume pull within 60 seconds **only** when the same Realtime connection generation remained continuously subscribed since the last successful pull. Any disconnect, channel error, auth refresh, suspension with unknown continuity, or reconnection forces an immediate delta pull.

**Phase 2 completion:** `flutter analyze` clean. Update `docs/version_history.md`.

## Phase 3 — Conflict Resolution (Three-Way Reconciliation + UI)

1. **On push conflict** (from Task 18 results): entity is `conflict_pending`, compaction frozen, later queue entries preserved, rejected attempt logged in `conflict_log`. Now implement the reconciliation: apply the server row as the authoritative base, three-way compare base/server/local `changed_fields`. **Disjoint** field changes are rebased into a new mutation against the latest server version; **overlapping or semantically coupled** fields stay `conflict_pending` for user review.
2. **On pull conflict:** identical path — a pull never silently overwrites a queued mutation.
3. **Tombstone conflicts:** if the server row is deleted while local edits are pending, attach the tombstone as `server_payload` and require explicit **rebase/copy-to-new-record** or **confirmed discard** — never silently delete queued work (Zombie Data rules, Sync Plan §3).
4. **Conflict UI:** a **non-dismissible banner** links to a **Review Conflict** screen showing server values, attempted values, and later preserved edits, with the editor's name resolved via same-firm `profiles` access. Initial release may require manual field selection/copying for ambiguous conflicts, but queue metadata must support `mergeable_conflict` from day one. Banner dismissal (`is_dismissed`) or elapsed time **never** resolves data — resolution occurs only through successful rebase/push, explicit user choice, or confirmed discard with authoritative rollback.
5. Mirror every local `conflict_log` entry to Supabase (`entity_type = 'conflict_log'` in the queue); on a new device, pull and merge conflict history by `id`.
6. Local tombstone purge guard: purge soft-deleted local rows after 90 days **only** when `synced_at IS NOT NULL AND synced_at >= updated_at` (never purge an unsynced tombstone).

**Phase 3 completion:** `flutter analyze` clean; structured-conflict and zombie-data tests pass. Update `docs/version_history.md`.

## Phase 4 — Sync Status / Diagnostics Screen

1. Available to **every** user (not just firm admins): list queue entries with entity, operation, state, retry count, last error, and last attempt time.
2. Actions per entry: **Retry**, **Discard** (with confirmation and authoritative-row rollback/pull), **Review Conflict** (routes to Phase 3 UI), and **Export Diagnostic Bundle**.
3. Diagnostic bundles default to **metadata only**; including queue/case payloads requires explicit consent and produces an **encrypted** bundle (Task 15 Phase 2 format) with a visible expiry/deletion reminder (§12.3.1).
4. A blocked/conflicted badge in the app header links here; no queue row may ever become permanently invisible.
5. No mockup HTML exists for this screen — follow the Justice Ledger design system and confirm the layout with the user.

**Phase 4 completion:** `flutter analyze` clean. Update `docs/version_history.md`.

## Phase 5 — Extended-Offline Recovery (150-Day, Per-Device)

> **Clarification (user approved; recorded in `docs/implementation_plan.md` → Resolved Design Clarifications, "Extended-Offline Recovery Lock Applies to Firm Mode Only").** This phase applies in **firm (multi-user) mode only** — `firmModeProvider` true. An account in **individual mode is never locked** and performs no recovery work and no network work for it. The lock exists to stop a device resurrecting rows that **another writer** deleted while it was away; a single-author diary has no other writer, so it cannot have anything deleted behind it, and locking it out of its own edits would be pure harm. This sharpens the plan's earlier "premium/Firm mode" wording: the gate is **firm mode alone**, never entitlement, so a premium individual is exempt too.

1. The check is **per-device**: compare the device-local `last_successful_sync_at` (Task 18 Phase 3) on reconnect. Threshold **150 days** (30-day buffer under the 180-day server tombstone retention). Never use `profiles.last_successful_sync_at` (another device would mask the gap).
2. When triggered, in one durable local transaction set persistent `extended_offline_recovery_required = true` **before** any export or network work; pause push/pull workers; wait for in-flight local writes. While set, repositories reject every mutation and the UI disables editing/FAB with a recovery-required message. The lock **survives process termination**.
3. **Automatic safety export under the lock:** export the complete local Drift DB plus all pending/blocked/conflicted `sync_queue` rows and metadata to the versioned encrypted Backup & Restore format (Task 15). Record archive path, checksum, completion state. No post-export mutation is possible.
4. Blocking warning: *"You have been offline for [X] days. Your local changes have been saved to [path]. Fresh data must be loaded from the server before editing can continue."* with:
   - **Proceed:** verify export checksum → wipe every local app-state class (all domain tables/tombstones, queue, pull-only caches, user preferences/settings, case-notification configuration, cursors, custom and seeded reference data, seed ledger, and nonessential sync/recovery metadata) while preserving only the minimum secure session material needed for the authenticated pull → full authenticated pull and seed reconstruction → commit the fresh DB → clear the recovery flag and re-enable mutations. Require reauthentication if retaining session material is unsafe. Any failure keeps the lock and retries safely.
   - **Close:** leave the app locked without cloud writes; every next launch restores the blocking flow until recovery succeeds.

**Phase 5 completion:** `flutter analyze` clean; extended-offline reset test per the Verification Plan passes. Update `docs/version_history.md`.

## Phase 6 — Branched Logout Flows

Implement the three logout branches from Sync Plan §5 (a single "sync before wipe" rule would deadlock free and offline users):

1. **(a) Premium + online:** if `sync_queue` has pending rows, run a mandatory sync; wipe local data and complete logout only after it succeeds.
2. **(b) Premium + offline:** block with *"Connect to the internet to sync your changes first."* plus an explicit **"Log out anyway"** option → warning *"Some data haven't finished syncing to cloud yet. Logging out now will result in those unsynced data being discarded."* with **Proceed**/**Close**. **Proceed** always auto-exports all data first (exact Task 15 Backup-to-Local-Storage format) with the *"Your data has been backed up to [path]…"* message, then wipes.
3. **(c) Free users:** always auto-export (same format/message), then wipe.
4. Wipe scope: local Drift DB **and** `sync_queue`, plus sensitive in-memory state (§12.3.1 lifecycle hardening). A new login starts with a fresh database and an initial pull (premium) or fresh local DB (free).
5. Route the forced re-login path (online session invalidation, Task 17 Phase 4) through these same branches.
6. **A completed logout lands on the Login screen (follow-up, user request).** `runBranchedLogout` returns true only when the session actually ended; Manage Account's `_signOut` then navigates to Login explicitly (`context.go`, not a pop) instead of closing back to Settings. The router's sign-in gate cannot do it: `authGateRequiredProvider` is read once per launch, so a device that launched signed in is never re-gated, and the user would be left on the now-empty Settings surface. A cancelled branch returns false and navigates nowhere.

**Phase 6 completion:** `flutter analyze` clean; all three logout branches manually verified per the Verification Plan. Update `docs/version_history.md`.

## Alignment Addendum (Implementation Plan Revision 2.4)

- Realtime/conflicts include court_categories and every firm-shared reference table.
- Diagnostics displays persisted `sync_queue.last_attempt_at`.
- Recovery flags, archive path/checksum/completion, per-device last successful sync, and checkpoints live in durable sync_metadata and are committed atomically.
- Fresh-start recovery clears all domain tables, queue, pull-only caches, user preferences/settings, case notification configuration, cursors, custom/seed data, seed ledger, and recovery metadata after archive verification. Preserve only minimum secure session material required for authenticated pull; require reauthentication when unsafe.
- Logout/account switch follows the same complete wipe scope and invalidates profile/preferences caches. **(0.0.394)** That includes the account-scoped **live reads** the app holds in memory rather than in the database — this account's payment history, the admin panel's status and its queue, a firm owner's roster and invite codes — which no wipe can reach. `AuthViewModel._forgetAccount()` drops them together with the SharedPreferences profile record, and it runs from the Logout button *and* from a sign-in that arrives as a different account id, because a session the server revoked, or one that expired, clears nothing on its own.
