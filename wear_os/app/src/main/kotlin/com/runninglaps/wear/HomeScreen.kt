@file:OptIn(
    androidx.wear.compose.material.ExperimentalWearMaterialApi::class,
    androidx.wear.compose.foundation.ExperimentalWearFoundationApi::class,
    androidx.compose.foundation.ExperimentalFoundationApi::class,
)

package com.runninglaps.wear

import android.content.Context
import android.util.Log
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.border
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.DirectionsRun
import androidx.compose.material.icons.filled.EmojiEvents
import androidx.compose.material.icons.filled.FitnessCenter
import androidx.compose.material.icons.filled.PlayArrow
import androidx.compose.material.icons.filled.Repeat
import androidx.compose.material.icons.filled.Speed
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.wear.compose.material.Chip
import androidx.wear.compose.material.Icon
import androidx.wear.compose.material.ChipDefaults
import androidx.wear.compose.material.CompactButton
import androidx.wear.compose.material.ButtonDefaults
import androidx.wear.compose.material.Picker
import androidx.wear.compose.material.ScalingLazyColumn
import androidx.wear.compose.material.Text
import androidx.wear.compose.material.rememberPickerState
import com.google.firebase.firestore.FirebaseFirestore
import com.runninglaps.wear.theme.WearColors
import com.runninglaps.wear.theme.WearTheme
import kotlinx.coroutines.tasks.await

// ── Data models ───────────────────────────────────────────────────────────────

data class StatsData(
    val totalKm: Double,
    val avgPaceSecPerKm: Double,
    val sessions: Int,
    val bestMarkSec: Double? = null,
    val bestMarkDistM: Int = 400,
)

data class TemplateItem(
    val id: String,
    val name: String,
    val blocksCount: Int,
)

// ── Formatters ────────────────────────────────────────────────────────────────

fun formatPaceShort(secPerKm: Double): String {
    if (secPerKm <= 0) return "--"
    val t = secPerKm.toInt()
    return "${t / 60}'${(t % 60).toString().padStart(2, '0')}\""
}

fun formatTime(totalSec: Double): String {
    val t = totalSec.toInt()
    val m = t / 60
    val s = t % 60
    return "$m:${s.toString().padStart(2, '0')}"
}

fun formatPace(secPerKm: Double): String {
    if (secPerKm <= 0) return "--"
    val t = secPerKm.toInt()
    return "${t / 60}:${(t % 60).toString().padStart(2, '0')} /km"
}

// ── HomeScreen ────────────────────────────────────────────────────────────────

@Composable
fun HomeScreen(onStartContinua: () -> Unit = {}) {
    val context = LocalContext.current
    val colors = WearTheme.colors
    val pagerState = rememberPagerState(initialPage = 0, pageCount = { 3 })

    var stats by remember { mutableStateOf<StatsData?>(null) }

    val uid = remember {
        context.getSharedPreferences("wear_prefs", Context.MODE_PRIVATE)
            .getString("uid", null)
    }

    LaunchedEffect(uid) {
        if (uid == null) return@LaunchedEffect
        try {
            val db = FirebaseFirestore.getInstance()

            // Load best mark distance preference
            val settingsDoc = db.collection("users").document(uid)
                .collection("settings").document("bestMarkDistance")
                .get().await()
            val bestDistM = (settingsDoc.get("distanceM") as? Number)?.toInt() ?: 400

            // Load entrenamientos
            val snap = db.collection("users").document(uid)
                .collection("entrenamientos")
                .get().await()

            var totalDist = 0.0
            var totalTime = 0.0
            var bestMarkSec: Double? = null

            for (doc in snap.documents) {
                val dist = (doc.get("distanciaTotalM") as? Number)?.toDouble() ?: 0.0
                val time = (doc.get("tiempoTotalSec") as? Number)?.toDouble() ?: 0.0
                totalDist += dist
                totalTime += time

                val seriesList = doc.get("series") as? List<*> ?: continue
                for (raw in seriesList) {
                    val serie = raw as? Map<*, *> ?: continue
                    val sDistM = (serie["distanciaM"] as? Number)?.toDouble() ?: 0.0
                    val sTimeSec = (serie["tiempoSec"] as? Number)?.toDouble() ?: 0.0
                    if (sDistM <= 0) continue
                    if (sDistM < bestDistM * 0.9 || sDistM > bestDistM * 1.1) continue
                    if (bestMarkSec == null || sTimeSec < bestMarkSec) bestMarkSec = sTimeSec
                }
            }

            stats = StatsData(
                totalKm = totalDist / 1000.0,
                avgPaceSecPerKm = if (totalDist > 0) (totalTime / totalDist) * 1000.0 else 0.0,
                sessions = snap.size(),
                bestMarkSec = bestMarkSec,
                bestMarkDistM = bestDistM,
            )
        } catch (_: Exception) {
            stats = StatsData(0.0, 0.0, 0)
        }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(Color(0xFF0D0D0D)),
    ) {
        HorizontalPager(
            state = pagerState,
            modifier = Modifier
                .fillMaxSize()
                .background(Color(0xFF0D0D0D)),
        ) { page ->
            when (page) {
                0 -> StatsPage(stats)
                1 -> ModeSelectorPage(onStartContinua = onStartContinua)
                2 -> SeriesPage()
            }
        }

        PageDots(
            pageCount = 3,
            currentPage = pagerState.currentPage,
            modifier = Modifier
                .align(Alignment.BottomCenter)
                .padding(bottom = 8.dp),
        )
    }
}

