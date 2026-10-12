/// Pure "when should we auto-check for an update?" rules.
///
/// Plain Dart, no Flutter, no network — the daily launch check and the About
/// screen's Auto Check For Update card both call it, so the "every N days"
/// the 7-day-offline → day-8-toast rule live here where a unit test can pin
/// them without an emulator.
///
/// **Frequency** mirrors `backup_schedule.dart`: an interval in days, with 0 =
/// Off. A check is due when the last check was more than `frequencyDays` days
/// ago (in **Bangladesh civil days**, via the caller's already-localized day
/// number). The first check after the interval is enabled is due immediately
/// (no last-check yet), the same first-run behavior the backup schedule has.
///
/// **Offline rule.** While there is no internet the check is *skipped*, and the
/// skip is counted as a calendar day. Days 1-7 stay silent. On the 8th
/// consecutive offline day the app asks the user to connect and check — but
/// only **once per streak**: repeating it every later day would nag someone who
/// is simply offline for a week. A successful online check resets the count,
/// so the toast is never seen again until another 8-day offline stretch.
library;

/// Milliseconds in one day, for the frequency arithmetic.
const int _msPerDay = 24 * 60 * 60 * 1000;

/// 7 days of silence before the 8th day shows the toast.
const int updateOfflineToastDay = 8;

/// Whether a launch-period check is due.
///
/// [frequencyDays] is the stored Auto Check interval (0 = off), [lastCheckAt]
/// is the epoch-ms of the previous check (null = never). Uses the caller's
/// already-localized [nowEpochMs] so a *day* boundary is the user's own.
bool isUpdateCheckDue({
  required int frequencyDays,
  int? lastCheckAt,
  required int nowEpochMs,
}) {
  if (frequencyDays <= 0) return false;
  if (lastCheckAt == null) return true;
  return nowEpochMs >= lastCheckAt + frequencyDays * _msPerDay;
}

/// Whether the day-8 "connect and check" toast should be shown.
///
/// True only when the offline streak has reached [updateOfflineToastDay] days
/// and the notice has not been shown in this streak. Once shown it stays
/// suppressed until a success resets the streak.
bool shouldShowOfflineToast({
  required int offlineCheckDays,
  required bool offlineNoticeShown,
}) =>
    offlineCheckDays >= updateOfflineToastDay && !offlineNoticeShown;