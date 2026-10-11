/// Preferences for the in-app updater (the About screen's App Update section).
///
/// Mirrors `backup_metadata_store.dart`: everything lives in [SharedPreferences]
/// (a per-user preference, not the database — the same class the backup
/// scheduler uses), read through an [Notifier] the screen and the daily check
/// both watch.
///
/// What is stored:
///  * **frequencyDays** — the Auto Update interval (0 = off, the default). This
///    dictates how often the launch check runs, exactly like the automatic
///    backup interval.
///  * **lastCheckedAt** — when the last check ran (drives the screen's
///    "Last checked" line and the frequency rule).
///  * **offlineCheckDays / offlineNoticeShown** — the continuous-offline rule:
///    day 1-7 stay silent, day 8 shows a "connect & check" toast once per
///    streak, and success resets the streak. Persisted so the 8-day count
///    survives app restarts (it is *calendar* days, not sessions).
///  * **latestKnownVersion** — the version of the last release the check saw,
///    so the green "You're On The Latest Version" survives a restart without a
///    re-download. It is only a display cache, never the authority (the
///    check itself always re-asks GitHub).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/providers/shared_preferences_provider.dart';

/// Preference key: how often the app checks for updates, in days (0 = off).
const String updateFrequencyDaysKey = 'update_frequency_days';

/// Preference key: epoch-ms of the last launch-period update check.
const String updateLastCheckedAtKey = 'update_last_checked_at';

/// Preference key: consecutive calendar days the launch check has been skipped
/// because there was no internet.
const String updateOfflineCheckDaysKey = 'update_offline_check_days';

/// Preference key: whether the day-8 "connect to check" toast has been shown in
/// the current offline streak.
const String updateOfflineNoticeShownKey = 'update_offline_notice_shown';

/// Preference key: the version of the last release the check saw, displayed by
/// the About screen's "You're On The Latest Version" line.
const String updateLatestKnownVersionKey = 'update_latest_known_version';

/// Default Auto Update frequency: check once a day (mirrors the backup
/// default of "Every Day").
const int defaultUpdateFrequencyDays = 1;

/// What the updater remembers between launches.
class UpdateMetadata {
  /// Auto-check interval in days; 0 means "Off".
  final int frequencyDays;

  /// Epoch-ms of the last launch-period check, or null when never checked.
  final int? lastCheckedAt;

  /// Consecutive calendar days the launch check has been skipped (offline).
  final int offlineCheckDays;

  /// Whether the offline toast has been shown in the current streak.
  final bool offlineNoticeShown;

  /// Version string (`0.0.480`) of the last release the check found, if any.
  final String? latestKnownVersion;

  /// Creates a snapshot.
  const UpdateMetadata({
    this.frequencyDays = defaultUpdateFrequencyDays,
    this.lastCheckedAt,
    this.offlineCheckDays = 0,
    this.offlineNoticeShown = false,
    this.latestKnownVersion,
  });
}

/// Reads and writes [UpdateMetadata] through [SharedPreferences].
class UpdateMetadataNotifier extends Notifier<UpdateMetadata> {
  late final SharedPreferences _prefs;

  @override
  UpdateMetadata build() {
    _prefs = ref.read(sharedPreferencesProvider);
    return UpdateMetadata(
      frequencyDays:
          _prefs.getInt(updateFrequencyDaysKey) ?? defaultUpdateFrequencyDays,
      lastCheckedAt: _prefs.getInt(updateLastCheckedAtKey),
      offlineCheckDays: _prefs.getInt(updateOfflineCheckDaysKey) ?? 0,
      offlineNoticeShown: _prefs.getBool(updateOfflineNoticeShownKey) ?? false,
      latestKnownVersion: _prefs.getString(updateLatestKnownVersionKey),
    );
  }

  /// Stores the chosen Auto Update interval (0 = off).
  Future<void> setFrequencyDays(int days) async {
    if (days == state.frequencyDays) return;
    await _prefs.setInt(updateFrequencyDaysKey, days);
    state = UpdateMetadata(
      frequencyDays: days,
      lastCheckedAt: state.lastCheckedAt,
      offlineCheckDays: state.offlineCheckDays,
      offlineNoticeShown: state.offlineNoticeShown,
      latestKnownVersion: state.latestKnownVersion,
    );
  }

  /// Records that a check ran at [atEpochMs], and what the release was.
  Future<void> recordCheck({
    required int atEpochMs,
    String? releaseVersion,
    required bool offline,
  }) async {
    await _prefs.setInt(updateLastCheckedAtKey, atEpochMs);
    // Offline successes accumulate the streak; an online check resets it. The
    // toast is armed for the next day-8, i.e. cleared only once a check online
    // proves the streak is over.
    final streak = offline ? state.offlineCheckDays + 1 : 0;
    final noticeShown = offline ? state.offlineNoticeShown : false;
    await _prefs.setInt(updateOfflineCheckDaysKey, streak);
    await _prefs.setBool(updateOfflineNoticeShownKey, noticeShown);
    if (releaseVersion != null) {
      await _prefs.setString(updateLatestKnownVersionKey, releaseVersion);
    }
    state = UpdateMetadata(
      frequencyDays: state.frequencyDays,
      lastCheckedAt: atEpochMs,
      offlineCheckDays: streak,
      offlineNoticeShown: noticeShown,
      latestKnownVersion: releaseVersion ?? state.latestKnownVersion,
    );
  }

  /// Marks the day-8 toast as shown for the current streak.
  Future<void> markOfflineNoticeShown() async {
    await _prefs.setBool(updateOfflineNoticeShownKey, true);
    state = UpdateMetadata(
      frequencyDays: state.frequencyDays,
      lastCheckedAt: state.lastCheckedAt,
      offlineCheckDays: state.offlineCheckDays,
      offlineNoticeShown: true,
      latestKnownVersion: state.latestKnownVersion,
    );
  }
}

/// Riverpod provider for [UpdateMetadataNotifier].
final updateMetadataProvider = NotifierProvider<UpdateMetadataNotifier, UpdateMetadata>(
  UpdateMetadataNotifier.new,
);