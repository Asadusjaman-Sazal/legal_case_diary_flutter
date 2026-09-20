/// Whether the monthly backup nudge is due (Task 15 Phase 6).
///
/// For a free user the local export is the only safety net there is, so the app
/// asks once a calendar month — and only when that month has no backup at all.
/// Both halves of that rule use the **Bangladesh civil month**, the app's
/// calendar convention (plan: civil dates are UTC+6, never the device's zone),
/// so a nudge on the last evening of a month is not repeated an hour later, and
/// a backup made on the 1st protects the whole month.
///
/// Kept pure and free of Flutter, Drift and plugin imports: the rule is the part
/// worth testing exhaustively, and it must stay callable from a test with three
/// integers.
library;

import '../utils/date_utils.dart';

/// Whether the free-user backup nudge should be shown at [now].
///
/// True only when [now]'s Bangladesh month holds **no** successful backup and
/// **no** earlier nudge. Callers still have to check entitlement (premium users
/// do not need the reminder) and that there is actually something to lose — this
/// answers the calendar question alone.
bool isBackupNudgeDue({
  required int now,
  required int? lastBackupAt,
  required int? lastNudgedAt,
}) {
  final current = AppDateUtils.bangladeshDateTime(now);
  return !_isSameCivilMonth(lastBackupAt, current) &&
      !_isSameCivilMonth(lastNudgedAt, current);
}

/// Whether [epochMs] falls in [reference]'s Bangladesh civil month.
bool _isSameCivilMonth(int? epochMs, DateTime reference) {
  if (epochMs == null) return false;
  final other = AppDateUtils.bangladeshDateTime(epochMs);
  return other.year == reference.year && other.month == reference.month;
}
