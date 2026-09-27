# PART A — Offline Manual Test Pass (device checklist)

> **Why this exists.** Task 15 Phase 6 closes with: *“PART A is now complete — run the full offline manual test pass before starting Task 16.”* Part A is the whole offline app (Tasks 01–15). This document is that pass.
>
> **What it is not.** It is not a re-run of the automated suite. `flutter analyze` is clean and `flutter test` is **739 passed, 2 skipped**; the 50-case boundary, the encryption round-trip, tamper rejection, the restore rollback, the nudge rule and the month boundary are all pinned by tests. Every item below exists because **only a device can prove it** — a platform channel, an OS dialog, a real status bar, an aggressive OEM, or a physical print/share target.
>
> **Ends with:** a recorded pass/fail per item. Any failure is fixed through the normal phase protocol (a new `docs/version_history.md` entry + `docs/currentlyWorking.md` note) before Task 16 begins.
>
> **Re-verified 26 September 2026 at `0.0.271`** (the version carrying the seven Task 15 refinements after the pass was first written). The quoted messages, the package id, the preference keys, the `archive.*` keys and the routes below were each checked against the code rather than assumed, so an item that fails on the device is a device finding and not a doc that drifted. None has been run yet: every box in this pass is still empty.

---

## 0. Setup

**Devices**
- **Required:** the Xiaomi/Redmi phone (aggressive OEM) — section D depends on it.
- **Also useful:** one non-aggressive device (or the same phone after clearing data) for D7, and an emulator for F1 if a slow one is available.
- Set the app to **English** for the wording quoted below; repeat any Bengali spot-check through Settings → Language.

**Build and install** (project convention: `docs/Guide&BestPractices.md` §4)

```bash
flutter analyze
flutter test
flutter build apk --debug
adb install -r build/app/outputs/flutter-apk/app-debug.apk
# or, for a live session with logs:
flutter run -d <device-id>
```

**Helpers** (package id `com.legalcasediary.app`)

| Purpose | Command |
|---|---|
| List devices | `flutter devices` |
| Reset the app completely (fresh install state) | `adb shell pm clear com.legalcasediary.app` |
| Read the app's stored flags (debug builds only) | `adb shell run-as com.legalcasediary.app cat /data/data/com.legalcasediary.app/shared_prefs/FlutterSharedPreferences.xml` |
| Pull a backup off the phone | `adb pull /sdcard/Download/<name>.lcbak` |
| Flutter logs only | `adb logcat -s flutter` |
| Screenshot for the record | `adb exec-out screencap -p > shot.png` |

Flags worth knowing when reading the XML: `last_successful_backup_at`, `last_backup_path`, `backup_schedule_days`, `last_backup_nudge_at`. The archive record (`archive.path` / `archive.checksum` / `archive.state`) lives in the **database**, not here.

---

## A. Backup & Restore (Task 15 Phases 2–4) - Pass

Start from a clean install with **at least one live case** (anything you add below counts).

