/// Pure planning for the daily hearing-alert job.
///
/// Everything here is plain Dart: no plugin, no platform channel, no database.
/// It answers two questions — which cases deserve an alert today, and what the
/// alert should say — so the answer is unit-testable without an emulator, and
/// so the alarm isolate and the Settings screens agree on the rules.
///
/// Offset semantics (plan §10): a case is alerted when
/// `next_date - today` equals one of the case's effective day offsets
/// (0 = hearing day, 1 = the day before, …). The offsets come from the per-user
/// defaults, overridden by the case's own `case_notification_preferences` row —
/// both per-user preference values.
library;

import 'dart:convert';

import '../l10n/app_translations.dart';
import '../l10n/generated/app_localizations.dart';
import '../utils/date_utils.dart';
import 'notification_scheduler.dart';

/// Milliseconds in one Bangladesh civil day (Bangladesh has no DST).
const int _millisecondsPerDay = 24 * 60 * 60 * 1000;

/// Fallback notification time (05:00 PM) used until the user picks one.
///
/// Shared with Settings → Notifications so the stored default and the job's
/// fallback can never drift apart.
const int defaultNotificationMinutes = 17 * 60;

/// How exactly the daily alarm can be armed, decided at runtime.
///
/// Android 12+ gates `setExactAndAllowWhileIdle` behind `SCHEDULE_EXACT_ALARM`,
/// and Android 14 denies it by default, so the app asks and degrades instead of
/// silently arming an alarm that never fires.
enum AlarmPrecision {
  /// Exact, idle-safe alarm (`setExactAndAllowWhileIdle`).
  exact,

  /// Inexact, idle-safe alarm (`setAndAllowWhileIdle`): the OS chooses the
  /// moment within a short window, so alerts still arrive with minute-level
  /// precision.
  inexact,
}

/// The precision to arm with, given whether exact alarms are permitted.
///
/// Pure on purpose: the permission check itself needs a device, this decision
/// does not.
AlarmPrecision alarmPrecisionFor({required bool exactAllowed}) =>
    exactAllowed ? AlarmPrecision.exact : AlarmPrecision.inexact;

/// A case reduced to the fields a hearing notification needs.
///
/// Decoupling the planner from the generated Drift row keeps the tests free of
/// a database.
class HearingCandidate {
  /// Case id (the notification payload).
  final String caseId;

  /// Case number as the user typed it, e.g. `110/2021`.
  final String caseNumber;

  /// Petitioner party label.
  final String petitioner;

  /// Respondent party label.
  final String respondent;

  /// Court id, resolved to a localized label through the seed data.
  final String courtId;

  /// Stored court name, used when the id is not pre-seeded (user-added court).
  final String? storedCourtName;

  /// Next hearing date (epoch ms).
  final int nextDateEpochMs;

  /// Creates a candidate.
  const HearingCandidate({
    required this.caseId,
    required this.caseNumber,
    required this.petitioner,
    required this.respondent,
    required this.courtId,
    required this.storedCourtName,
    required this.nextDateEpochMs,
  });
}

/// A case's own notification override (per-user `case_notification_preferences`).
class HearingPreference {
  /// Whether this case alerts at all.
  final bool enabled;

  /// The case's own offsets; null or empty means "use the user's defaults".
  final List<int>? offsets;

  /// Creates an override.
  const HearingPreference({this.enabled = true, this.offsets});
}

/// One day of work for the job.
class NotificationPlan {
  /// Alerts to post, ordered by hearing date.
  final List<HearingAlert> alerts;

  /// Creates a plan.
  const NotificationPlan(this.alerts);

  /// Whether the day produced nothing to post.
  bool get isEmpty => alerts.isEmpty;
}

/// Bangladesh civil-day difference between a date and today's start of day.
///
/// Both values are normalized to the Bangladesh civil date first, so a hearing
/// stored at any time of day still counts as that day (plan §10's offset rule).
int dayOffsetFor({required int todayStartEpochMs, required int dateEpochMs}) =>
    (AppDateUtils.normalizeToBangladeshStartOfDay(dateEpochMs) -
        todayStartEpochMs) ~/
    _millisecondsPerDay;

/// Offsets that apply to a case: its own, else the user's defaults.
List<int> effectiveOffsets(
  List<int> userDefaults,
  HearingPreference? preference,
) {
  final own = preference?.offsets;
  if (own != null && own.isNotEmpty) return own;
  // A user row with no offsets at all still alerts on the app's own default
  // (the day before), matching the Settings screen's fallback.
  return userDefaults.isEmpty ? const <int>[1] : userDefaults;
}

