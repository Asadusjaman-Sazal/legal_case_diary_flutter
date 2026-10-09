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

> Per §12.3.1 (revised): encryption is opt-in and off by default — a backup is sealed only when the user turns it on. Never place a *sealed* export in shared storage against the user's wish.

1. Seal a backup with an **authenticated format** (versioned header, KDF parameters, nonce, ciphertext, authentication tag, checksum) when encryption is on. See *Encryption is opt-in, off by default* below for the revised behaviour.
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

### Phase 4 follow-up — dialog-free backups into a diary folder (0.0.446)

> Requested by the user (Backup & Restore screen & system). Deviates from Phase 1/4's "manual backup → save dialog → shows saved path" and Phase 3's "restore → file picker" wording: pressing **Backup to Local Storage** (and **Backup as Excel File**, per the user's choice) no longer opens a "Save to…" dialog. It writes automatically into the diary's backup folder — the **public Downloads directory on Android, `Download/LegalCaseDiary`** (`/storage/emulated/0/Download/LegalCaseDiary`), answered by a small host channel because path_provider's Android paths are all app-scoped (`Android/data/<pkg>`) and invisible to a file manager; where the channel is absent the resolver falls back to the private documents directory — renamed to **`Backup_dd-mm-yy_hh-mm-ssam/pm.<ext>`** (`.lcbak` for the container, `.xlsx` for the workbook); `defaultBackupFileName`/`defaultExcelFileName` now use the local-civil date and the lower-case `am`/`pm`. **Restore** scans that folder instead of the file picker: one backup restores directly, several are offered in a slightly rounder-corner popup (the app's dialog with `sheetRadius + radiusSm`), and the system picker remains the fallback when the folder is missing or holds no app backup (explicit user requirement). **Backup to Google Drive** now also auto-saves into the folder (no save dialog) and then offers the share sheet, attaching the real public-folder file directly; the `ShareableBackupSink` that used to copy a `content://` result into the cache is removed (0.0.447). The picker is still used when the folder itself cannot be written or the folder-first sink throws a `FileSystemException`. The two automatic safety exports (logout and extended-offline) keep the private `LocalArchiveSink` (`<documents>/backups`) unchanged.

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

## Encryption is opt-in, off by default (user-requested)

> **This revises the Phase 2 note above and §12.3.1.** Encryption is no longer automatic; it is a per-user preference that starts **off**. Asked for directly, and the plan's §12.3.1 bullet now says the same.

- **One preference, read everywhere.** `BackupMetadata.encryptBackups` (SharedPreferences key `backup_encryption_enabled`, default `false`) is the single switch. Every export consults it: the manual local/Drive backup, the logout safety copy, the extended-offline recovery archive, and the diagnostic bundle. **Off** writes the readable versioned JSON envelope (`exportSnapshot` with no secret); **on** seals it in the existing authenticated container. The restore path already opens both kinds, and the screen now prompts for a passphrase **only** when the picked file is an encrypted container (`looksLikeEncryptedBackup`) — so a backup sealed while the setting was on still opens with it off.
- **The passphrase is still asked fresh each time and never stored.** Enable/Disable only turns the gate on or off; it does not set or remember a secret.
- **The screen gains a section the mockup does not draw.** **Encryption On Backup** sits before Automatic Backup and carries the usefulness/challenges copy plus Enable/Disable on one line, in the screen's own primary-button style. A recorded departure from the mockup's three sections.
- **The section's copy is sentence case, not Title Case (user-requested, 0.0.388).** The why / cost / state paragraphs and the note under the action card, plus the two safety-copy bodies on the recovery screen (`recoveryLock_saveBody`, `recoveryLock_saveBodyUnencrypted`), are stored in ordinary sentence case in the ARB: Title Case is for titles, headings, subtitles and button labels only. Recorded in the plan's §8 Backup & Restore bullet; the section heading, its subtitle and **Enable** / **Disable** keep Title Case.
- **The recovery screen's passphrase fields are conditional.** With encryption off the blocking recovery screen asks for no passphrase and writes the safety copy unencrypted; with it on the fields appear as before.

## Excel Backup & Restore — deliberate deviation (0.0.263, user-requested)

> **This deviates from two things stated above and must be carried into Part B.** The plan's backup format is the versioned **JSON** envelope, and §12.3.1 as it stood then required every export to be authenticated-encrypted. A workbook the user opens in Excel cannot carry the app's AEAD container, so this feature is **plaintext by design**: an exception the user asked for and approved, not an oversight. The encrypted `.lcbak` JSON remains the canonical, complete backup.

