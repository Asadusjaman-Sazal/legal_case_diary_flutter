# Task 22 — Full Verification Suite (Automated + Manual)

> **Plan references:** "Verification Plan" (Automated Tests, Manual Verification) in `docs/implementation_plan.md`.
> **Goal:** Execute the complete verification suite over the finished app. Earlier tasks created many of these tests incrementally — this task ensures every item exists, passes, and is documented; missing tests are written here.
> **Rules:** Follow the Universal Working Rules in `00_INDEX.md`. Ask, don't guess. Log every fix discovered during verification through the normal phase-completion protocol.

---

## Phase 1 — Automated Test Inventory & Gap Fill

1. Inventory all existing tests from Tasks 01–21 against the plan's Automated Tests list. Write any missing tests:
   - **Auth/onboarding:** associate login and single-use invite-code flow via `join_firm` (valid code joins; used/revoked codes rejected).
   - **DAOs:** soft-delete behavior, offline queue ordering (dependency-then-`created_at`), compaction matrix outcomes (insert+delete → both dropped, etc.), 50-case free-tier block at `count(is_deleted = false) >= 50`.
   - **Optimistic concurrency:** exact `base_version` accepted with one server increment; stale/future/tampered versions return structured conflicts; same-hash `mutation_id` retries return the stored receipt; different-hash reuse returns `mutation_id_reused`; tombstones cannot be resurrected; later queued edits survive reconciliation.
   - **Delta pull:** paginate multiple rows with identical `server_updated_at`; crash between fetch and local commit/checkpoint; replay safely; prove no row is skipped across page, table, reconnect, or empty-result boundaries.
   - **Delete review:** changed targets → `target_conflict`/`stale_review_required`; reconfirmed current versions delete atomically; duplicate approvals return the same terminal receipt.
   - **Timestamps:** `date_utils.dart` converts server UTC instants to local epoch ms, renders Bangladesh civil dates without day drift, handles DST-independent configured-zone boundaries deterministically.
   - **Security:** open/search the SQLCipher DB with the correct key; reject an incorrect/missing key **without replacing data**; raw files contain no known plaintext fixtures; round-trip an authenticated encrypted backup and detect tampering.
   - **Schema:** verify all Drift and server-internal tables, constraints, indexes, RLS grants, fixed RPC `search_path`, global sync columns, composite cursor storage, `mutation_receipts`, and immutable audit ledgers.
2. Run the entire suite (`flutter test` + server-side SQL/pgTAP tests) until green.

**Phase 1 completion:** All automated tests pass. Run `flutter analyze`, fix all errors. Update `docs/version_history.md` (new version entry + `## Current Version`).

## Phase 2 — Manual Verification: Device, PDF & Notifications

1. **Low-end device test:** verify no frame drops from the simulated blur alternatives (no `BackdropFilter` anywhere) on a representative 2GB RAM device.
2. **PDF print test:** export native-text PDFs with mixed English/Bengali and conjunct-heavy Tiro Bangla fixtures; then force the bounded raster fallback on a large cause list. Verify page-height pagination, configured bitmap caps, progress/cancellation, buffer disposal, and completion without OOM on a low-memory device.
3. **Notification reliability:** verify exact-alarm scheduling, boot rescheduling, inexact fallback, and the OEM guide flow (Task 13) on at least one aggressive-OEM device or emulator profile.

**Phase 2 completion:** Findings documented; regressions fixed. `flutter analyze` clean. Update `docs/version_history.md`.

## Phase 3 — Manual Verification: Sync, Conflicts & Recovery

Run each scenario exactly as written in the plan's Manual Verification section:

1. **Multi-user concurrency:** update a case on an emulator; verify it reflects on a physical device via Realtime.
2. **Offline auth:** login online → airplane mode → close/reopen → verify access, add cases, toggle airplane mode, verify sync.
3. **Extended-offline reset (335-day, per-device):** set device-local `last_successful_sync_at` to **336 days ago** — one day past the device's 335-day trust window, which sits 30 days under the server's 365-day tombstone retention — reconnect, and verify (and check that **334 days** does not lock): (1) the persistent mutation lock commits before export/network work, (2) the encrypted safety archive contains the versioned JSON payload + queue metadata, decrypts with the recovery secret, and fails closed on tampering, (3) **Close** leaves the app locked across restart, (4) wipe + full pull happens only after **Proceed** and clears the lock only on success. Verify another device syncing daily does not mask the stale device's gap.
4. **Clock skew:** set a device clock 1 year ahead; verify device time cannot influence server acceptance (only exact `base_version` succeeds) and the skew warning appears after sync.
5. **Structured conflict:** edit the same case offline on two devices from the same base; sync one, then the stale one. Verify `status = conflict` with the authoritative row/version, recorded base/submitted/server payloads, preserved later edits, and automatic rebase only for disjoint fields.
6. **Zombie data:** delete a case on Device A while Device B is offline; bring B online; verify the case does not reappear on A or Supabase.

**Phase 3 completion:** All scenarios pass; issues fixed and re-verified. `flutter analyze` clean. Update `docs/version_history.md`.

## Phase 4 — Manual Verification: Accounts, Subscription & Payments

