/// Date formatting and normalization utilities for the Legal Case Diary.
///
/// All civil-date logic uses the **Bangladesh** timezone (UTC+6, no DST) so
/// that `next_date`/`hearing_date` values are compared by calendar date rather
/// than by UTC instant or the device's local timezone.
///
/// Implemented in Task 02 Phase 4.
library;

import 'package:intl/intl.dart';

/// Bangladesh is UTC+6 and does not observe daylight saving time.
const Duration _bangladeshOffset = Duration(hours: 6);

/// Milliseconds in one day.
const int _millisecondsPerDay = 24 * 60 * 60 * 1000;

/// Date formatting and normalization helpers used throughout the app.
///
/// Every public method that accepts an epoch-ms value interprets it as a
/// Bangladesh civil date. Formatting is locale-aware via the [intl] package.
abstract final class AppDateUtils {
  AppDateUtils._();

  // ---------------------------------------------------------------------------
  // Normalization & civil-date comparison
  // ---------------------------------------------------------------------------

  /// Convert an epoch-ms value to a local [DateTime] whose year/month/day/hour
  /// values represent the equivalent Bangladesh civil date/time.
  ///
  /// Bangladesh time = UTC + [6 hours]. This method is used internally for
  /// all civil-date calculations so that hearing/next dates are interpreted
  /// consistently regardless of the device's current timezone.
  ///
  /// The returned [DateTime] is non-UTC so that [DateFormat.format] treats the
  /// fields as a wall-clock time in Bangladesh rather than converting a UTC
  /// instant to the device's local timezone.
  static DateTime bangladeshDateTime(int epochMs) {
    final utc = DateTime.fromMillisecondsSinceEpoch(epochMs, isUtc: true);
    final adjusted = utc.add(_bangladeshOffset);
    return DateTime(
      adjusted.year,
      adjusted.month,
      adjusted.day,
      adjusted.hour,
      adjusted.minute,
      adjusted.second,
      adjusted.millisecond,
      adjusted.microsecond,
    );
  }

  /// Normalize an epoch-ms value to the start of its Bangladesh civil date.
  ///
  /// Returns the epoch-ms of 00:00:00 Bangladesh time for the civil day on
  /// which the original instant falls. Two values that fall on the same
  /// Bangladesh day will return the same result.
  static int normalizeToBangladeshStartOfDay(int epochMs) {
    final bangladesh = bangladeshDateTime(epochMs);
    final startOfDayBangladesh = DateTime.utc(
      bangladesh.year,
      bangladesh.month,
      bangladesh.day,
    );
    final startOfDayUtc = startOfDayBangladesh.subtract(_bangladeshOffset);
    return startOfDayUtc.millisecondsSinceEpoch;
  }

  /// Returns `true` if [a] and [b] fall on the same Bangladesh civil date.
  static bool isSameBangladeshCivilDate(int a, int b) {
    return normalizeToBangladeshStartOfDay(a) ==
        normalizeToBangladeshStartOfDay(b);
  }

  /// Returns the start-of-day epoch-ms for the current Bangladesh civil date.
  static int bangladeshTodayStartOfDay({int? referenceEpochMs}) {
    return normalizeToBangladeshStartOfDay(
      referenceEpochMs ?? DateTime.now().millisecondsSinceEpoch,
    );
  }

  /// Returns the epoch-ms (UTC instant) of 00:00:00 Bangladesh time for the
  /// given civil [year]/[month]/[day]. Inverse of
  /// [normalizeToBangladeshStartOfDay]: the returned value round-trips back to
  /// the same Bangladesh civil date. Used to build calendar grid cell keys.
  static int bangladeshCivilDateEpoch(int year, int month, int day) {
    final bangladeshStart = DateTime.utc(year, month, day);
    return bangladeshStart.subtract(_bangladeshOffset).millisecondsSinceEpoch;
  }

  // ---------------------------------------------------------------------------
  // Formatting
  // ---------------------------------------------------------------------------

  /// Format as `DD/MM/YYYY`.
  static String formatDateDDMMYYYY(int epochMs, {required String locale}) {
    return DateFormat('dd/MM/yyyy', locale).format(
      bangladeshDateTime(epochMs),
    );
  }

  /// Format as `DD/MM/YY | DDD` for the Daily Cause List calendar control.
  ///
  /// The weekday abbreviation is localized (e.g. English "Tue", Bengali "মঙ্গল").
  static String formatDailyCauseCalendarDate(
    int epochMs, {
    required String locale,
  }) {
    return DateFormat('dd/MM/yy | EEE', locale).format(
      bangladeshDateTime(epochMs),
    );
  }

  /// Format as `DD/MM/YY, HH:MM AM/PM` for note card timestamps.
  static String formatNoteCardDate(int epochMs, {required String locale}) {
    return DateFormat('dd/MM/yy, hh:mm a', locale).format(
      bangladeshDateTime(epochMs),
    );
  }

  /// Format as a full localized date, e.g. "Tuesday, October 24, 2023".
  static String formatFullDate(int epochMs, {required String locale}) {
    return DateFormat('EEEE, MMMM d, y', locale).format(
      bangladeshDateTime(epochMs),
    );
  }

  /// Format a hearing/next date for display with the "Today"/"Tomorrow" rule.
  ///
  /// If the date falls on the current Bangladesh civil date, [todayLabel] is
  /// returned. If it falls on the next Bangladesh civil date, [tomorrowLabel]
  /// is returned. Otherwise the date is formatted as `DD/MM/YYYY` in the given
  /// [locale].
  static String formatDisplayDate(
    int epochMs, {
    required String todayLabel,
    required String tomorrowLabel,
    required String locale,
    int? referenceEpochMs,
  }) {
    final todayStart = bangladeshTodayStartOfDay(
      referenceEpochMs: referenceEpochMs,
    );
    final targetStart = normalizeToBangladeshStartOfDay(epochMs);

    if (targetStart == todayStart) {
      return todayLabel;
    }
    if (targetStart == todayStart + _millisecondsPerDay) {
      return tomorrowLabel;
    }

    return formatDateDDMMYYYY(epochMs, locale: locale);
  }

  // ---------------------------------------------------------------------------
  // Parsing
  // ---------------------------------------------------------------------------

  /// Parse a `DD/MM/YYYY` string into the epoch-ms of its Bangladesh
  /// start-of-day.
  ///
  /// Throws [FormatException] if the input is not in the expected format or
  /// represents an invalid date.
  static int parseDDMMYYYYToStartOfDay(String value) {
    final parts = value.split('/');
    if (parts.length != 3) {
      throw FormatException('Expected DD/MM/YYYY, got: $value');
    }

    final day = int.parse(parts[0]);
    final month = int.parse(parts[1]);
    final year = int.parse(parts[2]);

    // Construct the civil date in Bangladesh, then convert to the equivalent
    // UTC instant by removing the +6 hour offset.
    final bangladesh = DateTime.utc(year, month, day);
    final utc = bangladesh.subtract(_bangladeshOffset);
    return utc.millisecondsSinceEpoch;
  }
}
