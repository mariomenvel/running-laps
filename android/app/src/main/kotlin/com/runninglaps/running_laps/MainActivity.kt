package com.runninglaps.running_laps

import android.content.Context
import android.content.IntentFilter
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

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

    companion object {
        // Ensures only one ButtonLaunchReceiver is registered per process.
        private var receiverRegistered = false
    }
}
