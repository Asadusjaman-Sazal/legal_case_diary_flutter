/// The daily hearing-alert job, run by Android's alarm manager.
///
/// **Enforced rule (plan §12.3):** this file and everything it calls works
/// purely against the local, encrypted Drift database. There is no network
/// call, no GPS use and no Supabase request on this path, and there must never
/// be one — `notification_local_only_test.dart` guards that at source level.
///
/// The job runs in the alarm service's own isolate, so it builds its own
/// database and DAOs instead of reading Riverpod providers.
library;

import 'dart:developer' as dev;
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../database/app_database.dart';
import '../../database/database_factory.dart';
import '../../features/cases/data/local/cases_dao.dart';
import '../../features/settings/data/local/case_notification_preferences_dao.dart';
import '../../features/settings/data/local/courts_dao.dart';
import '../../features/settings/data/local/user_preferences_dao.dart';
import '../../features/settings/data/settings_repository.dart';
import '../l10n/app_translations.dart';
import '../l10n/generated/app_localizations.dart';
import '../services/local_identity_service.dart';
import '../utils/date_utils.dart';
import 'android_notification_gateway.dart';
import 'notification_plan.dart';
import 'notification_scheduler.dart';

/// Milliseconds in one day; the query window is expressed in whole days.
const int _millisecondsPerDay = 24 * 60 * 60 * 1000;

/// Entry point the alarm service executes in its background isolate.
///
/// Top-level and `@pragma('vm:entry-point')` on purpose: the AOT compiler must
/// keep it, and `AndroidAlarmManager` resolves it by callback handle.
@pragma('vm:entry-point')
Future<void> notificationAlarmCallback() async {
  WidgetsFlutterBinding.ensureInitialized();
  // This isolate is not the app's root isolate, so the plugins registered on
  // the alarm engine have to be wired to this isolate's channel handlers.
  DartPluginRegistrant.ensureInitialized();
  try {
    await runHearingNotificationJob();
  } catch (error, stackTrace) {
    // A failed job must never crash the alarm service; the next launch or
    // settings change re-arms the schedule anyway.
    dev.log(
      'Hearing notification job failed',
      name: 'notifications',
      error: error,
      stackTrace: stackTrace,
    );
  }
}

/// Runs today's job and re-arms tomorrow's alarm; returns the alerts posted.
///
/// [nowEpochMs] is injectable so the offset arithmetic can be tested without a
/// device clock.
Future<List<HearingAlert>> runHearingNotificationJob({int? nowEpochMs}) async {
  final prefs = await SharedPreferences.getInstance();
  // Read the identity without minting one: a background isolate must never
  // create a user identity, only follow the one the app already stored.
  final userId = LocalIdentityService(prefs).peekId();
  if (userId == null) return const <HearingAlert>[];

  final db = AppDatabase(await DatabaseFactory().createExecutor());
  try {
    final settings = UserSettings.fromRow(
      await UserPreferencesDao(db).getByUserId(userId),
    );
    // Alerts switched off: post nothing and let the next launch or settings
    // change decide the schedule, so a disabled preference cannot self-rearm.
    if (!settings.notificationEnabled) return const <HearingAlert>[];

    final reference = nowEpochMs ?? DateTime.now().millisecondsSinceEpoch;
    final todayStart = AppDateUtils.bangladeshTodayStartOfDay(
      referenceEpochMs: reference,
    );

    // Per-case overrides (per-user preference rows) decide which cases may
    // alert and with which offsets.
    final preferences = <String, HearingPreference>{};
    for (final row in await CaseNotificationPreferencesDao(db).getByUserId(
      userId,
    )) {
      preferences[row.caseId] = HearingPreference(
        enabled: row.enabled,
        offsets: decodeNotificationOffsets(row.offsets),
      );
    }

    // Only cases that can actually be due today are queried.
    final widest = widestOffset(
      settings.notificationDefaultOffsets,
      preferences.values,
    );
    final windowEnd = todayStart + (widest + 1) * _millisecondsPerDay - 1;

    final candidates = <HearingCandidate>[];
    // The court row is read once per court: its name labels the alert, and its
    // category picks the right localized case type when several categories
    // share one English label.
    final courts = <String, Court?>{};
    for (final row in await CasesDao(
      db,
    ).getByNextDateRange(todayStart, windowEnd)) {
      final nextDate = row.nextDate;
      if (nextDate == null) continue;
      if (!courts.containsKey(row.courtId)) {
        courts[row.courtId] = await CourtsDao(db).getById(row.courtId);
      }
      final court = courts[row.courtId];
      candidates.add(
        HearingCandidate(
          caseId: row.id,
          caseNumber: row.caseNumber,
          caseType: row.caseType,
          petitioner: row.petitioner,
          respondent: row.respondent,
          courtId: row.courtId,
          courtCategoryId: court?.courtCategoryId,
          storedCourtName: court?.courtName,
          nextDateEpochMs: nextDate,
        ),
      );
    }

    final translations = AppTranslations(
      lookupAppLocalizations(Locale(settings.language)),
    );
    final plan = buildNotificationPlan(
      todayStartEpochMs: todayStart,
      enabled: settings.notificationEnabled,
      defaultOffsets: settings.notificationDefaultOffsets,
      cases: candidates,
      preferences: preferences,
      translations: translations,
    );

    if (!plan.isEmpty) {
      await AndroidNotificationGateway.presentAlerts(
        alerts: plan.alerts,
        channelName: translations.raw.notificationJob_channelName,
        channelDescription: translations.raw.notificationJob_channelDescription,
      );
    }

    // Re-arm from inside the job so the chain survives without the app ever
    // being opened (Android clears one-shot alarms after they fire).
    await AndroidNotificationGateway.scheduleDailyAlarm(
      timeMinutes: settings.notificationTime ?? defaultNotificationMinutes,
      callback: notificationAlarmCallback,
      precision: alarmPrecisionFor(
        exactAllowed: await AndroidNotificationGateway.exactAlarmsAllowed(),
      ),
    );

    return plan.alerts;
  } finally {
    await db.close();
  }
}
