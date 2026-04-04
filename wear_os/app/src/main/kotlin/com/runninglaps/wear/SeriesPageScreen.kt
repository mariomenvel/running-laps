@file:OptIn(
    androidx.wear.compose.material.ExperimentalWearMaterialApi::class,
    androidx.wear.compose.foundation.ExperimentalWearFoundationApi::class,
    androidx.compose.foundation.ExperimentalFoundationApi::class,
)

package com.runninglaps.wear

import android.util.Log
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.FolderOpen
import androidx.compose.material.icons.filled.GpsFixed
import androidx.compose.material.icons.filled.NotificationsActive
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import androidx.wear.compose.material.Button
import androidx.wear.compose.material.ButtonDefaults
import androidx.wear.compose.material.Chip
import androidx.wear.compose.material.ChipDefaults
import androidx.wear.compose.material.Icon
import androidx.wear.compose.material.Picker
import androidx.wear.compose.material.Text
import androidx.wear.compose.material.rememberPickerState
import com.runninglaps.wear.theme.WearColors
import com.runninglaps.wear.theme.WearTheme

internal val distOptions = (1..100).map { i ->
    val meters = i * 50
    if (meters >= 1000) {
        val km = meters / 1000f
        if (km == km.toLong().toFloat()) "${km.toLong()}km" else "${km}km"
    } else "${meters}m"
}
internal val descOptions = (0..60).map { i ->
    val secs = i * 5
    if (secs == 0) "0s"
    else if (secs < 60) "${secs}s"
    else {
        val min = secs / 60
        val sec = secs % 60
        if (sec == 0) "${min}:00" else "${min}:${sec.toString().padStart(2, '0')}"
    }
}

internal fun metersToDistStr(meters: Int): String {
    val rounded = ((meters / 50) * 50).coerceIn(50, 5000)
    return if (rounded >= 1000) {
        val km = rounded / 1000f
        if (km == km.toLong().toFloat()) "${km.toLong()}km" else "${km}km"
    } else "${rounded}m"
}

internal fun secondsToDescStr(secs: Int): String {
    val rounded = (secs / 5) * 5
    return if (rounded == 0) "0s"
    else if (rounded < 60) "${rounded}s"
    else {
        val min = rounded / 60
        val sec = rounded % 60
        if (sec == 0) "$min:00" else "$min:${sec.toString().padStart(2, '0')}"
    }
}