// ── Page 0 — Stats (liquid glass, premium dark) ───────────────────────────────

@Composable
fun StatsPage(stats: StatsData?) {
    val kmValue = stats?.let { String.format("%.1f", it.totalKm) } ?: "…"
    val paceValue = stats?.let { formatPaceShort(it.avgPaceSecPerKm) } ?: "…"
    val sessionsValue = stats?.sessions?.toString() ?: "…"
    val bestLabel = stats?.let {
        if (it.bestMarkDistM >= 1000) "${it.bestMarkDistM / 1000}k" else "${it.bestMarkDistM}m"
    } ?: "…"
    val bestValue = stats?.bestMarkSec?.let { formatTime(it) } ?: "--"

    Box(
        modifier = Modifier
            .fillMaxSize()
            .clip(CircleShape)
            .background(Color(0xFF0D0D0D)),
    ) {
        // Layer 1: Radial purple ambient glow + cross dividers
        Canvas(modifier = Modifier.fillMaxSize()) {
            // Center purple glow
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
            // Cross dividers — barely visible, elegant
            val cx = size.width / 2f
            val cy = size.height / 2f
            val r = size.minDimension / 2f
            val lineColor = Color.White.copy(alpha = 0.15f)
            val stroke = 1.dp.toPx()
            drawLine(lineColor, Offset(cx - r, cy), Offset(cx + r, cy), strokeWidth = stroke)
            drawLine(lineColor, Offset(cx, cy - r), Offset(cx, cy + r), strokeWidth = stroke)
        }

        // Layer 2: 2×2 glass card grid
        Column(modifier = Modifier.fillMaxSize()) {
            Row(modifier = Modifier.weight(1f).fillMaxWidth()) {
                QuadrantCell(
                    modifier = Modifier.weight(1f).fillMaxHeight().padding(8.dp),
                    label = "Km totales",
                    value = kmValue,
                    icon = Icons.Default.DirectionsRun,
                )
                QuadrantCell(
                    modifier = Modifier.weight(1f).fillMaxHeight().padding(8.dp),
                    label = "Ritmo medio",
                    value = paceValue,
                    icon = Icons.Default.Speed,
                )
            }
            Row(modifier = Modifier.weight(1f).fillMaxWidth()) {
                QuadrantCell(
                    modifier = Modifier.weight(1f).fillMaxHeight().padding(8.dp),
                    label = "Sesiones",
                    value = sessionsValue,
                    icon = Icons.Default.FitnessCenter,
                )
                QuadrantCell(
                    modifier = Modifier.weight(1f).fillMaxHeight().padding(8.dp),
                    label = "Mejor $bestLabel",
                    value = bestValue,
                    icon = Icons.Default.EmojiEvents,
                )
            }
        }
    }
}

@Composable
fun QuadrantCell(modifier: Modifier, label: String, value: String, icon: ImageVector) {
    Box(
        modifier = modifier
            .background(Color.White.copy(alpha = 0.05f))
            .border(0.5.dp, Color.White.copy(alpha = 0.1f)),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(2.dp, Alignment.CenterVertically),
        ) {
            // Purple rounded-square icon, 32dp, with purple glow shadow
            Box(
                modifier = Modifier
                    .shadow(
                        elevation = 12.dp,
                        shape = RoundedCornerShape(8.dp),
                        spotColor = WearColors.brandPurple,
                    )
                    .size(32.dp)
                    .background(WearColors.brandPurple, RoundedCornerShape(8.dp)),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = icon,
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier.size(16.dp),
                )
            }
            // Value
            Text(
                text = value,
                color = Color.White,
                fontWeight = FontWeight.Bold,
                fontSize = 16.sp,
                textAlign = TextAlign.Center,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
            // Label
            Text(
                text = label,
                color = Color.White.copy(alpha = 0.6f),
                fontSize = 9.sp,
                textAlign = TextAlign.Center,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
            )
        }
    }
}

// ── Page 1 — Mode selector ────────────────────────────────────────────────────

