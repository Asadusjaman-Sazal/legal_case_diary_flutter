/// Shared test double for the notification system.
///
/// The real scheduler talks to Android through platform channels, so every
/// widget test over the Notifications screen, the app root or the OEM guide
/// drives a [FakeNotificationScheduler] and asserts what the UI asked it to do.
library;

import 'package:flutter/foundation.dart';

import 'package:legal_case_diary/core/notifications/notification_scheduler.dart';
import 'package:legal_case_diary/core/notifications/oem_setup_guide.dart';

/// Records every scheduler call and returns configurable answers.
class FakeNotificationScheduler implements NotificationScheduler {
  /// Times [initialize] was called.
  int initializeCalls = 0;

  /// Times [syncSchedule] was called (one per notification-settings write).
  int syncScheduleCalls = 0;

  /// Times [cancelAll] was called.
  int cancelAllCalls = 0;

  /// Times the notification permission was requested.
  int permissionRequests = 0;

  /// Times the system exact-alarm screen was opened.
  int exactAlarmScreenOpens = 0;

  /// Payload reported as the one that launched the app — a case id, or the
  /// payment alert's own marker (null = an ordinary launch).
  String? launchPayloadValue;

  /// Answer of [notificationsAllowed].
  bool notificationsAllowedValue = true;

  /// Answer of [canScheduleExactAlarms].
  ///
  /// Defaults to `false`, the Android 14 state a brand-new install starts in,
  /// so tests that expect the "already allowed" copy set it explicitly.
  bool exactAlarmsAllowedValue = false;

  /// Answer of [batteryOptimizationIgnored].
  ///
  /// Defaults to `false` too: a fresh install is battery-optimized until the
  /// user exempts it.
  bool batteryUnrestrictedValue = false;

  /// Handler registered through [onNotificationSelected]; call it to simulate a
  /// tap on a posted notification.
  ValueChanged<String>? notificationSelected;

  /// What [deviceIdentity] reports; defaults to an unknown phone.
  DeviceIdentity device = const DeviceIdentity();

  /// Targets [openSettingsTarget] was asked for, in call order.
  final List<OemSettingsTarget> openedTargets = <OemSettingsTarget>[];

  /// Targets this fake can open; anything else answers `false`, like a phone
  /// whose OEM page is missing.
  Set<OemSettingsTarget> openableTargets = OemSettingsTarget.values.toSet();

  /// Times a test notification was posted.
  int testNotifications = 0;

  @override
  Future<void> initialize() async => initializeCalls++;

  @override
  void onNotificationSelected(ValueChanged<String> handler) =>
      notificationSelected = handler;

  @override
  Future<String?> launchPayload() async => launchPayloadValue;

  @override
  Future<bool> notificationsAllowed() async => notificationsAllowedValue;

  @override
  Future<bool> requestNotificationsPermission() async {
    permissionRequests++;
    return true;
  }

  @override
  Future<bool> canScheduleExactAlarms() async => exactAlarmsAllowedValue;

  @override
  Future<bool> batteryOptimizationIgnored() async => batteryUnrestrictedValue;

  @override
  Future<bool> openExactAlarmSettings() async {
    exactAlarmScreenOpens++;
    return true;
  }

  @override
  Future<void> syncSchedule() async => syncScheduleCalls++;

  @override
  Future<void> cancelAll() async => cancelAllCalls++;

  @override
  Future<DeviceIdentity> deviceIdentity() async => device;

  @override
  Future<bool> openSettingsTarget(OemSettingsTarget target) async {
    openedTargets.add(target);
    return openableTargets.contains(target);
  }

  @override
  Future<void> showTestNotification() async => testNotifications++;
}