@Composable
fun SeriesPage(
    onOpenAlarmConfig: () -> Unit,
    onOpenTemplates: () -> Unit,
    onStartSeries: (distancia: String, descanso: String, gpsEnabled: Boolean, fcEnabled: Boolean, alarmEnabled: Boolean) -> Unit,
    initialTemplate: WearTemplate? = null,
) {
    val colors = WearTheme.colors

    val block0 = initialTemplate?.blocks?.firstOrNull()
    val distInitial = if (block0 != null && block0.type == "distance") {
        distOptions.indexOf(metersToDistStr(block0.value)).takeIf { it >= 0 }
            ?: distOptions.indexOf("400m")
    } else distOptions.indexOf("400m")
    val descInitial = if (block0 != null) {
        descOptions.indexOf(secondsToDescStr(block0.restSeconds)).takeIf { it >= 0 }
            ?: descOptions.indexOf("1:00")
    } else descOptions.indexOf("1:00")

    val distState = rememberPickerState(
        initialNumberOfOptions = distOptions.size,
        initiallySelectedOption = distInitial,
    )
    val descState = rememberPickerState(
        initialNumberOfOptions = descOptions.size,
        initiallySelectedOption = descInitial,
    )

    var gpsEnabled by remember { mutableStateOf(true) }
    var fcEnabled by remember { mutableStateOf(false) }
    var alarmsEnabled by remember { mutableStateOf(false) }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .clip(CircleShape)
            .background(Color(0xFF0D0D0D)),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
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
                }
                .padding(top = 10.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(6.dp, Alignment.CenterVertically),
        ) {
            // ── Template label ─────────────────────────────────────────────────
            if (initialTemplate != null) {
                Text(
                    text = "📋 ${initialTemplate.name}",
                    color = colors.brandPurpleLight,
                    fontSize = 9.sp,
                    fontWeight = FontWeight.Medium,
                    letterSpacing = 0.05.em,
                )
            }

            // ── Section 1: Pickers row ─────────────────────────────────────────
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(80.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                // DIST picker
                Column(
                    modifier = Modifier.weight(1f),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Text(
                        text = "DIST",
                        color = colors.brandPurpleLight.copy(alpha = 0.7f),
                        fontSize = 7.sp,
                        fontWeight = FontWeight.Medium,
                        letterSpacing = 0.08.em,
                    )
                    Picker(
                        state = distState,
                        modifier = Modifier
                            .height(72.dp)
                            .fillMaxWidth(),
                        gradientColor = Color(0xFF0D0D0D),
                    ) { index ->
                        val isSelected = index == distState.selectedOption
                        Text(
                            text = distOptions[index],
                            color = if (isSelected) Color.White else Color.White.copy(alpha = 0.25f),
                            fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                            fontSize = if (isSelected) 18.sp else 12.sp,
                        )
                    }
                }

                // Divider
                Box(
                    modifier = Modifier
                        .width(0.5.dp)
                        .fillMaxWidth(0.5f)
                        .height(40.dp) // 50% of 80dp row
                        .background(Color.White.copy(alpha = 0.1f)),
                )

                // DESC picker
                Column(
                    modifier = Modifier.weight(1f),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Text(
                        text = "DESC",
                        color = colors.brandPurpleLight.copy(alpha = 0.7f),
                        fontSize = 7.sp,
                        fontWeight = FontWeight.Medium,
                        letterSpacing = 0.08.em,
                    )
                    Picker(
                        state = descState,
                        modifier = Modifier
                            .height(72.dp)
                            .fillMaxWidth(),
                        gradientColor = Color(0xFF0D0D0D),
                    ) { index ->
                        val isSelected = index == descState.selectedOption
                        Text(
                            text = descOptions[index],
                            color = if (isSelected) Color.White else Color.White.copy(alpha = 0.25f),
                            fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Normal,
                            fontSize = if (isSelected) 18.sp else 12.sp,
                        )
                    }
                }
            }

            // ── Section 2: Toggle buttons ──────────────────────────────────────
            Row(
                horizontalArrangement = Arrangement.spacedBy(10.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                SeriesToggleButton(
                    icon = Icons.Default.GpsFixed,
                    active = gpsEnabled,
                    onClick = { gpsEnabled = !gpsEnabled },
                )
                SeriesToggleButton(
                    icon = Icons.Default.Favorite,
                    active = fcEnabled,
                    onClick = { fcEnabled = !fcEnabled },
                )
                SeriesToggleButton(
                    icon = Icons.Default.NotificationsActive,
                    active = alarmsEnabled,
                    onClick = {
                        val next = !alarmsEnabled
                        alarmsEnabled = next
                        if (next) onOpenAlarmConfig()
                    },
                )
            }

            // ── Section 3: Plantilla + Play side by side ───────────────────────
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Chip(
                    onClick = {
                        Log.d("RunningLaps", "Template picker tapped")
                        onOpenTemplates()
                    },
                    colors = ChipDefaults.chipColors(backgroundColor = Color.White.copy(alpha = 0.07f)),
                    modifier = Modifier
                        .width(110.dp)
                        .height(30.dp)
                        .clip(RoundedCornerShape(15.dp))
                        .border(0.5.dp, Color.White.copy(alpha = 0.12f), RoundedCornerShape(15.dp)),
                    label = {
                        Icon(
                            imageVector = Icons.Default.FolderOpen,
                            contentDescription = null,
                            tint = colors.brandPurpleLight,
                            modifier = Modifier.size(11.dp),
                        )
                        Text(
                            text = "  Plantilla",
                            color = colors.brandPurpleLight,
                            fontSize = 10.sp,
                        )
                    },
                )
                Button(
                    onClick = {
                        Log.d("RunningLaps", "SeriesPage play tapped — dist=${distOptions[distState.selectedOption]} desc=${descOptions[descState.selectedOption]}")
                        onStartSeries(
                            distOptions[distState.selectedOption],
                            descOptions[descState.selectedOption],
                            gpsEnabled,
                            fcEnabled,
                            alarmsEnabled,
                        )
                    },
                    modifier = Modifier
                        .shadow(10.dp, CircleShape, spotColor = WearColors.brandPurple)
                        .size(40.dp),
                    colors = ButtonDefaults.buttonColors(backgroundColor = WearColors.brandPurple),
                ) {
                    Icon(
                        imageVector = Icons.Default.PlayArrow,
                        contentDescription = "Iniciar",
                        tint = Color.White,
                        modifier = Modifier.size(20.dp),
                    )
                }
            }
        }
    }
}

@Composable
private fun SeriesToggleButton(
    icon: ImageVector,
    active: Boolean,
    onClick: () -> Unit,
) {
    Button(
        onClick = onClick,
        modifier = Modifier
            .then(
                if (active) Modifier.shadow(6.dp, CircleShape, spotColor = WearColors.brandPurple)
                else Modifier.border(0.5.dp, Color.White.copy(alpha = 0.12f), CircleShape)
            )
            .size(36.dp),
        colors = ButtonDefaults.buttonColors(
            backgroundColor = if (active) WearColors.brandPurple else Color.White.copy(alpha = 0.07f),
        ),
    ) {
        Icon(
            imageVector = icon,
            contentDescription = null,
            tint = if (active) WearColors.brandPurpleLight else Color.White.copy(alpha = 0.35f),
            modifier = Modifier.size(16.dp),
        )
    }
}
