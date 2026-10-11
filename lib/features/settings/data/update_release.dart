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
}

/// True when [releaseVersion] is a newer release than the installed app.
bool isReleaseNewerThanApp(String releaseVersion) =>
    compareReleaseVersions(releaseVersion, appVersion) > 0;

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