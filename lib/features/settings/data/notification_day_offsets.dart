/// Day-offset options shared by Settings → Notifications and the case form.
///
/// Settings is the source of truth: the Notifications screen's "Notification day
/// offset" picker and the Add/Edit Case form's Day Offset dropdown both offer
/// these days, and the form starts from whichever one Settings has stored — so a
/// choice made in Settings is always shown on a case. `0` means the hearing day
/// itself, `1` the day before, and so on — the same reading Task 13's daily job
/// uses for `notification_day_offset`.
///
/// Note: the plan's Task 07 field table lists a shorter fixed list for the form
/// (same day, 1, 3, 7, 15, 30). The user replaced that with this single shared
/// list during Task 12 Phase 4 follow-up, so both surfaces stay identical.
library;

/// Day offsets offered by every notification picker, in days before the hearing.
const List<int> notificationDayOffsetOptions = <int>[0, 1, 2, 3, 7, 15, 30];

/// Offset used while the user has not chosen one.
///
/// Matches `UserSettings.notificationDayOffset` and the mockup's default (the
/// day before the hearing).
const int defaultNotificationDayOffset = 1;
