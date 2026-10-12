/// Preferences for the in-app updater (the About screen's Update sub-page).
///
/// Mirrors `backup_metadata_store.dart`: everything lives in [SharedPreferences]
/// (a per-user preference, not the database), read through a [Notifier] the
/// screen and the launch check both watch.
///
/// What is stored:
///  * **frequencyDays** — how often the launch check runs (0 = off). The
///    feature is **Auto Check for Update**: the check only ever reports, it
///    never installs.
///  * **network** — whether an update may be downloaded over mobile data
///    (Wi-Fi only by default; the platform norm for updates).
///  * **availableRelease** — the release the last check found, so the About and
///    Update rows can carry their dot without a second lookup and the Update
///    screen can offer it offline. Cleared when a check finds nothing newer.
///  * **skippedVersion** — a release the user chose to skip. It stops being
///    offered until a newer one appears.
///  * **lastCheckedAt / offlineCheckDays / offlineNoticeShown** — when the check
///    last ran, and the continuous-offline rule (days 1-7 silent, day 8 one
///    toast per streak).
///
/// **"Later" is not stored.** Deferring an offer lasts only until the next app
/// launch ([updateDeferredProvider]), so the dot returns on its own.
library;

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../shared/providers/shared_preferences_provider.dart';
import 'update_release.dart';

/// Preference key: how often the app checks for updates, in days (0 = off).
const String updateFrequencyDaysKey = 'update_frequency_days';

/// Preference key: the network an update may be downloaded over.
const String updateNetworkKey = 'update_network';

/// Preference key: epoch-ms of the last launch-period update check.
const String updateLastCheckedAtKey = 'update_last_checked_at';

/// Preference key: consecutive calendar days the launch check has been skipped
/// because there was no internet.
const String updateOfflineCheckDaysKey = 'update_offline_check_days';

/// Preference key: whether the day-8 "connect to check" toast has been shown in
/// the current offline streak.
const String updateOfflineNoticeShownKey = 'update_offline_notice_shown';

/// Preference key: the release the last check found, as JSON.
const String updateAvailableReleaseKey = 'update_available_release';

/// Preference key: a release the user chose to skip.
const String updateSkippedVersionKey = 'update_skipped_version';

/// Default Auto Check frequency: once a day (mirrors the backup default).
const int defaultUpdateFrequencyDays = 1;

/// How an update may be downloaded.
enum UpdateNetwork {
  /// Wi-Fi only — the default, and the platform norm for updates.
  wifi,

  /// Wi-Fi or mobile data.
  mobileData;

  /// Reads a stored value, falling back to the default for anything unknown.
  static UpdateNetwork fromKey(String? key) =>
      key == UpdateNetwork.mobileData.name
      ? UpdateNetwork.mobileData
      : UpdateNetwork.wifi;
}

/// Default network: Wi-Fi only, so a large APK is never pulled over cellular
/// without the user asking.
const UpdateNetwork defaultUpdateNetwork = UpdateNetwork.wifi;

/// What the updater remembers between launches.
class UpdateMetadata {
  /// Auto-check interval in days; 0 means "Off".
  final int frequencyDays;

  /// Whether an update may be downloaded over mobile data.
  final UpdateNetwork network;

  /// Epoch-ms of the last launch-period check, or null when never checked.
  final int? lastCheckedAt;

  /// Consecutive calendar days the launch check has been skipped (offline).
  final int offlineCheckDays;

  /// Whether the offline toast has been shown in the current streak.
  final bool offlineNoticeShown;

  /// The release the last check found, or null when nothing newer exists.
  final AppRelease? availableRelease;

  /// A release the user skipped, or null.
  final String? skippedVersion;

  /// Creates a snapshot.
  const UpdateMetadata({
    this.frequencyDays = defaultUpdateFrequencyDays,
    this.network = defaultUpdateNetwork,
    this.lastCheckedAt,
    this.offlineCheckDays = 0,
    this.offlineNoticeShown = false,
    this.availableRelease,
    this.skippedVersion,
  });

