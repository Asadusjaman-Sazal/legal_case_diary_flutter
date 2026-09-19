/// Android notification/alarm gateway.
///
/// This is the **only** file in the app that imports `android_alarm_manager_plus`
/// or `flutter_local_notifications`. The foreground scheduler
/// (`android_notification_scheduler.dart`) and the alarm isolate's job both call
/// these low-level helpers, so the platform packages stay behind one boundary
/// and the future Windows port replaces this file alone (Task 13 Phase 1).
///
/// Nothing on this path performs a network, GPS or Supabase call — the enforced
/// purely-local rule of plan §12.3.
library;

import 'dart:developer' as dev;

import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:android_intent_plus/android_intent.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'notification_plan.dart';
import 'notification_scheduler.dart';
import 'oem_setup_guide.dart';

/// Low-level Android operations shared by the app and the background job.
abstract final class AndroidNotificationGateway {
  /// Alarm request id of the single daily job.
  ///
  /// Stable forever: the boot/update rescheduling path looks the alarm up by
  /// this id, so changing it would strand an already-scheduled alarm.
  static const int dailyJobId = 1301;

  /// Notification channel id holding every hearing alert.
  static const String channelId = 'hearing_alerts';

  /// Groups a day's per-case alerts into one Android stack.
  static const String groupKey = 'hearing_alerts';

  /// Small icon; the launcher icon until a dedicated monochrome drawable ships.
  static const String _icon = '@mipmap/ic_launcher';

  /// The app's own package id, needed to open its settings page.
  /// Kept equal to `applicationId` in `android/app/build.gradle.kts`.
  static const String _applicationId = 'com.legalcasediary.app';

  /// Notification id of the one-off test alert.
  static const int testNotificationId = 1300;

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  /// Whether this isolate already initialized the plugin.
  static bool _initialized = false;

  /// Resolves the Android side of the notifications plugin.
  static AndroidFlutterLocalNotificationsPlugin? get _androidPlugin =>
      _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  /// Starts the alarm service (foreground only) and initializes the plugin.
  ///
  /// [onCaseSelected] receives the case id of every notification tap while the
  /// app is running (the payload is the case id); a tap that launches the app
  /// is read back through [launchCaseId]. Taking a plain callback keeps the
  /// plugin's own types out of the scheduler and the call sites.
  static Future<void> initialize({
    required ValueChanged<String> onCaseSelected,
  }) async {
    // Must run before any alarm is scheduled: it registers the callback
    // dispatcher the background isolates are started from.
    await AndroidAlarmManager.initialize();
    await _initializePlugin(
      onResponse: (response) {
        final payload = response.payload;
        if (payload != null && payload.isNotEmpty) onCaseSelected(payload);
      },
    );
  }

