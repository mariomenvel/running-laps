package com.runninglaps.wear

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.Bundle
import android.os.IBinder
import android.util.Log
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import androidx.wear.compose.navigation.SwipeDismissableNavHost
import androidx.wear.compose.navigation.composable
import androidx.wear.compose.navigation.rememberSwipeDismissableNavController
import com.google.firebase.appcheck.FirebaseAppCheck
import com.google.firebase.appcheck.debug.DebugAppCheckProviderFactory
import com.google.firebase.appcheck.playintegrity.PlayIntegrityAppCheckProviderFactory
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FieldValue
import com.google.firebase.firestore.FirebaseFirestore
import com.runninglaps.wear.theme.ThemePreference
import com.runninglaps.wear.theme.WearAppTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        ThemePreference.init(this)

        val firebaseAppCheck = FirebaseAppCheck.getInstance()
        if (BuildConfig.DEBUG) {
            firebaseAppCheck.installAppCheckProviderFactory(
                DebugAppCheckProviderFactory.getInstance()
            )
        } else {
            firebaseAppCheck.installAppCheckProviderFactory(
                PlayIntegrityAppCheckProviderFactory.getInstance()
            )
        }

        setContent {
            WearApp()
        }
    }
}

@Composable
fun WearApp() {
    // TEMP: bypass QR auth for testing — restore AuthScreen check before release
    val context = LocalContext.current
    val testUid = "KtgNewIEWQYFIq5nm2tx9RDK31h1" // TODO: remove before production
    remember {
        context.getSharedPreferences("wear_prefs", Context.MODE_PRIVATE)
            .edit().putString("uid", testUid).apply()
    }

    val themeMode by ThemePreference.themeMode.collectAsState()
    val darkTheme = when (themeMode) {
        ThemePreference.DARK -> true
        ThemePreference.LIGHT -> false
        else -> isSystemInDarkTheme()
    }

    WearAppTheme(darkTheme = darkTheme) {
        AppNavHost()
    }
}