/// The widest offset the stored configuration can alert on.
///
/// Bounds the database query: no case further ahead than this can be due today.
int widestOffset(List<int> userDefaults, Iterable<HearingPreference> preferences) {
  var widest = userDefaults.isEmpty ? 1 : userDefaults.reduce((a, b) => a > b ? a : b);
  for (final preference in preferences) {
    if (!preference.enabled) continue;
    for (final offset in preference.offsets ?? const <int>[]) {
      if (offset > widest) widest = offset;
    }
  }
  return widest < 0 ? 0 : widest;
}

/// The next firing instant for a Bangladesh wall-clock time of day, as epoch ms.
///
/// Today's occurrence when it is still ahead, otherwise tomorrow's — the daily
/// job always has exactly one alarm armed, so this is the whole schedule.
int nextAlarmEpochMs({
  required int referenceEpochMs,
  required int minutesSinceMidnight,
}) {
  final todayStart = AppDateUtils.bangladeshTodayStartOfDay(
    referenceEpochMs: referenceEpochMs,
  );
  final todayFire = todayStart + minutesSinceMidnight * 60 * 1000;
  return todayFire > referenceEpochMs
      ? todayFire
      : todayFire + _millisecondsPerDay;
}

/// Decodes a stored offsets array (`case_notification_preferences.offsets`).
///
/// Returns null for a missing, malformed or empty array so the case falls back
/// to the user's default offsets instead of silently alerting on nothing.
List<int>? decodeNotificationOffsets(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! List) return null;
    final offsets = decoded.whereType<num>().map((value) => value.toInt()).toList();
    return offsets.isEmpty ? null : offsets;
  } on FormatException {
    return null;
  }
}

/// Stable per-case notification id (FNV-1a over the id's code units).
///
/// Deterministic across processes, unlike `String.hashCode`, so a re-post
/// replaces the previous notification for the same case instead of stacking.
int notificationIdFor(String caseId) {
  var hash = 0x811c9dc5;
  for (final unit in caseId.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0x7fffffff;
  }
  return hash;
}

/// Builds the day's alerts from the stored configuration and the candidate
/// cases. Returns an empty plan when alerts are switched off.
NotificationPlan buildNotificationPlan({
  required int todayStartEpochMs,
  required bool enabled,
  required List<int> defaultOffsets,
  required List<HearingCandidate> cases,
  required Map<String, HearingPreference> preferences,
  required AppTranslations translations,
}) {
  if (!enabled) return const NotificationPlan(<HearingAlert>[]);

  final alerts = <HearingAlert>[];
  for (final candidate in cases) {
    final preference = preferences[candidate.caseId];
    // A case the user switched off never alerts, whatever the global offsets are.
    if (preference != null && !preference.enabled) continue;

    final offsetDays = dayOffsetFor(
      todayStartEpochMs: todayStartEpochMs,
      dateEpochMs: candidate.nextDateEpochMs,
    );
    if (!effectiveOffsets(defaultOffsets, preference).contains(offsetDays)) {
      continue;
    }

    final details = _alertCopy(candidate, offsetDays, translations);
    alerts.add(
      HearingAlert(
        caseId: candidate.caseId,
        notificationId: notificationIdFor(candidate.caseId),
        title: details.title,
        body: details.body,
        offsetDays: offsetDays,
        hearingDateEpochMs: candidate.nextDateEpochMs,
      ),
    );
  }

  alerts.sort(
    (a, b) => a.hearingDateEpochMs.compareTo(b.hearingDateEpochMs),
  );
  return NotificationPlan(alerts);
}

/// Title and body of one alert, in the active language.
({String title, String body}) _alertCopy(
  HearingCandidate candidate,
  int offsetDays,
  AppTranslations translations,
) {
  final l = translations.raw;
  final title = switch (offsetDays) {
    <= 0 => l.notificationJob_titleSameDay,
    1 => l.notificationJob_titleDayBefore,
    _ => l.notificationJob_titleBeforeDays(
      AppDateUtils.formatDigits(offsetDays, l.localeName, grouping: false),
    ),
  };

  final parties = _partiesLine(l, candidate);
  final court = translations.seedLabel(
    candidate.courtId,
    fallbackEn: candidate.storedCourtName ?? '',
  );
  final body = <String>[
    candidate.caseNumber,
    ?parties,
    if (court.isNotEmpty) court,
  ].join('\n');

  return (title: title, body: body);
}

/// `Petitioner vs Respondent`, the one party that exists, or null when neither.
String? _partiesLine(AppLocalizations l, HearingCandidate candidate) {
  final petitioner = candidate.petitioner.trim();
  final respondent = candidate.respondent.trim();
  if (petitioner.isEmpty && respondent.isEmpty) return null;
  if (respondent.isEmpty) return petitioner;
  if (petitioner.isEmpty) return respondent;
  return l.notificationJob_parties(petitioner, respondent);
}
