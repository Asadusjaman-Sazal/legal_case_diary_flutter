/// How to compare the release versions the app shows, and what a release is.
///
/// Plain Dart on purpose — no Flutter, no network:
/// `test/core/update_release_test.dart` drives it without an emulator.
///
/// Releases are tagged `v<semver>` (e.g. `v0.0.479`); the installed version is
/// [appVersion] without the `v`. Semver here is the three-dot numeric string the
/// project actually ships (`0.0.479`) — not the full semver spec, deliberately:
/// this repo has never used prerelease tags (`0.0.479-beta`) and a full parser
/// would only grow a surface nothing exercises (`ponytail:` partial semver; go
/// full if prerelease tags ever ship).
library;

import '../../../core/constants/app_version.dart';

/// One GitHub release: both tag versions and what the APK downloader needs.
class AppRelease {
  /// Creates a release.
  const AppRelease({required this.version, required this.downloadUrl, this.size});

  /// The release's own semver without the leading `v`, e.g. `0.0.479`.
  final String version;

  /// The APK asset's browser download URL.
  final String downloadUrl;

  /// The asset's `Content-Length` in bytes, when the API reported it.
  final int? size;

  /// The [version] rendered with the app's usual leading `V` prefix.
  String get displayName => 'V$version';

  /// This release as a plain map, for the small preference cache that lets the
  /// About screen offer an update the launch check has already found — so the
  /// offer survives a restart and needs no second lookup.
  Map<String, Object?> toJson() => <String, Object?>{
    'version': version,
    'url': downloadUrl,
    'size': size,
  };

  /// Reads back what [toJson] wrote; null when the shape is not a release.
  ///
  /// Deliberately strict: a half-written or hand-edited cache yields null
  /// (no offer) rather than a release with an empty download URL, which would
  /// only fail later at the point of download.
  static AppRelease? fromJson(Object? json) {
    if (json is! Map) return null;
    final version = json['version'];
    final url = json['url'];
    if (version is! String ||
        url is! String ||
        version.isEmpty ||
        url.isEmpty) {
      return null;
    }
    final size = json['size'];
    return AppRelease(
      version: version,
      downloadUrl: url,
      size: size is int ? size : null,
    );
  }
}

/// True when [releaseVersion] is a newer release than the installed app.
bool isReleaseNewerThanApp(String releaseVersion) =>
    compareReleaseVersions(releaseVersion, appVersion) > 0;

/// Whether [release] is an update worth offering, given what the user skipped.
///
/// False for nothing at all, for a release this build already has (the stored
/// offer outlives the check that found it, and the app may have caught up since),
/// and for one the user chose to **skip** — a skipped version stops counting as
/// an update until a newer one appears.
///
/// This is the one place those rules live, so the dot on a row, the button on
/// the Update screen and the manual check can never disagree about whether there
/// is something to say. The session deferral ("Later") is deliberately *not*
/// here: it silences the dots, not the screen.
bool shouldOfferRelease({
  required AppRelease? release,
  String? skippedVersion,
}) {
  if (release == null) return false;
  if (!isReleaseNewerThanApp(release.version)) return false;
  return release.version != skippedVersion;
}

/// Compares two dotted numeric version strings.
///
/// Every dotted segment is parsed as an integer and compared in order — so
/// `0.0.9` < `0.0.479` and `0.0.479` == `0.0.479`. A leading `v`/`V` is
/// stripped, so callers can pass the raw release tag or the display string.
/// Anything that is not three dotted numbers is treated as **older** than
/// anything well-formed, so a junk tag can never claim to be a newer release.
int compareReleaseVersions(String a, String b) {
  final pa = _parse(a);
  final pb = _parse(b);
  for (var i = 0; i < pa.length; i++) {
    if (pa[i] != pb[i]) return pa[i] < pb[i] ? -1 : 1;
  }
  return 0;
}

/// Parses `v0.0.479` (or `0.0.479`) into `[0, 0, 479]`; malformed → `[0,0,0]`.
List<int> _parse(String v) {
  final clean = v.trim().toLowerCase();
  final s = clean.startsWith('v') ? clean.substring(1) : clean;
  final parts = s.split('.');
  if (parts.length != 3) return const <int>[0, 0, 0];
  final nums = <int>[];
  for (final part in parts) {
    final n = int.tryParse(part);
    if (n == null || n < 0) return const <int>[0, 0, 0];
    nums.add(n);
  }
  return nums;
}