@Composable
fun AppNavHost() {
    val navController = rememberSwipeDismissableNavController()
    val context = LocalContext.current

    // Hoisted state shared across continua_config and alarm_config screens
    var fcEnabled by remember { mutableStateOf(false) }
    var alarmEnabled by remember { mutableStateOf(false) }
    var alarmMode by remember { mutableStateOf("time") }
    var alarmIntervalMs by remember { mutableStateOf<Long?>(null) }

    // Series config state
    var seriesDistancia by remember { mutableStateOf("400m") }
    var seriesDescanso by remember { mutableStateOf("1:00") }
    var seriesGpsEnabled by remember { mutableStateOf(true) }
    var seriesFcEnabled by remember { mutableStateOf(false) }
    var activeTemplate by remember { mutableStateOf<WearTemplate?>(null) }

    // State captured at stop time, passed to rpe_picker → tag_selector → continua_summary
    var trainingSnapshot by remember { mutableStateOf<TrainingSnapshot?>(null) }
    var savedRpe by remember { mutableStateOf(5.0f) }
    var savedTrainingId by remember { mutableStateOf<String?>(null) }

    SwipeDismissableNavHost(
        navController = navController,
        startDestination = "home",
    ) {
        composable("home") {
            HomeScreen(
                onStartContinua = { navController.navigate("continua_config") },
                onOpenSeries = { navController.navigate("series_page") },
            )
        }
        composable("series_page") {
            SeriesPage(
                initialTemplate = activeTemplate,
                onOpenAlarmConfig = { navController.navigate("alarm_config") },
                onOpenTemplates = {
                    activeTemplate = null
                    SeriesTrainingService.pendingTemplate = null
                    navController.navigate("template_picker")
                },
                onStartSeries = { dist, desc, gps, fc, alarm ->
                    Log.d("RunningLaps", "onStartSeries called — navigating to series_config")
                    seriesDistancia = dist
                    seriesDescanso = desc
                    seriesGpsEnabled = gps
                    seriesFcEnabled = fc
                    alarmEnabled = alarm
                    activeTemplate = null
                    navController.navigate("series_config")
                },
            )
        }
        composable("continua_config") {
            ContinuaConfigScreen(
                onBack = { navController.popBackStack() },
                onOpenAlarmConfig = { navController.navigate("alarm_config") },
                onStartTraining = {
                    val intent = Intent(context, ContinuaTrainingService::class.java).apply {
                        putExtra("fcEnabled", fcEnabled)
                        putExtra("alarmEnabled", alarmEnabled)
                        putExtra("alarmIntervalMs", alarmIntervalMs ?: 0L)
                    }
                    context.startForegroundService(intent)
                    navController.navigate("continua_active")
                },
                fcEnabled = fcEnabled,
                onFcToggle = { fcEnabled = it },
                alarmEnabled = alarmEnabled,
                onAlarmToggle = { alarmEnabled = it },
            )
        }
        composable("alarm_config") {
            AlarmConfigScreen(
                onBack = { navController.popBackStack() },
                onSave = { mode, intervalMs ->
                    alarmMode = mode
                    alarmIntervalMs = intervalMs
                    navController.popBackStack()
                },
            )
        }
        composable("series_config") {
            LaunchedEffect(Unit) {
                val intent = Intent(context, SeriesTrainingService::class.java).apply {
                    putExtra("distanciaStr", seriesDistancia)
                    putExtra("descansoStr", seriesDescanso)
                    putExtra("gpsEnabled", seriesGpsEnabled)
                    putExtra("fcEnabled", seriesFcEnabled)
                    putExtra("alarmEnabled", alarmEnabled)
                    putExtra("alarmIntervalMs", alarmIntervalMs ?: 0L)
                }
                context.startForegroundService(intent)
                navController.navigate("series_active") {
                    popUpTo("series_config") { inclusive = true }
                }
            }
        }
        composable("series_active") {
            SeriesActiveScreen(
                fcEnabled = seriesFcEnabled,
                gpsEnabled = seriesGpsEnabled,
                distanciaConfigM = SeriesTrainingService.parseDistancia(seriesDistancia),
                onStop = {
                    val serviceIntent = Intent(context, SeriesTrainingService::class.java)
                    val connection = object : ServiceConnection {
                        override fun onServiceConnected(name: ComponentName?, binder: IBinder?) {
                            val service = (binder as SeriesTrainingService.LocalBinder).getService()
                            service.captureSnapshot()
                            val snap = SeriesTrainingService.lastSnapshot.value
                            context.unbindService(this)
                            context.stopService(serviceIntent)
                            val uid = context.getSharedPreferences("wear_prefs", Context.MODE_PRIVATE)
                                .getString("uid", null)
                            if (uid != null && snap != null && snap.seriesData.isNotEmpty()) {
                                val parsedDescansoSec = SeriesTrainingService.parseDescanso(seriesDescanso)
                                val seriesMapList = snap.seriesData.map { serie ->
                                    mapOf(
                                        "tiempoSec" to serie.elapsedSec.toDouble(),
                                        "distanciaM" to serie.distanceM.toInt(),
                                        "descansoSec" to parsedDescansoSec.toDouble(),
                                        "rpe" to serie.rpe.toDouble(),
                                        "usedGps" to serie.usedGps,
                                        "finishedAt" to com.google.firebase.Timestamp.now(),
                                    )
                                }
                                val seriesTrainingMap: Map<String, Any> = mapOf(
                                    "titulo" to "Entrenamiento por series",
                                    "fecha" to FieldValue.serverTimestamp(),
                                    "gps" to seriesGpsEnabled,
                                    "series" to seriesMapList,
                                    "tags" to emptyList<String>(),
                                    "trackPoints" to emptyList<Map<String, Any>>(),
                                    "createdAt" to FieldValue.serverTimestamp(),
                                    "updatedAt" to FieldValue.serverTimestamp(),
                                    "source" to "wear_os",
                                    "wear_uid" to uid,
                                )
                                trainingSnapshot = TrainingSnapshot(
                                    elapsedSeconds = snap.totalElapsedSec,
                                    distanceMeters = snap.totalDistanceM,
                                    avgPaceSecPerKm = if (snap.totalDistanceM > 10f && snap.totalElapsedSec > 0L)
                                        (snap.totalElapsedSec * 1000L / snap.totalDistanceM).toLong() else 0L,
                                    avgHeartRate = snap.avgHeartRate,
                                )
                                FirebaseFirestore.getInstance()
                                    .collection("users")
                                    .document(uid)
                                    .collection("trainings")
                                    .add(seriesTrainingMap)
                                    .addOnSuccessListener { doc ->
                                        Log.d("RunningLaps", "Series training saved: ${doc.id}")
                                        savedTrainingId = doc.id
                                        navController.navigate("tag_selector") {
                                            popUpTo("series_active") { inclusive = true }
                                        }
                                    }
                                    .addOnFailureListener { e ->
                                        Log.e("RunningLaps", "Save failed: ${e.message}", e)
                                        navController.navigate("continua_summary") {
                                            popUpTo("series_active") { inclusive = true }
                                        }
                                    }
                            } else {
                                navController.navigate("continua_summary") {
                                    popUpTo("series_active") { inclusive = true }
                                }
                            }
                        }
                        override fun onServiceDisconnected(name: ComponentName?) {}
                    }
                    context.bindService(serviceIntent, connection, Context.BIND_AUTO_CREATE)
                },
            )
        }
        composable("template_picker") {
            TemplatePickerScreen(
                onTemplateSelected = { template ->
                    activeTemplate = template
                    SeriesTrainingService.pendingTemplate = template
                    SeriesTrainingService.instance?.loadTemplate(template)
                    navController.popBackStack()
                },
                onBack = { navController.popBackStack() },
            )
        }
        composable("continua_active") {
            ContinuaActiveScreen(
                fcEnabled = fcEnabled,
                onStop = {
                    val serviceIntent = Intent(context, ContinuaTrainingService::class.java)
                    val connection = object : ServiceConnection {
                        override fun onServiceConnected(name: ComponentName?, binder: IBinder?) {
                            val service = (binder as ContinuaTrainingService.LocalBinder).getService()
                            service.captureSnapshot()
                            trainingSnapshot = ContinuaTrainingService.lastSnapshot.value
                            context.unbindService(this)
                            context.stopService(serviceIntent)
                            navController.navigate("rpe_picker") {
                                popUpTo("continua_active") { inclusive = true }
                            }
                        }
                        override fun onServiceDisconnected(name: ComponentName?) {}
                    }
                    context.bindService(serviceIntent, connection, Context.BIND_AUTO_CREATE)
                },
            )
        }
        composable("rpe_picker") {
            RpePickerScreen(
                onConfirm = { rpe ->
                    savedRpe = rpe
                    val uid = context.getSharedPreferences("wear_prefs", Context.MODE_PRIVATE)
                        .getString("uid", null)
                    Log.d("RunningLaps", "Current user: ${uid ?: "NULL"}")
                    val contSnap = trainingSnapshot
                    if (uid != null && contSnap != null) {
                        // ── Continua training save ────────────────────────────
                        val serieMap = mapOf(
                            "tiempoSec" to contSnap.elapsedSeconds.toDouble(),
                            "distanciaM" to contSnap.distanceMeters.toInt(),
                            "descansoSec" to 0.0,
                            "rpe" to rpe.toDouble(),
                            "usedGps" to true,
                            "finishedAt" to com.google.firebase.Timestamp.now(),
                        )
                        val trainingMap: Map<String, Any> = mapOf(
                            "titulo" to "Carrera continua",
                            "fecha" to FieldValue.serverTimestamp(),
                            "gps" to true,
                            "series" to listOf(serieMap),
                            "tags" to emptyList<String>(),
                            "trackPoints" to emptyList<Map<String, Any>>(),
                            "source" to "wear_os",
                            "wear_uid" to uid,
                            "createdAt" to FieldValue.serverTimestamp(),
                            "updatedAt" to FieldValue.serverTimestamp(),
                        )
                        FirebaseFirestore.getInstance()
                            .collection("users")
                            .document(uid)
                            .collection("trainings")
                            .add(trainingMap)
                            .addOnSuccessListener { doc ->
                                Log.d("RunningLaps", "Training saved: ${doc.id}")
                                savedTrainingId = doc.id
                                navController.navigate("tag_selector") {
                                    popUpTo("rpe_picker") { inclusive = true }
                                }
                            }
                            .addOnFailureListener { e ->
                                Log.e("RunningLaps", "Save failed: ${e.message}", e)
                                navController.navigate("continua_summary") {
                                    popUpTo("rpe_picker") { inclusive = true }
                                }
                            }
                    } else {
                        navController.navigate("continua_summary") {
                            popUpTo("rpe_picker") { inclusive = true }
                        }
                    }
                },
            )
        }
        composable("tag_selector") {
            val uid = context.getSharedPreferences("wear_prefs", Context.MODE_PRIVATE)
                .getString("uid", null)
            TagSelectorScreen(
                onConfirm = { selectedTags ->
                    val docId = savedTrainingId
                    if (uid != null && docId != null && selectedTags.isNotEmpty()) {
                        FirebaseFirestore.getInstance()
                            .collection("users")
                            .document(uid)
                            .collection("trainings")
                            .document(docId)
                            .update("tags", selectedTags)
                            .addOnSuccessListener {
                                Log.d("RunningLaps", "Tags updated: $selectedTags")
                            }
                            .addOnFailureListener { e ->
                                Log.e("RunningLaps", "Tags update failed: ${e.message}", e)
                            }
                    }
                    navController.navigate("continua_summary") {
                        popUpTo("tag_selector") { inclusive = true }
                    }
                },
                onSkip = {
                    navController.navigate("continua_summary") {
                        popUpTo("tag_selector") { inclusive = true }
                    }
                },
            )
        }
        composable("continua_summary") {
            val snapshot = trainingSnapshot
            ContinuaSummaryScreen(
                elapsedSeconds = snapshot?.elapsedSeconds ?: 0L,
                distanceMeters = snapshot?.distanceMeters ?: 0f,
                avgPaceSecPerKm = snapshot?.avgPaceSecPerKm ?: 0L,
                avgHeartRate = snapshot?.avgHeartRate ?: 0,
                fcEnabled = fcEnabled,
                onFinish = {
                    navController.navigate("home") {
                        popUpTo("home") { inclusive = true }
                    }
                },
            )
        }
    }
}
