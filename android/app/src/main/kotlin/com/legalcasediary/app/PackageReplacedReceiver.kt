package com.legalcasediary.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import dev.fluttercommunity.plus.androidalarmmanager.AlarmService

/**
 * Re-arms the daily hearing alert after the app is updated (Task 13 Phase 2).
 *
 * `android_alarm_manager_plus` ships a receiver for BOOT_COMPLETED only, and
 * the plan requires the app-update case too, so this receiver hands the job to
 * the plugin's own public rescheduling entry point. Alarms persisted with
 * `rescheduleOnReboot` are recreated from that stored state; nothing here needs
 * the Flutter engine to be running.
 */
class PackageReplacedReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (Intent.ACTION_MY_PACKAGE_REPLACED == intent.action) {
            AlarmService.reschedulePersistentAlarms(context.applicationContext)
        }
    }
}
