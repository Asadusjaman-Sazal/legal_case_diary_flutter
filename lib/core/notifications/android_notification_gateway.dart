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
import 'package:shared_preferences/shared_preferences.dart';
// `services.dart` re-exports the parts of `foundation.dart` used here
// (`ValueChanged`), so the single import keeps the gateway's header honest.
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'notification_plan.dart';
import 'notification_scheduler.dart';
import 'oem_setup_guide.dart';

/// Low-level Android operations shared by the app and the background job.
abstract final class AndroidNotificationGateway {
  /// Base alarm request id of the hearing alerts.
  ///
  /// One alarm is armed per distinct alert time, every one derived from this
  /// base plus its time of day (`alertAlarmIdBase + minutes`), so the background
  /// job can read which slot fired from the id it is handed. The base is kept
  /// clear of `1301`, the single daily alarm's id in earlier builds: such an
  /// alarm is then recognised as unknown — it posts what is due and hands over
  /// to the new schedule — instead of being misread as the midnight slot.
  static const int alertAlarmIdBase = 1301 + 24 * 60;

  /// SharedPreferences key naming the alert times whose alarms are armed.
  ///
  /// The bookkeeping that lets a sync cancel the slots it no longer wants:
  /// without it a stale alarm could not be found again, since its id is derived
  /// from a time the settings no longer mention.
  static const String _armedTimesKey = 'notification_armed_times';

  /// Notification channel id holding every hearing alert.
  static const String channelId = 'hearing_alerts';

  /// Notification channel id of the automatic-backup skip notice.
  static const String backupNoticeChannelId = 'backup_notices';

  /// Groups a day's per-case alerts into one Android stack.
  static const String groupKey = 'hearing_alerts';

  /// Small icon; the launcher icon until a dedicated monochrome drawable ships.
  static const String _icon = '@mipmap/ic_launcher';

  /// Notification id of the "automatic backup skipped" notice.
  ///
  /// Distinct from the hearing-alert ids (`alertAlarmIdBase + minutes`) and the
  /// test alert, so a re-post replaces rather than stacks.
  static const int backupSkippedNotificationId = 1300 + 24 * 60 + 61;

  /// The reserve of backup ids: the automatic-backup schedule, and the skipped
  /// notice above, live in the `alarmAlarmIdBase` range of 1301–2500.
  /// (Kept alongside the notification ids so the whole app's alarm id space is
  /// visible in one place.)
  static const int backupAlarmIdBase = 1301 + 24 * 60 + 100;

  /// The app's own package id, needed to open its settings page.
  /// Kept equal to `applicationId` in `android/app/build.gradle.kts`.
  static const String _applicationId = 'com.legalcasediary.app';

  /// Notification id of the one-off test alert.
  static const int testNotificationId = 1300;

  /// Channel for the one device check no plugin in the app exposes.
  ///
  /// Served by `MainActivity.kt`; the protocol carries a single method, so the
  /// Dart side names no Android class and the Windows port ignores it.
  static const MethodChannel _setupChannel = MethodChannel(
    'com.legalcasediary.app/device_setup',
  );

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

  /// Whether this phone has the app off battery optimization.
  ///
  /// `PowerManager.isIgnoringBatteryOptimizations` is the OS's own answer to
  /// the setup guide's battery step — exactly the state the Battery-usage
  /// screen writes — and no installed plugin exposes it, so the app queries its
  /// own host activity. `false` where the channel is missing (the test host, the
  /// Windows build), which leaves the step offering its button rather than
  /// claiming to be done.
  static Future<bool> batteryOptimizationIgnored() async {
    try {
      return await _setupChannel.invokeMethod<bool>(
            'isIgnoringBatteryOptimizations',
          ) ??
          false;
    } catch (error, stackTrace) {
      reportFailure(error, stackTrace);
      return false;
    }
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

    for (final alert in alerts) {
      await _plugin.show(
        id: alert.notificationId,
        title: alert.title,
        body: alert.body,
        notificationDetails: NotificationDetails(
          android: _details(
            channelName,
            channelDescription,
            body: alert.body,
          ),
        ),
        // The payload is the case id; a tap deep-links to that case's detail.
        payload: alert.caseId,
      );
    }
  }

  /// The one high-importance channel every hearing alert shares.
  ///
  /// [body] is handed over as a BigText style, and that is what makes the alert
  /// readable: without a style Android lays the text out itself and ellipsises a
  /// line — even in the expanded view, where a long `Petitioner vs Respondent`
  /// line was cut after a few characters. BigText shows the whole body, each
  /// body line on its own line and wrapped where it is long.
  static AndroidNotificationDetails _details(
    String channelName,
    String channelDescription, {
    required String body,
  }) => AndroidNotificationDetails(
    channelId,
    channelName,
    channelDescription: channelDescription,
    icon: _icon,
    importance: Importance.max,
    priority: Priority.high,
    groupKey: groupKey,
    category: AndroidNotificationCategory.reminder,
    styleInformation: BigTextStyleInformation(body),
  );

