package com.runninglaps.wear

import android.util.Log
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Stop
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.wear.compose.material.Icon
import androidx.wear.compose.material.Text
import com.runninglaps.wear.theme.WearColors
import com.runninglaps.wear.theme.WearTheme

@Composable
fun SeriesActiveScreen(
    distancia: String,
    descanso: String,
    gpsEnabled: Boolean,
    fcEnabled: Boolean,
    alarmIntervalMs: Long,
    onStop: () -> Unit,
) {
    LaunchedEffect(Unit) {
        Log.d(
            "RunningLaps",
            "SeriesActive: dist=$distancia desc=$descanso gps=$gpsEnabled fc=$fcEnabled alarm=$alarmIntervalMs",
        )
    }

    val colors = WearTheme.colors

    Box(
        modifier = Modifier
            .fillMaxSize()
            .clip(CircleShape)
            .background(Color(0xFF0D0D0D)),
        contentAlignment = Alignment.Center,
    ) {
        Canvas(modifier = Modifier.fillMaxSize()) {
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

        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.Center,
        ) {
            Text(
                text = distancia,
                color = Color.White,
                fontWeight = FontWeight.Bold,
                fontSize = 28.sp,
                textAlign = TextAlign.Center,
            )
            Spacer(Modifier.height(2.dp))
            Text(
                text = "desc $descanso",
                color = colors.onSurfaceSecondary,
                fontSize = 10.sp,
                textAlign = TextAlign.Center,
            )
            Spacer(Modifier.height(16.dp))
            Box(
                modifier = Modifier
                    .shadow(
                        elevation = 10.dp,
                        shape = CircleShape,
                        spotColor = Color.Red,
                    )
                    .size(44.dp)
                    .background(Color(0xFFD32F2F), CircleShape)
                    .clickable(onClick = onStop),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = Icons.Default.Stop,
                    contentDescription = "Parar",
                    tint = Color.White,
                    modifier = Modifier.size(20.dp),
                )
            }
        }
    }
}
