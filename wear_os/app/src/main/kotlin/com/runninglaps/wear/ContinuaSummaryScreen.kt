package com.runninglaps.wear

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.EmojiEvents
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.wear.compose.material.Icon
import androidx.wear.compose.material.Text
import com.runninglaps.wear.theme.WearColors

@Composable
fun ContinuaSummaryScreen(
    elapsedSeconds: Long,
    distanceMeters: Float,
    avgPaceSecPerKm: Long,
    avgHeartRate: Int,
    fcEnabled: Boolean,
    onFinish: () -> Unit,
) {
    val dividerColor = Color.White.copy(alpha = 0.08f)

    Box(
        modifier = Modifier
            .fillMaxSize()
            .clip(CircleShape)
            .background(Color(0xFF0D0D0D)),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            // Trophy + title
            Icon(
                imageVector = Icons.Default.EmojiEvents,
                contentDescription = null,
                tint = WearColors.brandPurpleLight,
                modifier = Modifier.size(20.dp),
            )

            Spacer(Modifier.height(2.dp))

            Text(
                text = "¡Completado!",
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
                color = Color.White,
            )

            Spacer(Modifier.height(6.dp))

            // Metrics
            MetricRow(label = "TIEMPO", value = formatSummaryElapsed(elapsedSeconds))

            SummaryDivider()

            MetricRow(label = "DISTANCIA", value = formatSummaryDistance(distanceMeters))

            SummaryDivider()

            MetricRow(label = "RITMO MEDIO", value = formatSummaryPace(avgPaceSecPerKm))

            if (fcEnabled) {
                SummaryDivider()
                MetricRow(
                    label = "FC MEDIA",
                    value = if (avgHeartRate == 0) "-- bpm" else "$avgHeartRate bpm",
                )
            }

            Spacer(Modifier.height(8.dp))

            // Volver pill
            Box(
                modifier = Modifier
                    .width(110.dp)
                    .height(28.dp)
                    .clip(RoundedCornerShape(14.dp))
                    .background(Color.White.copy(alpha = 0.08f))
                    .border(0.5.dp, Color.White.copy(alpha = 0.15f), RoundedCornerShape(14.dp))
                    .clickable(onClick = onFinish),
                contentAlignment = Alignment.Center,
            ) {
                Text(
                    text = "Volver",
                    fontSize = 12.sp,
                    color = Color.White,
                )
            }
        }
    }
}

@Composable
private fun MetricRow(label: String, value: String) {
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.padding(horizontal = 4.dp),
    ) {
        Text(
            text = label,
            fontSize = 9.sp,
            color = Color.White.copy(alpha = 0.5f),
            modifier = Modifier.width(66.dp),
        )
        Spacer(Modifier.width(4.dp))
        Text(
            text = value,
            fontSize = 12.sp,
            fontWeight = FontWeight.Medium,
            color = Color.White,
        )
    }
}

@Composable
private fun SummaryDivider() {
    Spacer(Modifier.height(2.dp))
    Box(
        modifier = Modifier
            .width(100.dp)
            .height(0.5.dp)
            .background(Color.White.copy(alpha = 0.08f)),
    )
    Spacer(Modifier.height(2.dp))
}

// ── Formatters ────────────────────────────────────────────────────────────────

private fun formatSummaryElapsed(seconds: Long): String {
    val h = seconds / 3600
    val m = (seconds % 3600) / 60
    val s = seconds % 60
    return if (h > 0) "%d:%02d:%02d".format(h, m, s)
    else "%02d:%02d".format(m, s)
}

private fun formatSummaryDistance(meters: Float): String =
    if (meters >= 1000f) "${"%.2f".format(meters / 1000f)} km"
    else "${meters.toInt()} m"

private fun formatSummaryPace(secPerKm: Long): String {
    if (secPerKm == 0L) return "--:--"
    val m = secPerKm / 60
    val s = secPerKm % 60
    return "%d:%02d /km".format(m, s)
}
