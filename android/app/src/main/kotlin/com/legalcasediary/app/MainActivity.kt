package com.legalcasediary.app

import android.content.Context
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.PowerManager
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest

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
        configureAppInstallChannel(flutterEngine)
    }

    /**
     * Installs a downloaded APK by handing it to Android's package installer
     * through a FileProvider `content:` URI (the App Update section).
     *
     * Android refuses an APK another app wrote unless the caller is told apart
     * from the installer: an app needs REQUEST_INSTALL_PACKAGES and must pass
     * the file by content URI, not a raw path — a raw path is refused outright
     * from API 24. The FileProvider for the app's cache dir is declared in the
     * manifest; its authority is `<applicationId>.apkprovider`.
     *
     * The Dart side treats the install as fire-and-forget: Android shows its
     * own "install this app?" confirmation, and the installer, not this
     * channel, decides whether the install succeeds.
     */
    private fun configureAppInstallChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, INSTALL_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "install" -> {
                        val path = call.arguments as? String
                        if (path == null) {
                            result.error("bad_args", "APK path missing", null)
                            return@setMethodCallHandler
                        }
                        val file = File(path)
                        if (!file.exists() || file.length() == 0L) {
                            result.error(
                                "missing_apk",
                                "Downloaded APK not found: $path",
                                null
                            )
                            return@setMethodCallHandler
                        }
                        // Authenticity first, and in this same call, so the file
                        // cannot change between the check and the handoff.
                        if (!apkSignatureMatchesInstalledApp(file)) {
                            result.error(
                                "unverified_signature",
                                "Downloaded APK is not signed by this app's key: $path",
                                null
                            )
                            return@setMethodCallHandler
                        }
                        val uri: Uri = FileProvider.getUriForFile(
                            this,
                            "$packageName.apkprovider",
                            file
                        )
                        val intent = Intent(Intent.ACTION_VIEW).apply {
                            setDataAndType(uri, "application/vnd.android.package-archive")
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        // Grant the URI to every activity that can handle the
                        // intent, not just to the intent itself.
                        //
                        // FLAG_GRANT_READ_URI_PERMISSION is enough when Android
                        // starts one target, but this intent has several (the
                        // system installer and, on many devices, others), so
                        // Android shows a chooser — and **the chooser does not
                        // forward the grant to whichever app the user picks**.
                        // The installer then received a `content://` URI it had
                        // no permission to open, could not read the APK, and
                        // did nothing at all: the reported "selecting Package
                        // Installer does nothing". Granting per resolver is the
                        // documented way to make a chooser's result readable.
                        //
                        // The `<queries>` entry in the manifest is what makes
                        // this list non-empty on Android 11+, where package
                        // visibility hides anything not declared.
                        packageManager
                            .queryIntentActivities(intent, 0)
                            .forEach { resolved ->
                                grantUriPermission(
                                    resolved.activityInfo.packageName,
                                    uri,
                                    Intent.FLAG_GRANT_READ_URI_PERMISSION
                                )
                            }
                        startActivity(intent)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /**
     * Whether the downloaded APK is signed like this app.
     *
     * Direct distribution means no store stands between a release and somebody's
     * diary, so this is what tells a release of ours from anything else: the
     * archive's signing certificate is read and compared with the certificate of
     * the app already installed. Nothing is pinned by hand — the anchor is the
     * running app's own signature, which is the identity Android itself would
     * enforce at install — so an APK signed with another key is refused here,
     * before the installer is ever offered the file, rather than after a prompt a
     * user could be talked past.
     *
     * An unreadable archive, or either side carrying no certificate, returns
     * false as well: an unverifiable update is refused exactly like a foreign one.
     */
    private fun apkSignatureMatchesInstalledApp(apk: File): Boolean {
        val archive = runCatching {
            signerCertificateSha256(
                packageManager.getPackageArchiveInfo(apk.absolutePath, signingFlags)
            )
        }.getOrNull() ?: return false
        val installed = runCatching {
            signerCertificateSha256(packageManager.getPackageInfo(packageName, signingFlags))
        }.getOrNull() ?: return false
        return archive.contentEquals(installed)
    }

    /// The flag asking for a package's signing certificate on this API level.
    ///
    /// `GET_SIGNATURES` is the pre-28 spelling and returns the same certificate
    /// bytes; minSdk is 24, so both spellings are reachable at runtime.
    @Suppress("DEPRECATION")
    private val signingFlags: Int
        get() = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            PackageManager.GET_SIGNING_CERTIFICATES
        } else {
            PackageManager.GET_SIGNATURES
        }

    /// SHA-256 of the first signing certificate [info] carries, or null.
    @Suppress("DEPRECATION")
    private fun signerCertificateSha256(info: PackageInfo?): ByteArray? {
        // Not typed `Signature?`: the `?: return null` below is what makes the
        // receiver non-null for the hash, and re-declaring it nullable undoes it.
        val signer = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info?.signingInfo?.apkContentsSigners?.firstOrNull()
        } else {
            info?.signatures?.firstOrNull()
        } ?: return null
        return MessageDigest.getInstance("SHA-256").digest(signer.toByteArray())
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

        /// The in-app update install channel (`lib/features/settings/presentation/app_install.dart`).
        const val INSTALL_CHANNEL = "com.legalcasediary.app/app_install"
    }
}
