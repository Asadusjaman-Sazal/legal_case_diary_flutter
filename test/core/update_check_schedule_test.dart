/// Guards the automatic-update-check rules (update_check_schedule.dart).
///
/// Pure Dart, no Flutter: the launch check decides "check now?" and "nag about
/// being offline?" from these two functions, so the frequency rule and the
/// 7-day-offline/day-8-toast rule are pinned here where they live.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/features/settings/data/update_check_schedule.dart';

/// One day in ms, for readable expectations.
const int day = 24 * 60 * 60 * 1000;

void main() {
  group('isUpdateCheckDue', () {
    test('off never checks', () {
      expect(
        isUpdateCheckDue(frequencyDays: 0, lastCheckAt: null, nowEpochMs: 0),
        isFalse,
      );
    });

    test('the first check after enabling is due at once', () {
      expect(
        isUpdateCheckDue(frequencyDays: 7, lastCheckAt: null, nowEpochMs: day),
        isTrue,
      );
    });

    test('it is not due again before the interval has passed', () {
      expect(
        isUpdateCheckDue(
          frequencyDays: 7,
          lastCheckAt: 1 * day,
          nowEpochMs: 1 * day + 6 * day,
        ),
        isFalse,
      );
    });

    test('it is due once the interval has passed', () {
      expect(
        isUpdateCheckDue(
          frequencyDays: 7,
          lastCheckAt: 1 * day,
          nowEpochMs: 1 * day + 7 * day,
        ),
        isTrue,
      );
    });

    test('every day means a day between checks', () {
      expect(
        isUpdateCheckDue(frequencyDays: 1, lastCheckAt: 0, nowEpochMs: day),
        isTrue,
      );
      expect(
        isUpdateCheckDue(frequencyDays: 1, lastCheckAt: 0, nowEpochMs: day - 1),
        isFalse,
      );
    });
  });

  group('shouldShowOfflineToast', () {
    test('silent for the first seven offline days', () {
      for (var days = 0; days < 8; days++) {
        expect(
          shouldShowOfflineToast(offlineCheckDays: days, offlineNoticeShown: false),
          isFalse,
          reason: 'day $days should be silent',
        );
      }
    });

    test('it shows on the eighth consecutive offline day', () {
      expect(
        shouldShowOfflineToast(
          offlineCheckDays: 8,
          offlineNoticeShown: false,
        ),
        isTrue,
      );
    });

    test('it does not repeat within the same streak', () {
      expect(
        shouldShowOfflineToast(
          offlineCheckDays: 9,
          offlineNoticeShown: true,
        ),
        isFalse,
      );
    });
  });
}