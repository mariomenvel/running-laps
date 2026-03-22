package com.runninglaps.wear

import android.content.Context
import android.util.Log
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.wear.compose.material.CircularProgressIndicator
import androidx.wear.compose.material.Icon
import androidx.wear.compose.material.ScalingLazyColumn
import androidx.wear.compose.material.ScalingLazyListAnchorType
import androidx.wear.compose.material.Text
import androidx.wear.compose.material.items
import com.google.firebase.firestore.FirebaseFirestore
import com.runninglaps.wear.theme.WearColors
import kotlinx.coroutines.tasks.await

@Composable
fun TagSelectorScreen(
    onConfirm: (List<String>) -> Unit,
    onSkip: () -> Unit,
) {
    val context = LocalContext.current
    val uid = remember {
        context.getSharedPreferences("wear_prefs", Context.MODE_PRIVATE)
            .getString("uid", null)
    }

    // List of (name, colorValue)
    var tags by remember { mutableStateOf<List<Pair<String, Int>>>(emptyList()) }
    var selectedTags by remember { mutableStateOf<Set<String>>(emptySet()) }
    var isLoading by remember { mutableStateOf(true) }

    LaunchedEffect(uid) {
        Log.d("RunningLaps", "TagSelector uid: ${uid ?: "NULL"}")
        if (uid == null) {
            isLoading = false
            onSkip()
            return@LaunchedEffect
        }
        try {
            val result = FirebaseFirestore.getInstance()
                .collection("users")
                .document(uid)
                .collection("tags")
                .get()
                .await()

            Log.d("RunningLaps", "TagSelector loaded ${result.documents.size} tag documents")

            val loaded = result.documents.mapNotNull { doc ->
                val name = doc.getString("name") ?: return@mapNotNull null
                val color = (doc.get("color") as? Number)?.toInt() ?: 0xFF8E24AA.toInt()
                Pair(name, color)
            }.sortedBy { it.first.lowercase() }.take(6)

            if (loaded.isEmpty()) {
                Log.d("RunningLaps", "TagSelector skipping — no tags found")
                onSkip()
            } else {
                tags = loaded
                isLoading = false
            }
        } catch (e: Exception) {
            Log.e("RunningLaps", "TagSelector load failed: ${e.message}")
            isLoading = false
            onSkip()
        }
    }

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
                        radius = 80.dp.toPx(),
                    ),
                )
            },
        contentAlignment = Alignment.Center,
    ) {
        if (isLoading) {
            CircularProgressIndicator(
                indicatorColor = WearColors.brandPurple,
                modifier = Modifier.size(24.dp),
            )
        } else {
            ScalingLazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(
                    horizontal = 16.dp,
                    vertical = 18.dp,
                ),
                verticalArrangement = Arrangement.spacedBy(4.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                anchorType = ScalingLazyListAnchorType.ItemStart,
            ) {
                item {
                    Text(
                        text = "Etiquetas",
                        fontSize = 10.sp,
                        color = Color.White.copy(alpha = 0.5f),
                        modifier = Modifier.padding(bottom = 4.dp),
                    )
                }

                items(tags) { (name, colorValue) ->
                    val isSelected = name in selectedTags
                    val chipColor = Color(colorValue)

                    Row(
                        modifier = Modifier
                            .width(140.dp)
                            .size(width = 140.dp, height = 30.dp)
                            .clip(RoundedCornerShape(15.dp))
                            .then(
                                if (isSelected)
                                    Modifier.background(chipColor.copy(alpha = 0.75f))
                                else
                                    Modifier
                                        .background(chipColor.copy(alpha = 0.12f))
                                        .border(0.5.dp, chipColor.copy(alpha = 0.35f), RoundedCornerShape(15.dp))
                            )
                            .clickable {
                                selectedTags = if (isSelected)
                                    selectedTags - name
                                else
                                    selectedTags + name
                            }
                            .padding(horizontal = 8.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        if (isSelected) {
                            Icon(
                                imageVector = Icons.Default.Check,
                                contentDescription = null,
                                tint = Color.White,
                                modifier = Modifier
                                    .size(10.dp)
                                    .padding(end = 4.dp),
                            )
                        }
                        Text(
                            text = name,
                            fontSize = 11.sp,
                            color = if (isSelected) Color.White else chipColor,
                            fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
                            maxLines = 1,
                            overflow = TextOverflow.Ellipsis,
                        )
                    }
                }

                item {
                    Box(
                        modifier = Modifier
                            .padding(top = 6.dp)
                            .shadow(10.dp, CircleShape, spotColor = WearColors.brandPurple)
                            .size(36.dp)
                            .background(WearColors.brandPurple, CircleShape)
                            .clickable { onConfirm(selectedTags.toList()) },
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
    }
}
