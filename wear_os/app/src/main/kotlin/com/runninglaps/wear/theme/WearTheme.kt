package com.runninglaps.wear.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.wear.compose.material.MaterialTheme

// ── Color palette ─────────────────────────────────────────────────────────────

object WearColors {
    val brandPurple = Color(0xFF8E24AA)
    val brandPurpleLight = Color(0xFFD48DE7) // for text on dark

    // Light
    val backgroundLight = Color(0xFFF4F6F8)
    val surfaceLight = Color(0xFFFFFFFF)
    val onSurfaceLight = Color(0xFF1C1C1E)
    val onSurfaceSecondaryLight = Color(0xFF6B7280)

    // Dark
    val backgroundDark = Color(0xFF1C1C1E)
    val surfaceDark = Color(0xFF2C2C2E)
    val onSurfaceDark = Color(0xFFFFFFFF)
    val onSurfaceSecondaryDark = Color(0xFF8E8E93)
}

// ── Color scheme ──────────────────────────────────────────────────────────────

data class WearColorScheme(
    val background: Color,
    val surface: Color,
    val onSurface: Color,
    val onSurfaceSecondary: Color,
    val brandPurple: Color,
    val brandPurpleLight: Color,
)

private val darkColorScheme = WearColorScheme(
    background = WearColors.backgroundDark,
    surface = WearColors.surfaceDark,
    onSurface = WearColors.onSurfaceDark,
    onSurfaceSecondary = WearColors.onSurfaceSecondaryDark,
    brandPurple = WearColors.brandPurple,
    brandPurpleLight = WearColors.brandPurpleLight,
)

private val lightColorScheme = WearColorScheme(
    background = WearColors.backgroundLight,
    surface = WearColors.surfaceLight,
    onSurface = WearColors.onSurfaceLight,
    onSurfaceSecondary = WearColors.onSurfaceSecondaryLight,
    brandPurple = WearColors.brandPurple,
    brandPurpleLight = WearColors.brandPurple, // use full purple on light backgrounds
)

// ── Composition local ─────────────────────────────────────────────────────────

val LocalWearColorScheme = staticCompositionLocalOf { darkColorScheme }

object WearTheme {
    val colors: WearColorScheme
        @Composable get() = LocalWearColorScheme.current
}

// ── WearAppTheme ──────────────────────────────────────────────────────────────

@Composable
fun WearAppTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    val scheme = if (darkTheme) darkColorScheme else lightColorScheme
    CompositionLocalProvider(LocalWearColorScheme provides scheme) {
        MaterialTheme(content = content)
    }
}
