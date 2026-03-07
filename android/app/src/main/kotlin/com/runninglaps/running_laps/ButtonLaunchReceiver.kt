package com.runninglaps.running_laps

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Brings the app to the foreground when a flutter_foreground_task notification
 * action button is tapped.
 *
 * flutter_foreground_task fires `"onNotificationButtonPressed"` broadcasts via
 * a BroadcastReceiver that is internal to the foreground service. That receiver
 * handles the Dart callback chain; this one handles the UI side: it starts
 * MainActivity so the user is brought back to the running screen immediately.
 *
 * Registered dynamically from [MainActivity] using the application context so
 * it survives Activity lifecycle events. The foreground service (started by
 * flutter_foreground_task) keeps the process alive during a training session,
 * which also satisfies the Android 10+ foreground-service exemption that allows
 * startActivity() calls from a BroadcastReceiver.
 */
class ButtonLaunchReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != "onNotificationButtonPressed") return

        context.startActivity(
            Intent(context, MainActivity::class.java).apply {
                // FLAG_ACTIVITY_NEW_TASK is required when starting from a
                // non-Activity context (BroadcastReceiver).
                // FLAG_ACTIVITY_SINGLE_TOP matches MainActivity's launchMode so no
                // duplicate instance is created if it is already at the top.
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
            }
        )
    }
}
