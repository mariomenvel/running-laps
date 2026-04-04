package com.runninglaps.wear

import android.app.Notification
import android.util.Log
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.media.RingtoneManager
import android.os.Binder
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import com.google.android.gms.location.FusedLocationProviderClient
import com.google.android.gms.location.LocationCallback
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationResult
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.Priority
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.cancel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import kotlin.math.asin
import kotlin.math.cos
import kotlin.math.sin
import kotlin.math.sqrt
import kotlin.random.Random

data class SeriesSnapshot(
    val totalElapsedSec: Long,
    val totalDistanceM: Float,
    val serieCount: Int,
    val avgHeartRate: Int,
    val seriesData: List<SerieData>,
    val avgRpe: Float,
)

data class SerieData(
    val distanceM: Float,
    val elapsedSec: Long,
    val paceSecPerKm: Long,
    val rpe: Float = 5.0f,
    val usedGps: Boolean = true,
)

class SeriesTrainingService : Service(), SensorEventListener {

    // ── Companion: shared StateFlows collected by the UI ──────────────────────

    companion object {
        /** Set to false before shipping to production. */
        const val DEBUG_SIMULATE = true

        private val _phase = MutableStateFlow("running")
        val phase: StateFlow<String> = _phase

        private val _serieNumber = MutableStateFlow(1)
        val serieNumber: StateFlow<Int> = _serieNumber

        private val _serieElapsedSec = MutableStateFlow(0L)
        val serieElapsedSec: StateFlow<Long> = _serieElapsedSec

        private val _serieDistanceM = MutableStateFlow(0f)
        val serieDistanceM: StateFlow<Float> = _serieDistanceM

        private val _totalDistanceM = MutableStateFlow(0f)
        val totalDistanceM: StateFlow<Float> = _totalDistanceM

        private val _totalElapsedSec = MutableStateFlow(0L)
        val totalElapsedSec: StateFlow<Long> = _totalElapsedSec

        private val _restRemainingMs = MutableStateFlow(0L)
        val restRemainingMs: StateFlow<Long> = _restRemainingMs

        private val _heartRate = MutableStateFlow(0)
        val heartRate: StateFlow<Int> = _heartRate

        private val _avgHeartRate = MutableStateFlow(0)
        val avgHeartRate: StateFlow<Int> = _avgHeartRate

        private val _gpsFix = MutableStateFlow(false)
        val gpsFix: StateFlow<Boolean> = _gpsFix

        private val _alarmPulse = MutableStateFlow(false)
        val alarmPulse: StateFlow<Boolean> = _alarmPulse

        private val _avgPaceSecPerKm = MutableStateFlow(0L)
        val avgPaceSecPerKm: StateFlow<Long> = _avgPaceSecPerKm

        private val _pendingDistanceChoice = MutableStateFlow(false)
        val pendingDistanceChoice: StateFlow<Boolean> = _pendingDistanceChoice

        private val _pendingSerieRpe = MutableStateFlow(false)
        val pendingSerieRpe: StateFlow<Boolean> = _pendingSerieRpe

        private val _lastSnapshot = MutableStateFlow<SeriesSnapshot?>(null)
        val lastSnapshot: StateFlow<SeriesSnapshot?> = _lastSnapshot

        private val _templateFinished = MutableStateFlow(false)
        val templateFinished: StateFlow<Boolean> = _templateFinished

        var instance: SeriesTrainingService? = null
        var pendingTemplate: WearTemplate? = null

        fun reset() {
            _phase.value = "running"
            _serieNumber.value = 1
            _serieElapsedSec.value = 0L
            _serieDistanceM.value = 0f
            _totalDistanceM.value = 0f
            _totalElapsedSec.value = 0L
            _restRemainingMs.value = 0L
            _heartRate.value = 0
            _avgHeartRate.value = 0
            _gpsFix.value = false
            _alarmPulse.value = false
            _avgPaceSecPerKm.value = 0L
            _pendingDistanceChoice.value = false
            _pendingSerieRpe.value = false
            _lastSnapshot.value = null
            _templateFinished.value = false
        }

        fun parseDistancia(s: String): Int {
            return when {
                s.endsWith("km") -> (s.dropLast(2).toFloatOrNull() ?: 0f).times(1000).toInt()
                s.endsWith("m") -> s.dropLast(1).toIntOrNull() ?: 0
                else -> 0
            }
        }

        fun parseDescanso(s: String): Int {
            return if (s.contains(":")) {
                val parts = s.split(":")
                (parts[0].toIntOrNull() ?: 0) * 60 + (parts[1].toIntOrNull() ?: 0)
            } else {
                s.dropLast(1).toIntOrNull() ?: 0
            }
        }
    }

