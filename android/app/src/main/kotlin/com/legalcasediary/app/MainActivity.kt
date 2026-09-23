package com.legalcasediary.app

import android.content.Context
import android.os.PowerManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts the single Android query the Battery & Auto-Start Setup guide needs.
 *
 * `PowerManager.isIgnoringBatteryOptimizations` is the OS's own answer to the
 * guide's battery step, and no plugin in the app exposes it. The channel is
 * host-only: the background alarm isolate never asks this question, and the
 * Dart side ([AndroidNotificationGateway.batteryOptimizationIgnored]) treats a
 * missing channel as "not done" rather than as a failure.
 */
class MainActivity : FlutterActivity() {
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
    }

    /** True when this app is exempt from battery optimization ("Unrestricted"). */
    private fun isIgnoringBatteryOptimizations(): Boolean {
        val power = getSystemService(Context.POWER_SERVICE) as? PowerManager
            ?: return false
        return power.isIgnoringBatteryOptimizations(packageName)
    }

    private companion object {
        const val CHANNEL = "com.legalcasediary.app/device_setup"
    }
}
