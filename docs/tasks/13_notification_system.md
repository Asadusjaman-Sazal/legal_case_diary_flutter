# Task 13 — Bullet-Proof Notification System

> **Plan references:** §10 "Bullet-proof Notification System (Upcoming Case Alerts)", §12.3 "Purely Local Background Operations (Enforced Rule)".
> **Goal:** Reliable daily hearing alerts on aggressive Bangladeshi OEM devices, fully local (no network in background), behind a platform abstraction ready for the future Windows port.
> **Rules:** Follow the Universal Working Rules in `00_INDEX.md`. Ask, don't guess.

---

## Phase 1 — Platform Abstraction & Core Scheduling

1. Define a `NotificationScheduler` interface with an `AndroidNotificationScheduler` implementation (future `WindowsNotificationScheduler` slot). `android_alarm_manager_plus`, `android_intent_plus`, and OEM-guide logic live only behind this interface — call sites never import Android-only packages directly.
2. Core mechanism: `flutter_local_notifications` (high-importance banners) + `android_alarm_manager_plus` with `setExactAndAllowWhileIdle`. **No persistent foreground-service notification.**
3. Daily background job at `notification_time`: query the **local Drift DB only** for cases whose `next_date` matches the configured `notification_day_offset` (0 = hearing day, 1 = 1 day before, …). If found, schedule a high-priority notification with case number, parties, and court name.
4. **Enforced rule:** background isolates make **no network calls, no GPS, no Supabase requests** — purely local DB reads. This must remain true even after Part B.
5. Notification tap → deep-navigate to that case's Detail View.

**Phase 1 completion:** `flutter analyze` clean. Update `docs/version_history.md`.

## Phase 2 — Exact Alarm Permission & Boot Rescheduling

1. Runtime check `canScheduleExactAlarms` (Android 12–14+; Android 14 denies by default for new installs).
2. If denied: deep-link to the system "Alarms & reminders" grant screen (integrated into the OEM guide UI).
3. If refused: **fall back to inexact windowed alarms** (`setWindow`/`setAndAllowWhileIdle`) — notifications still fire with minute-level precision.
4. Register a `BOOT_COMPLETED` receiver to reschedule the daily alarm after reboot, and handle `MY_PACKAGE_REPLACED` after app updates.

**Phase 2 completion:** `flutter analyze` clean; test alarm survives reboot on emulator. Update `docs/version_history.md`.

## Phase 3 — OEM Battery-Killer Mitigation

1. On first launch (and from Settings > Notifications): detect manufacturer via `device_info_plus`.
2. Localized step-by-step "Battery Optimization & Auto-Start Guide" screen instructing: enable **Auto-start** (Xiaomi/MIUI, Oppo/ColorOS, Vivo) and set battery optimization to **Unrestricted/No restrictions**.
3. "Take Me There" deep links via `android_intent_plus` to the specific OEM battery/auto-start settings pages where possible.
4. If skipped: persistent non-intrusive banner in Settings > Notifications — *"Notifications may not work reliably on your device. Tap to complete setup."*

**Phase 3 completion:** `flutter analyze` clean; manual test of the guide flow. Update `docs/version_history.md`.

## Alignment Addendum (Implementation Plan Revision 2.4)

- Read global notification enabled/time/default offsets from per-user `user_preferences` and case-specific toggle/offset overrides from `case_notification_preferences`.
- Scheduling remains purely local even when premium preference synchronization is enabled; server sync only updates the local preference cache in foreground sync flows.
- Backup/restore, identity adoption, account switch, fresh-start recovery, and logout must include or clear notification configuration according to their explicit scope.

## Client Notification (added 0.0.614, user request)

A second, separate notification path: telling the **client** about a changed hearing date through the lawyer's own WhatsApp or SMS. It is not a background alert and never runs in an alarm isolate.

- **Trigger.** `maybeSendAutomatedClientNotification` runs from **both** save tails in `add_edit_case_sheet.dart` (Quick Update `_commit`, Edit Case `_save`) after the transaction and `syncSchedule()`, before the window pops. It acts only when `next_date` moved to a different Bangladesh civil day (`AppDateUtils.isSameBangladeshCivilDate`), the case has a `party_phone`, and the account enabled the feature. Add mode and a same-day re-pick do nothing.
- **Delivery.** Store-safe by design: the chosen external app opens with the finished text via the existing `contactLauncherProvider` (`wa.me` or `sms:`); **no `SEND_SMS`, no package queries, no native change**. A failed launch shows the existing `casesContact_unable…` snackbar through the root messenger, which outlives the Edit sheet.
- **Confirmation and memory.** Ask is the default: **Send Message to Client?** (the word *Automated* was dropped at 0.0.618, because the lawyer still confirms and sends) with a red **No**, a **Yes**, and **Remember my choice** under the two buttons, which are 16 px apart. Remembering Yes stores **Automated Notification = On** and **Ask = Off**, so later date changes send without asking; remembering No stores **both Off**, so nothing is asked or sent. The lawyer can bring the confirmation back by turning both switches on by hand. Without Remember, the answer applies to that save only; a dismissed prompt is No for that save. The decision is pure (`resolveClientNotificationDecision`) and reads only the two switches.
- **Settings and storage.** Settings → Notifications gains a **Client Notification** section for every account, placed **before** the Battery & Auto-Start Setup Guide and titled in bold; the screen also titles the main card **Device Notification Settings** (0.0.617). The section opens with the Automated Notification switch and then **Ask Before Sending Automated Message?**, followed by the channel, templates and Contact Number: master On/Off (default off), channel (WhatsApp or SMS, one at a time), per-channel Long/Short templates (WhatsApp Long and SMS Short by default) with a justified **Example:** quotation under each channel (no accent stripe), the Ask pair, and a read-only **Contact Number** field with an edit icon (digits only; empty is allowed); the number dialog uses the Update window's corner and the Exit App action size, 12 px apart. Everything is stored in the existing per-user `UserSettings` blob (`automated_notification_*`, `notification_contact_number`), which is already synced; **no Drift column, migration or server change**. Every new field must be carried by `copyWithLastAddCaseSelection` as well.
- **Message.** The identified client comes from the represented side (`representedClientName`), the case line is the localized case type plus the stored number, steps are localized and joined `/`, the court is the localized seeded label with its stored name as fallback, the date is `DD/MM/YYYY` in the active language's digits. The long message keeps a blank line before its sign-off, appends the call-back line (Contact Number → Profile mobile → omitted), and the short message never carries it. The per-channel Long / Short buttons sit side by side with no slash. Higher-court cases have no steps, so the clause is a separate localized fragment that renders empty — no dangling "for" or brackets.
- **Tests.** `test/features/client_notification_message_test.dart` (wording and the decision matrix), `client_notification_settings_test.dart` (defaults, persistence, previews, contact dialog), `client_notification_flow_test.dart` (ask/remember/send/skip, URI and failure), plus a Quick Update wiring test in `task07_acceptance_test.dart` and the settings round-trip in `repositories_test.dart`.