    // ── Instance fields ───────────────────────────────────────────────────────

    private lateinit var fusedLocationClient: FusedLocationProviderClient
    private lateinit var locationCallback: LocationCallback

    private var sensorManager: SensorManager? = null
    private var heartRateSensor: Sensor? = null

    private val alarmHandler = Handler(Looper.getMainLooper())
    private var alarmRunnable: Runnable? = null

    private val scope = CoroutineScope(Dispatchers.Default)
    private var timerJob: Job? = null
    private var restJob: Job? = null

    private var fcEnabled = false
    private var gpsEnabled = false
    private var alarmEnabled = false
    private var alarmIntervalMs = 0L
    private var descansoSec = 60
    private var distanciaConfigM = 400

    private var templateBlocks: List<WearTemplateBlock> = emptyList()
    private var currentBlockIndex: Int = 0

    private var lastLat: Double? = null
    private var lastLon: Double? = null
    private var lastLocationTime: Long = 0L

    private val heartRateSamples = mutableListOf<Int>()
    private val completedSeries = mutableListOf<SerieData>()

    // Pending data for the serie awaiting distance/RPE confirmation
    private var pendingDistanceM: Float = 0f
    private var pendingElapsedSec: Long = 0L
    private var pendingPaceSecPerKm: Long = 0L
    private var pendingUsedGps: Boolean = true

    private val notifManager by lazy {
        getSystemService(NotificationManager::class.java)
    }

    // ── Lifecycle ─────────────────────────────────────────────────────────────

    override fun onCreate() {
        super.onCreate()
        instance = this
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val distanciaStr = intent?.getStringExtra("distanciaStr") ?: "400m"
        val descansoStr = intent?.getStringExtra("descansoStr") ?: "1:00"
        gpsEnabled = intent?.getBooleanExtra("gpsEnabled", false) ?: false
        fcEnabled = intent?.getBooleanExtra("fcEnabled", false) ?: false
        alarmEnabled = intent?.getBooleanExtra("alarmEnabled", false) ?: false
        alarmIntervalMs = intent?.getLongExtra("alarmIntervalMs", 0L) ?: 0L
        distanciaConfigM = parseDistancia(distanciaStr)
        descansoSec = parseDescanso(descansoStr)

        reset()

        val template = pendingTemplate
        pendingTemplate = null
        if (template != null) loadTemplate(template)

        startForeground(2, buildNotification())

        if (DEBUG_SIMULATE) {
            startDebugSimulation()
        } else {
            startLocationUpdates()
            if (fcEnabled) startHeartRate()
        }
        startTimer()
        if (alarmEnabled && alarmIntervalMs > 0) scheduleAlarm()

        return START_NOT_STICKY
    }

    inner class LocalBinder : Binder() {
        fun getService(): SeriesTrainingService = this@SeriesTrainingService
    }

    override fun onBind(intent: Intent?): IBinder = LocalBinder()

    // ── Public binder methods ─────────────────────────────────────────────────

    fun endSerie() {
        if (_phase.value == "running" && !_pendingDistanceChoice.value && !_pendingSerieRpe.value) {
            // Capture serie data — do NOT reset counters yet (display values shown in overlay)
            val pace = if (_serieDistanceM.value > 10f && _serieElapsedSec.value > 0L) {
                (_serieElapsedSec.value * 1000f / _serieDistanceM.value).toLong()
            } else 0L
            pendingDistanceM = _serieDistanceM.value
            pendingElapsedSec = _serieElapsedSec.value
            pendingPaceSecPerKm = pace
            pendingUsedGps = gpsEnabled

            // Reset GPS anchor so real-time accumulation stops
            lastLat = null
            lastLon = null
            cancelAlarm()

            if (gpsEnabled) {
                _pendingDistanceChoice.value = true
            } else {
                _pendingSerieRpe.value = true
            }
        } else if (_phase.value == "rest") {
            // Skip rest — start next serie immediately
            restJob?.cancel()
            _restRemainingMs.value = 0L
            _serieNumber.value++
            _phase.value = "running"
            if (alarmEnabled && alarmIntervalMs > 0) scheduleAlarm()
        }
        updateNotification()
    }