@Composable
fun ModeSelectorPage(onStartContinua: () -> Unit) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .clip(CircleShape)
            .background(Color(0xFF0D0D0D)),
    ) {
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
            ModeCard(
                label = "Por Series",
                icon = Icons.Default.Repeat,
                onClick = { Log.d("RunningLaps", "mode: por_series") },
            )
            Spacer(Modifier.height(12.dp))
            ModeCard(
                label = "Continua",
                icon = Icons.Default.DirectionsRun,
                onClick = onStartContinua,
            )
        }
    }
}

@Composable
fun ModeCard(label: String, icon: ImageVector, onClick: () -> Unit) {
    Row(
        modifier = Modifier
            .size(width = 155.dp, height = 48.dp)
            .clip(RoundedCornerShape(24.dp))
            .background(Color.White.copy(alpha = 0.07f))
            .border(0.5.dp, Color.White.copy(alpha = 0.12f), RoundedCornerShape(24.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 8.dp),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Box(
            modifier = Modifier
                .shadow(8.dp, RoundedCornerShape(7.dp), spotColor = WearColors.brandPurple)
                .size(28.dp)
                .background(WearColors.brandPurple, RoundedCornerShape(7.dp)),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = icon,
                contentDescription = null,
                tint = Color.White,
                modifier = Modifier.size(14.dp),
            )
        }
        Text(
            text = label,
            color = Color.White,
            fontWeight = FontWeight.SemiBold,
            fontSize = 11.sp,
            modifier = Modifier.weight(1f),
            maxLines = 1,
            softWrap = false,
            overflow = TextOverflow.Ellipsis,
        )
        Box(
            modifier = Modifier
                .size(28.dp)
                .background(WearColors.brandPurple, CircleShape),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                imageVector = Icons.Default.PlayArrow,
                contentDescription = null,
                tint = Color.White,
                modifier = Modifier.size(12.dp),
            )
        }
    }
}

// ── Page 2 — Por series ───────────────────────────────────────────────────────

private val distOptions = listOf("100m", "200m", "400m", "800m", "1km", "2km", "3km", "5km", "10km", "21km", "42km")
private val descOptions = listOf("30s", "1:00", "1:30", "2:00", "2:30", "3:00", "4:00", "5:00", "10:00")

@Composable
fun SeriesPage() {
    val colors = WearTheme.colors

    val distState = rememberPickerState(
        initialNumberOfOptions = distOptions.size,
        initiallySelectedOption = 2, // 400m
    )
    val descState = rememberPickerState(
        initialNumberOfOptions = descOptions.size,
        initiallySelectedOption = 1, // 1:00
    )

    var gpsEnabled by remember { mutableStateOf(true) }
    var fcEnabled by remember { mutableStateOf(false) }
    var alarmsEnabled by remember { mutableStateOf(true) }

    ScalingLazyColumn(
        modifier = Modifier.fillMaxSize(),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        // Pickers row: DIST | DESC
        item {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(100.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                // DIST picker
                Column(
                    modifier = Modifier
                        .weight(1f)
                        .fillMaxHeight(),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Text(
                        text = "DIST",
                        color = colors.brandPurpleLight,
                        fontSize = 9.sp,
                        fontWeight = FontWeight.Bold,
                    )
                    Picker(
                        state = distState,
                        modifier = Modifier.weight(1f),
                        gradientColor = colors.background,
                    ) { index ->
                        Text(
                            text = distOptions[index],
                            color = if (index == distState.selectedOption) colors.onSurface
                            else colors.onSurface.copy(alpha = 0.35f),
                            fontWeight = if (index == distState.selectedOption) FontWeight.Bold
                            else FontWeight.Normal,
                            fontSize = 14.sp,
                        )
                    }
                }

                // Divider
                Box(
                    modifier = Modifier
                        .width(1.dp)
                        .fillMaxHeight(0.7f)
                        .background(colors.onSurface.copy(alpha = 0.2f)),
                )

                // DESC picker
                Column(
                    modifier = Modifier
                        .weight(1f)
                        .fillMaxHeight(),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Text(
                        text = "DESC",
                        color = colors.brandPurpleLight,
                        fontSize = 9.sp,
                        fontWeight = FontWeight.Bold,
                    )
                    Picker(
                        state = descState,
                        modifier = Modifier.weight(1f),
                        gradientColor = colors.background,
                    ) { index ->
                        Text(
                            text = descOptions[index],
                            color = if (index == descState.selectedOption) colors.onSurface
                            else colors.onSurface.copy(alpha = 0.35f),
                            fontWeight = if (index == descState.selectedOption) FontWeight.Bold
                            else FontWeight.Normal,
                            fontSize = 14.sp,
                        )
                    }
                }
            }
        }

        // Toggle row: GPS / FC / ALA
        item {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 4.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp, Alignment.CenterHorizontally),
            ) {
                ToggleIconButton(label = "GPS", active = gpsEnabled) { gpsEnabled = !gpsEnabled }
                ToggleIconButton(label = "FC", active = fcEnabled) { fcEnabled = !fcEnabled }
                ToggleIconButton(label = "ALA", active = alarmsEnabled) { alarmsEnabled = !alarmsEnabled }
            }
        }

        // Plantilla chip
        item {
            Chip(
                onClick = { /* TODO: open template picker */ },
                colors = ChipDefaults.chipColors(backgroundColor = colors.surface),
                modifier = Modifier.fillMaxWidth(0.75f),
                label = {
                    Text(
                        text = "Plantilla",
                        color = colors.brandPurpleLight,
                        fontSize = 12.sp,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.fillMaxWidth(),
                    )
                },
            )
        }

        // Iniciar button
        item {
            Chip(
                onClick = { /* TODO: navigate to TrainingConfigScreen(mode=series) */ },
                colors = ChipDefaults.chipColors(backgroundColor = colors.brandPurple),
                modifier = Modifier.fillMaxWidth(),
                label = {
                    Text(
                        text = "▶  Iniciar",
                        color = Color.White,
                        fontWeight = FontWeight.Bold,
                        fontSize = 16.sp,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.fillMaxWidth(),
                    )
                },
            )
        }

        item { Spacer(Modifier.height(16.dp)) }
    }
}

