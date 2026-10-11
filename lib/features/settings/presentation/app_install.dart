/// Hands a downloaded APK to Android's installer (the App Update section).
///
/// Android refuses to install a file a second app wrote without (a) the
/// `REQUEST_INSTALL_PACKAGES` permission and (b) a [FileProvider] that hands
/// the installer a `content:` URI instead of a raw path. This file's host hook
/// (in `MainActivity.kt`) does exactly that — it resolves the cached file
/// through the FileProvider and fires `ACTION_INSTALL_PACKAGE`. On anything
/// without the hook (tests, desktop) the call is a no-op, so a tap never
/// throws: the update section treats "installed" as success and the OS shows
/// its own confirmation.
library;

import 'package:flutter/services.dart';

/// Channel served by `MainActivity.kt` for installing a downloaded APK.
const MethodChannel _installChannel = MethodChannel(
  'com.legalcasediary.app/app_install',
);

/// Installs the APK at [absolutePath] via Android's package installer.
///
/// Returns false when the host has no install hook (unsupported platform); the
/// caller reports that honestly rather than pretending it installed.
Future<bool> installDownloadedApk(String absolutePath) async {
  try {
    await _installChannel.invokeMethod<void>('install', absolutePath);
    return true;
  } on MissingPluginException {
    return false;
  } on PlatformException {
    return false;
  }
}