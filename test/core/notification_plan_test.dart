/// Tests for the pure part of the notification system (Task 13 Phase 1).
///
/// All offset matching, alert copy and schedule arithmetic lives in
/// `notification_plan.dart` precisely so it can be tested here, with no
/// database, no plugin and no emulator: these are the rules the daily job will
/// follow on a device.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/core/constants/pre_seeded_data.dart' as seed;
import 'package:legal_case_diary/core/l10n/app_translations.dart';
import 'package:legal_case_diary/core/l10n/generated/app_localizations.dart';
import 'package:legal_case_diary/core/notifications/notification_plan.dart';
import 'package:legal_case_diary/core/utils/date_utils.dart';

/// A date [days] away from [todayStart] at noon Bangladesh time.
int _hearingAt(int todayStart, int days) =>
    todayStart + days * 24 * 60 * 60 * 1000 + 12 * 60 * 60 * 1000;

HearingCandidate _candidate({
  required int nextDateEpochMs,
  String caseId = 'case-1',
  String caseNumber = '110/2021',
  // A pre-seeded label, dash included, so the alert's first line is the real
  // shape the app stores rather than a made-up one.
  String caseType = 'Civil Appeal-',
  String? courtCategoryId,
  String petitioner = 'Karim',
  String respondent = 'State',
  String? storedCourtName,
}) => HearingCandidate(
  caseId: caseId,
  caseNumber: caseNumber,
  caseType: caseType,
  petitioner: petitioner,
  respondent: respondent,
  courtId: seed.courtLabelEn.keys.first,
  courtCategoryId: courtCategoryId,
  storedCourtName: storedCourtName,
  nextDateEpochMs: nextDateEpochMs,
);

AppTranslations _translations(String language) =>
    AppTranslations(lookupAppLocalizations(Locale(language)));