    fun confirmDistance(useGps: Boolean) {
        if (!_pendingDistanceChoice.value) return
        if (!useGps) {
            // Correct totalDistanceM: swap GPS-measured for configured manual distance
            _totalDistanceM.value = (_totalDistanceM.value - pendingDistanceM + distanciaConfigM.toFloat())
                .coerceAtLeast(0f)
            pendingDistanceM = distanciaConfigM.toFloat()
        }
        pendingUsedGps = useGps
        _pendingDistanceChoice.value = false
        _pendingSerieRpe.value = true
        updateNotification()
    }

    fun confirmRpe(rpe: Float) {
        if (!_pendingSerieRpe.value) return

        // Discard serie if it has no meaningful data
        if (pendingDistanceM <= 0f && pendingElapsedSec <= 2L) {
            Log.d("RunningLaps", "Serie discarded — zero distance and negligible time")
            _serieElapsedSec.value = 0L
            _serieDistanceM.value = 0f
            _avgPaceSecPerKm.value = 0L
            _pendingSerieRpe.value = false
            if (descansoSec > 0) {
                _phase.value = "rest"
                _restRemainingMs.value = descansoSec * 1000L
                startRestCountdown()
            } else {
                _serieNumber.value++
                _phase.value = "running"
                if (alarmEnabled && alarmIntervalMs > 0) scheduleAlarm()
            }
            updateNotification()
            return
        }

        completedSeries.add(
            SerieData(
                distanceM = pendingDistanceM,
                elapsedSec = pendingElapsedSec,
                paceSecPerKm = pendingPaceSecPerKm,
                rpe = rpe,
                usedGps = pendingUsedGps,
            )
        )

        // Reset serie-level counters now that data is committed
        _serieElapsedSec.value = 0L
        _serieDistanceM.value = 0f
        _avgPaceSecPerKm.value = 0L
        _pendingSerieRpe.value = false

        // Advance template block if a template is active
        if (templateBlocks.isNotEmpty()) {
            currentBlockIndex++
            if (currentBlockIndex < templateBlocks.size) {
                applyBlock(templateBlocks[currentBlockIndex])
            } else {
                _templateFinished.value = true
                updateNotification()
                return  // skip rest countdown — UI will call onStop()
            }
        }

        if (descansoSec > 0) {
            _phase.value = "rest"
            _restRemainingMs.value = descansoSec * 1000L
            startRestCountdown()
        } else {
            _serieNumber.value++
            _phase.value = "running"
            if (alarmEnabled && alarmIntervalMs > 0) scheduleAlarm()
        }
        updateNotification()
    }

    fun updateNextSerie(distStr: String, descStr: String) {
        distanciaConfigM = parseDistancia(distStr)
        descansoSec = parseDescanso(descStr)
        updateNotification()
    }

    fun loadTemplate(template: WearTemplate) {
        templateBlocks = template.blocks
        currentBlockIndex = 0
        _templateFinished.value = false
        if (templateBlocks.isNotEmpty()) applyBlock(templateBlocks[0])
    }

    private fun applyBlock(block: WearTemplateBlock) {
        if (block.type == "distance") distanciaConfigM = block.value
        descansoSec = block.restSeconds
        alarmEnabled = block.alerts.enabled
        alarmIntervalMs = if (block.alerts.enabled) computeAlarmIntervalMs(block.alerts) else 0L
    }

    private fun computeAlarmIntervalMs(alerts: WearTemplateAlerts): Long {
        return if (alerts.mode == "pace") {
            val paceSecPerKm = alerts.paceMin * 60L + alerts.paceSec
            paceSecPerKm * alerts.segmentDistance
        } else {
            ((alerts.timeMin * 60.0 + alerts.timeSec) * 1000.0).toLong()
        }
    }

