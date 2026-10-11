/// Checks GitHub for a newer release, and downloads it with progress.
///
/// The About screen's App Update section drives this, and the daily auto-check
/// calls [checkForLatestRelease] once per launch. It talks only to the public
/// GitHub API — no auth token, no Supabase, no other network — so it is a
/// straight `dart:io` `HttpClient` with no new dependency (`http` is only a
/// transitive package here).
///
/// **Why not `http`:** the release API is plain GET/JSON and the download is a
/// binary stream with a known `Content-Length`; `HttpClient` does both with the
/// stdlib, and [downloadRelease] needs the byte stream + length that `http`'s
/// higher-level `Response` would buffer anyway. `ponytail:` stdlib HTTP until a
/// second endpoint, an upload, or a timeout need a real client.
library;

import 'dart:convert';
import 'dart:io';

import 'update_release.dart';

/// The GitHub owner and repository that publish this app's releases.
const String updateRepositoryOwner = 'Asadusjaman-Sazal';
const String updateRepositoryName = 'legal_case_diary_flutter';

/// The API host, fixed so a test cannot reach an arbitrary host.
const String updateApiHost = 'api.github.com';

/// What one release check decided.
enum ReleaseCheckResult {
  /// A release newer than the installed version exists and can be downloaded.
  updateAvailable,

  /// The latest release is this app's own version (or older).
  upToDate,

  /// The API could not be reached (offline, DNS, HTTP error). Nothing decided.
  unavailable,
}

/// Answers [checkForLatestRelease]: the verdict and, when a newer release was
/// found, what it is.
class UpdateCheckOutcome {
  const UpdateCheckOutcome(this.result, {this.release, this.error});

  final ReleaseCheckResult result;

  /// The newer release when [result] is [ReleaseCheckResult.updateAvailable].
  final AppRelease? release;

  /// A human-readable reason when the check could not answer.
  final String? error;

  bool get isUpdate => result == ReleaseCheckResult.updateAvailable;
}

/// A single downloaded byte chunk's worth of progress.
///
/// [received] counts bytes so far, [total] is what [downloadRelease] reported
/// the response's `Content-Length` to be (-1 when the server gave none).
typedef DownloadProgress = ({int received, int total});

/// The GitHub release client for this app.
class UpdateRepository {
  /// Creates a client; pass an [HttpClient] to control redirects/timeouts in
  /// tests, otherwise a fresh one is used.
  UpdateRepository({HttpClient? client}) : _client = client ?? HttpClient();

  final HttpClient _client;

  String get _releasesApi =>
      'https://$updateApiHost/repos/$updateRepositoryOwner/'
      '$updateRepositoryName/releases/latest';

  /// Fetches the latest release and decides whether it is newer than the app.
  Future<UpdateCheckOutcome> checkForLatestRelease() async {
    try {
      final request = await _client.getUrl(Uri.parse(_releasesApi));
      request.headers.set('Accept', 'application/vnd.github+json');
      request.headers.set('User-Agent', 'legal-case-diary');
      final response = await request.close();

      if (response.statusCode != HttpStatus.ok) {
        return UpdateCheckOutcome(
          ReleaseCheckResult.unavailable,
          error: 'GitHub responded ${response.statusCode}',
        );
      }

      final body = await response.transform(utf8.decoder).join();
      final release = _releaseFromJson(body);
      if (release == null) {
        return const UpdateCheckOutcome(
          ReleaseCheckResult.unavailable,
          error: 'Release format not understood',
        );
      }

      return UpdateCheckOutcome(
        isReleaseNewerThanApp(release.version)
            ? ReleaseCheckResult.updateAvailable
            : ReleaseCheckResult.upToDate,
        release: isReleaseNewerThanApp(release.version) ? release : null,
      );
    } on Exception catch (e) {
      return UpdateCheckOutcome(
        ReleaseCheckResult.unavailable,
        error: e.toString(),
      );
    }
  }

  /// Downloads the [release]'s APK asset into [bytes], reporting [onProgress].
  ///
  /// Invokes [onProgress] with the running [received] count and the response's
  /// `Content-Length` as [total] (-1 when none). Throws on a non-200, so a
  /// caller can detect truncation by comparing [received] against the asset's
  /// stated [AppRelease.size].
  Future<DownloadProgress> downloadRelease(
    AppRelease release,
    List<int> bytes, {
    void Function(int received, int total)? onProgress,
  }) async {
    final request = await _client.getUrl(Uri.parse(release.downloadUrl));
    request.headers.set('User-Agent', 'legal-case-diary');
    final response = await request.close();

    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'Download failed: HTTP ${response.statusCode}',
        uri: request.uri,
      );
    }

    final total = response.contentLength;
    var received = bytes.length;
    await for (final chunk in response) {
      bytes.addAll(chunk);
      received += chunk.length;
      onProgress?.call(received, total);
    }
    return (received: received, total: total);
  }

  /// Extracts the release's tag version + first APK asset from the GitHub JSON.
  AppRelease? _releaseFromJson(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, dynamic>) return null;
      final tag = decoded['tag_name'];
      if (tag is! String) return null;
      final version = tag.startsWith('v') ? tag.substring(1) : tag;

      // The asset list is a `[{name, browser_download_url, size}, …]`.
      final assets = decoded['assets'];
      if (assets is! List || assets.isEmpty) return null;
      final asset = assets.first;
      if (asset is! Map<String, dynamic>) return null;
      final url = asset['browser_download_url'];
      final size = asset['size'];
      return AppRelease(
        version: version,
        downloadUrl: url is String ? url : '',
        size: size is int ? size : null,
      );
    } on FormatException {
      return null;
    }
  }
}