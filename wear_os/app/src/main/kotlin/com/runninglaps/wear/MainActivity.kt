package com.runninglaps.wear

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.wear.compose.navigation.SwipeDismissableNavHost
import androidx.wear.compose.navigation.composable
import androidx.wear.compose.navigation.rememberSwipeDismissableNavController
import com.google.firebase.auth.FirebaseAuth
import com.runninglaps.wear.theme.ThemePreference
import com.runninglaps.wear.theme.WearAppTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        ThemePreference.init(this)
        setContent {
            WearApp()
        }
    }
}

@Composable
fun WearApp() {
    val auth = remember { FirebaseAuth.getInstance() }
    var isAuthenticated by remember { mutableStateOf(auth.currentUser != null) }

    val themeMode by ThemePreference.themeMode.collectAsState()
    val darkTheme = when (themeMode) {
        ThemePreference.DARK -> true
        ThemePreference.LIGHT -> false
        else -> isSystemInDarkTheme()
    }

    WearAppTheme(darkTheme = darkTheme) {
        if (isAuthenticated) {
            AppNavHost()
        } else {
            AuthScreen(onAuthenticated = { isAuthenticated = true })
        }
    }
}

@Composable
fun AppNavHost() {
    val navController = rememberSwipeDismissableNavController()

    // Hoisted state shared across continua_config and alarm_config screens
    var fcEnabled by remember { mutableStateOf(false) }
    var alarmEnabled by remember { mutableStateOf(false) }
    var alarmMode by remember { mutableStateOf("time") }
    var alarmIntervalMs by remember { mutableStateOf<Long?>(null) }

    SwipeDismissableNavHost(
        navController = navController,
        startDestination = "home",
    ) {
        composable("home") {
            HomeScreen(onStartContinua = { navController.navigate("continua_config") })
        }
        composable("continua_config") {
            ContinuaConfigScreen(
                onBack = { navController.popBackStack() },
                onOpenAlarmConfig = { navController.navigate("alarm_config") },
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
    }
}
