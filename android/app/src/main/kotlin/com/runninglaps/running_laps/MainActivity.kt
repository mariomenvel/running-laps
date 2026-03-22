package com.runninglaps.running_laps

import android.content.Context
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import com.google.android.gms.tasks.Tasks
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.Wearable
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class MainActivity : FlutterActivity() {

    private val ioScope = CoroutineScope(Dispatchers.IO)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Register ButtonLaunchReceiver exactly once for the lifetime of the
        // process. Using applicationContext means the receiver stays alive even
        // when this Activity is paused or destroyed, so notification button taps
        // while the screen is locked still work.
        if (!receiverRegistered) {
            receiverRegistered = true
            val filter = IntentFilter("onNotificationButtonPressed")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                // API 33+: must declare exported/not-exported explicitly.
                // RECEIVER_NOT_EXPORTED is correct here because the sender
                // (flutter_foreground_task) is within the same package.
                applicationContext.registerReceiver(
                    ButtonLaunchReceiver(),
                    filter,
                    Context.RECEIVER_NOT_EXPORTED,
                )
            } else {
                applicationContext.registerReceiver(ButtonLaunchReceiver(), filter)
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // ── Wear → Flutter: command events received from the watch ────────────
        // Flutter listens on this channel to react to watch button presses.
        // Commands mirror the existing notificationAction values ("end_serie",
        // "finish_run", "pause", "resume") so no new Dart logic is needed.
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, WEAR_COMMANDS_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink) {
                    wearCommandSink = sink
                    // Flush any command that arrived while the Activity was paused
                    WearListenerService.pendingCommand?.let { cmd ->
                        sink.success(cmd)
                        WearListenerService.pendingCommand = null
                    }
                }

                override fun onCancel(arguments: Any?) {
                    wearCommandSink = null
                }
            })

        // ── Flutter → Wear: push live training metrics to the watch ───────────
        // Called from Dart with: MethodChannel("wear/metrics").invokeMethod(
        //   "sendMetrics", {"distance_m": 1200, "pace": "5:30 /km", ...})
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, WEAR_METRICS_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "sendMetrics" -> {
                        @Suppress("UNCHECKED_CAST")
                        val args = call.arguments as? Map<String, Any>
                        if (args != null) {
                            ioScope.launch { pushMetricsToWatch(args) }
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onDestroy() {
        wearCommandSink = null
        super.onDestroy()
    }

    // ── Data Layer: phone → watch ─────────────────────────────────────────────

    private fun pushMetricsToWatch(metrics: Map<String, Any>) {
        try {
            val request = PutDataMapRequest.create(WearListenerService.METRICS_PATH).apply {
                dataMap.putInt("distance_m",   (metrics["distance_m"]   as? Int)    ?: 0)
                dataMap.putString("pace",       (metrics["pace"]         as? String) ?: "--:-- /km")
                dataMap.putInt("serie_number", (metrics["serie_number"] as? Int)    ?: 1)
                dataMap.putInt("elapsed_sec",  (metrics["elapsed_sec"]  as? Int)    ?: 0)
                dataMap.putString("status",     (metrics["status"]       as? String) ?: "idle")
                // Bump timestamp so identical payloads still trigger onDataChanged
                dataMap.putLong("ts", System.currentTimeMillis())
            }
            Tasks.await(
                Wearable.getDataClient(applicationContext)
                    .putDataItem(request.asPutDataRequest().setUrgent())
            )
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    companion object {
        // Ensures only one ButtonLaunchReceiver is registered per process.
        private var receiverRegistered = false

        /**
         * EventSink shared with [WearListenerService] (same process).
         * Non-null only while Flutter is actively listening on [WEAR_COMMANDS_CHANNEL].
         */
        @Volatile
        var wearCommandSink: EventChannel.EventSink? = null

        const val WEAR_COMMANDS_CHANNEL = "wear/commands"
        const val WEAR_METRICS_CHANNEL  = "wear/metrics"
    }
}
