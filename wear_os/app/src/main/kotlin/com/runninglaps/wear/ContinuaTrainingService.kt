package com.runninglaps.wear

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Intent
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.media.RingtoneManager
import android.os.Build
import android.os.Handler
import android.os.Binder
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

data class TrainingSnapshot(
    val elapsedSeconds: Long,
    val distanceMeters: Float,
    val avgPaceSecPerKm: Long,
    val avgHeartRate: Int,
)

class ContinuaTrainingService : Service(), SensorEventListener {

    // ── Companion: shared StateFlows collected by the UI ──────────────────────

    companion object {
        /** Set to false before shipping to production. */
        const val DEBUG_SIMULATE = true

        private val _distanceMeters = MutableStateFlow(0f)
        val distanceMeters: StateFlow<Float> = _distanceMeters

        private val _elapsedSeconds = MutableStateFlow(0L)
        val elapsedSeconds: StateFlow<Long> = _elapsedSeconds

        private val _avgPaceSecPerKm = MutableStateFlow(0L)
        val avgPaceSecPerKm: StateFlow<Long> = _avgPaceSecPerKm

        private val _heartRate = MutableStateFlow(0)
        val heartRate: StateFlow<Int> = _heartRate

        private val _avgHeartRate = MutableStateFlow(0)
        val avgHeartRate: StateFlow<Int> = _avgHeartRate

        private val _isRunning = MutableStateFlow(false)
        val isRunning: StateFlow<Boolean> = _isRunning

        private val _gpsFix = MutableStateFlow(false)
        val gpsFix: StateFlow<Boolean> = _gpsFix

        private val _alarmPulse = MutableStateFlow(false)
        val alarmPulse: StateFlow<Boolean> = _alarmPulse

        private val _lastSnapshot = MutableStateFlow<TrainingSnapshot?>(null)
        val lastSnapshot: StateFlow<TrainingSnapshot?> = _lastSnapshot

        fun reset() {
            _distanceMeters.value = 0f
            _elapsedSeconds.value = 0L
            _avgPaceSecPerKm.value = 0L
            _heartRate.value = 0
            _avgHeartRate.value = 0
            _isRunning.value = false
            _gpsFix.value = false
            _alarmPulse.value = false
            _lastSnapshot.value = null
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

    private var fcEnabled = false
    private var alarmEnabled = false
    private var alarmIntervalMs = 0L

    private var lastLat: Double? = null
    private var lastLon: Double? = null
    private var lastLocationTime: Long = 0L

    private val heartRateSamples = mutableListOf<Int>()

    private val notifManager by lazy {
        getSystemService(NotificationManager::class.java)
    }

    // ── Lifecycle ─────────────────────────────────────────────────────────────

    override fun onCreate() {
        super.onCreate()
        fusedLocationClient = LocationServices.getFusedLocationProviderClient(this)
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        fcEnabled = intent?.getBooleanExtra("fcEnabled", false) ?: false
        alarmEnabled = intent?.getBooleanExtra("alarmEnabled", false) ?: false
        alarmIntervalMs = intent?.getLongExtra("alarmIntervalMs", 0L) ?: 0L

        reset()
        _isRunning.value = true

        startForeground(1, buildNotification())
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
        fun getService(): ContinuaTrainingService = this@ContinuaTrainingService
    }

    override fun onBind(intent: Intent?): IBinder = LocalBinder()

    fun captureSnapshot() {
        _lastSnapshot.value = TrainingSnapshot(
            elapsedSeconds = _elapsedSeconds.value,
            distanceMeters = _distanceMeters.value,
            avgPaceSecPerKm = _avgPaceSecPerKm.value,
            avgHeartRate = if (heartRateSamples.isEmpty()) 0
                          else heartRateSamples.average().toInt(),
        )
    }

    override fun onDestroy() {
        _isRunning.value = false
        stopLocationUpdates()
        stopHeartRate()
        cancelAlarm()
        scope.cancel()
        super.onDestroy()
    }

    // ── Timer ─────────────────────────────────────────────────────────────────

    private fun startTimer() {
        timerJob = scope.launch {
            while (true) {
                delay(1000L)
                _elapsedSeconds.value++
                updatePace()
                updateNotification()
            }
        }
    }

    private fun updatePace() {
        val dist = _distanceMeters.value
        val elapsed = _elapsedSeconds.value
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

        // Simulate GPS distance: +8–12 m every 2 s (~10 m/s ≈ 6:00 /km)
        scope.launch {
            while (true) {
                delay(2000L)
                _distanceMeters.value += Random.nextFloat() * 4f + 8f // 8–12 m
                updatePace()
            }
        }

        // Simulate heart rate: 145–175 bpm every 3 s (only when fcEnabled)
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
        } catch (_: SecurityException) {
            // Location permission not granted — service continues without GPS
        }
    }

    private fun stopLocationUpdates() {
        if (::locationCallback.isInitialized) {
            fusedLocationClient.removeLocationUpdates(locationCallback)
        }
    }

    private fun handleLocation(lat: Double, lon: Double, accuracy: Float, speed: Float) {
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

        _distanceMeters.value += dist
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
        // Vibrate
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

        // Sound
        try {
            val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            RingtoneManager.getRingtone(applicationContext, uri)?.play()
        } catch (_: Exception) {}

        // Pulse StateFlow — true for 500 ms, then false
        scope.launch {
            _alarmPulse.value = true
            delay(500L)
            _alarmPulse.value = false
        }
    }

    // ── Foreground notification ───────────────────────────────────────────────

    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            "continua_training",
            "Carrera continua",
            NotificationManager.IMPORTANCE_LOW,
        )
        notifManager.createNotificationChannel(channel)
    }

    private fun buildNotification(): Notification {
        val distStr = formatDistance(_distanceMeters.value)
        val elapsedStr = formatElapsed(_elapsedSeconds.value)
        val paceStr = formatPace(_avgPaceSecPerKm.value)

        return Notification.Builder(this, "continua_training")
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentTitle("Running Laps · En carrera")
            .setContentText("$distStr  ·  $elapsedStr  ·  $paceStr")
            .setOngoing(true)
            .build()
    }

    private fun updateNotification() {
        notifManager.notify(1, buildNotification())
    }

    // ── Formatters ────────────────────────────────────────────────────────────

    private fun formatDistance(meters: Float): String =
        if (meters >= 1000f) "${"%.2f".format(meters / 1000f)} km"
        else "${meters.toInt()} m"

    private fun formatElapsed(seconds: Long): String {
        val h = seconds / 3600
        val m = (seconds % 3600) / 60
        val s = seconds % 60
        return if (h > 0) "%d:%02d:%02d".format(h, m, s)
        else "%02d:%02d".format(m, s)
    }

    private fun formatPace(secPerKm: Long): String {
        if (secPerKm == 0L) return "--:--"
        val m = secPerKm / 60
        val s = secPerKm % 60
        return "%d:%02d /km".format(m, s)
    }
}
