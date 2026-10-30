/// Hands a downloaded APK to Android's installer (the App Update section).
///
/// Android refuses to install a file a second app wrote without (a) the
/// `REQUEST_INSTALL_PACKAGES` permission and (b) a [FileProvider] that hands
/// the installer a `content:` URI instead of a raw path. This file's host hook
/// (in `MainActivity.kt`) does exactly that — it resolves the cached file
/// through the FileProvider and fires `ACTION_VIEW`. On anything without the
/// hook (tests, desktop) the call is a no-op, so a tap never throws.
///
/// **The host also refuses an update it cannot authenticate** (firm-mode §5.6,
/// direct distribution): the APK must be signed like this app, or nothing at
/// all is dispatched. That refusal gets an answer of its own — telling a user
/// whose release failed its authenticity check that "this device cannot install
/// an update" would be simply untrue.
library;

import 'package:flutter/services.dart';

/// Channel served by `MainActivity.kt` for installing a downloaded APK.
///
/// Public so a test can answer it: the refusal below is a fact about the host,
/// and the only way to exercise it without a device is to speak on this channel.
const MethodChannel appInstallChannel = MethodChannel(
  'com.legumsoft.legalcasediary/app_install',
);

/// The host's error code for *this APK is not signed like this app*.
const String apkUnverifiedSignatureCode = 'unverified_signature';

/// What a handoff to Android's installer ended in.
enum ApkInstallOutcome {
  /// The installer was given the file; it shows its own confirmation, and
  /// whether the install succeeds is Android's decision, not ours.
  handedOff,

  /// No install hook on this platform (tests, desktop), or the host failed for
  /// a reason of its own: nothing was dispatched.
  unsupported,

  /// The APK failed the host's authenticity check — it is not signed like this
  /// app, or its signature could not be read — so nothing was dispatched.
  unverified,
}

/// Installs the APK at [absolutePath] via Android's package installer.
///
/// Never throws: every platform answer, including a refusal, is one of the
/// [ApkInstallOutcome] cases, so a caller cannot mistake a refusal for a
/// successful handoff.
Future<ApkInstallOutcome> installDownloadedApk(String absolutePath) async {
  try {
    await appInstallChannel.invokeMethod<void>('install', absolutePath);
    return ApkInstallOutcome.handedOff;
  } on MissingPluginException {
    return ApkInstallOutcome.unsupported;
  } on PlatformException catch (e) {
    return e.code == apkUnverifiedSignatureCode
        ? ApkInstallOutcome.unverified
        : ApkInstallOutcome.unsupported;
  }
}
