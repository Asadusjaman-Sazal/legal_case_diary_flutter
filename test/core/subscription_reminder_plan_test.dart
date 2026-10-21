/// Pre-expiry subscription reminder maths — the pure half of the feature.
///
/// The alarms themselves need a device, so what is testable here is what decides
/// when a reminder fires and whether it is still true when it does: two named
/// mornings (seven and three civil days before the end date), nothing once those
/// mornings have passed, and nothing at all for a plan that was renewed in the
/// meantime.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/core/notifications/notification_plan.dart';
import 'package:legal_case_diary/core/utils/date_utils.dart';

void main() {
  /// Epoch ms of a Bangladesh civil date and hour, so the tests read as dates.
  int bd(int year, int month, int day, {int hour = 0}) =>
      AppDateUtils.bangladeshCivilDateEpoch(year, month, day) +
      hour * 60 * 60 * 1000;

  group('days left', () {
    test('counts civil days, not elapsed hours', () {
      expect(
        subscriptionDaysLeft(
          expiryEpochMs: bd(2026, 10, 30, hour: 23),
          nowEpochMs: bd(2026, 10, 23, hour: 1),
        ),
        7,
      );
    });

    test('the last day is 0 and the day after is negative', () {
      expect(
        subscriptionDaysLeft(
          expiryEpochMs: bd(2026, 10, 30, hour: 23),
          nowEpochMs: bd(2026, 10, 30, hour: 1),
        ),
        0,
      );
      expect(
        subscriptionDaysLeft(
          expiryEpochMs: bd(2026, 10, 29, hour: 12),
          nowEpochMs: bd(2026, 10, 30, hour: 12),
        ),
        -1,
      );
    });
  });

  group('fire times', () {
    test('a plan gets two reminders: seven and three days out, at 09:00', () {
      final reminders = subscriptionReminderFireTimes(
        expiryEpochMs: bd(2026, 10, 30, hour: 12),
        nowEpochMs: bd(2026, 10, 1, hour: 12),
      );
      expect(reminders.map((r) => r.daysLeft), <int>[7, 3]);
      expect(reminders.first.fireAtEpochMs, bd(2026, 10, 23, hour: 9));
      expect(reminders.last.fireAtEpochMs, bd(2026, 10, 27, hour: 9));
    });

    test('a reminder whose morning has passed is not armed', () {
      // 10:00 on the seven-day mark: that one is gone, the three-day one is
      // still ahead, so opening the app late in the week still warns.
      final reminders = subscriptionReminderFireTimes(
        expiryEpochMs: bd(2026, 10, 30, hour: 12),
        nowEpochMs: bd(2026, 10, 23, hour: 10),
      );
      expect(reminders.map((r) => r.daysLeft), <int>[3]);
    });

    test('nothing is armed once both mornings have passed', () {
      expect(
        subscriptionReminderFireTimes(
          expiryEpochMs: bd(2026, 10, 30, hour: 12),
          nowEpochMs: bd(2026, 10, 28, hour: 9),
        ),
        isEmpty,
      );
      expect(
        subscriptionReminderFireTimes(
          expiryEpochMs: bd(2026, 10, 30, hour: 12),
          nowEpochMs: bd(2026, 11, 2),
        ),
        isEmpty,
      );
    });

    test('a free account has nothing to remind about', () {
      expect(
        subscriptionReminderFireTimes(
          expiryEpochMs: null,
          nowEpochMs: bd(2026, 10, 1),
        ),
        isEmpty,
      );
    });
  });

  group('is the reminder still true', () {
    test('it posts on its own civil day, whatever the hour', () {
      final expiry = bd(2026, 10, 30, hour: 12);
      expect(
        isSubscriptionReminderDue(
          expiryEpochMs: expiry,
          nowEpochMs: bd(2026, 10, 23, hour: 9),
          daysLeft: 7,
        ),
        isTrue,
      );
      expect(
        isSubscriptionReminderDue(
          expiryEpochMs: expiry,
          nowEpochMs: bd(2026, 10, 23, hour: 22),
          daysLeft: 7,
        ),
        isTrue,
      );
    });

    test('it stays silent a day later, or on the other reminder\'s day', () {
      final expiry = bd(2026, 10, 30, hour: 12);
      expect(
        isSubscriptionReminderDue(
          expiryEpochMs: expiry,
          nowEpochMs: bd(2026, 10, 24, hour: 9),
          daysLeft: 7,
        ),
        isFalse,
      );
      expect(
        isSubscriptionReminderDue(
          expiryEpochMs: expiry,
          nowEpochMs: bd(2026, 10, 27, hour: 9),
          daysLeft: 7,
        ),
        isFalse,
      );
    });

    test('a renewal silences the reminder armed for the old date', () {
      // Renewed for another month; the alarm armed for the old end date fires
      // anyway, and must not announce an ending that is not happening.
      expect(
        isSubscriptionReminderDue(
          expiryEpochMs: bd(2026, 11, 30, hour: 12),
          nowEpochMs: bd(2026, 10, 23, hour: 9),
          daysLeft: 7,
        ),
        isFalse,
      );
    });

    test('a plan that has already ended posts nothing', () {
      expect(
        isSubscriptionReminderDue(
          expiryEpochMs: null,
          nowEpochMs: bd(2026, 10, 23, hour: 9),
          daysLeft: 7,
        ),
        isFalse,
      );
    });
  });
}
