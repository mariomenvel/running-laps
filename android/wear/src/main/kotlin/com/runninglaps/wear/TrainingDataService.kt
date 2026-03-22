package com.runninglaps.wear

import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.WearableListenerService
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Receives DataLayer updates from the phone (path: /training/metrics).
 * Parsed values are pushed into [metricsFlow] so MainActivity can observe
 * them without holding a direct reference to this Service.
 */
class TrainingDataService : WearableListenerService() {

    override fun onDataChanged(dataEvents: DataEventBuffer) {
        dataEvents.use { buffer ->
            buffer.forEach { event ->
                if (event.dataItem.uri.path == METRICS_PATH) {
                    val dataMap = DataMapItem.fromDataItem(event.dataItem).dataMap
                    _metricsFlow.value = TrainingMetrics(
                        distanceM    = dataMap.getInt("distance_m", 0),
                        pace         = dataMap.getString("pace", "--:-- /km") ?: "--:-- /km",
                        serieNumber  = dataMap.getInt("serie_number", 1),
                        elapsedSec   = dataMap.getInt("elapsed_sec", 0),
                        status       = dataMap.getString("status", "idle") ?: "idle",
                    )
                }
            }
        }
    }

    companion object {
        const val METRICS_PATH = "/training/metrics"
        const val COMMAND_PATH = "/training/command"

        private val _metricsFlow = MutableStateFlow(TrainingMetrics())

        /** Observed by MainActivity to update the Wear UI. */
        val metricsFlow: StateFlow<TrainingMetrics> = _metricsFlow.asStateFlow()
    }
}

/** Immutable snapshot of the current training metrics sent by the phone. */
data class TrainingMetrics(
    val distanceM: Int    = 0,
    val pace: String      = "--:-- /km",
    val serieNumber: Int  = 1,
    val elapsedSec: Int   = 0,
    val status: String    = "idle",
)