- **Scope is four tables, not all twenty.** The workbook carries `cases`, `case_history`, `notes` and `case_references`, plus an `Info` sheet holding the format marker, `schema_version`, app version and export time. Courts, steps, case types, on-behalfs, court/case categories, preferences, caches, cursors, the queue and metadata are **not** in it, so a workbook is not a complete backup and is restored into a diary that already holds that reference data. The screen's Excel-format section says both of these plainly.
- **Restore is scoped to the file's own tables.** `BackupRepository.restoreSnapshot` now runs its collision check and its delete-all over **the tables the file carries**, in reverse FK order, instead of every portable table. A JSON backup carries all twenty, so its behaviour is unchanged and the plan's Replace-or-Cancel rule still holds; a workbook replaces only its four tables and leaves everything else untouched — which is what keeps a partial file from emptying a working diary's reference data. The same scoping runs the pre-replace question (`hasDataInTables`), so a workbook never asks about data it would not touch.
- **No spreadsheet package could be used.** `excel` pins `xml <7` and `pdf ^3.13.0` (Task 14) requires `xml ^7.0.1`, so the two can never coexist. The container is therefore hand-built OOXML on `archive` + `xml`, both of which were already resolved transitively through `pdf` and are now direct dependencies. Writing is string-built; reading also understands shared strings, so a workbook the user re-saved in Excel still restores.
- **The column list is derived, not written down.** Sheet headers come from the live Drift schema (`$columns` / `requiredDuringInsert`) via `BackupRepository.excelColumnSpecsFor`, so the export, the downloadable template and the reader cannot drift from the tables: adding a column to a table adds it to all three.
- **Sheet names are fixed English identifiers** (`Cases`, `Case History`, `Notes`, `Case References`, `Info`), deliberately **not localized**, so one workbook restores in either app language; the ARB explains the names in the user's own language instead.
- **Row rules.** A blank `id` is given a fresh UUID, which is what makes a hand-added row importable; any other blank in a NOT NULL column without a default is refused **naming the sheet and the spreadsheet row**, before any SQL runs. Rows import verbatim otherwise, keeping ids and all five sync columns, so a restored row can be pushed unchanged after a Part B upgrade.
- **Part B must mirror this.** The four tables are the synced domain tables, and the workbook carries their sync columns — so nothing about the workbook needs server-side change, but the plaintext-export exception must be recorded wherever server/backup policy is written, and `schema_version` in the `Info` sheet must be upgraded through the same `backupPayloadAdapters` chain as the JSON payload (it already is).

## Screen headings and the template's reference sheets (0.0.264, user-requested)

- **The mockup's headings are now sub-menu buttons.** Backup & Restore, Automatic Backup and Excel Backup Format render through the shared `SettingsMenuCard` — the same control the Account & Profile menu uses — with an expand chevron in place of the "open a screen" arrow, and still reveal their options one at a time. This deliberately departs from the mockup, which draws those three as plain `h2` headings, and was asked for so the screen reads like every other Settings sub-menu.
- **Backup Status stays exactly as the mockup draws it:** a plain, always-visible heading over the status card. It is a report, not a set of options, so it is deliberately **not** a member of the screen's `_Section` enum and can never collapse.
- **The downloadable template carries reference sheets the workbook format itself does not.** `Courts`, `Case Categories`, `Case Types`, `Steps` and `On Behalfs` list the live reference data (each led by one clearly-labelled `Example — Sample Row`), and a `Guide` sheet explains in prose how to add cases: a blank `id` gets a fresh UUID, `court_id`/`on_behalf_id`/`case_category_id` must quote ids from the reference sheets, `case_type`/`last_step` must quote a name, and dates are Unix epoch milliseconds. The Guide is English like the sheet names, so one workbook reads the same in either app language.
- **Only the template carries them; a real export still writes just the four data sheets plus `Info`.** The reader accepts `excelTemplateSheets` and ignores them, so the user can fill in the very sample they downloaded and restore it without deleting anything. `buildExcelTemplate` takes the extra sheets and an `exampleValues` override, and `BackupRepository.buildExcelTemplateWorkbook` fills both from the live database — so it is now `async` — which is what makes the sample case quote this diary's own court, role and category ids.
- **Regenerating the localizations also corrected two stale strings.** The checked-in generated localizations still carried sentence-case "Restore from backup" and "Last successful backup" after the ARB had been moved to Title Case, so `flutter gen-l10n` (needed for the new keys) changed them; the screen test's expectations were updated to match the ARB, which is the source of truth.

## Courts sheet: District column and district grouping (0.0.265, user-requested)

- **The template's `Courts` sheet gains a fourth `District` column** so a court can be filtered by the district it sits in. It shows the district's displayed name in the language the sheet was generated in — the screen passes a `districtLabel` callback resolved from the app's seeded district labels, exactly as it already passes `categoryLabel` for court categories. The sheet is template-only and never read back, so no reader or schema change was needed.
- **AD/HCD rows are unchanged.** The Appellate Division and High Court Division courts carry no district, so their `District` cell is left blank and they still head the sheet in their own category order.
- **Lower courts are grouped by District, then Court Category.** `_courtsSql` returns `district`, `cc.order_index` and `c.order_index`; `_referenceData` sorts in Dart (rather than SQL) so the district names come out alphabetical in either app language, falling back to the existing category/order sequence within a district.
- **The Guide gained one line** explaining the new column and its blank AD/HCD cells.