1. **Logout flows:** verify all three branches — premium+online (sync then wipe), premium+offline ("Log out anyway" warning with Proceed/Close), free (the **Backup Data to Local Storage** Yes/No choice, then wipe). The choice is offered, never mandatory, and is skipped for a premium account already synced and for a free account that authored nothing (0.0.398).
2. **Firm subscription expiry:** expire a firm owner's subscription in Supabase Studio; verify all associates lose sync access on next connection (after the 48h grace), with the correct owner/associate banners.
3. **Payment submission & approval:** submit a Monthly payment; verify server `submitted_at` and pending status. Approve only through the protected `approve_payment` RPC; verify row locking, exact amount/plan validation, server-calculated expiry, owner-firm mirroring, approval metadata, and one immutable audit event. Retry and concurrently invoke approval to prove expiry extends exactly once; verify ordinary clients and direct row updates cannot approve or alter audit records.

**Phase 4 completion:** All scenarios pass. `flutter analyze` clean. Update `docs/version_history.md` and mark the project verification complete in `docs/currentlyWorking.md`.

## Phase 5 — Complete Requirement Traceability

Create a matrix mapping every implementation-plan heading to its task, implementation artifact, automated test, and manual check. At minimum verify:

1. All five case lists, their filters/grouping/search scopes, KPIs, manual sync states, and responsive mobile layouts.
2. Every Add/Edit field and cascade reset, both party-phone fields, durable per-user notification choices, validation, and non-deleted 50-case gating.
3. Date-change-only repository-owned history creation; no duplicate or step/note-only automatic history.
4. Daily Cause List badge calendar; Notes and References CRUD/pinning/contextual search.
5. Every Settings submenu, court hierarchy add/edit/delete/reorder, `is_user_modified`, Bengali rendering, language switching, and per-user preference isolation.
6. Phone, SMS, WhatsApp message, supported-capability WhatsApp call/fallback, Android app sharing URI/MIME/failure behavior, and PDF flows.
7. Full-state encrypted backup contents, exclusions, checksum/version validation, Replace/Cancel collision flow, transactional rollback, identity adoption, and account-switch isolation.
8. Court-category sync/RLS/Broadcast/conflict behavior, pull-only cache rules, `last_attempt_at`, recovery metadata, and fresh-start wipe scope.
9. Failed-join cleanup, associate revocation/forced wipe, removed-member mutation rejection, MFS config validation/rotation, and all self-versus-firm scope boundaries.

**Phase 5 completion:** Every implementation-plan heading has at least one passing traceability entry; no requirement is marked implicitly covered. Run the full suite and `flutter analyze`, then update version/progress documentation.

## Phase 6 — The Device Limit (0.0.565)

The plans' concurrent-device numbers are now enforced server-side (plan bullet *The Device Limit Is Enforced On The Server*). This phase is what a database and two phones must prove before the limit is trusted. The server half is **done** (0.0.566): both migrations and their correction are applied, the project records 60 versions, and the proof prints `DEVICE OK`. The proof earned its keep on the first run by catching a defect in the trim — a third sign-in was admitted and an active device was revoked as `lapse` instead of the plan-full answer; `20261022120000_device_trim_counts_the_caller.sql` fixed it (see the plan bullet). The phone scenarios below are still outstanding, because they need devices.

1. **~~Apply and prove the server half.~~ Done (0.0.566).** `dart run tool/apply_supabase_migrations.dart` applied the pair plus the trim correction, and `psql` on `supabase/tests/device_limit_test.sql` prints `DEVICE OK`. Run it again after any later change to these functions — it is the gate that caught the trim defect. It covers: the caps per tier, a third device refused while both others are recent, a re-login on a known phone reusing its row, an idle spare evicted as `cap` with its push token deleted, a lapsed account evicting nothing, a device unable to revoke itself, a revoked session reading nothing but still writing inside its 14-day window and refused with `device_revoked` after it, the grand-fathered window, the wipe acknowledgement, and `device_trim_surplus` revoking the surplus after a ceiling falls and nothing without a live plan.
2. **Manually, on two phones on one Pro account.** Sign in on A and B; use both; sign in on C — C is refused and names A and B. Leave B idle eight days (or age its row in the database) and sign in on C — B is evicted, C is admitted, and the lawyer on B sees *This Device Was Signed Out*. On B, write a case while offline, then let it be evicted: it must upload that case before erasing, and must show the "could not save" screen and keep the data when it cannot reach the account.
3. **Lapse.** Expire the plan with a revoked device pending: nothing is erased anywhere, and the app keeps working locally. Renew, and the surplus device is told the plan changed.
4. **Devices screen.** Settings → Manage Account → Devices lists the slots with *This device* and *Last used*, frees one on request, and cannot remove the device you are holding.
5. **Roll-out safety — the server half is proved (0.0.567).** With the migrations applied but the app not updated, an old install must keep syncing until 2026-11-21 — **reading and writing alike**; after that date an unregistered session reads nothing and pushes nothing. `supabase/tests/device_limit_test.sql` now covers both sides: an unregistered session pushes inside the window and `push_changes` lets it through, a revoked device is still refused while that window is open, and after it an unregistered session is refused with `device_revoked`. The proof fails on the first of those when the pre-0.0.567 `device_may_push` is put back, so the checks depend on the branch rather than passing beside it. Still manual: verify the app shows no gate at all if the registry RPCs are missing, and that an install on an older build really does hand its unsent work up — the first half of this item was a server promise the server did not keep until `20261022130000_device_push_rollout_window.sql`.

**Phase 6 completion:** `DEVICE OK` printed (done), the manual scenarios documented, the applied versions recorded in `supabase/AllSupabaseSql.md` (done — 60 versions, ledger regenerated), and the plan's bullet updated from "written but not applied" (done).
