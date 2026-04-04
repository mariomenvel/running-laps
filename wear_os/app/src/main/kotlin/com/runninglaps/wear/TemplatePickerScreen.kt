@file:OptIn(
    androidx.wear.compose.material.ExperimentalWearMaterialApi::class,
    androidx.wear.compose.foundation.ExperimentalWearFoundationApi::class,
)

package com.runninglaps.wear

import android.content.Context
import android.util.Log
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.wear.compose.foundation.lazy.ScalingLazyColumn
import androidx.wear.compose.foundation.lazy.items
import androidx.wear.compose.material.Chip
import androidx.wear.compose.material.ChipDefaults
import androidx.wear.compose.material.CircularProgressIndicator
import androidx.wear.compose.material.Text
import com.google.firebase.firestore.FirebaseFirestore
import com.runninglaps.wear.theme.WearColors

@Composable
fun TemplatePickerScreen(
    onTemplateSelected: (WearTemplate) -> Unit,
    onBack: () -> Unit,
) {
    val context = LocalContext.current
    var templates by remember { mutableStateOf<List<WearTemplate>?>(null) }
    var loading by remember { mutableStateOf(true) }

    LaunchedEffect(Unit) {
        val uid = context.getSharedPreferences("wear_prefs", Context.MODE_PRIVATE)
            .getString("uid", null)
        if (uid == null) {
            templates = emptyList()
            loading = false
            return@LaunchedEffect
        }
        FirebaseFirestore.getInstance()
            .collection("users")
            .document(uid)
            .collection("templates")
            .get()
            .addOnSuccessListener { snapshot ->
                templates = snapshot.documents.mapNotNull { doc ->
                    val data = doc.data ?: return@mapNotNull null
                    try {
                        parseTemplateFromFirestore(doc.id, data)
                    } catch (e: Exception) {
                        Log.e("RunningLaps", "Template parse error: ${e.message}", e)
                        null
                    }
                }
                loading = false
            }
            .addOnFailureListener { e ->
                Log.e("RunningLaps", "Templates load failed: ${e.message}", e)
                templates = emptyList()
                loading = false
            }
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .clip(CircleShape)
            .background(Color(0xFF0D0D0D)),
        contentAlignment = Alignment.Center,
    ) {
        when {
            loading -> CircularProgressIndicator(indicatorColor = WearColors.brandPurple)

            templates.isNullOrEmpty() -> Text(
                text = "Sin plantillas",
                color = Color.White.copy(alpha = 0.5f),
                fontSize = 12.sp,
            )

            else -> ScalingLazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = PaddingValues(vertical = 40.dp, horizontal = 8.dp),
                verticalArrangement = Arrangement.spacedBy(6.dp),
            ) {
                items(templates!!) { template ->
                    val accentColor = Color(template.colorValue.toInt())
                    Chip(
                        onClick = { onTemplateSelected(template) },
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(44.dp)
                            .border(
                                0.5.dp,
                                accentColor.copy(alpha = 0.4f),
                                RoundedCornerShape(22.dp),
                            ),
                        colors = ChipDefaults.chipColors(
                            backgroundColor = accentColor.copy(alpha = 0.18f),
                        ),
                        label = {
                            Column {
                                Text(
                                    text = template.name,
                                    color = Color.White,
                                    fontSize = 12.sp,
                                    fontWeight = FontWeight.SemiBold,
                                )
                                Text(
                                    text = "${template.blocks.size} series",
                                    color = Color.White.copy(alpha = 0.5f),
                                    fontSize = 9.sp,
                                )
                            }
                        },
                    )
                }
            }
        }
    }
}
