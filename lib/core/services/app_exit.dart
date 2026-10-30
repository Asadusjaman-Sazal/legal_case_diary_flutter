/// Closing the app for real, which one Dart call can no longer do (Task 06,
/// Exit App? window).
///
/// `SystemNavigator.pop()` used to finish the Android activity. On this Flutter
/// it does not: the engine's `PlatformPlugin.popSystemNavigator()` dispatches an
/// Android **back press** (`OnBackPressedDispatcher.onBackPressed()`) whenever the
/// host activity is a `ComponentActivity` — and `FlutterFragmentActivity`, which
/// App Lock's fingerprint needs, always is. A back press at the root of the
/// app's task does not finish it; the app stays in memory and is resumed where it
/// left off, which is what "Exit App? behaves like the home button" means.
///
/// So the host does it: `MainActivity.kt` answers `closeApp` by finishing the
/// task and removing it from recents. `SystemNavigator.pop()` stays as the
/// fallback for a host without that hook (tests, Windows), so the button is
/// never dead.
library;

import 'package:flutter/services.dart';

/// Channel served by `MainActivity.kt` for the one platform action Dart lacks.
const MethodChannel _appExitChannel = MethodChannel(
  'com.legumsoft.legalcasediary/app_exit',
);

/// Closes the app: finishes the task on Android, pops the widget elsewhere.
Future<void> closeApp() async {
  try {
    await _appExitChannel.invokeMethod<void>('closeApp');
  } on MissingPluginException {
    // No host hook (tests, Windows desktop): the framework's own pop is the
    // closest thing there is, and the caller has already confirmed the exit.
    await SystemNavigator.pop();
  } on PlatformException {
    // A hook that refused: still better than a button that does nothing.
    await SystemNavigator.pop();
  }
}
