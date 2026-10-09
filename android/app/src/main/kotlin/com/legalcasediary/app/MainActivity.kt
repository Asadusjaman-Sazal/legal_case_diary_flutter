package com.legalcasediary.app

import android.content.Context
import android.os.Environment
import android.os.PowerManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts the two things the Android side must do for Dart.
 *
 * `PowerManager.isIgnoringBatteryOptimizations` is the OS's own answer to the
 * Battery & Auto-Start Setup guide's battery step, no plugin in the app exposes
 * it, and no Dart code can finish the app's task on this Flutter (`closeApp`
 * below). Each action sits on its own channel, so the two concerns stay
 * independent. The channels are host-only: the background alarm isolate never
 * asks these questions, and the Dart side
 * ([AndroidNotificationGateway.batteryOptimizationIgnored]) treats a missing
 * channel as "not done" rather than as a failure.
 */
// FlutterFragmentActivity, not FlutterActivity: local_auth's BiometricPrompt
// needs a FragmentActivity host, and its theme must be an AppCompat theme
// (see styles.xml) or older devices crash on launch.
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isIgnoringBatteryOptimizations" ->
                        result.success(isIgnoringBatteryOptimizations())
                    else -> result.notImplemented()
                }
            }
        configureAppExitChannel(flutterEngine)
        configurePublicDownloadsChannel(flutterEngine)
    }

    /**
     * Answers the device's public Downloads directory for the backup folder.
     *
     * path_provider's Android paths are all app-scoped (`Android/data/<pkg>`),
     * invisible to a file manager — exactly the folder the user found backups
     * in and did not want. The public `/storage/emulated/0/Download` is
     * `Environment.getExternalStoragePublicDirectory(DIRECTORY_DOWNLOADS)`:
     * deprecated since API 29 but still returns the real shared Downloads
     * folder, which apps can write to directly (their own files) under scoped
     * storage without any permission. A missing channel is answered by the
     * Dart side as "no public folder" and it falls back to private storage.
     */
    private fun configurePublicDownloadsChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DOWNLOADS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "path" -> result.success(
                        Environment.getExternalStoragePublicDirectory(
                            Environment.DIRECTORY_DOWNLOADS
                        ).absolutePath
                    )
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Closes the app for the Exit App? window, served to Dart on its own channel.
     *
     * Dart cannot close the task itself on this Flutter: the engine turns
     * `SystemNavigator.pop()` into an Android back press
     * (`PlatformPlugin.popSystemNavigator` calls
     * `OnBackPressedDispatcher.onBackPressed()` whenever the host is a
     * `ComponentActivity`, and `FlutterFragmentActivity` — which App Lock's
     * fingerprint needs — always is). A back press at the root of a task leaves
     * the app alive in memory, so Exit behaved like the home button.
     *
     * `finishAndRemoveTask()` is the real close: the task is finished *and*
     * dropped from recents, so relaunching starts the app fresh. The reply is
     * sent first so the Dart call completes before the engine goes with it.
     */
    private fun configureAppExitChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, EXIT_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "closeApp" -> {
                        result.success(null)
                        finishAndRemoveTask()
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /** True when this app is exempt from battery optimization ("Unrestricted"). */
    private fun isIgnoringBatteryOptimizations(): Boolean {
        val power = getSystemService(Context.POWER_SERVICE) as? PowerManager
            ?: return false
        return power.isIgnoringBatteryOptimizations(packageName)
    }

    private companion object {
        const val CHANNEL = "com.legalcasediary.app/device_setup"

        /// The Exit App? channel (`lib/core/services/app_exit.dart`).
        const val EXIT_CHANNEL = "com.legalcasediary.app/app_exit"

        /// The public Downloads channel (`backupDocumentsDirectory`).
        const val DOWNLOADS_CHANNEL = "com.legalcasediary.app/public_downloads"
    }
}
