package com.runninglaps.wear

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Stop
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.wear.compose.material.Icon
import androidx.wear.compose.material.Text
import com.runninglaps.wear.theme.WearColors

@Composable
fun ContinuaActiveScreen(
    fcEnabled: Boolean,
    onStop: () -> Unit,
) {
    val distanceMeters by ContinuaTrainingService.distanceMeters.collectAsState()
    val elapsedSeconds by ContinuaTrainingService.elapsedSeconds.collectAsState()
    val avgPaceSecPerKm by ContinuaTrainingService.avgPaceSecPerKm.collectAsState()
    val heartRate by ContinuaTrainingService.heartRate.collectAsState()
    val gpsFix by ContinuaTrainingService.gpsFix.collectAsState()
    val alarmPulse by ContinuaTrainingService.alarmPulse.collectAsState()

    Box(
        modifier = Modifier
            .fillMaxSize()
            .clip(CircleShape)
            .background(Color(0xFF0D0D0D))
            .drawBehind {
                // Base radial purple glow
                drawCircle(
                    brush = Brush.radialGradient(
                        colors = listOf(
                            WearColors.brandPurple.copy(alpha = 0.18f),
                            Color.Transparent,
                        ),
                        center = Offset(size.width / 2f, size.height / 2f),
                        radius = 90.dp.toPx(),
                    ),
                )
                // Alarm pulse overlay
                if (alarmPulse) {
                    drawCircle(
                        brush = Brush.radialGradient(
                            colors = listOf(
                                WearColors.brandPurple.copy(alpha = 0.35f),
                                Color.Transparent,
                            ),
                            center = Offset(size.width / 2f, size.height / 2f),
                            radius = 120.dp.toPx(),
                        ),
                    )
                }
            },
    ) {
        // GPS fix dot — top-right corner
        Box(
            modifier = Modifier
                .align(Alignment.TopEnd)
                .offset(x = (-12).dp, y = 12.dp)
                .size(6.dp)
                .background(
                    color = if (gpsFix) Color(0xFF4CAF50) else Color(0xFFFF6B6B),
                    shape = CircleShape,
                ),
        )

        // Main content — centered column
        Column(
            modifier = Modifier.align(Alignment.Center),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            // 1. Elapsed time — hero
            Text(
                text = formatActiveElapsed(elapsedSeconds),
                fontSize = 26.sp,
                fontWeight = FontWeight.Bold,
                color = Color.White,
            )

            Spacer(Modifier.height(4.dp))

            // 2. Distance
            Text(
                text = formatActiveDistance(distanceMeters, gpsFix),
                fontSize = 18.sp,
                fontWeight = FontWeight.Medium,
                color = Color.White.copy(alpha = 0.9f),
            )

            Spacer(Modifier.height(2.dp))

            // 3. Avg pace
            Text(
                text = formatActivePace(avgPaceSecPerKm),
                fontSize = 18.sp,
                color = Color.White,
            )

            // 4. Heart rate — only when fcEnabled
            if (fcEnabled) {
                Spacer(Modifier.height(2.dp))
                Text(
                    text = if (heartRate == 0) "♥ -- bpm" else "♥ $heartRate bpm",
                    fontSize = 12.sp,
                    color = WearColors.brandPurpleLight,
                )
            }

            Spacer(Modifier.height(12.dp))

            // Stop button
            Box(
                modifier = Modifier
                    .size(48.dp)
                    .clip(CircleShape)
                    .background(Color.White.copy(alpha = 0.12f))
                    .border(0.5.dp, Color.White.copy(alpha = 0.2f), CircleShape)
                    .clickable(onClick = onStop),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = Icons.Default.Stop,
                    contentDescription = "Detener",
                    tint = Color.White,
                    modifier = Modifier.size(22.dp),
                )
            }
        }
    }
}

// ── Private formatters ────────────────────────────────────────────────────────

private fun formatActiveElapsed(seconds: Long): String {
    val h = seconds / 3600
    val m = (seconds % 3600) / 60
    val s = seconds % 60
    return if (h > 0) "%d:%02d:%02d".format(h, m, s)
    else "%02d:%02d".format(m, s)
}

private fun formatActiveDistance(meters: Float, gpsFix: Boolean): String {
    if (!gpsFix) return "-- m"
    return if (meters >= 100f) "${"%.2f".format(meters / 1000f)} km"
    else "${meters.toInt()} m"
}

private fun formatActivePace(secPerKm: Long): String {
    if (secPerKm == 0L) return "--:--"
    val m = secPerKm / 60
    val s = secPerKm % 60
    return "%d:%02d /km".format(m, s)
}