  /// Posts a single immediate notification through the real channel.
  /// Posts the one notification the automatic-backup job can produce.
  ///
  /// The job skips (rather than writing a plain file) when encryption is on, and
  /// this notice tells the user to open the app and back up by hand — the only
  /// person who knows the passphrase. It rides its own lightweight channel so it
  /// never mixes with the hearing alerts' group.
  static Future<void> presentBackupSkippedNotice({
    required String title,
    required String body,
    required String channelName,
    required String channelDescription,
  }) async {
    await _initializePlugin();
    await _plugin.show(
      id: backupSkippedNotificationId,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          backupNoticeChannelId,
          channelName,
          channelDescription: channelDescription,
          icon: _icon,
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
      ),
    );
  }

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
        android: _details(channelName, channelDescription, body: body),
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

  /// Arms the alert alarm for the next occurrence of [timeMinutes]
  /// (Bangladesh wall-clock, minutes since midnight).
  ///
  /// [callback] is the `@pragma('vm:entry-point')` job function; it is passed
  /// in rather than imported so this gateway stays free of the job's database
  /// logic (and of an import cycle). The callback takes the alarm id, which is
  /// how the job learns which time slot it is running for.
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
      alertAlarmIdBase + timeMinutes,
      callback,
      exact: precision == AlarmPrecision.exact,
      wakeup: true,
      allowWhileIdle: true,
      rescheduleOnReboot: true,
    );
  }

  /// Arms the daily automatic-backup alarm.
  ///
  /// One alarm, at a fixed quiet hour, firing once a day indefinitely — the
  /// cadence (Everyday / Every 3 days / …) is decided *inside* the job, which
  /// reads the stored interval and the last backup time, so the alarm itself
  /// never needs to know the interval or be re-armed when it changes.
  ///
  /// Like the hearing alerts, the backup alarm re-arms itself each firing so
  /// the chain survives without the app ever being opened, and it survives
  /// reboot via `rescheduleOnReboot`.
  static Future<void> scheduleBackupAlarm({
    required Function callback,
    required AlarmPrecision precision,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final fireAt = nextAlarmEpochMs(
      referenceEpochMs: now,
      minutesSinceMidnight: backupAlarmHour,
    );
    await AndroidAlarmManager.oneShotAt(
      DateTime.fromMillisecondsSinceEpoch(fireAt),
      backupAlarmIdBase,
      callback,
      exact: precision == AlarmPrecision.exact,
      wakeup: false,
      allowWhileIdle: true,
      rescheduleOnReboot: true,
    );
  }

  /// Cancels the daily automatic-backup alarm, if armed.
  static Future<void> cancelBackupAlarm() async {
    await AndroidAlarmManager.cancel(backupAlarmIdBase);
  }

  /// The wall-clock hour the daily backup alarm fires at (03:00, quiet and
  /// unlikely to disturb).
  static const int backupAlarmHour = 3 * 60;

  /// Cancels the alarm armed for [timeMinutes], if any.
  static Future<void> cancelDailyAlarm(int timeMinutes) async {
    await AndroidAlarmManager.cancel(alertAlarmIdBase + timeMinutes);
  }

  /// The alert time encoded in [alarmId], or null when the id is not one of
  /// this app's alert alarms (an alarm from an earlier build, say). The job
  /// learns its slot from exactly this.
  static int? alertMinutesForId(int alarmId) {
    final minutes = alarmId - alertAlarmIdBase;
    return isValidTimeOfDay(minutes) ? minutes : null;
  }

  /// Arms one alarm per distinct alert time and cancels the rest.
  ///
  /// Idempotent, and the single entry point the foreground scheduler uses: a
  /// slot that is no longer wanted is cancelled rather than left to fire once
  /// more, and the armed set is remembered so the next sync can do the same.
  static Future<void> syncAlertAlarms({
    required Iterable<int> times,
    required Function callback,
    required AlarmPrecision precision,
  }) async {
    final wanted = times.where(isValidTimeOfDay).toSet();
    for (final stale in (await armedAlertTimes()).difference(wanted)) {
      await cancelDailyAlarm(stale);
    }
    for (final time in wanted) {
      await scheduleDailyAlarm(
        timeMinutes: time,
        callback: callback,
        precision: precision,
      );
    }
    await _storeArmedAlertTimes(wanted);
  }

  /// Cancels every armed alert alarm and forgets them.
  ///
  /// Used on sign-out/account switch, where a previous identity's alerts must
  /// not outlive it.
  static Future<void> cancelAllAlertAlarms() async {
    for (final time in await armedAlertTimes()) {
      await cancelDailyAlarm(time);
    }
    await _storeArmedAlertTimes(const <int>{});
  }

  /// Alert times whose alarms this app has armed.
  static Future<Set<int>> armedAlertTimes() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stored = prefs.getStringList(_armedTimesKey);
      if (stored == null) return <int>{};
      return stored.map(int.tryParse).whereType<int>().toSet();
    } catch (error, stackTrace) {
      // Unreadable bookkeeping must not block arming: the sync simply has no
      // stale slots to cancel, and the next successful write restores it.
      reportFailure(error, stackTrace);
      return <int>{};
    }
  }

  static Future<void> _storeArmedAlertTimes(Set<int> times) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_armedTimesKey, [
        for (final time in times) '$time',
      ]);
    } catch (error, stackTrace) {
      reportFailure(error, stackTrace);
    }
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
