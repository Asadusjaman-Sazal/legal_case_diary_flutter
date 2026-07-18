# Task 15 — Backup/Restore & Free-Tier Gating (Local)

> **Plan references:** "Resolved Design Clarifications" (Subscription Model, Free User Data Recovery), Sync Plan §5 "Local Database Security & Account Switching" (auto-export format), §6 "Subscription Enforcement", §12.3.1 "Security, Local Database Encryption & Sensitive Exports", Settings §8 (Backup & Restore screen) in `docs/implementation_plan.md`.
> **Goal:** Versioned JSON backup/restore with authenticated encryption, the Backup & Restore settings screen, local 50-case paywall gating, and the monthly backup nudge for free users. This completes PART A — the offline app.
> **Rules:** Follow the Universal Working Rules in `00_INDEX.md`. Ask, don't guess. Strictly offline — no Supabase or network code.

---

## Phase 1 — Versioned JSON Backup Format & Export Engine

1. Define the canonical backup envelope in a dedicated module (e.g., `core/utils/backup_format.dart`):
   - A top-level **`schema_version`** field (integer) in the JSON envelope — mandatory for forward compatibility.
   - App version, export timestamp (epoch ms), and a payload **checksum**.
   - Full data payload: a restorable snapshot of every portable app-state class: all domain rows and tombstones (`cases`, `case_history`, `notes`, `case_references`, `court_categories`, `courts`, `steps`, `case_types`, `on_behalfs`, `delete_requests`, `conflict_log`) including sync columns; all pending/blocked/conflicted `sync_queue` rows; per-user preferences and case-notification settings; pull-only profile/firm/member caches; composite cursors; seed migration ledger; sync/recovery metadata; and required local configuration. Include all custom and user-modified seed rows plus enough canonical seed/version information to reproduce the exact state.
2. Implement the export engine as a repository-level service so the **same code path** serves: manual "Backup to Local Storage", logout auto-export (Part B, Task 19), and the extended-offline safety archive (Part B, Task 19). This single-format rule comes straight from Sync Plan §5.
3. Record archive path, checksum, and completion state after every export.

**Phase 1 completion:** Run `flutter analyze`, fix all errors. Update `docs/version_history.md` (new version entry + `## Current Version`).

## Phase 2 — Authenticated Encrypted Export

> Per §12.3.1: never place plaintext exports in shared storage.

1. Encrypt every backup with an **authenticated format**: versioned header, KDF parameters, nonce, ciphertext, authentication tag, and checksum.
2. The encryption key derives from a **user recovery secret** (passphrase) or a platform-protected key — ask the user which UX they prefer for the manual backup flow (passphrase prompt vs. silent device-key) before implementing; the plan requires one of the two.
3. Never log or persist the recovery secret; redact all key material from any diagnostics.
4. Add security tests: round-trip an encrypted backup, verify decryption with the correct secret, and verify tampering with ciphertext/tag/checksum **fails closed** (per Verification Plan).

**Phase 2 completion:** `flutter analyze` clean; encryption round-trip tests pass. Update `docs/version_history.md`.

## Phase 3 — Restore / Import with Validation

1. Implement restore from a user-selected backup file:
   - Decrypt and authenticate first; on any tag/checksum failure, abort with a clear error and **never partially import**.
   - Validate the `schema_version` and run per-version upgrade adapters so **future schema changes never break old backups**. Unknown/newer versions are rejected with a clear message.
   - Import inside a single Drift transaction; on failure, roll back completely.
2. Define collision behavior: restoring into a non-empty database must ask the user (replace all vs. cancel). Do **not** silently merge — ask the user for the desired policy if the mockup doesn't define it.
3. Restored rows keep their original IDs and sync columns so a later premium upgrade (Part B) can push the restored data unchanged.
4. Add tests: full export → wipe → import round-trip preserving row counts, IDs, sync columns, and queue contents.

**Phase 3 completion:** `flutter analyze` clean; round-trip tests pass. Update `docs/version_history.md`.

## Phase 4 — Backup & Restore Screen UI

1. Build `features/settings/presentation/backup_restore_screen.dart`, matching **exactly** the mockup `legal_case_diary_flutter\mockup_html_screens\settings_backupRestore\code.html` (mandatory design reference), inside the `settings_sub_page_modal` header shell from Task 12.
2. Actions: **Backup to Local Storage** (runs Phases 1–2 export, then shows the saved path) and **Restore** (file picker → Phase 3 import flow with confirmation).
3. Show last-backup metadata (date/path) if available; store it in `SharedPreferences`.
4. All strings localized via `app_translations.dart` (Bengali default).

**Phase 4 completion:** `flutter analyze` clean; manual walkthrough of backup + restore. Update `docs/version_history.md`.

## Phase 5 — 50-Case Free-Tier Gating (Local Enforcement)

1. Enforce the free-tier limit **locally at the Add Case flow** (Task 07 left the hook in place): before inserting in add mode, call `CasesDao.getNonDeletedCaseCount()` — the count includes **only `is_deleted = false`** rows. Soft-deleted cases never count.
2. If count `>= 50` AND `isPremium == false` (from `SettingsRepository`), block the save and navigate to the **`PaywallScreen` stub** (`features/payments/presentation/paywall_screen.dart` — the real screen arrives in Task 21; the stub shows plans/benefits placeholder and a back action).
3. **Lapsed-premium users keep everything:** the gate only blocks *adding new cases beyond 50* on a free entitlement. It never hides, blocks, or deletes existing cases — even if a previously premium user has 200 cases.
4. In Part A there is no real subscription, so `isPremium` derives from the local `SettingsRepository` entitlement stub (default `false`). Keep the derivation behind one function so Task 21 swaps in `subscription_expiry + 48h grace > now()` with no call-site changes.
5. Editing, viewing, deleting, Daily Cause List, and Client Management remain fully available at/over the limit.
6. Add DAO/ViewModel tests: block at exactly 50 live cases; adding after soft-deleting one case below 50 succeeds.

**Phase 5 completion:** `flutter analyze` clean; gating tests pass. Update `docs/version_history.md`.

## Phase 6 — Monthly Backup Nudge (Free Users)

1. Because local export is a free user's **only safety net**, show a gentle monthly *"Back up your data"* nudge to free users (Resolved Clarifications — Free User Data Recovery).
2. Track `last_backup_nudge_at` and `last_successful_backup_at` in `SharedPreferences`; nudge at most once per calendar month, and skip if a backup happened within the month.
3. Nudge form: non-intrusive banner or dialog on app open that deep-links to the Backup & Restore screen — ask the user which presentation they prefer before implementing.
4. Localized text in `app_translations.dart`.

**Phase 6 completion:** `flutter analyze` clean. Update `docs/version_history.md`. **PART A is now complete — run the full offline manual test pass before starting Task 16.**

## Alignment Addendum (Implementation Plan Revision 2.4)

- Export a versioned authenticated-encrypted full-app snapshot: all domain rows/history/tombstones, court_categories and other custom/user-modified seeds, queue, user preferences, case-notification settings, pull-only caches, cursors, seed ledger, sync/recovery metadata, and required local configuration.
- Exclude database keys, auth tokens, passwords, recovery secrets, and other nonportable secure credentials. Recreate keys or require reauthentication after restore.
- Restore validates tag/checksum/version first, then offers Replace or Cancel for non-empty data. Replace occurs in one transaction and rolls back completely on failure.
- Use `getNonDeletedCaseCount()` for the free-tier gate; `getActiveCaseCount()` has different semantics and must not be used.
- Identity adoption and account transitions must preserve the correct per-user preference/notification scope and prevent cross-account leakage.
