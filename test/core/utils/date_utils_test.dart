import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:legal_case_diary/core/utils/date_utils.dart';

void main() {
  // Ensure intl locale data is available for both English and Bengali.
  setUpAll(() async {
    await initializeDateFormatting();
  });

  group('Bangladesh civil date normalization', () {
    test('normalizes different times within the same Bangladesh day', () {
      // 2023-10-24 00:00:00 UTC is 2023-10-24 06:00 Bangladesh.
      final base = DateTime.utc(2023, 10, 24, 0, 0, 0).millisecondsSinceEpoch;
      final later = base + 10 * 60 * 60 * 1000; // 10 hours later

      expect(
        AppDateUtils.normalizeToBangladeshStartOfDay(base),
        AppDateUtils.normalizeToBangladeshStartOfDay(later),
      );
    });

    test('crosses the Bangladesh civil date boundary at UTC 18:00', () {
      // Bangladesh midnight = UTC 18:00. Use DateTime to avoid epoch math.
      final boundary = DateTime.utc(2023, 10, 24, 18, 0, 0);
      final justBefore = boundary.subtract(const Duration(seconds: 1)).millisecondsSinceEpoch;
      final justAfter = boundary.millisecondsSinceEpoch;

      final startBefore = AppDateUtils.normalizeToBangladeshStartOfDay(justBefore);
      final startAfter = AppDateUtils.normalizeToBangladeshStartOfDay(justAfter);

      // They should be one day apart.
      expect(startAfter - startBefore, 24 * 60 * 60 * 1000);
    });

    test('isSameBangladeshCivilDate returns true for same day', () {
      final day1 = DateTime.utc(2023, 10, 24, 0, 0, 0).millisecondsSinceEpoch;
      final day2 = day1 + 10 * 60 * 60 * 1000; // still 2023-10-24 Bangladesh
      expect(AppDateUtils.isSameBangladeshCivilDate(day1, day2), isTrue);
    });

    test('isSameBangladeshCivilDate returns false for different days', () {
      final day1 = DateTime.utc(2023, 10, 24, 0, 0, 0).millisecondsSinceEpoch;
      final day2 = DateTime.utc(2023, 10, 25, 0, 0, 0).millisecondsSinceEpoch;
      expect(AppDateUtils.isSameBangladeshCivilDate(day1, day2), isFalse);
    });
  });

  group('formatDateDDMMYYYY', () {
    test('formats a known epoch to DD/MM/YYYY in English', () {
      // 2023-10-24 06:00 Bangladesh == 2023-10-24 00:00 UTC
      final epoch = DateTime.utc(2023, 10, 24, 0, 0, 0).millisecondsSinceEpoch;
      expect(
        AppDateUtils.formatDateDDMMYYYY(epoch, locale: 'en'),
        '24/10/2023',
      );
    });

    test('formats a known epoch to DD/MM/YYYY in Bengali', () {
      final epoch = DateTime.utc(2023, 10, 24, 0, 0, 0).millisecondsSinceEpoch;
      final result = AppDateUtils.formatDateDDMMYYYY(epoch, locale: 'bn');
      // Bengali locale should produce a non-empty formatted string containing
      // the date separators used by the pattern.
      expect(result, isNotEmpty);
      expect(result, contains('/'));
    });
  });

  group('formatDailyCauseCalendarDate', () {
    test('produces DD/MM/YY | DDD pattern in English', () {
      // 2023-10-24 is a Tuesday.
      final epoch = DateTime.utc(2023, 10, 24, 0, 0, 0).millisecondsSinceEpoch;
      final result = AppDateUtils.formatDailyCauseCalendarDate(
        epoch,
        locale: 'en',
      );
      expect(result, '24/10/23 | Tue');
    });

    test('produces localized weekday in Bengali', () {
      final epoch = DateTime.utc(2023, 10, 24, 0, 0, 0).millisecondsSinceEpoch;
      final result = AppDateUtils.formatDailyCauseCalendarDate(
        epoch,
        locale: 'bn',
      );
      expect(result, isNotEmpty);
      // Bengali locale renders numerals and weekday in Bengali script.
      expect(result, contains('২৪/১০/২৩'));
      expect(result, contains('মঙ্গল'));
    });
  });

  group('formatNoteCardDate', () {
    test('produces DD/MM/YY, HH:MM AM/PM pattern in English', () {
      // 2023-10-24 15:30 Bangladesh == 2023-10-24 09:30 UTC
      final bangladesh = DateTime.utc(2023, 10, 24, 15, 30);
      final utc = bangladesh.subtract(const Duration(hours: 6));
      final epoch = utc.millisecondsSinceEpoch;

      final result = AppDateUtils.formatNoteCardDate(epoch, locale: 'en');
      expect(result, '24/10/23, 03:30 PM');
    });
  });

  group('formatFullDate', () {
    test('produces full localized date in English', () {
      final epoch = DateTime.utc(2023, 10, 24, 0, 0, 0).millisecondsSinceEpoch;
      final result = AppDateUtils.formatFullDate(epoch, locale: 'en');
      expect(result, 'Tuesday, October 24, 2023');
    });

    test('produces full localized date in Bengali', () {
      final epoch = DateTime.utc(2023, 10, 24, 0, 0, 0).millisecondsSinceEpoch;
      final result = AppDateUtils.formatFullDate(epoch, locale: 'bn');
      expect(result, isNotEmpty);
    });
  });

  group('formatDisplayDate', () {
    const locale = 'en';
    const todayLabel = 'Today';
    const tomorrowLabel = 'Tomorrow';

    test('returns todayLabel when the date is today', () {
      final today = AppDateUtils.bangladeshTodayStartOfDay();
      final result = AppDateUtils.formatDisplayDate(
        today,
        todayLabel: todayLabel,
        tomorrowLabel: tomorrowLabel,
        locale: locale,
      );
      expect(result, todayLabel);
    });

    test('returns tomorrowLabel when the date is tomorrow', () {
      final today = AppDateUtils.bangladeshTodayStartOfDay();
      final tomorrow = today + 24 * 60 * 60 * 1000;
      final result = AppDateUtils.formatDisplayDate(
        tomorrow,
        todayLabel: todayLabel,
        tomorrowLabel: tomorrowLabel,
        locale: locale,
      );
      expect(result, tomorrowLabel);
    });

    test('returns formatted DD/MM/YYYY for other dates', () {
      final epoch = AppDateUtils.parseDDMMYYYYToStartOfDay('15/08/2024');
      final result = AppDateUtils.formatDisplayDate(
        epoch,
        todayLabel: todayLabel,
        tomorrowLabel: tomorrowLabel,
        locale: locale,
      );
      expect(result, '15/08/2024');
    });
  });

  group('parseDDMMYYYYToStartOfDay', () {
    test('round-trips DD/MM/YYYY through formatting', () {
      const input = '24/10/2023';
      final epoch = AppDateUtils.parseDDMMYYYYToStartOfDay(input);
      final formatted = AppDateUtils.formatDateDDMMYYYY(epoch, locale: 'en');
      expect(formatted, input);
    });

    test('throws for invalid format', () {
      expect(() => AppDateUtils.parseDDMMYYYYToStartOfDay('2023-10-24'), throwsFormatException);
    });
  });

  group('day-drift safety', () {
    test('normalizes late-evening UTC to the correct Bangladesh day', () {
      // 2023-10-24 20:00:00 UTC is 2023-10-25 02:00:00 Bangladesh.
      final epoch = DateTime.utc(2023, 10, 24, 20, 0, 0).millisecondsSinceEpoch;
      final normalized = AppDateUtils.normalizeToBangladeshStartOfDay(epoch);
      final formatted = AppDateUtils.formatDateDDMMYYYY(normalized, locale: 'en');
      expect(formatted, '25/10/2023');
    });

    test('normalizes early-morning UTC to the correct Bangladesh day', () {
      // 2023-10-24 02:00:00 UTC is 2023-10-24 08:00:00 Bangladesh.
      final epoch = DateTime.utc(2023, 10, 24, 2, 0, 0).millisecondsSinceEpoch;
      final normalized = AppDateUtils.normalizeToBangladeshStartOfDay(epoch);
      final formatted = AppDateUtils.formatDateDDMMYYYY(normalized, locale: 'en');
      expect(formatted, '24/10/2023');
    });
  });
}
