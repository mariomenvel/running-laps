package com.runninglaps.wear

import android.Manifest
import android.content.pm.PackageManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Favorite
import androidx.compose.material.icons.filled.NotificationsActive
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import androidx.wear.compose.material.Icon
import androidx.wear.compose.material.Text
import com.runninglaps.wear.theme.WearColors
import kotlinx.coroutines.delay

@Composable
fun ContinuaConfigScreen(
    onBack: () -> Unit,
    onOpenAlarmConfig: () -> Unit,
    onStartTraining: () -> Unit,
    fcEnabled: Boolean,
    onFcToggle: (Boolean) -> Unit,
    alarmEnabled: Boolean,
    onAlarmToggle: (Boolean) -> Unit,
) {
    val context = LocalContext.current
    var showPermissionError by remember { mutableStateOf(false) }

    val permissionLauncher = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.RequestMultiplePermissions(),
    ) { results ->
        if (results.values.all { it }) {
            onStartTraining()
        } else {
            showPermissionError = true
        }
    }

    // Auto-hide error after 3 seconds
    LaunchedEffect(showPermissionError) {
        if (showPermissionError) {
            delay(3000L)
            showPermissionError = false
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .clip(CircleShape)
            .background(Color(0xFF0D0D0D)),
    ) {
        // Purple radial glow
        Canvas(modifier = Modifier.fillMaxSize()) {
            drawCircle(
                brush = Brush.radialGradient(
                    colors = listOf(
                        WearColors.brandPurple.copy(alpha = 0.25f),
                        Color.Transparent,
                    ),
                    center = Offset(size.width / 2f, size.height / 2f),
                    radius = size.minDimension * 0.55f,
                ),
            )
        }

        Column(
            modifier = Modifier.fillMaxSize(),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            // FC toggle
            ConfigToggleRow(
                icon = Icons.Default.Favorite,
                label = "Frec. Cardíaca",
                enabled = fcEnabled,
                onClick = { onFcToggle(!fcEnabled) },
            )

            Spacer(Modifier.height(10.dp))

            // Alarm toggle — navigates to alarm config when enabled
            ConfigToggleRow(
                icon = Icons.Default.NotificationsActive,
                label = "Avisos Ritmo",
                enabled = alarmEnabled,
                onClick = {
                    val newVal = !alarmEnabled
                    onAlarmToggle(newVal)
                    if (newVal) onOpenAlarmConfig()
                },
            )

            Spacer(Modifier.height(16.dp))

            // Play button — checks permissions before starting
            Box(
                modifier = Modifier
                    .shadow(12.dp, CircleShape, spotColor = WearColors.brandPurple)
                    .size(44.dp)
                    .background(WearColors.brandPurple, CircleShape)
                    .clickable {
                        val permsNeeded = buildList {
                            add(Manifest.permission.ACCESS_FINE_LOCATION)
                            if (fcEnabled) add(Manifest.permission.BODY_SENSORS)
                        }
                        val allGranted = permsNeeded.all {
                            ContextCompat.checkSelfPermission(context, it) ==
                                PackageManager.PERMISSION_GRANTED
                        }
                        if (allGranted) {
                            onStartTraining()
                        } else {
                            permissionLauncher.launch(permsNeeded.toTypedArray())
                        }
                    },
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = Icons.Default.PlayArrow,
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier.size(22.dp),
                )
            }

            // Permission error — auto-hidden after 3 s
            if (showPermissionError) {
                Spacer(Modifier.height(6.dp))
                Text(
                    text = "Permiso requerido",
                    fontSize = 11.sp,
                    color = Color(0xFFFF6B6B),
                )
            }
        }
    }
}

@Composable
private fun ConfigToggleRow(
    icon: ImageVector,
    label: String,
    enabled: Boolean,
    onClick: () -> Unit,
) {
    Row(
        modifier = Modifier
            .size(width = 155.dp, height = 36.dp)
            .clip(RoundedCornerShape(18.dp))
            .background(Color.White.copy(alpha = 0.07f))
            .border(0.5.dp, Color.White.copy(alpha = 0.12f), RoundedCornerShape(18.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        // Left: purple rounded-square icon
        Box(
            modifier = Modifier
                .size(24.dp)
                .background(WearColors.brandPurple, RoundedCornerShape(6.dp)),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = Color.White,
                modifier = Modifier.size(12.dp),
            )
        }

        // Label
        Text(
            text = label,
            color = Color.White,
            fontWeight = FontWeight.Medium,
            fontSize = 10.sp,
            modifier = Modifier.weight(1f),
            maxLines = 1,
            softWrap = false,
            overflow = TextOverflow.Clip,
        )

        // Right: toggle indicator circle
        Box(
            modifier = Modifier
                .size(20.dp)
                .background(
                    color = if (enabled) WearColors.brandPurple else Color.White.copy(alpha = 0.2f),
                    shape = CircleShape,
                ),
            contentAlignment = Alignment.Center,
        ) {
            if (enabled) {
                Icon(
                    imageVector = Icons.Default.Check,
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier.size(10.dp),
                )
            }
        }
    }
}