- [ ] **A1 — Backup writes an encrypted file.** Settings → Backup & Restore → **Backup to Local Storage** → the “Protect this backup” window appears, asking for the passphrase **twice** (typing a mismatched confirmation shows “The two passphrases do not match.” and writes nothing). Enter a passphrase → the progress window appears (it cannot be dismissed) → Android's **Save to…** dialog appears.
- [ ] **A2 — The saved location is reported.** After saving: a snack bar says *Backup saved to &lt;path&gt;*, and the **Backup Status** card shows the same path with the date in Bangladesh time. Check the file exists in Files/Downloads.
- [ ] **A3 — The file is not readable.** `adb pull` it. Open it: it is a JSON header (`"format": "legal-case-diary-encrypted-backup"`, `"kdf": "pbkdf2-hmac-sha256"`, `"cipher": "aes-256-gcm"`, `salt`, `nonce`, `ciphertext`, `tag`, `checksum`). Grep it for a party name or case number — **none must appear**. This is §12.3.1: no plaintext ever reaches shared storage.
- [ ] **A4 — The passphrase is not stored.** Force-close the app, reopen, tap Backup again: it asks for a passphrase again, with nothing pre-filled. (Nothing may be written anywhere for it; only the *backup* metadata is stored.)
- [ ] **A5 — A wrong passphrase fails closed.** Restore with the wrong passphrase → *“Wrong passphrase, or the backup file has been changed.”* and **no Replace window** — the database is untouched.
- [ ] **A6 — A non-backup file is refused.** Restore → pick a photo/PDF → *“That file is not a backup made by this app.”*
- [ ] **A7 — A tampered file is refused.** Flip a character inside the `ciphertext` value in a copy of the `.lcbak`, then restore it → the same wrong-passphrase/tampered message. (Optional variant: set `format_version` to a higher number → *“This backup was made by a newer version of the app.”*)
- [ ] **A8 — Restore into an empty database asks nothing.** Clear the app data, add one throwaway case, then restore a backup that holds different data: with the database not empty you must get the Replace window (see A9); with an empty database (clear data, launch, restore immediately) the restore runs straight through and ends with the **Restore complete** window → OK.
- [ ] **A9 — Replace or Cancel on a non-empty database.** Restore with data present → the window shows the **file name**, its **backup time**, the **app version** that wrote it, the **record count**, and the warning “Everything currently on this device will be replaced. This cannot be undone.”
  - **Cancel** → nothing changes (the cases you had are still there, and none of the backup's are).
  - **Replace** → “Restore complete”, then the app reloads its data.
- [ ] **A10 — Every screen shows the restored data.** Immediately after Replace, without restarting: All Cases, Daily Cause List, Notes, Case Reference, and a case's Detail view all show the restored rows (the restore invalidates the database provider on purpose). Watch for a stale list anywhere — that is the exact thing this item exists to catch.
- [ ] **A11 — Schedules persist.** Pick *Every 7 days*, close and reopen the screen, reopen the app: the choice is still selected. (Nothing runs on it yet — that is Part B's executor.)
- [ ] **A12 — Backup to Google Drive.** Tap it: same passphrase window, same Save-to dialog, then a window **“Send to Google Drive?”** naming the saved file, with **Send** / **Not now**.
  - **Not now** → nothing is shared and the backup stays saved and recorded.
  - **Send** → the Android **share sheet** opens with the backup attached; choose **Drive** and confirm the file uploads. With Drive **not** installed, the same sheet must still open with other targets — no crash, no “not available” message.
  - Note: Android's Save-to dialog usually returns a `content://` URI that no share sheet can attach, so the app shares a temporary copy of the same bytes from its cache. If nothing can open the sheet, the app must say *“Could not open the share sheet.”* — never a dead tap.
- [ ] **A13 — A dismissed dialog writes nothing.** Tap Backup, then dismiss Android's Save-to dialog. No snack bar, and the status card still shows the previous backup (or “No backup has been made yet.”). `archive.state` must not become `complete`.
- [ ] **A14 — A legacy plaintext backup (if you have one).** A `.json` envelope written by 0.0.227 or earlier restores with an **empty** passphrase and is reported as a legacy file rather than as corrupt. If no such file exists on this machine, mark **N/A** — the automated suite covers both file kinds.

---

## B. Free-tier gating & the paywall (Task 15 Phase 5) - Pass

Part A has one entitlement only (**free**), so the premium side of these rules is automated-only and deliberately not repeatable by hand here.

- [ ] **B1 — The 50th case is allowed.** With **49** live cases, add one: it saves normally.
- [ ] **B2 — The 51st opens the paywall.** With **50** live cases, add one: the case is **not** saved and the **Premium** screen opens, saying “Free plan limit reached”, “The free plan holds up to 50 cases…”, the benefits, both plans (৳100 per month, ৳1,000 per year) and *“Subscriptions are not available yet.”* Both plan buttons are visibly **disabled**.
- [ ] **B3 — Back returns to work.** The app-bar back arrow (and the system back gesture) closes the paywall, the case count is still 50, and the form can be reopened and cancelled normally.
- [ ] **B4 — Everything else still works at the limit.** At 50 cases: open a case, **edit** and save it, **delete** a case, use the Daily Cause List, and open Client Management (case history). None of them may mention the limit or open the paywall.
- [ ] **B5 — A delete makes room.** After deleting one case (49 live), adding a new one saves normally.
- [ ] **B6 — Deleted cases do not count.** Soft-deleting cases never moves the count: from 50 live, delete three and confirm three adds succeed.
- [ ] **B7 — A lapsed premium user keeps everything** *(automated-only in Part A)*: a database with 200 cases must stay fully viewable/editable/deletable. If a premium profile can be arranged on a test build, re-check B4 against it.

*Reaching 50 cases by hand is tedious; the boundary itself is automated. If you already have a case-heavy database, use it — otherwise B1/B2 can be spot-checked by adding/removing near the boundary and trusting the suite for the exact edge.*

---

## C. The monthly backup nudge (Task 15 Phase 6) - Pass

- [ ] **C1 — It appears when it should.** Fresh data, **at least one live case**, no backup this month → on launch a strip appears above the app: *“You have not backed up this month. Your cases live only on this phone — save a backup to keep them safe.”* with a **“Back up to local storage”** link and a **✕**.
- [ ] **C2 — It never blocks.** The strip does not cover the status bar, the app's header, or the bottom navigation; the app is fully usable with it on screen.
- [ ] **C3 — It appears wherever the user lands.** Change the default landing page (Settings) and relaunch: the strip is there too. Open a case detail and a Settings sub-page: it stays. Rotate the device in each: still no gap above the content, and no double spacing where the strip used to be.
- [ ] **C4 — Tapping opens Backup & Restore.** Tap the message (not the ✕) → Settings → Backup & Restore opens and the strip disappears.
- [ ] **C5 — Dismissing costs one tap.** Relaunch and press **✕** → the strip goes away and does **not** come back for the rest of the month, even after a restart. (`last_backup_nudge_at` is set when it is *shown*, so an abandoned launch still counts as the month's one ask — check the flag in the prefs XML.)
- [ ] **C6 — A backup in the month cancels it.** After a successful backup, relaunch: no strip.
- [ ] **C7 — Next month it comes back.** With automatic date/time off, move the device clock forward one month (the rule uses the **Bangladesh civil month**), relaunch: the strip appears again. Move the clock back afterwards.
- [ ] **C8 — No cases, no nag.** Clear the app data, launch, leave the diary empty: no strip. Add one case and relaunch: the strip appears.
- [ ] **C9 — Free users only** *(automated-only in Part A)*: a premium profile must never see the strip. Check it if a premium test profile is available; otherwise it is covered by `backup_nudge_banner_test.dart`.

---

## D. Notification alarms (Task 13's outstanding device checklist) - Pass

Nothing in the test host can prove any of these.

- [ ] **D1 — First launch on the Redmi** offers the battery/auto-start guide **once**, and **Take Me There** lands on MIUI's auto-start page.
- [ ] **D2 — Exact alarms.** Grant “Alarms & reminders” from the guide's exact-alarm step and confirm the state line flips to the already-allowed wording.
- [ ] **D3 — Test notification.** Settings → Notifications → **Send Test Notification** posts a banner. Deny the OS permission and confirm it reports a refusal instead of claiming success.
- [ ] **D4 — The daily alert fires with the app closed.** Set the time a minute or two ahead, swipe the app away, and wait: the alert arrives with the case number, parties and court.
- [ ] **D5 — It survives a reboot.** Reboot with the app closed and confirm the alarm is re-armed (the plugin's `RebootBroadcastReceiver`).
- [ ] **D6 — Tapping an alert opens the case.** From a warm start **and** from a cold start, tapping the posted alert opens that case's Detail view — and the launch must **not** be covered by the setup guide.
- [ ] **D7 — No guide on a phone that does not need it.** On a non-aggressive device (or after clearing app data on any device whose brand is not aggressive), no guide is offered at launch; the reminder banner in Settings → Notifications still offers it.

---

## E. Print, share and contact launch paths (Task 14's outstanding items) - Pass

- [ ] **E1 — A Bengali print on the Redmi.** Print a **cause list** and a **Case Detail** sheet in Bengali: the page renders, and the double yellow underline under every line is gone (the fix was the fallback text style; this needs one real print to confirm).
- [ ] **E2 — Print preview.** From Daily Cause List and from Case Detail: the OS print preview opens with sensible pagination, and cancelling leaves the app untouched.
- [ ] **E3 — The four launch paths.** From a case card and from Case Detail: **phone** (dialer with the number), **SMS** (message app with the localized template: case number, next date, court, profile name), **WhatsApp chat**, and the **refusal message** when the capability is missing (e.g. WhatsApp not installed → a clear message, never a dead tap).
- [ ] **E4 — App sharing from the navigation drawer.** Share opens the sheet carrying the invite text; with no share target available the invite is copied to the clipboard and the app says so (Task 14's `AppShareService` fallback).
- [ ] **E5 — Share the backup file (repeat of A12 with Drive absent)** to confirm the file-attachment path never falls back to the clipboard, since a clipboard holds no file.

---

## F. Cross-cutting checks (Task 22 Phase 2 items + general) - Pass

- [ ] **F1 — Low-end device.** On a representative 2 GB device, scroll the case lists and open the modals: no visible frame drops, and no `BackdropFilter`-style blur anywhere (the design avoids it deliberately).
- [ ] **F2 — Text scaling and overflow.** System font size at its largest: no clipped labels on the case cards, the Backup & Restore card, the paywall or the nudge strip; nothing overflows on a long Bengali string.
- [ ] **F3 — Keyboard and scrolling.** Open the Add Case form and the restore/passphrase windows with the keyboard up: fields stay reachable and the Save button is not hidden.
- [ ] **F4 — Empty / loading / error states.** Open each case list and the Backup & Restore screen on a database with no cases: empty states render, and nothing claims a backup that was never made.

---

## G. Carried-over manual items from earlier tasks - Pass

These were never recorded as done (see `docs/currentlyWorking.md`); fold them into this pass rather than opening a separate one.

- [ ] **G1 — Five case-list screens against their mockups** (Task 08 Phase 5): All Cases, Active, Upcoming, Overdue, Disposed — layout, filters, grouping, KPIs, both view modes.
- [ ] **G2 — Notes and Case Reference against their mockups** (Task 11 Phase 2), including pinning and contextual search.
- [ ] **G3 — The full Settings hierarchy walkthrough** (Task 12 Phase 3): every submenu opens, every row does what its mockup says.
- [ ] **G4 — The Lower Court Categories reorder gesture** (Task 12): the drag itself, not just its slot mapping — reorder two rows and relaunch to confirm the order persisted.

---

## Recording the result

1. Note the **version** you tested (`0.0.271` at the time of writing) and the device(s) with their Android version.
2. Mark each item **PASS / FAIL / N/A**; for every FAIL, capture the screen, the exact message shown and the `adb logcat -s flutter` lines around it.
3. Fix failures through the normal phase protocol — a new entry in `docs/version_history.md` (with a version bump) and a note in `docs/currentlyWorking.md`, including what the device proved that the tests could not.
4. Only then start Task 16 (Part B: Supabase, auth and sync). Anything still unverified here must be carried forward explicitly, not silently.