// ── ContinuaPage — not in pager (kept for future use) ─────────────────────────

@Composable
fun ContinuaPage() {
    val colors = WearTheme.colors

    var fcEnabled by remember { mutableStateOf(false) }
    var alarmsEnabled by remember { mutableStateOf(true) }

    ScalingLazyColumn(
        modifier = Modifier.fillMaxSize(),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        item { Spacer(Modifier.height(8.dp)) }

        // FC toggle
        item {
            ToggleRow(
                label = "FC",
                active = fcEnabled,
                onToggle = { fcEnabled = !fcEnabled },
            )
        }

        // Alarmas toggle
        item {
            ToggleRow(
                label = "Alarmas",
                active = alarmsEnabled,
                onToggle = { alarmsEnabled = !alarmsEnabled },
            )
        }

        // Correr button
        item {
            Chip(
                onClick = { /* TODO: navigate to TrainingConfigScreen(mode=continuo) */ },
                colors = ChipDefaults.chipColors(backgroundColor = colors.brandPurple),
                modifier = Modifier.fillMaxWidth(),
                label = {
                    Text(
                        text = "▶  Correr",
                        color = Color.White,
                        fontWeight = FontWeight.Bold,
                        fontSize = 16.sp,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.fillMaxWidth(),
                    )
                },
            )
        }

        item { Spacer(Modifier.height(16.dp)) }
    }
}

// ── Shared components ─────────────────────────────────────────────────────────

@Composable
fun ToggleIconButton(label: String, active: Boolean, onClick: () -> Unit) {
    val colors = WearTheme.colors
    CompactButton(
        onClick = onClick,
        colors = ButtonDefaults.buttonColors(
            backgroundColor = if (active) colors.brandPurple else colors.surface,
        ),
        modifier = Modifier.size(40.dp),
    ) {
        Text(
            text = label,
            color = if (active) Color.White else colors.onSurfaceSecondary,
            fontSize = 9.sp,
            fontWeight = FontWeight.Bold,
        )
    }
}

@Composable
fun ToggleRow(label: String, active: Boolean, onToggle: () -> Unit) {
    val colors = WearTheme.colors
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 8.dp, vertical = 3.dp)
            .background(colors.surface, androidx.compose.foundation.shape.RoundedCornerShape(20.dp))
            .clickable(onClick = onToggle)
            .padding(horizontal = 16.dp, vertical = 10.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(text = label, color = colors.onSurface, fontSize = 13.sp)
        Box(
            modifier = Modifier
                .size(14.dp)
                .background(
                    color = if (active) colors.brandPurple else colors.onSurface.copy(alpha = 0.25f),
                    shape = CircleShape,
                ),
        )
    }
}

@Composable
fun PageDots(pageCount: Int, currentPage: Int, modifier: Modifier = Modifier) {
    val colors = WearTheme.colors
    Row(
        modifier = modifier,
        horizontalArrangement = Arrangement.spacedBy(5.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        repeat(pageCount) { i ->
            Box(
                modifier = Modifier
                    .size(if (i == currentPage) 7.dp else 5.dp)
                    .background(
                        color = if (i == currentPage) colors.brandPurple
                        else colors.onSurface.copy(alpha = 0.3f),
                        shape = CircleShape,
                    ),
            )
        }
    }
}