    fun captureSnapshot() {
        val avgRpe = if (completedSeries.isEmpty()) 5.0f
                     else completedSeries.map { it.rpe }.average().toFloat()
        _lastSnapshot.value = SeriesSnapshot(
            totalElapsedSec = _totalElapsedSec.value,
            totalDistanceM = _totalDistanceM.value,
            serieCount = completedSeries.size,
            avgHeartRate = if (heartRateSamples.isEmpty()) 0
                           else heartRateSamples.average().toInt(),
            seriesData = completedSeries.toList(),
            avgRpe = avgRpe,
        )
    }

    override fun onDestroy() {
        instance = null
        stopLocationUpdates()
        stopHeartRate()
        cancelAlarm()
        restJob?.cancel()
        scope.cancel()
        super.onDestroy()
    }

    // ── Timers ────────────────────────────────────────────────────────────────

    private fun startTimer() {
        timerJob = scope.launch {
            while (true) {
                delay(1000L)
                _totalElapsedSec.value++
                // Only tick serie timer when running and no pending confirmation
                if (_phase.value == "running" && !_pendingDistanceChoice.value && !_pendingSerieRpe.value) {
                    _serieElapsedSec.value++
                    updatePace()
                }
                updateNotification()
            }
        }
    }

    private fun startRestCountdown() {
        restJob?.cancel()
        restJob = scope.launch {
            while (_restRemainingMs.value > 0L) {
                delay(100L)
                val next = _restRemainingMs.value - 100L
                _restRemainingMs.value = if (next < 0L) 0L else next
            }
            if (_phase.value == "rest") {
                _serieNumber.value++
                _phase.value = "running"
                if (alarmEnabled && alarmIntervalMs > 0) scheduleAlarm()
                updateNotification()
            }
        }
    }

    private fun updatePace() {
        val dist = _serieDistanceM.value
        val elapsed = _serieElapsedSec.value
        _avgPaceSecPerKm.value = if (dist > 10f && elapsed > 0L) {
            (elapsed * 1000f / dist).toLong()
        } else {
            0L
        }
    }

    // ── Heart rate helpers ────────────────────────────────────────────────────

    private fun recordHeartRate(bpm: Int) {
        _heartRate.value = bpm
        heartRateSamples.add(bpm)
        _avgHeartRate.value = heartRateSamples.average().toInt()
    }

    // ── Debug simulation ──────────────────────────────────────────────────────

    private fun startDebugSimulation() {
        _gpsFix.value = true

        scope.launch {
            while (true) {
                delay(2000L)
                if (_phase.value == "running" && !_pendingDistanceChoice.value && !_pendingSerieRpe.value) {
                    val delta = Random.nextFloat() * 4f + 8f
                    _serieDistanceM.value += delta
                    _totalDistanceM.value += delta
                    updatePace()
                }
            }
        }

        if (fcEnabled) {
            scope.launch {
                while (true) {
                    delay(3000L)
                    recordHeartRate(Random.nextInt(145, 176))
                }
            }
        }
    }

    // ── GPS ───────────────────────────────────────────────────────────────────

    private fun startLocationUpdates() {
        val request = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 2000L)
            .setMinUpdateIntervalMillis(1000L)
            .build()

        locationCallback = object : LocationCallback() {
            override fun onLocationResult(result: LocationResult) {
                val loc = result.lastLocation ?: return
                handleLocation(loc.latitude, loc.longitude, loc.accuracy, loc.speed)
            }
        }

