package com.runninglaps.running_laps

import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.WearableListenerService

/**
 * Receives command messages sent from the Wear OS companion app.
 *
 * When the watch taps "Fin de Serie" or "Parar", it calls
 * WearMessageService.sendCommand() which delivers a message here.
 * The command is then forwarded to Flutter via [MainActivity.wearCommandSink]
 * (EventChannel "wear/commands").
 *
 * If MainActivity is not active (sink is null), the command is held in
 * [pendingCommand] and delivered as soon as the EventSink is registered
 * (i.e. the next time MainActivity.configureFlutterEngine runs onListen).
 *
 * Supported commands:
 *   "end_serie"   → mirrors notification button "end_serie"
 *   "finish_run"  → mirrors notification button "finish_run"
 *   "pause"       → pause GPS / stopwatch
 *   "resume"      → resume GPS / stopwatch
 */
class WearListenerService : WearableListenerService() {

    override fun onMessageReceived(event: MessageEvent) {
        if (event.path != COMMAND_PATH) return

        val command = String(event.data, Charsets.UTF_8)

        val sink = MainActivity.wearCommandSink
        if (sink != null) {
            // MainActivity is active — deliver immediately to Flutter
            sink.success(command)
        } else {
            // Queue for delivery when MainActivity (re)activates
            pendingCommand = command
        }
    }

    companion object {
        const val COMMAND_PATH  = "/training/command"
        const val METRICS_PATH  = "/training/metrics"

        /** Holds a command received while MainActivity was not active. */
        @Volatile
        var pendingCommand: String? = null
    }
}
