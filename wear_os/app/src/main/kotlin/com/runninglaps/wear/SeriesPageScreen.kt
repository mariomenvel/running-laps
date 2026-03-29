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

private val distOptions = listOf("100m","200m","300m","400m","500m","600m","800m","1km","1.2km","1.5km","2km","3km","4km","5km","8km","10km","15km","21km","42km")
private val descOptions = listOf("0s","15s","30s","45s","1:00","1:15","1:30","1:45","2:00","2:30","3:00","3:30","4:00","5:00","6:00","7:00","8:00","10:00")

@Composable
fun SeriesPage(
    onOpenAlarmConfig: () -> Unit,
    onOpenTemplates: () -> Unit,
    onStartSeries: (distancia: String, descanso: String, gpsEnabled: Boolean, fcEnabled: Boolean, alarmEnabled: Boolean) -> Unit,
) {
    val colors = WearTheme.colors

    val distState = rememberPickerState(
        initialNumberOfOptions = distOptions.size,
        initiallySelectedOption = 3, // 400m
    )
    val descState = rememberPickerState(
        initialNumberOfOptions = descOptions.size,
        initiallySelectedOption = 4, // 1:00
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
