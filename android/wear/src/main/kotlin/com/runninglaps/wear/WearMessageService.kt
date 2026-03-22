package com.runninglaps.wear

import android.content.Context
import com.google.android.gms.tasks.Tasks
import com.google.android.gms.wearable.Wearable
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext

/**
 * Sends command messages to the paired phone via the Wearable Message API.
 *
 * Commands are sent to [TrainingDataService.COMMAND_PATH] and received on
 * the phone by WearListenerService, which forwards them to Flutter.
 *
 * Usage:
 *   lifecycleScope.launch { WearMessageService.sendCommand(context, "end_serie") }
 *
 * Supported commands (must match phone WearListenerService):
 *   "end_serie"   — finish current interval serie
 *   "finish_run"  — stop the entire training session
 *   "pause"       — pause GPS tracking
 *   "resume"      — resume GPS tracking
 */
object WearMessageService {

    suspend fun sendCommand(context: Context, command: String) =
        withContext(Dispatchers.IO) {
            try {
                val nodes = Tasks.await(
                    Wearable.getNodeClient(context).connectedNodes
                )
                nodes.forEach { node ->
                    Tasks.await(
                        Wearable.getMessageClient(context).sendMessage(
                            node.id,
                            TrainingDataService.COMMAND_PATH,
                            command.toByteArray(Charsets.UTF_8),
                        )
                    )
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
}
