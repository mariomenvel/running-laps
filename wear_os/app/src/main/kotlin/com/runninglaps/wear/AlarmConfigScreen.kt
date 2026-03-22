@file:OptIn(
    androidx.wear.compose.material.ExperimentalWearMaterialApi::class,
    androidx.wear.compose.foundation.ExperimentalWearFoundationApi::class,
)

package com.runninglaps.wear

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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.wear.compose.material.Icon
import androidx.wear.compose.material.Picker
import androidx.wear.compose.material.PickerState
import androidx.wear.compose.material.Text
import androidx.wear.compose.material.rememberPickerState
import com.runninglaps.wear.theme.WearColors

private val segmentOptions = listOf(50, 100, 200, 300, 400, 500, 1000)

@Composable
fun AlarmConfigScreen(
    onBack: () -> Unit,
    onSave: (mode: String, intervalMs: Long) -> Unit,
) {
    var mode by remember { mutableStateOf("time") }

    val timeMinState = rememberPickerState(initialNumberOfOptions = 60, initiallySelectedOption = 0)
    val timeSecState = rememberPickerState(initialNumberOfOptions = 120, initiallySelectedOption = 0)
    val paceMinState = rememberPickerState(initialNumberOfOptions = 29, initiallySelectedOption = 3) // index 3 → 5 min/km
    val paceSecState = rememberPickerState(initialNumberOfOptions = 12, initiallySelectedOption = 0)
    val segmentState = rememberPickerState(initialNumberOfOptions = segmentOptions.size, initiallySelectedOption = 2) // 200m

    Box(
        modifier = Modifier
            .fillMaxSize()
            .clip(CircleShape)
            .background(Color(0xFF0D0D0D))
            .drawBehind {
                drawCircle(
                    brush = Brush.radialGradient(
                        colors = listOf(
                            WearColors.brandPurple.copy(alpha = 0.20f),
                            Color.Transparent,
                        ),
                        center = Offset(size.width / 2f, size.height / 2f),
                        radius = 90.dp.toPx(),
                    ),
                )
            },
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(top = 14.dp, bottom = 10.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            // ── 1. Mode selector ──────────────────────────────────────────────
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                AlarmModeChip(label = "Tiempo", selected = mode == "time", onClick = { mode = "time" })
                AlarmModeChip(label = "Ritmo", selected = mode == "pace", onClick = { mode = "pace" })
            }

            Spacer(Modifier.height(8.dp))

            // ── 2. Pickers row ────────────────────────────────────────────────
            Row(
                modifier = Modifier.weight(1f),
                horizontalArrangement = Arrangement.spacedBy(4.dp, Alignment.CenterHorizontally),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                if (mode == "time") {
                    PickerColumn(
                        label = "MIN",
                        state = timeMinState,
                        width = 52.dp,
                        fontSize = 13.sp,
                        display = { i -> i.toString().padStart(2, '0') },
                    )
                    PickerColumn(
                        label = "SEG",
                        state = timeSecState,
                        width = 52.dp,
                        fontSize = 13.sp,
                        display = { i ->
                            val whole = i / 2
                            val frac = if (i % 2 == 0) "0" else "5"
                            "${whole.toString().padStart(2, '0')}.$frac"
                        },
                    )
                } else {
                    PickerColumn(
                        label = "MIN",
                        state = paceMinState,
                        width = 38.dp,
                        fontSize = 11.sp,
                        display = { i -> (i + 2).toString().padStart(2, '0') },
                    )
                    PickerColumn(
                        label = "SEG",
                        state = paceSecState,
                        width = 38.dp,
                        fontSize = 11.sp,
                        display = { i -> (i * 5).toString().padStart(2, '0') },
                    )
                    PickerColumn(
                        label = "M",
                        state = segmentState,
                        width = 38.dp,
                        fontSize = 11.sp,
                        display = { i ->
                            val v = segmentOptions[i]
                            if (v >= 1000) "${v / 1000}km" else "${v}m"
                        },
                    )
                }
            }

            Spacer(Modifier.height(8.dp))

            // ── 3. Save button ────────────────────────────────────────────────
            Box(
                modifier = Modifier
                    .shadow(10.dp, CircleShape, spotColor = WearColors.brandPurple)
                    .size(36.dp)
                    .background(WearColors.brandPurple, CircleShape)
                    .clickable {
                        val intervalMs: Long = if (mode == "time") {
                            val totalSec = timeMinState.selectedOption * 60.0 +
                                timeSecState.selectedOption * 0.5
                            (totalSec * 1000).toLong()
                        } else {
                            val paceSecPerKm = (paceMinState.selectedOption + 2) * 60 +
                                paceSecState.selectedOption * 5
                            val segments = segmentOptions[segmentState.selectedOption]
                            (paceSecPerKm * segments / 1000.0 * 1000).toLong()
                        }
                        if (intervalMs > 0) onSave(mode, intervalMs)
                    },
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = Icons.Default.Check,
                    contentDescription = null,
                    tint = Color.White,
                    modifier = Modifier.size(16.dp),
                )
            }
        }
    }
}

// ── Private helpers ───────────────────────────────────────────────────────────

@Composable
private fun PickerColumn(
    label: String,
    state: PickerState,
    width: Dp,
    fontSize: TextUnit,
    display: (Int) -> String,
) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(
            text = label,
            color = Color.White.copy(alpha = 0.5f),
            fontSize = 7.sp,
        )
        Picker(
            state = state,
            modifier = Modifier.size(width = width, height = 72.dp),
            gradientColor = Color(0xFF0D0D0D),
        ) { i ->
            Text(
                text = display(i),
                color = if (i == state.selectedOption) Color.White
                else Color.White.copy(alpha = 0.35f),
                fontWeight = if (i == state.selectedOption) FontWeight.Medium
                else FontWeight.Normal,
                fontSize = fontSize,
            )
        }
    }
}

@Composable
private fun AlarmModeChip(label: String, selected: Boolean, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .size(width = 58.dp, height = 22.dp)
            .clip(RoundedCornerShape(11.dp))
            .background(if (selected) WearColors.brandPurple else Color.White.copy(alpha = 0.08f))
            .then(
                if (!selected) Modifier.border(
                    0.5.dp,
                    Color.White.copy(alpha = 0.15f),
                    RoundedCornerShape(11.dp),
                ) else Modifier
            )
            .clickable(onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = label,
            color = if (selected) Color.White else Color.White.copy(alpha = 0.5f),
            fontWeight = FontWeight.SemiBold,
            fontSize = 10.sp,
        )
    }
}
