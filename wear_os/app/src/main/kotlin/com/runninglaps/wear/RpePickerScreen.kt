package com.runninglaps.wear

import androidx.compose.foundation.background
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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.em
import androidx.compose.ui.unit.sp
import androidx.wear.compose.material.Icon
import androidx.wear.compose.material.Text
import com.runninglaps.wear.theme.WearColors

// RPE steps: 1.0, 1.5, 2.0, … 10.0 → 19 values
private val RPE_STEPS = (2..20).map { it / 2f } // 1.0 to 10.0

@Composable
fun RpePickerScreen(onConfirm: (Float) -> Unit) {
    var selectedIndex by remember { mutableStateOf(RPE_STEPS.indexOf(5.0f)) } // initial = 5.0
    var dragAccumulator by remember { mutableStateOf(0f) }

    val rpe = RPE_STEPS[selectedIndex]

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
            // Header: two-line label
            Text(
                text = "RPE",
                fontSize = 10.sp,
                fontWeight = FontWeight.Medium,
                color = Color.White.copy(alpha = 0.5f),
                letterSpacing = 0.1.em,
            )
            Spacer(Modifier.height(2.dp))
            Text(
                text = "¿Cómo fue?",
                fontSize = 11.sp,
                fontWeight = FontWeight.Normal,
                color = Color.White.copy(alpha = 0.8f),
            )

            Spacer(Modifier.height(4.dp))

            // Drag target: full-width box containing RPE value + dots
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
                    // RPE value
                    Text(
                        text = if (rpe % 1f == 0f) rpe.toInt().toString() else "%.1f".format(rpe),
                        fontSize = 28.sp,
                        fontWeight = FontWeight.Bold,
                        color = Color.White,
                    )

                    Spacer(Modifier.height(6.dp))

                    // Dot row
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

                    // Drag hint
                    Text(
                        text = "← desliza →",
                        fontSize = 8.sp,
                        color = Color.White.copy(alpha = 0.3f),
                    )
                }
            }

            Spacer(Modifier.height(8.dp))

            // Confirm button
            Box(
                modifier = Modifier
                    .size(36.dp)
                    .clip(CircleShape)
                    .background(WearColors.brandPurple)
                    .clickable { onConfirm(rpe) },
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    imageVector = Icons.Default.Check,
                    contentDescription = "Confirmar",
                    tint = Color.White,
                    modifier = Modifier.size(16.dp),
                )
            }
        }
    }
}
