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
