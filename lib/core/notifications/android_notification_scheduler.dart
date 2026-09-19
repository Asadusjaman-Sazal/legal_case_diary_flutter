/// Android implementation of [NotificationScheduler].
///
/// Wires the per-user notification preferences to the platform gateway: it
/// names no Android-only package itself, so the planned Windows port replaces
/// this file and the gateway while every call site keeps working (Task 13
/// Phase 1).
library;

import 'dart:ui';

import 'package:flutter/foundation.dart';

import '../../features/settings/data/settings_repository.dart';
import '../l10n/app_translations.dart';
import '../l10n/generated/app_localizations.dart';
import 'android_notification_gateway.dart';
import 'notification_alarm_callback.dart';
import 'notification_plan.dart';
import 'notification_scheduler.dart';
import 'oem_setup_guide.dart';

/// Schedules the daily hearing alert through Android's alarm manager and the
/// notifications plugin.
class AndroidNotificationScheduler implements NotificationScheduler {
  /// Creates the scheduler.
  ///
  /// [readSettings] supplies the live per-user settings; injecting it keeps this
  /// class independent of Riverpod and of the repository's construction.
  AndroidNotificationScheduler({required this.readSettings});

  /// Reads the current per-user settings.
  final Future<UserSettings> Function() readSettings;

  /// Handler invoked for a tap on a posted hearing notification.
  ValueChanged<String>? _caseSelected;

  @override
  Future<void> initialize() async {
    try {
      await AndroidNotificationGateway.initialize(
        onCaseSelected: (caseId) => _caseSelected?.call(caseId),
      );

      // Re-arm on every launch: OEM battery managers and app updates can drop
      // an armed alarm, and this is the cheapest place to restore it.
      await syncSchedule();
    } catch (error, stackTrace) {
      // Alerts are an enhancement: a platform without the plugin (the test host,
      // the Windows build before its implementation lands) must still launch.
      AndroidNotificationGateway.reportFailure(error, stackTrace);
    }
  }

  @override
  void onCaseSelected(ValueChanged<String> handler) => _caseSelected = handler;

  @override
  Future<String?> launchCaseId() => AndroidNotificationGateway.launchCaseId();

  @override
  Future<bool> notificationsAllowed() =>
      AndroidNotificationGateway.notificationsAllowed();

  @override
  Future<bool> requestNotificationsPermission() =>
      AndroidNotificationGateway.requestNotificationsPermission();

  @override
  Future<bool> canScheduleExactAlarms() async {
    try {
      return await AndroidNotificationGateway.exactAlarmsAllowed();
    } catch (error, stackTrace) {
      AndroidNotificationGateway.reportFailure(error, stackTrace);
      return true;
    }
  }

  @override
  Future<bool> openExactAlarmSettings() async {
    try {
      return await AndroidNotificationGateway.requestExactAlarmsPermission();
    } catch (error, stackTrace) {
      AndroidNotificationGateway.reportFailure(error, stackTrace);
      return false;
    }
  }

  @override
  Future<void> syncSchedule() async {
    try {
      // Always cancel first: re-arming with a stale time would leave two alarms
      // racing for the same request id.
      await AndroidNotificationGateway.cancelDailyAlarm();

      final settings = await readSettings();
      if (!settings.notificationEnabled) return;

      // Android 13+ needs POST_NOTIFICATIONS at runtime; without it every alert
      // would be posted and silently dropped by the OS. The permission is asked
      // for the first time the user actually wants alerts, not on app start.
      if (!await AndroidNotificationGateway.notificationsAllowed()) {
        await AndroidNotificationGateway.requestNotificationsPermission();
      }

      await AndroidNotificationGateway.scheduleDailyAlarm(
        timeMinutes: settings.notificationTime ?? defaultNotificationMinutes,
        callback: notificationAlarmCallback,
        // Android 14 denies exact alarms by default: ask, and fall back to an
        // inexact idle-safe alarm rather than scheduling nothing at all.
        precision: alarmPrecisionFor(
          exactAllowed: await AndroidNotificationGateway.exactAlarmsAllowed(),
        ),
      );
    } catch (error, stackTrace) {
      // A failed re-arm must never take the app down with it; the next launch
      // or settings change tries again.
      AndroidNotificationGateway.reportFailure(error, stackTrace);
    }
  }

  @override
  Future<void> cancelAll() async {
    try {
      await AndroidNotificationGateway.cancelDailyAlarm();
      await AndroidNotificationGateway.cancelAllPresentedAlerts();
    } catch (error, stackTrace) {
      AndroidNotificationGateway.reportFailure(error, stackTrace);
    }
  }

  @override
  Future<DeviceIdentity> deviceIdentity() async {
    try {
      return await AndroidNotificationGateway.deviceIdentity();
    } catch (error, stackTrace) {
      AndroidNotificationGateway.reportFailure(error, stackTrace);
      return const DeviceIdentity();
    }
  }

  @override
  Future<bool> openSettingsTarget(OemSettingsTarget target) async {
    try {
      return await AndroidNotificationGateway.openSettingsTarget(
        target: target,
        device: await AndroidNotificationGateway.deviceIdentity(),
      );
    } catch (error, stackTrace) {
      AndroidNotificationGateway.reportFailure(error, stackTrace);
      return false;
    }
  }

  @override
  Future<void> showTestNotification() async {
    try {
      // Localized from the stored preference: the test alert must read like the
      // real ones, which are composed in the background without a BuildContext.
      final settings = await readSettings();
      final translations = AppTranslations(
        lookupAppLocalizations(Locale(settings.language)),
      );
      await AndroidNotificationGateway.showTestNotification(
        title: translations.raw.notificationJob_testTitle,
        body: translations.raw.notificationJob_testBody,
        channelName: translations.raw.notificationJob_channelName,
        channelDescription: translations.raw.notificationJob_channelDescription,
      );
    } catch (error, stackTrace) {
      AndroidNotificationGateway.reportFailure(error, stackTrace);
    }
  }
}
