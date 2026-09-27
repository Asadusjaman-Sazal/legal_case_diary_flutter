/// Platform abstraction over the notification machinery.
///
/// Every Android-only package — `android_alarm_manager_plus`,
/// `flutter_local_notifications`, `android_intent_plus` — and the OEM battery
/// guide logic live behind this interface (Task 13 Phase 1). Call sites such as
/// the app root and the Settings screens depend on this contract only, so the
/// planned Windows port swaps the implementation instead of rewriting callers.
library;

import 'package:flutter/foundation.dart';

import 'oem_setup_guide.dart';

/// A single notification to post for one upcoming hearing.
///
/// Built by the pure planner in `notification_plan.dart`; carrying it across the
/// abstraction keeps the platform implementation free of any scheduling or
/// localization logic.
class HearingAlert {
  /// Case the alert belongs to; the notification payload, so a tap can deep-link.
  final String caseId;

  /// Stable notification id, so a re-post replaces rather than duplicates.
  final int notificationId;

  /// Localized notification title (e.g. "Hearing Tomorrow").
  final String title;

  /// Localized notification body: case number, parties and court name.
  final String body;

  /// Days between the alert day and the hearing (0 = hearing day).
  final int offsetDays;

  /// Hearing date (epoch ms), used to order the day's alerts.
  final int hearingDateEpochMs;

  /// Creates an alert.
  const HearingAlert({
    required this.caseId,
    required this.notificationId,
    required this.title,
    required this.body,
    required this.offsetDays,
    required this.hearingDateEpochMs,
  });
}

/// The platform notification/alarm contract.
///
/// Implementations are constructed once per app process. The background job
/// itself does not go through this interface: it runs in the alarm isolate,
/// where no Riverpod scope exists, and talks to the same gateway directly.
abstract class NotificationScheduler {
  /// Prepares the plugin, the high-importance channel and tap handling.
  ///
  /// Must be awaited before scheduling, and before any launch payload is read.
  Future<void> initialize();

  /// Registers the handler invoked when the user taps a hearing notification
  /// while the app is running. Cold-start taps are read through [launchCaseId].
  void onCaseSelected(ValueChanged<String> handler);

  /// Case id of the notification that launched the app, or null on a normal
  /// launch.
  Future<String?> launchCaseId();

  /// Whether the OS currently allows this app to post notifications.
  Future<bool> notificationsAllowed();

  /// Asks for the notification permission (Android 13+ POST_NOTIFICATIONS).
  Future<bool> requestNotificationsPermission();

  /// Whether the OS will accept an exact alarm right now.
  ///
  /// Android 12+ requires `SCHEDULE_EXACT_ALARM`; when it is refused (the
  /// Android 14 default for new installs) the daily job is armed as an inexact
  /// idle-safe alarm instead of being dropped.
  Future<bool> canScheduleExactAlarms();

  /// Opens the system "Alarms & reminders" screen so the user can grant exact
  /// alarms. Used by the OEM setup guide, alongside the battery steps.
  Future<bool> openExactAlarmSettings();

  /// Whether the OS has this app off battery optimization ("Unrestricted").
  ///
  /// Lets the setup guide tick the battery step from the phone's own state
  /// rather than from what the user says they did. `false` where the platform
  /// cannot say, which leaves the step un-ticked.
  Future<bool> batteryOptimizationIgnored();

  /// (Re-)arms the daily hearing job from the stored settings. Idempotent: it
  /// cancels the previous alarm first, and arms nothing once no case may alert —
  /// that is, when the Settings default is off and no case has been switched on
  /// individually. The default itself does not stop the arming: a case switched
  /// on individually alerts while that default is off.
  Future<void> syncSchedule();

  /// Cancels the daily alarm and clears any posted hearing notifications.
  ///
  /// Account switch, sign-out and fresh-start recovery clear the schedule with
  /// this so a previous identity's alerts cannot outlive it (Phase 1 has no
  /// such flow yet; the entry point exists for them).
  Future<void> cancelAll();

  /// The device's reported manufacturer/brand, used to pick the OEM setup steps
  /// and to decide whether the guide opens by itself on first launch.
  Future<DeviceIdentity> deviceIdentity();

  /// Opens one of the guide's settings pages.
  ///
  /// Returns `false` when this phone has no such page (the OEM renamed or
  /// removed it) so the caller can fall through to the next target.
  Future<bool> openSettingsTarget(OemSettingsTarget target);

  /// Posts an immediate notification through the real channel.
  ///
  /// Lets the user verify that alerts can reach them without waiting for the
  /// daily alarm — the mockup's Test Notification section.
  Future<void> showTestNotification();
}