  /// A copy with the given fields replaced.
  ///
  /// Written out rather than copied with a helper so every field is visible at
  /// the point a new one is added.
  UpdateMetadata copyWith({
    int? frequencyDays,
    UpdateNetwork? network,
    int? lastCheckedAt,
    int? offlineCheckDays,
    bool? offlineNoticeShown,
    AppRelease? availableRelease,
    bool clearAvailableRelease = false,
    String? skippedVersion,
    bool clearSkippedVersion = false,
  }) => UpdateMetadata(
    frequencyDays: frequencyDays ?? this.frequencyDays,
    network: network ?? this.network,
    lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
    offlineCheckDays: offlineCheckDays ?? this.offlineCheckDays,
    offlineNoticeShown: offlineNoticeShown ?? this.offlineNoticeShown,
    availableRelease: clearAvailableRelease
        ? null
        : (availableRelease ?? this.availableRelease),
    skippedVersion: clearSkippedVersion
        ? null
        : (skippedVersion ?? this.skippedVersion),
  );
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
      network: UpdateNetwork.fromKey(_prefs.getString(updateNetworkKey)),
      lastCheckedAt: _prefs.getInt(updateLastCheckedAtKey),
      offlineCheckDays: _prefs.getInt(updateOfflineCheckDaysKey) ?? 0,
      offlineNoticeShown: _prefs.getBool(updateOfflineNoticeShownKey) ?? false,
      availableRelease: _readAvailableRelease(),
      skippedVersion: _prefs.getString(updateSkippedVersionKey),
    );
  }

  AppRelease? _readAvailableRelease() {
    final raw = _prefs.getString(updateAvailableReleaseKey);
    if (raw == null) return null;
    try {
      return AppRelease.fromJson(jsonDecode(raw));
    } on FormatException {
      return null;
    }
  }

  /// Stores the chosen Auto Check interval (0 = off).
  Future<void> setFrequencyDays(int days) async {
    if (days == state.frequencyDays) return;
    await _prefs.setInt(updateFrequencyDaysKey, days);
    state = state.copyWith(frequencyDays: days);
  }

  /// Stores the chosen download network.
  Future<void> setNetwork(UpdateNetwork network) async {
    if (network == state.network) return;
    await _prefs.setString(updateNetworkKey, network.name);
    state = state.copyWith(network: network);
  }

  /// Records that a check ran at [atEpochMs], and what it found.
  ///
  /// [offline] means the check could not run at all: the streak grows and the
  /// stored offer is left alone, because nothing was learned. An online check
  /// either stores the newer [release] or clears the offer outright — which is
  /// what stops the dot surviving the update that satisfied it.
  Future<void> recordCheck({
    required int atEpochMs,
    required bool offline,
    AppRelease? release,
  }) async {
    final streak = offline ? state.offlineCheckDays + 1 : 0;
    final noticeShown = offline ? state.offlineNoticeShown : false;
    await _prefs.setInt(updateLastCheckedAtKey, atEpochMs);
    await _prefs.setInt(updateOfflineCheckDaysKey, streak);
    await _prefs.setBool(updateOfflineNoticeShownKey, noticeShown);

    if (offline) {
      state = state.copyWith(
        lastCheckedAt: atEpochMs,
        offlineCheckDays: streak,
        offlineNoticeShown: noticeShown,
      );
      return;
    }

    if (release == null) {
      await _prefs.remove(updateAvailableReleaseKey);
    } else {
      await _prefs.setString(
        updateAvailableReleaseKey,
        jsonEncode(release.toJson()),
      );
    }
    state = state.copyWith(
      lastCheckedAt: atEpochMs,
      offlineCheckDays: streak,
      offlineNoticeShown: noticeShown,
      availableRelease: release,
      clearAvailableRelease: release == null,
    );
  }

  /// Marks the day-8 toast as shown for the current streak.
  Future<void> markOfflineNoticeShown() async {
    await _prefs.setBool(updateOfflineNoticeShownKey, true);
    state = state.copyWith(offlineNoticeShown: true);
  }

  /// Stops offering [version] until a newer release appears.
  Future<void> skipVersion(String version) async {
    await _prefs.setString(updateSkippedVersionKey, version);
    state = state.copyWith(skippedVersion: version);
  }

  /// Drops the stored offer.
  ///
  /// Called once an update has been handed to the installer: there is nothing
  /// left to tell the user about, and a dot that outlived the update it pointed
  /// at is exactly the unclearable badge this is meant to avoid.
  Future<void> clearAvailableRelease() async {
    await _prefs.remove(updateAvailableReleaseKey);
    state = state.copyWith(clearAvailableRelease: true);
  }
}

/// Riverpod provider for [UpdateMetadataNotifier].
final updateMetadataProvider =
    NotifierProvider<UpdateMetadataNotifier, UpdateMetadata>(
      UpdateMetadataNotifier.new,
    );

/// Whether the user deferred the offered update with **Later**.
///
/// Deliberately **not persisted**: "later" means "not this session", so the
/// indicator returns by itself on the next launch.
class UpdateDeferral extends Notifier<bool> {
  @override
  bool build() => false;

  /// Hides the offered update until the app is next launched.
  void defer() => state = true;
}

/// Riverpod provider for [UpdateDeferral].
final updateDeferredProvider = NotifierProvider<UpdateDeferral, bool>(
  UpdateDeferral.new,
);

/// The update to tell the user about, or null when there is nothing to say.
///
/// This is what the **dots** read — on the About row and the Update row — so
/// every reason not to nag lives here: nothing found, a release the app already
/// has, one the user skipped, or one they deferred with Later.
final updateAvailableProvider = Provider<AppRelease?>((ref) {
  final metadata = ref.watch(updateMetadataProvider);
  if (!shouldOfferRelease(
    release: metadata.availableRelease,
    skippedVersion: metadata.skippedVersion,
  )) {
    return null;
  }
  if (ref.watch(updateDeferredProvider)) return null;
  return metadata.availableRelease;
});