  /// Initializes the plugin once per isolate.
  static Future<void> _initializePlugin({
    DidReceiveNotificationResponseCallback? onResponse,
  }) async {
    if (_initialized) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings(_icon),
      ),
      onDidReceiveNotificationResponse: onResponse,
    );
    _initialized = true;
  }

  /// Case id carried by the notification that launched the app, if any.
  static Future<String?> launchCaseId() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    final payload = details.notificationResponse?.payload;
    return (payload == null || payload.isEmpty) ? null : payload;
  }

  /// Whether the OS currently lets this app post notifications.
  static Future<bool> notificationsAllowed() async =>
      await _androidPlugin?.areNotificationsEnabled() ?? true;

  /// Requests the Android 13+ POST_NOTIFICATIONS permission.
  static Future<bool> requestNotificationsPermission() async {
    await _initializePlugin();
    return await _androidPlugin?.requestNotificationsPermission() ?? true;
  }

  /// Whether exact alarms are permitted right now (Android 12+).
  ///
  /// Defaults to `true` where the question does not apply, so the app never
  /// downgrades itself on a platform that has no such gate.
  static Future<bool> exactAlarmsAllowed() async {
    await _initializePlugin();
    return await _androidPlugin?.canScheduleExactNotifications() ?? true;
  }

  /// Opens the system "Alarms & reminders" screen so the user can grant
  /// `SCHEDULE_EXACT_ALARM`; the plugin jumps straight to that page.
  static Future<bool> requestExactAlarmsPermission() async {
    await _initializePlugin();
    return await _androidPlugin?.requestExactAlarmsPermission() ?? false;
  }

  /// Posts one high-importance notification per alert.
  ///
  /// Called from the foreground (test action) and from the alarm isolate, which
  /// is why it initializes the plugin lazily instead of taking one.
  static Future<void> presentAlerts({
    required List<HearingAlert> alerts,
    required String channelName,
    required String channelDescription,
  }) async {
    if (alerts.isEmpty) return;
    await _initializePlugin();

    final details = _details(channelName, channelDescription);

    for (final alert in alerts) {
      await _plugin.show(
        id: alert.notificationId,
        title: alert.title,
        body: alert.body,
        notificationDetails: NotificationDetails(android: details),
        // The payload is the case id; a tap deep-links to that case's detail.
        payload: alert.caseId,
      );
    }
  }

  /// The one high-importance channel every hearing alert shares.
  static AndroidNotificationDetails _details(
    String channelName,
    String channelDescription,
  ) => AndroidNotificationDetails(
    channelId,
    channelName,
    channelDescription: channelDescription,
    icon: _icon,
    importance: Importance.max,
    priority: Priority.high,
    groupKey: groupKey,
    category: AndroidNotificationCategory.reminder,
  );

  /// Posts a single immediate notification through the real channel.
  static Future<void> showTestNotification({
    required String title,
    required String body,
    required String channelName,
    required String channelDescription,
  }) async {
    await _initializePlugin();
    await _plugin.show(
      id: testNotificationId,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: _details(channelName, channelDescription),
      ),
    );
  }

  /// The device's reported manufacturer and brand.
  ///
  /// Returns an empty identity where the plugin is unavailable (the test host,
  /// the future Windows build) rather than failing the guide. This is local
  /// device metadata, not a network lookup.
  static Future<DeviceIdentity> deviceIdentity() async {
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      return DeviceIdentity(
        manufacturer: info.manufacturer,
        brand: info.brand,
      );
    } catch (error, stackTrace) {
      reportFailure(error, stackTrace);
      return const DeviceIdentity();
    }
  }

  /// Opens one of the guide's settings pages, as the plan's "Take Me There".
  ///
  /// [OemSettingsTarget.appDetails] is the universal fallback; the OEM pages are
  /// community-known component names, so a missing or renamed page simply
  /// returns `false` and the caller tries the next target.
  static Future<bool> openSettingsTarget({
    required OemSettingsTarget target,
    required DeviceIdentity device,
  }) async {
    switch (target) {
      case OemSettingsTarget.exactAlarms:
        return await requestExactAlarmsPermission();
      case OemSettingsTarget.batteryOptimization:
        return _launchIntent(
          const AndroidIntent(
            action: 'android.settings.IGNORE_BATTERY_OPTIMIZATION_SETTINGS',
          ),
        );
      case OemSettingsTarget.appDetails:
        return _launchIntent(
          const AndroidIntent(
            action: 'android.settings.APPLICATION_DETAILS_SETTINGS',
            data: 'package:$_applicationId',
          ),
        );
      case OemSettingsTarget.autoStart:
        for (final component in _autoStartComponents(
          oemFamilyFor(device),
        )) {
          if (await _launchIntent(AndroidIntent(componentName: component))) {
            return true;
          }
        }
        return false;
    }
  }

  /// Launches [intent] when some activity can handle it.
  static Future<bool> _launchIntent(AndroidIntent intent) async {
    try {
      final resolves = await intent.canResolveActivity();
      if (resolves == false) return false;
      await intent.launch();
      return true;
    } catch (error, stackTrace) {
      // ActivityNotFoundException on the platform side, or no plugin at all.
      reportFailure(error, stackTrace);
      return false;
    }
  }

  /// OEM auto-start / startup-manager pages, tried in order.
  static List<String> _autoStartComponents(OemFamily family) => switch (family) {
    OemFamily.xiaomi => const [
      'com.miui.securitycenter/com.miui.permcenter.autostart.AutoStartManagementActivity',
      'com.miui.securitycenter/com.miui.powercenter.PowerSettings',
    ],
    OemFamily.oppo => const [
      'com.coloros.safecenter/com.coloros.safecenter.permission.startup.StartupAppListActivity',
      'com.coloros.safecenter/com.coloros.safecenter.startupapp.StartupAppListActivity',
      'com.oppo.safe/com.oppo.safe.permission.startup.StartupAppListActivity',
    ],
    OemFamily.vivo => const [
      'com.vivo.permissionmanager/com.vivo.permissionmanager.activity.BgStartUpManagerActivity',
      'com.iqoo.secure/com.iqoo.secure.ui.phoneoptimize.AddWhiteListActivity',
      'com.iqoo.secure/com.iqoo.secure.MainActivity',
    ],
    OemFamily.huawei => const [
      'com.huawei.systemmanager/com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity',
      'com.huawei.systemmanager/com.huawei.systemmanager.optimize.process.ProtectActivity',
    ],
    OemFamily.infinix => const [
      'com.transsion.phonemaster/com.transsion.phonemaster.optimization.ui.activity.StartupAppListActivity',
      'com.transsion.phonemaster/com.transsion.phonemaster.MainActivity',
    ],
    // No such page exists on these phones; the app-details fallback is used.
    OemFamily.samsung || OemFamily.generic => const <String>[],
  };

  /// Clears every notification this app has posted.
  static Future<void> cancelAllPresentedAlerts() async {
    await _initializePlugin();
    await _plugin.cancelAll();
  }

  /// Arms the daily job for the next occurrence of [timeMinutes]
  /// (Bangladesh wall-clock, minutes since midnight).
  ///
  /// [callback] is the `@pragma('vm:entry-point')` job function; it is passed
  /// in rather than imported so this gateway stays free of the job's database
  /// logic (and of an import cycle).
  ///
  /// `setExactAndAllowWhileIdle` with `wakeup: true` per plan §10, plus
  /// `rescheduleOnReboot: true` so the plugin's reboot receiver re-arms it.
  ///
  /// When [precision] is [AlarmPrecision.inexact] the exact flag is dropped,
  /// which the plugin maps to `setAndAllowWhileIdle` — notifications still fire,
  /// with minute-level rather than second-level precision. The plugin exposes
  /// no `setWindow`, so this is the closest available inexact-windowed alarm.
  static Future<void> scheduleDailyAlarm({
    required int timeMinutes,
    required Function callback,
    required AlarmPrecision precision,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final fireAt = nextAlarmEpochMs(
      referenceEpochMs: now,
      minutesSinceMidnight: timeMinutes,
    );
    await AndroidAlarmManager.oneShotAt(
      DateTime.fromMillisecondsSinceEpoch(fireAt),
      dailyJobId,
      callback,
      exact: precision == AlarmPrecision.exact,
      wakeup: true,
      allowWhileIdle: true,
      rescheduleOnReboot: true,
    );
  }

  /// Cancels the daily job if it is armed.
  static Future<void> cancelDailyAlarm() async {
    await AndroidAlarmManager.cancel(dailyJobId);
  }

  /// Logs and swallows a failure so a background job never kills the alarm
  /// chain. Used by the entry point that runs outside a UI zone.
  static void reportFailure(Object error, StackTrace stackTrace) {
    dev.log(
      'Notification job failed',
      name: 'notifications',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
