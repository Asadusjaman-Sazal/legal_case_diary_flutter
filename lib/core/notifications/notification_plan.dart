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
///
/// Whether a case alerts at all is decided the same way: its own
/// `case_notification_preferences.enabled` if it has a row, otherwise the
/// Settings → Notifications default. That default never vetoes a case the user
/// switched on individually.
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

  /// Case type as stored on the case, e.g. `Civil Appeal-`.
  ///
  /// The pre-seeded labels carry their own trailing dash, so the alert puts the
  /// type in front of the number and adds no separator of its own.
  final String caseType;

  /// Petitioner party label.
  final String petitioner;

  /// Respondent party label.
  final String respondent;

  /// The case's most recent court step(s) as stored on the case, e.g. `Hearing`
  /// or `Hearing,Argument`. Null when the case has no step recorded yet.
  final String? lastStep;

  /// The AD/HCD result text as stored on the case, i.e. the disposal keyword a
  /// higher-court case records instead of a step. Null for lower courts.
  final String? result;

  /// Court id, resolved to a localized label through the seed data.
  final String courtId;

  /// Court category of [courtId], used to pick the right localized case type
  /// when several categories share one English label. Null when the court row
  /// could not be read.
  final String? courtCategoryId;

  /// Stored court name, used when the id is not pre-seeded (user-added court).
  final String? storedCourtName;

  /// Next hearing date (epoch ms).
  final int nextDateEpochMs;

  /// Creates a candidate.
  const HearingCandidate({
    required this.caseId,
    required this.caseNumber,
    required this.caseType,
    required this.petitioner,
    required this.respondent,
    this.lastStep,
    this.result,
    required this.courtId,
    this.courtCategoryId,
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

  /// The case's own alert time (minutes since midnight); null means "use the
  /// user's default time" from Settings → Notifications.
  final int? timeMinutes;

  /// Creates an override.
  const HearingPreference({this.enabled = true, this.offsets, this.timeMinutes});
}

/// Whether [minutes] is a real time of day, so a hand-edited or corrupt value
/// can never arm an alarm for a nonsense moment.
bool isValidTimeOfDay(int minutes) => minutes >= 0 && minutes < 24 * 60;

/// The time a case's alerts fire: its own override, else the user's default.
int effectiveTimeMinutes(int defaultMinutes, HearingPreference? preference) {
  final own = preference?.timeMinutes;
  return own != null && isValidTimeOfDay(own) ? own : defaultMinutes;
}

/// Every distinct alert time currently in use: the user's default plus each
/// stored per-case override, ascending.
///
/// One alarm is armed per value, so a case that picked its own time is alerted
/// then rather than at the default. Nulls (a case with no override) and
/// nonsense values are dropped rather than armed.
List<int> distinctNotificationTimes(
  int defaultMinutes,
  Iterable<int?> caseTimes,
) {
  final times = <int>{defaultMinutes};
  for (final own in caseTimes) {
    if (own != null && isValidTimeOfDay(own)) times.add(own);
  }
  return times.toList()..sort();
}

/// The alarm slots to arm, given the Settings default and the times of the
/// cases that may alert (`null` = that case follows [defaultMinutes]).
///
/// The default decides *which cases may alert*, never whether anything is armed:
/// with it on every case may alert, so [defaultMinutes] is always one of the
/// slots; with it off only the cases switched on individually alert, so the
/// result holds exactly the moments they need — their own time, or
/// [defaultMinutes] when they follow it — and is **empty** when no such case
/// exists, which is what lets the caller cancel the schedule outright. A corrupt
/// per-case time falls back to [defaultMinutes], as it does everywhere else.
List<int> alertTimesFor({
  required bool defaultEnabled,
  required int defaultMinutes,
  required Iterable<int?> caseTimes,
}) {
  if (defaultEnabled) {
    return distinctNotificationTimes(defaultMinutes, caseTimes);
  }
  final times = <int>{
    for (final own in caseTimes)
      if (own == null || !isValidTimeOfDay(own)) defaultMinutes else own,
  };
  return times.toList()..sort();
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
}// ---------------------------------------------------------------------------
// Subscription reminders (pre-expiry)
// ---------------------------------------------------------------------------
//
// A paying account is warned *before* its plan ends, not only after sync has
// stopped. The days are civil days on the Bangladesh calendar, exactly like a
// hearing offset, so "7 days before" means the morning of the same weekday a
// week earlier, whatever time of day the plan happens to end.

/// Days left on which a subscription reminder is posted: seven and three.
///
/// Two, deliberately: the user asked not to be nagged, so a chamber on a
/// monthly plan hears from the app twice in its last week and then the existing
/// expiry warnings take over.
const List<int> subscriptionReminderDays = <int>[7, 3];

/// Wall-clock time of a reminder (09:00 Bangladesh): early enough to act on in
/// the working day, too early to interrupt the evening.
const int subscriptionReminderMinutes = 9 * 60;

/// Whole Bangladesh civil days from [nowEpochMs] until [expiryEpochMs].
///
/// 7 for a plan ending seven civil days later, 0 on the plan's last day, and
/// negative once it has ended. Civil dates rather than elapsed hours, because
/// that is how the lawyer reads "ends on the 30th".
int subscriptionDaysLeft({
  required int expiryEpochMs,
  required int nowEpochMs,
}) {
  final expiryDay = AppDateUtils.normalizeToBangladeshStartOfDay(expiryEpochMs);
  final today = AppDateUtils.bangladeshTodayStartOfDay(
    referenceEpochMs: nowEpochMs,
  );
  return (expiryDay - today) ~/ _millisecondsPerDay;
}

/// The reminders still ahead of [nowEpochMs], each with the day it announces.
///
/// A reminder whose morning has already passed is simply not armed, so opening
/// the app for the first time on day 5 still arms day 3. Returns an empty list
/// for an account with no expiry (never subscribed) or one already ending today.
List<({int daysLeft, int fireAtEpochMs})> subscriptionReminderFireTimes({
  required int? expiryEpochMs,
  required int nowEpochMs,
}) {
  if (expiryEpochMs == null) return const <({int daysLeft, int fireAtEpochMs})>[];
  final expiryDay = AppDateUtils.normalizeToBangladeshStartOfDay(expiryEpochMs);
  return <({int daysLeft, int fireAtEpochMs})>[
    for (final daysLeft in subscriptionReminderDays)
      if (expiryDay - daysLeft * _millisecondsPerDay +
              subscriptionReminderMinutes * 60 * 1000 >
          nowEpochMs)
        (
          daysLeft: daysLeft,
          fireAtEpochMs:
              expiryDay -
              daysLeft * _millisecondsPerDay +
              subscriptionReminderMinutes * 60 * 1000,
        ),
  ];
}

/// Whether a reminder armed for [daysLeft] may still be posted.
///
/// The alarm is armed days in advance and nothing cancels it when the chamber
/// renews, so the job re-reads the expiry and posts only if the plan still ends
/// in exactly [daysLeft] days. A renewal, a lapse or a moved date therefore
/// silences the stale reminder instead of announcing the wrong thing.
bool isSubscriptionReminderDue({
  required int? expiryEpochMs,
  required int nowEpochMs,
  required int daysLeft,
}) =>
    expiryEpochMs != null &&
    subscriptionDaysLeft(expiryEpochMs: expiryEpochMs, nowEpochMs: nowEpochMs) ==
        daysLeft;

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
/// cases.
///
/// [defaultEnabled] is the **Default Notification Status** switch from
/// Settings → Notifications, and it is only ever a *default*: a case follows its
/// own `case_notification_preferences` row when it has one and this value when
/// it does not. It is deliberately not a veto — a case the user switched on
/// individually still alerts while that default is off, because the switch is
/// what a case starts from, not a decision about which cases may alert.
NotificationPlan buildNotificationPlan({
  required int todayStartEpochMs,
  required bool defaultEnabled,
  required List<int> defaultOffsets,
  required List<HearingCandidate> cases,
  required Map<String, HearingPreference> preferences,
  required AppTranslations translations,
  int defaultTimeMinutes = defaultNotificationMinutes,
  int? onlyTimeMinutes,
}) {
  final alerts = <HearingAlert>[];
  for (final candidate in cases) {
    final preference = preferences[candidate.caseId];
    // The case's own choice if it has one, else the Settings default. A case
    // switched off never alerts, whatever the global offsets are.
    if (!(preference?.enabled ?? defaultEnabled)) continue;

    final offsetDays = dayOffsetFor(
      todayStartEpochMs: todayStartEpochMs,
      dateEpochMs: candidate.nextDateEpochMs,
    );
    if (!effectiveOffsets(defaultOffsets, preference).contains(offsetDays)) {
      continue;
    }
    // One alarm is armed per distinct time, so a case whose own time differs
    // from the slot that just fired belongs to another alarm's run.
    if (onlyTimeMinutes != null &&
        effectiveTimeMinutes(defaultTimeMinutes, preference) !=
            onlyTimeMinutes) {
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
///
/// The body is the four lines the user reads in the expanded notification:
/// `Case Type Case Number`, `Petitioner vs Respondent`, the court name, and the
/// case's step — or its Result when the case has no step, which is how an
/// Appellate & High Court Division case records its outcome instead (the same
/// either/or rule the case card applies). Empty parts are dropped rather than
/// left as blank lines.
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
  // The stored step names are English on every case, so they are resolved the
  // same way the case card does it — through the seed data and the case's own
  // court category, which is what tells two identically named steps apart.
  final step = translations
      .stepNames(candidate.lastStep, courtCategoryId: candidate.courtCategoryId)
      ?.trim();
  // Step when the case has one, otherwise the AD/HCD result — the card's rule.
  // The result is free text the user typed, so it is shown verbatim.
  final result = candidate.result?.trim();
  final lastLine = switch ((step, result)) {
    (final String s, _) when s.isNotEmpty => '${l.caseCard_lastStep}: $s',
    (_, final String? r) when r != null && r.isNotEmpty =>
      '${l.addEditCaseSheet_result}: $r',
    _ => null,
  };
  final body = <String>[
    _caseLine(candidate, translations),
    ?parties,
    if (court.isNotEmpty) court,
    ?lastLine,
  ].join('\n');

  return (title: title, body: body);
}

/// `Case Type Case Number` — `Civil Appeal- 110/2021`, in the active language.
///
/// The type comes first and its own trailing dash is the separator the seed
/// labels already carry, so the two are joined by a space (the same shape the
/// case sheet's header uses). A case with no type keeps the bare number.
String _caseLine(HearingCandidate candidate, AppTranslations translations) {
  final caseType = translations
      .caseTypeLabel(
        candidate.caseType,
        courtCategoryId: candidate.courtCategoryId,
      )
      .trim();
  final caseNumber = candidate.caseNumber.trim();
  return <String>[
    if (caseType.isNotEmpty) caseType,
    if (caseNumber.isNotEmpty) caseNumber,
  ].join(' ');
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