void main() {
  // A fixed reference day keeps the tests independent of the wall clock.
  final todayStart = AppDateUtils.bangladeshTodayStartOfDay(
    referenceEpochMs: DateTime.utc(2026, 9, 19, 10).millisecondsSinceEpoch,
  );

  group('offset matching', () {
    test('alerts a case whose hearing is the configured days away', () {
      final plan = buildNotificationPlan(
        todayStartEpochMs: todayStart,
        enabled: true,
        defaultOffsets: const [1],
        cases: [_candidate(nextDateEpochMs: _hearingAt(todayStart, 1))],
        preferences: const {},
        translations: _translations('en'),
      );

      expect(plan.alerts, hasLength(1));
      final alert = plan.alerts.single;
      expect(alert.caseId, 'case-1');
      expect(alert.offsetDays, 1);
      expect(alert.title, 'Hearing Tomorrow');
      expect(alert.body, contains('110/2021'));
      expect(alert.body, contains('Karim vs State'));
    });

    test('leaves cases outside the configured offsets alone', () {
      final plan = buildNotificationPlan(
        todayStartEpochMs: todayStart,
        enabled: true,
        defaultOffsets: const [1, 3],
        cases: [
          _candidate(nextDateEpochMs: _hearingAt(todayStart, 2)),
          _candidate(nextDateEpochMs: _hearingAt(todayStart, 8), caseId: 'c2'),
        ],
        preferences: const {},
        translations: _translations('en'),
      );

      expect(plan.isEmpty, isTrue);
    });

    test('a case alerts on the same day when the offset list says so', () {
      final plan = buildNotificationPlan(
        todayStartEpochMs: todayStart,
        enabled: true,
        defaultOffsets: const [0],
        cases: [_candidate(nextDateEpochMs: _hearingAt(todayStart, 0))],
        preferences: const {},
        translations: _translations('en'),
      );

      expect(plan.alerts.single.title, 'Hearing Today');
      expect(plan.alerts.single.offsetDays, 0);
    });

    test('a case\'s own offsets override the user defaults', () {
      final plan = buildNotificationPlan(
        todayStartEpochMs: todayStart,
        enabled: true,
        defaultOffsets: const [1],
        cases: [
          // Defaults would alert this one tomorrow…
          _candidate(nextDateEpochMs: _hearingAt(todayStart, 1)),
          // …but its own row asks for three days before instead.
          _candidate(nextDateEpochMs: _hearingAt(todayStart, 3), caseId: 'c2'),
        ],
        preferences: const {
          'case-1': HearingPreference(offsets: [3]),
          'c2': HearingPreference(offsets: [3]),
        },
        translations: _translations('en'),
      );

      expect(plan.alerts.map((a) => a.caseId), <String>['c2']);
      expect(plan.alerts.single.offsetDays, 3);
    });

    test('a case switched off never alerts, whatever the offsets are', () {
      final plan = buildNotificationPlan(
        todayStartEpochMs: todayStart,
        enabled: true,
        defaultOffsets: const [1],
        cases: [_candidate(nextDateEpochMs: _hearingAt(todayStart, 1))],
        preferences: const {'case-1': HearingPreference(enabled: false)},
        translations: _translations('en'),
      );

      expect(plan.isEmpty, isTrue);
    });

    test('the master switch off produces an empty plan', () {
      final plan = buildNotificationPlan(
        todayStartEpochMs: todayStart,
        enabled: false,
        defaultOffsets: const [1],
        cases: [_candidate(nextDateEpochMs: _hearingAt(todayStart, 1))],
        preferences: const {},
        translations: _translations('en'),
      );

      expect(plan.isEmpty, isTrue);
    });

    test('days are counted by Bangladesh civil date, not by instant', () {
      // 23:59 today and 00:01 tomorrow are one minute apart but are a day apart
      // as hearing dates.
      expect(
        dayOffsetFor(
          todayStartEpochMs: todayStart,
          dateEpochMs: todayStart + 24 * 60 * 60 * 1000 - 60 * 1000,
        ),
        0,
      );
      expect(
        dayOffsetFor(
          todayStartEpochMs: todayStart,
          dateEpochMs: todayStart + 24 * 60 * 60 * 1000 + 60 * 1000,
        ),
        1,
      );
    });

    test('alerts are ordered by hearing date', () {
      final plan = buildNotificationPlan(
        todayStartEpochMs: todayStart,
        enabled: true,
        defaultOffsets: const [1, 2],
        cases: [
          _candidate(nextDateEpochMs: _hearingAt(todayStart, 2), caseId: 'later'),
          _candidate(nextDateEpochMs: _hearingAt(todayStart, 1), caseId: 'sooner'),
        ],
        preferences: const {},
        translations: _translations('en'),
      );

      expect(plan.alerts.map((a) => a.caseId), <String>['sooner', 'later']);
    });
  });

  group('alert copy', () {
    test('the body carries the case type then the number, parties and court', () {
      final courtId = seed.courtLabelEn.keys.first;
      final english = seed.courtLabelEn[courtId]!;

      final plan = buildNotificationPlan(
        todayStartEpochMs: todayStart,
        enabled: true,
        defaultOffsets: const [1],
        cases: [
          _candidate(
            nextDateEpochMs: _hearingAt(todayStart, 1),
            storedCourtName: 'Stored English Name',
          ),
        ],
        preferences: const {},
        translations: _translations('en'),
      );

      final lines = plan.alerts.single.body.split('\n');
      // The type comes first and its own trailing dash separates the two: no
      // separator is added, and the number stays as the user typed it.
      expect(lines.first, 'Civil Appeal- 110/2021');
      expect(lines, contains('Karim vs State'));
      expect(lines, contains(english));
      // The pre-seeded label wins over the stored name.
      expect(plan.alerts.single.body, isNot(contains('Stored English Name')));
    });

    test('a case with no case type keeps the bare number on the first line', () {
      final plan = buildNotificationPlan(
        todayStartEpochMs: todayStart,
        enabled: true,
        defaultOffsets: const [1],
        cases: [
          _candidate(nextDateEpochMs: _hearingAt(todayStart, 1), caseType: ''),
        ],
        preferences: const {},
        translations: _translations('en'),
      );

      expect(plan.alerts.single.body.split('\n').first, '110/2021');
    });

    test('the case type follows Bengali like every other seed label', () {
      // `cases.case_type` stores the English label, so the alert has to map it
      // back through the seed data under বাংলা.
      final bengali = seed.caseTypeLabelBnByEnName['Civil Appeal-']!;
      expect(bengali, isNot('Civil Appeal-'));

      final plan = buildNotificationPlan(
        todayStartEpochMs: todayStart,
        enabled: true,
        defaultOffsets: const [1],
        cases: [_candidate(nextDateEpochMs: _hearingAt(todayStart, 1))],
        preferences: const {},
        translations: _translations('bn'),
      );

      final firstLine = plan.alerts.single.body.split('\n').first;
      expect(firstLine, '$bengali 110/2021');
      expect(firstLine, isNot(contains('Civil Appeal')));
    });

    test('a case type shared by two court categories follows the case\'s own', () {
      // Twenty pre-seeded names are labelled differently by different court
      // categories, so the label is resolved through the case's court category
      // instead of whichever category happens to come first.
      final byName = <String, Map<String, String>>{};
      for (final category in seed.caseTypeLabelBnByCourtCategory.entries) {
        for (final type in category.value.entries) {
          byName.putIfAbsent(type.key, () => <String, String>{})[category
              .key] = type.value;
        }
      }
      final shared = byName.entries.firstWhere(
        (entry) => entry.value.values.toSet().length > 1,
      );
      final first = shared.value.entries.first;
      final other = shared.value.entries.firstWhere(
        (entry) => entry.value != first.value,
      );

      String firstLineFor(String? courtCategoryId) => buildNotificationPlan(
        todayStartEpochMs: todayStart,
        enabled: true,
        defaultOffsets: const [1],
        cases: [
          _candidate(
            nextDateEpochMs: _hearingAt(todayStart, 1),
            caseType: shared.key,
            courtCategoryId: courtCategoryId,
          ),
        ],
        preferences: const {},
        translations: _translations('bn'),
      ).alerts.single.body.split('\n').first;

      expect(firstLineFor(first.key), '${first.value} 110/2021');
      expect(firstLineFor(other.key), '${other.value} 110/2021');
      // With no category to go on, the by-name fallback is the documented one.
      expect(
        firstLineFor(null),
        '${seed.caseTypeLabelBnByEnName[shared.key]} 110/2021',
      );
    });

    test('a user-added court keeps the name the user typed', () {
      final plan = buildNotificationPlan(
        todayStartEpochMs: todayStart,
        enabled: true,
        defaultOffsets: const [1],
        cases: [
          HearingCandidate(
            caseId: 'case-1',
            caseNumber: '110/2021',
            caseType: 'Civil Appeal-',
            petitioner: 'Karim',
            respondent: 'State',
            courtId: 'court_the_user_added',
            storedCourtName: 'My Own Court',
            nextDateEpochMs: _hearingAt(todayStart, 1),
          ),
        ],
        preferences: const {},
        translations: _translations('en'),
      );

      expect(plan.alerts.single.body, contains('My Own Court'));
    });

    test('the title and digits follow Bengali', () {
      final plan = buildNotificationPlan(
        todayStartEpochMs: todayStart,
        enabled: true,
        defaultOffsets: const [3],
        cases: [_candidate(nextDateEpochMs: _hearingAt(todayStart, 3))],
        preferences: const {},
        translations: _translations('bn'),
      );

      // Bengali title and Bengali numerals, matching every other surface.
      expect(plan.alerts.single.title, contains('৩ দিন পর শুনানি'));
      expect(plan.alerts.single.title, isNot(contains('3')));
    });

    test('a missing party is dropped from the party line', () {
      final plan = buildNotificationPlan(
        todayStartEpochMs: todayStart,
        enabled: true,
        defaultOffsets: const [1],
        cases: [
          _candidate(
            nextDateEpochMs: _hearingAt(todayStart, 1),
            petitioner: '',
            respondent: '',
          ),
        ],
        preferences: const {},
        translations: _translations('en'),
      );

      final lines = plan.alerts.single.body.split('\n');
      expect(lines, isNot(contains('')),
      );
      expect(lines.first, 'Civil Appeal- 110/2021');
      // Case line and court only — no empty party line, no "vs".
      expect(lines.any((line) => line.contains('vs')), isFalse);
    });

    test('one party alone is shown without "vs"', () {
      final plan = buildNotificationPlan(
        todayStartEpochMs: todayStart,
        enabled: true,
        defaultOffsets: const [1],
        cases: [
          _candidate(
            nextDateEpochMs: _hearingAt(todayStart, 1),
            petitioner: 'Karim',
            respondent: '   ',
          ),
        ],
        preferences: const {},
        translations: _translations('en'),
      );

      expect(plan.alerts.single.body, contains('Karim'));
      expect(plan.alerts.single.body, isNot(contains('vs')));
    });
  });

  group('helpers', () {
    test('decodeNotificationOffsets reads stored arrays and rejects rubbish', () {
      expect(decodeNotificationOffsets('[1,3]'), <int>[1, 3]);
      expect(decodeNotificationOffsets('[0]'), <int>[0]);
      expect(decodeNotificationOffsets('[]'), isNull);
      expect(decodeNotificationOffsets('not json'), isNull);
      expect(decodeNotificationOffsets('{"a":1}'), isNull);
      expect(decodeNotificationOffsets(null), isNull);
      expect(decodeNotificationOffsets(''), isNull);
    });

    test('effectiveOffsets falls back to the user default', () {
      expect(effectiveOffsets(const [1], null), const [1]);
      expect(effectiveOffsets(const [1], const HearingPreference()), const [1]);
      expect(
        effectiveOffsets(const [1], const HearingPreference(offsets: [7])),
        const [7],
      );
      expect(
        effectiveOffsets(const [1], const HearingPreference(offsets: [])),
        const [1],
      );
      // A row with no offsets at all still alerts on the day before.
      expect(effectiveOffsets(const [], null), const [1]);
    });

    test('widestOffset bounds the query window from the real configuration', () {
      expect(widestOffset(const [1], const []), 1);
      expect(widestOffset(const [0, 7, 3], const []), 7);
      expect(
        widestOffset(const [1], const [
          HearingPreference(offsets: [30]),
          HearingPreference(offsets: [15]),
        ]),
        30,
      );
      // A switched-off case cannot be due today, so its offsets are ignored.
      expect(
        widestOffset(const [2], const [
          HearingPreference(enabled: false, offsets: [30]),
        ]),
        2,
      );
      expect(widestOffset(const [], const []), 1);
    });

    test('nextAlarmEpochMs picks today or tomorrow', () {
      final reference = todayStart + 8 * 60 * 60 * 1000; // 08:00 Bangladesh
      expect(
        nextAlarmEpochMs(referenceEpochMs: reference, minutesSinceMidnight: 17 * 60),
        todayStart + 17 * 60 * 60 * 1000,
      );
      // Already past today's time → tomorrow, never a moment that has gone.
      expect(
        nextAlarmEpochMs(referenceEpochMs: reference, minutesSinceMidnight: 7 * 60),
        todayStart + 24 * 60 * 60 * 1000 + 7 * 60 * 60 * 1000,
      );
      // Exactly now counts as gone, so the alarm is not armed for this instant.
      expect(
        nextAlarmEpochMs(referenceEpochMs: reference, minutesSinceMidnight: 8 * 60),
        todayStart + 24 * 60 * 60 * 1000 + 8 * 60 * 60 * 1000,
      );
    });

    test('alarmPrecisionFor follows the exact-alarm permission', () {
      // Android 14 denies exact alarms by default; the job still runs, just
      // with the OS choosing the moment.
      expect(
        alarmPrecisionFor(exactAllowed: true),
        AlarmPrecision.exact,
      );
      expect(
        alarmPrecisionFor(exactAllowed: false),
        AlarmPrecision.inexact,
      );
    });

    test('notificationIdFor is stable, positive and per-case', () {
      final first = notificationIdFor('11111111-2222-3333-4444-555555555555');
      expect(first, notificationIdFor('11111111-2222-3333-4444-555555555555'));
      expect(first, greaterThanOrEqualTo(0));
      expect(first, lessThan(1 << 31));
      expect(first, isNot(notificationIdFor('other-case')));
    });
  });
}
