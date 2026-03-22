package com.runninglaps.wear

import android.graphics.Bitmap
import android.util.Log
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import android.content.Context
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.wear.compose.material.CircularProgressIndicator
import androidx.wear.compose.material.MaterialTheme
import androidx.wear.compose.material.Text
import com.google.firebase.Timestamp
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import qrcode.QRCode
import kotlinx.coroutines.tasks.await

private const val TAG = "AuthScreen"
private const val BRAND_PURPLE = 0xFF8E24AA

@Composable
fun AuthScreen(onAuthenticated: () -> Unit) {
    val context = LocalContext.current
    val db = remember { FirebaseFirestore.getInstance() }
    val auth = remember { FirebaseAuth.getInstance() }

    var sessionCode by remember { mutableStateOf<String?>(null) }
    var qrBitmap by remember { mutableStateOf<Bitmap?>(null) }
    var isLoading by remember { mutableStateOf(true) }
    var errorMessage by remember { mutableStateOf<String?>(null) }

    // Step 1: Create session document and generate QR on launch
    LaunchedEffect(Unit) {
        try {
            val code = generateSessionCode()
            sessionCode = code

            db.collection("wear_sessions").document(code).set(
                mapOf(
                    "status" to "pending",
                    "createdAt" to Timestamp.now(),
                )
            ).await()

            val qrContent = "runninglaps://wear-auth?code=$code"
            qrBitmap = generateQrBitmap(qrContent)
            isLoading = false
        } catch (e: Exception) {
            Log.e(TAG, "Failed to create wear session", e)
            errorMessage = "Error al crear sesión"
            isLoading = false
        }
    }

    // Step 2: Listen for phone authentication
    DisposableEffect(sessionCode) {
        val code = sessionCode ?: return@DisposableEffect onDispose {}

        Log.d(TAG, "Starting Firestore listener for code=$code")
        val listener = db.collection("wear_sessions").document(code)
            .addSnapshotListener { snapshot, error ->
                if (error != null) {
                    Log.e(TAG, "Session listener error", error)
                    return@addSnapshotListener
                }
                Log.d(TAG, "Document update: status=${snapshot?.getString("status")}, exists=${snapshot?.exists()}")
                if (snapshot?.getString("status") == "authenticated") {
                    val idToken = snapshot.getString("idToken") ?: run {
                        Log.w(TAG, "idToken field missing from authenticated session")
                        return@addSnapshotListener
                    }
                    val uid = snapshot.getString("uid") ?: run {
                        Log.w(TAG, "uid field missing from authenticated session")
                        return@addSnapshotListener
                    }

                    // TODO: Production — replace with Cloud Function custom token
                    // The phone should call a Cloud Function (Firebase Admin SDK) that
                    // exchanges the ID token for a real Custom Token, then write it as
                    // 'customToken'. signInWithCustomToken() requires a server-generated
                    // token (Blaze plan required for Cloud Functions).
                    // See: https://firebase.google.com/docs/auth/admin/create-custom-tokens
                    auth.signInWithCustomToken(idToken)
                        .addOnSuccessListener {
                            Log.i(TAG, "Watch signed in via token")
                            onAuthenticated()
                        }
                        .addOnFailureListener { e ->
                            // TODO: Production — remove this fallback once Cloud Function is in place.
                            // For development: token auth will fail because a client ID token is not
                            // a valid custom token. Store the uid locally so the watch can still
                            // make Firestore queries using the known uid.
                            Log.w(TAG, "signInWithCustomToken failed, falling back to uid storage", e)
                            val prefs = context.getSharedPreferences("wear_prefs", Context.MODE_PRIVATE)
                            prefs.edit().putString("uid", uid).apply()
                            onAuthenticated()
                        }
                }
            }

        onDispose { listener.remove() }
    }

    MaterialTheme {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(Color.Black),
            contentAlignment = Alignment.Center,
        ) {
            when {
                errorMessage != null -> Text(
                    text = errorMessage!!,
                    color = Color.Red,
                    fontSize = 11.sp,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.padding(horizontal = 12.dp),
                )

                isLoading -> CircularProgressIndicator(
                    indicatorColor = Color(BRAND_PURPLE),
                )

                else -> Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center,
                    modifier = Modifier
                        .fillMaxSize()
                        .padding(6.dp),
                ) {
                    qrBitmap?.let { bmp ->
                        Image(
                            bitmap = bmp.asImageBitmap(),
                            contentDescription = "QR de emparejamiento",
                            modifier = Modifier.size(120.dp),
                        )
                    }
                    Spacer(modifier = Modifier.height(6.dp))
                    Text(
                        text = "Escanea con tu móvil",
                        color = Color.White,
                        fontSize = 11.sp,
                        textAlign = TextAlign.Center,
                    )
                    sessionCode?.let { code ->
                        Spacer(modifier = Modifier.height(4.dp))
                        Text(
                            text = code,
                            color = Color(BRAND_PURPLE),
                            fontSize = 15.sp,
                            fontWeight = FontWeight.Bold,
                        )
                    }
                }
            }
        }
    }
}

private fun generateSessionCode(): String {
    // Excludes easily confused characters (0/O, 1/I)
    val chars = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    return (1..6).map { chars.random() }.joinToString("")
}

private fun generateQrBitmap(content: String): Bitmap {
    return QRCode.ofSquares()
        .build(content)
        .render()
        .nativeImage() as Bitmap
}
