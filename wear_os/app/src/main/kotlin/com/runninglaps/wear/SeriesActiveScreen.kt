@file:OptIn(
    androidx.wear.compose.material.ExperimentalWearMaterialApi::class,
)

package com.runninglaps.wear

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.ServiceConnection
import android.os.IBinder
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Stop
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import kotlinx.coroutines.delay
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import androidx.wear.compose.material.Chip
import androidx.wear.compose.material.ChipDefaults
import androidx.wear.compose.material.Icon
import androidx.wear.compose.material.Picker
import androidx.wear.compose.material.Text
import androidx.wear.compose.material.rememberPickerState
import com.runninglaps.wear.theme.WearColors
import kotlin.math.roundToInt

private val RPE_STEPS = (2..20).map { it / 2f }

@Composable
fun SeriesActiveScreen(
    fcEnabled: Boolean,
    gpsEnabled: Boolean,
    distanciaConfigM: Int,
    onStop: () -> Unit,
) {
    val context = LocalContext.current
    var seriesService by remember { mutableStateOf<SeriesTrainingService?>(null) }

    DisposableEffect(Unit) {
        val connection = object : ServiceConnection {
            override fun onServiceConnected(name: ComponentName?, binder: IBinder?) {
                seriesService = (binder as SeriesTrainingService.LocalBinder).getService()
            }
            override fun onServiceDisconnected(name: ComponentName?) {
                seriesService = null
            }
        }
        val intent = Intent(context, SeriesTrainingService::class.java)
        context.bindService(intent, connection, Context.BIND_AUTO_CREATE)
        onDispose { context.unbindService(connection) }
    }

    val phase by SeriesTrainingService.phase.collectAsState()
    val serieNumber by SeriesTrainingService.serieNumber.collectAsState()
    val serieElapsedSec by SeriesTrainingService.serieElapsedSec.collectAsState()
    val serieDistanceM by SeriesTrainingService.serieDistanceM.collectAsState()
    val totalDistanceM by SeriesTrainingService.totalDistanceM.collectAsState()
    val restRemainingMs by SeriesTrainingService.restRemainingMs.collectAsState()
    val heartRate by SeriesTrainingService.heartRate.collectAsState()
    val gpsFix by SeriesTrainingService.gpsFix.collectAsState()
    val alarmPulse by SeriesTrainingService.alarmPulse.collectAsState()
    val avgPaceSecPerKm by SeriesTrainingService.avgPaceSecPerKm.collectAsState()
    val pendingDistanceChoice by SeriesTrainingService.pendingDistanceChoice.collectAsState()
    val pendingSerieRpe by SeriesTrainingService.pendingSerieRpe.collectAsState()
    val templateFinished by SeriesTrainingService.templateFinished.collectAsState()

    // RPE overlay state (mirrors RpePickerScreen implementation)
    var selectedIndex by remember { mutableStateOf(RPE_STEPS.indexOf(5.0f)) }
    var dragAccumulator by remember { mutableStateOf(0f) }

    // Rest phase edit mode
    var editMode by remember { mutableStateOf(false) }
    val nextDistState = rememberPickerState(
        initialNumberOfOptions = distOptions.size,
        initiallySelectedOption = distOptions.indexOf("400m"),
    )
    val nextDescState = rememberPickerState(
        initialNumberOfOptions = descOptions.size,
        initiallySelectedOption = descOptions.indexOf("1:00"),
    )

    Box(
        modifier = Modifier
            .fillMaxSize()
            .clip(CircleShape)
            .background(Color(0xFF0D0D0D))
            .drawBehind {
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
        // GPS fix dot — top-right, always visible
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

        // ── Normal phase content (hidden when overlay is active) ───────────────
        if (!pendingDistanceChoice && !pendingSerieRpe) {
            if (phase == "running") {
                Column(
                    modifier = Modifier.align(Alignment.Center),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center,
                ) {
                    Text(
                        text = "SERIE $serieNumber",
                        fontSize = 9.sp,
                        color = Color.White.copy(alpha = 0.5f),
                        letterSpacing = 0.1.em,
                    )
                    Spacer(Modifier.height(4.dp))
                    Text(
                        text = seriesFormatElapsed(serieElapsedSec),
                        fontSize = 24.sp,
                        fontWeight = FontWeight.Bold,
                        color = Color.White,
                    )
                    Spacer(Modifier.height(2.dp))
                    Text(
                        text = seriesFormatDistance(serieDistanceM),
                        fontSize = 16.sp,
                        color = Color.White.copy(alpha = 0.9f),
                    )
                    Spacer(Modifier.height(2.dp))
                    Text(
                        text = seriesFormatPace(avgPaceSecPerKm),
                        fontSize = 13.sp,
                        color = Color.White.copy(alpha = 0.7f),
                    )
                    if (fcEnabled) {
                        Spacer(Modifier.height(2.dp))
                        Text(
                            text = if (heartRate == 0) "♥ -- bpm" else "♥ $heartRate bpm",
                            fontSize = 11.sp,
                            color = Color(0xFFD48DE7),
                        )
                    }
                    Spacer(Modifier.height(10.dp))
                    // CHANGE 1: running phase — only "Fin de serie", no stop button
                    Chip(
                        onClick = { seriesService?.endSerie() },
                        colors = ChipDefaults.chipColors(backgroundColor = WearColors.brandPurple),
                        modifier = Modifier
                            .shadow(8.dp, RoundedCornerShape(16.dp), spotColor = WearColors.brandPurple)
                            .width(120.dp)
                            .height(32.dp)
                            .clip(RoundedCornerShape(16.dp)),
                        label = {
                            Text(
                                text = "Fin de serie",
                                color = Color.White,
                                fontSize = 11.sp,
                                fontWeight = FontWeight.SemiBold,
                            )
                        },
                    )
                }
            } else {
                // CHANGE 3: REST phase with edit mode
                Column(
                    modifier = Modifier.align(Alignment.Center),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center,
                ) {
                    if (!editMode) {
                        Text(
                            text = "DESCANSO",
                            fontSize = 9.sp,
                            color = Color.White.copy(alpha = 0.5f),
                            letterSpacing = 0.1.em,
                        )
                        Spacer(Modifier.height(4.dp))
                        Text(
                            text = seriesFormatRestMs(restRemainingMs),
                            fontSize = 28.sp,
                            fontWeight = FontWeight.Bold,
                            color = WearColors.brandPurpleLight,
                        )
                        Spacer(Modifier.height(2.dp))
                        Text(
                            text = "Serie $serieNumber completada",
                            fontSize = 10.sp,
                            color = Color.White.copy(alpha = 0.6f),
                        )
                        Spacer(Modifier.height(2.dp))
                        Text(
                            text = "${seriesFormatDistance(totalDistanceM)} total",
                            fontSize = 11.sp,
                            color = Color.White.copy(alpha = 0.5f),
                        )
                        Spacer(Modifier.height(10.dp))
                        Row(
                            horizontalArrangement = Arrangement.spacedBy(6.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            // Edit button
                            Box(
                                modifier = Modifier
                                    .size(32.dp)
                                    .clip(CircleShape)
                                    .background(Color.White.copy(alpha = 0.12f))
                                    .border(0.5.dp, Color.White.copy(alpha = 0.2f), CircleShape)
                                    .clickable { editMode = true },
                                contentAlignment = Alignment.Center,
                            ) {
                                Icon(
                                    imageVector = Icons.Default.Edit,
                                    contentDescription = "Editar siguiente serie",
                                    tint = Color.White,
                                    modifier = Modifier.size(14.dp),
                                )
                            }
                            // Empezar ya chip
                            Chip(
                                onClick = { seriesService?.endSerie() },
                                colors = ChipDefaults.chipColors(backgroundColor = WearColors.brandPurple),
                                modifier = Modifier
                                    .shadow(8.dp, RoundedCornerShape(16.dp), spotColor = WearColors.brandPurple)
                                    .width(90.dp)
                                    .height(28.dp)
                                    .clip(RoundedCornerShape(16.dp)),
                                label = {
                                    Text(
                                        text = "Empezar ya",
                                        color = Color.White,
                                        fontSize = 10.sp,
                                        fontWeight = FontWeight.SemiBold,
                                    )
                                },
                            )
                            // Stop button
                            Box(
                                modifier = Modifier
                                    .size(32.dp)
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
                                    modifier = Modifier.size(14.dp),
                                )
                            }
                        }
                    } else {
                        // Edit mode: configure next serie
                        Text(
                            text = "SIGUIENTE SERIE",
                            fontSize = 9.sp,
                            color = WearColors.brandPurpleLight,
                            letterSpacing = 0.1.em,
                        )
                        Spacer(Modifier.height(4.dp))
                        Row(
                            horizontalArrangement = Arrangement.spacedBy(4.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Picker(
                                state = nextDistState,
                                modifier = Modifier.width(60.dp).height(70.dp),
                            ) { index ->
                                Text(
                                    text = distOptions[index],
                                    fontSize = 11.sp,
                                    color = Color.White,
                                    fontWeight = FontWeight.Medium,
                                )
                            }
                            Picker(
                                state = nextDescState,
                                modifier = Modifier.width(60.dp).height(70.dp),
                            ) { index ->
                                Text(
                                    text = descOptions[index],
                                    fontSize = 11.sp,
                                    color = Color.White,
                                    fontWeight = FontWeight.Medium,
                                )
                            }
                        }
                        Spacer(Modifier.height(6.dp))
                        Row(
                            horizontalArrangement = Arrangement.spacedBy(8.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            // Cancel
                            Box(
                                modifier = Modifier
                                    .size(32.dp)
                                    .clip(CircleShape)
                                    .background(Color.White.copy(alpha = 0.12f))
                                    .border(0.5.dp, Color.White.copy(alpha = 0.2f), CircleShape)
                                    .clickable { editMode = false },
                                contentAlignment = Alignment.Center,
                            ) {
                                Icon(
                                    imageVector = Icons.Default.Close,
                                    contentDescription = "Cancelar",
                                    tint = Color.White,
                                    modifier = Modifier.size(14.dp),
                                )
                            }
                            // Confirm
                            Box(
                                modifier = Modifier
                                    .size(32.dp)
                                    .clip(CircleShape)
                                    .background(WearColors.brandPurple)
                                    .clickable {
                                        seriesService?.updateNextSerie(
                                            distOptions[nextDistState.selectedOption],
                                            descOptions[nextDescState.selectedOption],
                                        )
                                        editMode = false
                                    },
                                contentAlignment = Alignment.Center,
                            ) {
                                Icon(
                                    imageVector = Icons.Default.Check,
                                    contentDescription = "Confirmar",
                                    tint = Color.White,
                                    modifier = Modifier.size(14.dp),
                                )
                            }
                        }
                    }
                }
            }
        }

        // ── GPS vs Manual distance overlay ────────────────────────────────────
        if (pendingDistanceChoice) {
            Column(
                modifier = Modifier.align(Alignment.Center),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center,
            ) {
                Text(
                    text = "¿Distancia?",
                    fontSize = 11.sp,
                    color = Color.White.copy(alpha = 0.7f),
                )
                Spacer(Modifier.height(6.dp))
                Text(
                    text = "${serieDistanceM.roundToInt()} m GPS",
                    fontSize = 18.sp,
                    fontWeight = FontWeight.Bold,
                    color = Color.White,
                )
                Spacer(Modifier.height(2.dp))
                Text(
                    text = "$distanciaConfigM m manual",
                    fontSize = 13.sp,
                    color = Color.White.copy(alpha = 0.6f),
                )
                Spacer(Modifier.height(10.dp))
                Row(
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Chip(
                        onClick = { seriesService?.confirmDistance(true) },
                        colors = ChipDefaults.chipColors(backgroundColor = WearColors.brandPurple),
                        modifier = Modifier
                            .shadow(6.dp, RoundedCornerShape(15.dp), spotColor = WearColors.brandPurple)
                            .width(70.dp)
                            .height(30.dp)
                            .clip(RoundedCornerShape(15.dp)),
                        label = {
                            Text(text = "GPS", color = Color.White, fontSize = 11.sp, fontWeight = FontWeight.SemiBold)
                        },
                    )
                    Chip(
                        onClick = { seriesService?.confirmDistance(false) },
                        colors = ChipDefaults.chipColors(backgroundColor = Color.White.copy(alpha = 0.10f)),
                        modifier = Modifier
                            .border(0.5.dp, Color.White.copy(alpha = 0.25f), RoundedCornerShape(15.dp))
                            .width(70.dp)
                            .height(30.dp)
                            .clip(RoundedCornerShape(15.dp)),
                        label = {
                            Text(text = "Manual", color = Color.White, fontSize = 11.sp)
                        },
                    )
                }
            }
        }

        // ── Template finished overlay ──────────────────────────────────────────
        if (templateFinished) {
            LaunchedEffect(Unit) {
                delay(2000L)
                onStop()
            }
            Box(
                modifier = Modifier
                    .fillMaxSize()
                    .clip(CircleShape)
                    .background(Color(0xFF0D0D0D).copy(alpha = 0.93f))
                    .drawBehind {
                        drawCircle(
                            brush = Brush.radialGradient(
                                colors = listOf(
                                    WearColors.brandPurple.copy(alpha = 0.45f),
                                    Color.Transparent,
                                ),
                                center = Offset(size.width / 2f, size.height / 2f),
                                radius = 100.dp.toPx(),
                            ),
                        )
                    },
                contentAlignment = Alignment.Center,
            ) {
                androidx.compose.foundation.layout.Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Text(
                        text = "¡Plantilla",
                        fontSize = 15.sp,
                        fontWeight = FontWeight.Bold,
                        color = Color.White,
                    )
                    Text(
                        text = "completada!",
                        fontSize = 15.sp,
                        fontWeight = FontWeight.Bold,
                        color = WearColors.brandPurpleLight,
                    )
                }
            }
        }

        // CHANGE 2: RPE overlay — exact RpePickerScreen implementation
        if (pendingSerieRpe) {
            Column(
                modifier = Modifier.align(Alignment.Center),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Text(
                    text = "RPE SERIE $serieNumber",
                    fontSize = 10.sp,
                    fontWeight = FontWeight.Medium,
                    color = Color.White.copy(alpha = 0.5f),
                    letterSpacing = 0.1.em,
                )
                Spacer(Modifier.height(4.dp))
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(140.dp)
                        .pointerInput(Unit) {
                            detectHorizontalDragGestures(
                                onDragEnd = { dragAccumulator = 0f },
                                onDragCancel = { dragAccumulator = 0f },
                            ) { _, dragAmount ->
                                dragAccumulator += dragAmount
                                val steps = (dragAccumulator / 20f).toInt()
                                if (steps != 0) {
                                    selectedIndex = (selectedIndex + steps)
                                        .coerceIn(0, RPE_STEPS.lastIndex)
                                    dragAccumulator -= steps * 20f
                                }
                            }
                        },
                    contentAlignment = Alignment.Center,
                ) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        val rpe = RPE_STEPS[selectedIndex]
                        Text(
                            text = if (rpe % 1f == 0f) rpe.toInt().toString() else "%.1f".format(rpe),
                            fontSize = 28.sp,
                            fontWeight = FontWeight.Bold,
                            color = Color.White,
                        )
                        Spacer(Modifier.height(6.dp))
                        Row(
                            horizontalArrangement = Arrangement.spacedBy(3.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            RPE_STEPS.forEachIndexed { index, _ ->
                                Box(
                                    modifier = Modifier
                                        .size(if (index == selectedIndex) 7.dp else 4.dp)
                                        .background(
                                            color = if (index == selectedIndex) WearColors.brandPurple
                                                    else Color.White.copy(alpha = 0.2f),
                                            shape = CircleShape,
                                        ),
                                )
                            }
                        }
                        Spacer(Modifier.height(4.dp))
                        Text(
                            text = "← desliza →",
                            fontSize = 8.sp,
                            color = Color.White.copy(alpha = 0.3f),
                        )
                    }
                }
                Spacer(Modifier.height(8.dp))
                Box(
                    modifier = Modifier
                        .size(36.dp)
                        .clip(CircleShape)
                        .background(WearColors.brandPurple)
                        .clickable {
                            seriesService?.confirmRpe(RPE_STEPS[selectedIndex])
                            selectedIndex = RPE_STEPS.indexOf(5.0f)
                            dragAccumulator = 0f
                        },
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(
                        imageVector = Icons.Default.Check,
                        contentDescription = "Confirmar RPE",
                        tint = Color.White,
                        modifier = Modifier.size(16.dp),
                    )
                }
            }
        }
    }
}

// ── Formatters ────────────────────────────────────────────────────────────────

private fun seriesFormatElapsed(seconds: Long): String {
    val m = seconds / 60
    val s = seconds % 60
    return "%02d:%02d".format(m, s)
}

private fun seriesFormatDistance(meters: Float): String =
    if (meters >= 1000f) "${"%.2f".format(meters / 1000f)} km"
    else "${meters.toInt()} m"

private fun seriesFormatPace(secPerKm: Long): String {
    if (secPerKm == 0L) return "--:--"
    val m = secPerKm / 60
    val s = secPerKm % 60
    return "%d:%02d /km".format(m, s)
}

private fun seriesFormatRestMs(ms: Long): String {
    val totalSec = ms / 1000L
    val m = totalSec / 60
    val s = totalSec % 60
    return "%02d:%02d".format(m, s)
}
