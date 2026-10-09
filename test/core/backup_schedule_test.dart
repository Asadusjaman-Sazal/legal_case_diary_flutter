/// Tests for the automatic-backup scheduling rules.
///
/// The rules are pure Dart so they run without a device: which interval is due
/// at which cadence, and what the job must do when encryption is on (skip and
/// ask the user) versus when it is plain (run).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:legal_case_diary/core/backup/backup_schedule.dart';

void main() {
  group('BackupSchedule.isDue', () {
    test('is never due while Off', () {
      final schedule = BackupSchedule(backupScheduleOff);
      expect(schedule.isEnabled, isFalse);
      expect(
        schedule.isDue(nowEpochMs: 1000, lastRunEpochMs: 500),
        isFalse,
      );
    });

    test('a fresh schedule is due immediately (no last run yet)', () {
      final schedule = BackupSchedule(1);
      expect(
        schedule.isDue(nowEpochMs: 0, lastRunEpochMs: null),
        isTrue,
      );
    });

    test('Everyday is due a full day after the last run', () {
      final schedule = BackupSchedule(1);
      final lastRun = 1 * millisecondsPerDay;
      expect(
        schedule.isDue(nowEpochMs: lastRun + millisecondsPerDay - 1, lastRunEpochMs: lastRun),
        isFalse,
      );
      expect(
        schedule.isDue(nowEpochMs: lastRun + millisecondsPerDay, lastRunEpochMs: lastRun),
        isTrue,
      );
    });

    test('Every 3 days is due only after three whole days', () {
      final schedule = BackupSchedule(3);
      final lastRun = 1 * millisecondsPerDay;
      expect(
        schedule.isDue(nowEpochMs: lastRun + 2 * millisecondsPerDay, lastRunEpochMs: lastRun),
        isFalse,
      );
      expect(
        schedule.isDue(nowEpochMs: lastRun + 3 * millisecondsPerDay, lastRunEpochMs: lastRun),
        isTrue,
      );
    });

    test('Every month honours a 30-day interval', () {
      final schedule = BackupSchedule(30);
      final lastRun = 1 * millisecondsPerDay;
      expect(
        schedule.isDue(nowEpochMs: lastRun + 29 * millisecondsPerDay, lastRunEpochMs: lastRun),
        isFalse,
      );
      expect(
        schedule.isDue(nowEpochMs: lastRun + 30 * millisecondsPerDay, lastRunEpochMs: lastRun),
        isTrue,
      );
    });
  });

  group('decideBackupJob', () {
    test('disabled when the schedule is off', () {
      expect(
        decideBackupJob(
          schedule: BackupSchedule(backupScheduleOff),
          encryptBackups: false,
          nowEpochMs: 0,
          lastRunEpochMs: null,
        ),
        BackupJobDecision.disabled,
      );
    });

    test('runs when due and encryption is off', () {
      expect(
        decideBackupJob(
          schedule: BackupSchedule(1),
          encryptBackups: false,
          nowEpochMs: millisecondsPerDay * 2,
          lastRunEpochMs: millisecondsPerDay,
        ),
        BackupJobDecision.run,
      );
    });

    test('skips for the user when encryption is on', () {
      expect(
        decideBackupJob(
          schedule: BackupSchedule(1),
          encryptBackups: true,
          nowEpochMs: millisecondsPerDay * 2,
          lastRunEpochMs: millisecondsPerDay,
        ),
        BackupJobDecision.encryptionOnSkips,
      );
    });

    test('encryption on does not nag on a day that is not due', () {
      expect(
        decideBackupJob(
          schedule: BackupSchedule(7),
          encryptBackups: true,
          nowEpochMs: millisecondsPerDay,
          lastRunEpochMs: 0,
        ),
        BackupJobDecision.disabled,
      );
    });

    test('is disabled rather than run when not yet due', () {
      expect(
        decideBackupJob(
          schedule: BackupSchedule(7),
          encryptBackups: false,
          nowEpochMs: millisecondsPerDay,
          lastRunEpochMs: 0,
        ),
        BackupJobDecision.disabled,
      );
    });
  });
}