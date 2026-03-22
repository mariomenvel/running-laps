package com.runninglaps.wear

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.lifecycle.lifecycleScope
import com.runninglaps.wear.databinding.ActivityMainBinding
import kotlinx.coroutines.launch

/**
 * Main Wear OS activity.
 *
 * Displays live training metrics received from the phone via the Wearable
 * Data Layer (pushed into [TrainingDataService.metricsFlow]).
 *
 * Two buttons send commands back to the phone via [WearMessageService]:
 *   • "Fin de Serie" → "end_serie"
 *   • "Parar"        → "finish_run"
 */
class MainActivity : ComponentActivity() {

    private lateinit var binding: ActivityMainBinding

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        observeMetrics()
        setupButtons()
    }

    // ── Metrics observer ─────────────────────────────────────────────────────

    private fun observeMetrics() {
        lifecycleScope.launch {
            TrainingDataService.metricsFlow.collect { metrics ->
                binding.tvSerie.text    = getString(R.string.label_serie_n, metrics.serieNumber)
                binding.tvElapsed.text  = formatElapsed(metrics.elapsedSec)
                binding.tvDistance.text = formatDistance(metrics.distanceM)
                binding.tvPace.text     = metrics.pace
            }
        }
    }

    // ── Button handlers ──────────────────────────────────────────────────────

    private fun setupButtons() {
        binding.btnEndSerie.setOnClickListener {
            lifecycleScope.launch {
                WearMessageService.sendCommand(applicationContext, "end_serie")
            }
        }

        binding.btnStop.setOnClickListener {
            lifecycleScope.launch {
                WearMessageService.sendCommand(applicationContext, "finish_run")
            }
        }
    }

    // ── Formatters ───────────────────────────────────────────────────────────

    private fun formatElapsed(sec: Int): String {
        val m = sec / 60
        val s = sec % 60
        return "%02d:%02d".format(m, s)
    }

    private fun formatDistance(meters: Int): String =
        if (meters < 1000) "${meters}m"
        else "${"%.2f".format(meters / 1000.0)}km"
}