        try {
            fusedLocationClient.requestLocationUpdates(
                request,
                locationCallback,
                Looper.getMainLooper(),
            )
        } catch (_: SecurityException) {}
    }

    private fun stopLocationUpdates() {
        if (::locationCallback.isInitialized) {
            fusedLocationClient.removeLocationUpdates(locationCallback)
        }
    }

    private fun handleLocation(lat: Double, lon: Double, accuracy: Float, speed: Float) {
        if (_phase.value != "running" || _pendingDistanceChoice.value || _pendingSerieRpe.value) return
        if (accuracy > 30f) return
        if (speed < 0.1f || speed > 10f) return

        val now = System.currentTimeMillis()
        val prevLat = lastLat
        val prevLon = lastLon

        if (prevLat == null || prevLon == null) {
            lastLat = lat
            lastLon = lon
            lastLocationTime = now
            _gpsFix.value = true
            return
        }

        val dt = (now - lastLocationTime) / 1000f
        if (dt <= 0f) return

        val dist = haversine(prevLat, prevLon, lat, lon)
        val maxDist = speed * dt * 1.5f
        if (dist > maxDist && dist > 5f) return

        _serieDistanceM.value += dist
        _totalDistanceM.value += dist
        lastLat = lat
        lastLon = lon
        lastLocationTime = now
        updatePace()
    }

    private fun haversine(lat1: Double, lon1: Double, lat2: Double, lon2: Double): Float {
        val r = 6371000.0
        val dLat = Math.toRadians(lat2 - lat1)
        val dLon = Math.toRadians(lon2 - lon1)
        val a = sin(dLat / 2) * sin(dLat / 2) +
            cos(Math.toRadians(lat1)) * cos(Math.toRadians(lat2)) *
            sin(dLon / 2) * sin(dLon / 2)
        return (r * 2 * asin(sqrt(a))).toFloat()
    }

    // ── Heart rate ────────────────────────────────────────────────────────────

    private fun startHeartRate() {
        sensorManager = getSystemService(SensorManager::class.java)
        heartRateSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_HEART_RATE)
        heartRateSensor?.let {
            sensorManager?.registerListener(this, it, SensorManager.SENSOR_DELAY_NORMAL)
        }
    }

    private fun stopHeartRate() {
        sensorManager?.unregisterListener(this)
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (event?.sensor?.type == Sensor.TYPE_HEART_RATE) {
            val bpm = event.values.firstOrNull()?.toInt() ?: return
            if (bpm > 0) recordHeartRate(bpm)
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    // ── Alarm ─────────────────────────────────────────────────────────────────

    private fun scheduleAlarm() {
        alarmRunnable = object : Runnable {
            override fun run() {
                triggerAlarm()
                alarmHandler.postDelayed(this, alarmIntervalMs)
            }
        }
        alarmHandler.postDelayed(alarmRunnable!!, alarmIntervalMs)
    }

    private fun cancelAlarm() {
        alarmRunnable?.let { alarmHandler.removeCallbacks(it) }
        alarmRunnable = null
    }

    private fun triggerAlarm() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val vm = getSystemService(VibratorManager::class.java)
            vm?.defaultVibrator?.vibrate(
                VibrationEffect.createOneShot(300L, VibrationEffect.DEFAULT_AMPLITUDE),
            )
        } else {
            @Suppress("DEPRECATION")
            val vibrator = getSystemService(Vibrator::class.java)
            vibrator?.vibrate(
                VibrationEffect.createOneShot(300L, VibrationEffect.DEFAULT_AMPLITUDE),
            )
        }

        try {
            val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            RingtoneManager.getRingtone(applicationContext, uri)?.play()
        } catch (_: Exception) {}

        scope.launch {
            _alarmPulse.value = true
            delay(500L)
            _alarmPulse.value = false
        }
    }

    // ── Foreground notification ───────────────────────────────────────────────

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            "series_training",
            "Entrenamiento por series",
            NotificationManager.IMPORTANCE_LOW,
        )
        notifManager.createNotificationChannel(channel)
    }

    private fun buildNotification(): Notification {
        val text = when {
            _pendingDistanceChoice.value -> "Elige distancia · Serie ${_serieNumber.value}"
            _pendingSerieRpe.value -> "RPE Serie ${_serieNumber.value}..."
            _phase.value == "rest" -> "Descanso · ${_restRemainingMs.value / 1000}s"
            else -> {
                val distStr = if (_serieDistanceM.value >= 1000f)
                    "${"%.2f".format(_serieDistanceM.value / 1000f)} km"
                else
                    "${_serieDistanceM.value.toInt()} m"
                val timeStr = "%02d:%02d".format(_serieElapsedSec.value / 60, _serieElapsedSec.value % 60)
                "Serie ${_serieNumber.value} · $distStr · $timeStr"
            }
        }
        return Notification.Builder(this, "series_training")
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentTitle("Running Laps · Series")
            .setContentText(text)
            .setOngoing(true)
            .build()
    }

    private fun updateNotification() {
        notifManager.notify(2, buildNotification())
    }
}
