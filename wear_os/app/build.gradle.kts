plugins {
    id("com.android.application") version "8.9.1"
    id("org.jetbrains.kotlin.android") version "2.1.0"
    id("org.jetbrains.kotlin.plugin.compose") version "2.1.0"
    id("com.google.gms.google-services")
}

android {
    namespace = "com.runninglaps.wear"
    compileSdk = 34

    defaultConfig {
        applicationId = "com.runninglaps.wear"
        minSdk = 26
        targetSdk = 34
        versionCode = 1
        versionName = "1.0"
    }

    buildFeatures {
        compose = true
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }
}

dependencies {
    // Wear OS Compose UI
    implementation("androidx.wear.compose:compose-material:1.3.0")
    implementation("androidx.wear.compose:compose-foundation:1.3.0")
    implementation("androidx.wear.compose:compose-navigation:1.3.0")
    implementation("androidx.activity:activity-compose:1.8.2")

    // Firebase
    implementation(platform("com.google.firebase:firebase-bom:32.7.0"))
    implementation("com.google.firebase:firebase-auth-ktx")
    implementation("com.google.firebase:firebase-firestore-ktx")

    // Coroutines
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-android:1.7.3")

    // Wearable Data Layer (communication with the Flutter phone app)
    implementation("com.google.android.gms:play-services-wearable:18.1.0")

    // Material Icons Extended (for DirectionsRun, Speed, FitnessCenter, EmojiEvents)
    implementation("androidx.compose.material:material-icons-extended:1.7.8")

    // QR Code generation
    implementation("io.github.g0dkar:qrcode-kotlin-android:4.1.1")
}
