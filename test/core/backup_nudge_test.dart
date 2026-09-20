/// Tests for the monthly backup-nudge rule (Task 15 Phase 6).
///
/// The rule decides when a free user is asked to save a backup, so it is tested
/// as a pure function of three instants — including the month boundary, which is
/// where a naive UTC comparison would nag twice or not at all.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/core/backup/backup_nudge.dart';

/// Epoch-ms of a UTC instant.
int _at(int year, int month, int day, [int hour = 12, int minute = 0]) =>
    DateTime.utc(year, month, day, hour, minute).millisecondsSinceEpoch;

void main() {
  test('a user with no backup and no nudge is due', () {
    expect(
      isBackupNudgeDue(
        now: _at(2026, 8, 10),
        lastBackupAt: null,
        lastNudgedAt: null,
      ),
      isTrue,
    );
  });

  test('a backup this month cancels the nudge', () {
    expect(
      isBackupNudgeDue(
        now: _at(2026, 8, 10),
        lastBackupAt: _at(2026, 8, 1),
        lastNudgedAt: null,
      ),
      isFalse,
    );
  });

  test('a nudge this month is not repeated', () {
    expect(
      isBackupNudgeDue(
        now: _at(2026, 8, 10),
        lastBackupAt: null,
        lastNudgedAt: _at(2026, 8, 2),
      ),
      isFalse,
    );
  });

  test('last month\'s backup and nudge both come round again', () {
    expect(
      isBackupNudgeDue(
        now: _at(2026, 8, 10),
        lastBackupAt: _at(2026, 7, 31),
        lastNudgedAt: _at(2026, 7, 1),
      ),
      isTrue,
    );
  });

  test('the boundary is the Bangladesh month, not the UTC one', () {
    // 31 Jul 19:00 UTC is already 1 August in Dhaka (UTC+6), so this is
    // August's first moments: last month's records no longer count.
    final augustFirstDhaka = _at(2026, 7, 31, 19);
    expect(
      isBackupNudgeDue(
        now: augustFirstDhaka,
        lastBackupAt: _at(2026, 7, 31, 17, 30), // 23:30 Dhaka, still July
        lastNudgedAt: null,
      ),
      isTrue,
    );
    // A backup half an hour later in Dhaka time belongs to August and does
    // protect the whole month, even though UTC still reads 31 July.
    expect(
      isBackupNudgeDue(
        now: augustFirstDhaka,
        lastBackupAt: _at(2026, 7, 31, 18, 30), // 00:30 Dhaka, August
        lastNudgedAt: null,
      ),
      isFalse,
    );
  });

  test('a nudge on the last day of a month is not repeated the next day', () {
    // 23:00 Dhaka on 31 August, nudge shown two hours earlier.
    final lateAugust = _at(2026, 8, 31, 17);
    expect(
      isBackupNudgeDue(
        now: lateAugust,
        lastBackupAt: null,
        lastNudgedAt: _at(2026, 8, 31, 15),
      ),
      isFalse,
    );
    // …but the same clock a month earlier was due, so this is a real check.
    expect(
      isBackupNudgeDue(
        now: lateAugust,
        lastBackupAt: null,
        lastNudgedAt: _at(2026, 7, 31, 15),
      ),
      isTrue,
    );
  });
}
