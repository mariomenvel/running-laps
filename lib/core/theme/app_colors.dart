// ===== REGLAS DE COLOR (ver COLOR_SYSTEM.md) =====
// ❌ Degradados en tarjetas (prohibidos salvo Live Activity)
// ❌ Color generado desde título/ID de entrenamiento o grupo
// ❌ Iconos con color propio (azul distancia, naranja tiempo, verde ritmo)
// ❌ Botones mismo nivel con colores distintos
// ❌ Colors.teal, Colors.pink, Colors.orange de Material
// ❌ Cualquier color que no sea un token de AppColors
// ✅ El color comunica significado, no decoración
// ✅ Máximo 1 color de acento por tarjeta
// ✅ RPE siempre via effortColor(), nunca hardcodeado

import 'package:flutter/material.dart';

/// Fuente de verdad absoluta para todos los colores de Running Laps.
/// Importar desde aquí. No hardcodear Color(0xFF...) en vistas.
class AppColors {
  AppColors._();

  // ── Capa 1 · Marca (morado) ────────────────────────────────────────
  static const brand        = Color(0xFF8E24AA); // Botón principal, pestaña activa, underline serie activa
  static const brandDark    = Color(0xFF6A1B9A); // Pressed state, sombras
  static const brandLight   = Color(0xFFCE93D8); // Texto sobre fondos oscuros morados
  static const brandSurface = Color(0xFF1E1530); // Fondo tarjetas con acento morado (dark mode)
  static const brandBorder  = Color(0xFF3D2A6E); // Borde tarjetas con acento morado (dark mode)
  static const brandDisabled = Color(0xFF8E24AA); // se usará con opacity en el widget
  static Color brandDisabledColor() => brand.withValues(alpha: 0.35); // botón primario deshabilitado
  static Color brandGhost() => brand.withValues(alpha: 0.10); // fondo ghost variant de IconButton

  // ── Capa 2 · Acento / Esfuerzo (coral-naranja) ────────────────────
  static const effort        = Color(0xFFD85A30); // Retos distancia, RPE alto, ritmo al acabar serie
  static const effortLight   = Color(0xFFF0997B); // Texto sobre fondos oscuros de esfuerzo
  static const effortSurfaceConst = Color(0xFF2A1208); // Fondo dark de elementos de esfuerzo (const)
  static const effortBorder  = Color(0xFF993C1D); // Borde de elementos de esfuerzo

  // ── Capa 3 · Funcional ────────────────────────────────────────────
  // Descanso / recuperación
  static const rest        = Color(0xFF378ADD);
  static const restLight   = Color(0xFF85B7EB);
  static const restSurface = Color(0xFF0D1825);
  static const restBorder  = Color(0xFF1A3A5A);

  // RPE — NUNCA hardcodear, usar effortColor()
  static const rpeLow  = Color(0xFF5A9E5A); // RPE 1-4, esfuerzo suave
  static const rpeMid  = Color(0xFFEF9F27); // RPE 5-7, esfuerzo moderado
  static const rpeHigh = Color(0xFFD85A30); // RPE 8 (= effort)
  static const rpeMax  = Color(0xFFE24B4A); // RPE 9-10 únicamente

  // ── Feedback de UI (toasts/snackbars) — NO es escala RPE ───────────
  // Semántica de acción del sistema (éxito/error/aviso/info), no de esfuerzo físico.
  static const feedbackSuccess = Color(0xFF10B981); // ModernSnackBar.showSuccess
  static const feedbackError   = Color(0xFFEF4444); // ModernSnackBar.showError
  static const feedbackWarning = Color(0xFFF59E0B); // ModernSnackBar.showWarning
  static const feedbackInfo    = Color(0xFF3B82F6); // ModernSnackBar.showInfo

  // ── Neutros dark mode ─────────────────────────────────────────────
  static const surface   = Color(0xFF1A1A1A); // Fondo tarjetas neutras
  static const surface2  = Color(0xFF1E1E1E); // Fondo tarjetas secundarias
  static const border    = Color(0xFF2A2A2A); // Bordes tarjetas
  static const border2   = Color(0xFF252525); // Bordes secundarios
  static const iconMuted = Color(0xFF555555); // Iconos grises — sin color semántico

  // ── Skeleton shimmer ──────────────────────────────────────────────
  static const skeletonBaseLight  = Color(0xFFE5E7EB);
  static const skeletonBaseDark   = Color(0xFF3A3A3C);
  static const skeletonShineLight = Color(0xFFF3F4F6);
  static const skeletonShineDark  = Color(0xFF48484A);

  // ── Helpers RPE (usar siempre estos, nunca hardcodear) ────────────
  static Color effortColor(double rpe) {
    if (rpe <= 4) return rpeLow;
    if (rpe <= 7) return rpeMid;
    if (rpe <= 8) return effortLight;
    return rpeMax;
  }

  static Color effortSurface(double rpe) {
    if (rpe <= 4) return const Color(0xFF0F1F0F);
    if (rpe <= 7) return const Color(0xFF1F1A08);
    if (rpe <= 8) return const Color(0xFF2A1208);
    return const Color(0xFF2A0808);
  }

  static Color effortBorderColor(double rpe) {
    if (rpe <= 4) return const Color(0xFF3B6D11);
    if (rpe <= 7) return const Color(0xFF854F0B);
    if (rpe <= 8) return const Color(0xFF993C1D);
    return const Color(0xFF791F1F);
  }

  // ── Serie activa ──────────────────────────────────────────────────
  static const serieBackground      = Color(0xFF111111);
  static const serieTimerText       = Color(0xFFFFFFFF);
  static const serieHeaderUnderline = brand;
  static const serieMetricsSecondary = Color(0xFFAAAAAA);
  static const serieButtonFinish    = brand;

  // ── Descanso ──────────────────────────────────────────────────────
  static const descansoBackground   = restSurface;
  static const descansoCountdown    = rest;
  static const descansoResumenBg    = restSurface;
  static const descansoResumenBorder = restBorder;
  static const descansoPaceText     = effortLight;
  static const descansoSkipButton   = rest;

  // ── Config previa (antes de correr) ───────────────────────────────
  static const configCardBg              = surface2;
  static const configValueAccent         = brand;
  static const configToggleOff           = Color(0xFF333333);
  static const configToggleOn            = brandSurface;
  static const configToggleThumb         = brand;
  static const configButtonPrimary       = brand;
  static const configButtonSecondaryBg   = surface2;
  static const configButtonSecondaryBorder = border;

  // ── Home ──────────────────────────────────────────────────────────
  static const homeBannerBg        = brandSurface;
  static const homeBannerBorderLeft = brand;
  static const homeStatsBg         = surface;
  static const homeStatsIcon       = iconMuted;
  static const homeTrainingCardBg  = surface;
  static const homeCommunityCardBg = surface;
  static const homeNavInactive     = Color(0xFF2A2A2A);
  static const homeNavActive       = brand;

  // ── Tokens modo claro — usar resolvers contextOf() en vistas ─────────────
  // ignore: library_private_types_in_public_api
  static const lightBackground   = Color(0xFFF5F5F5);
  static const lightSurface      = Color(0xFFFFFFFF);
  static const lightSurface2     = Color(0xFFF0F0F0);
  static const lightBorder       = Color(0xFFE0E0E0);
  static const lightBorder2      = Color(0xFFD0D0D0);
  static const lightIconMuted    = Color(0xFF888888);
  static const lightTextPrimary  = Color(0xFF1A1A1A);
  static const lightTextSecondary = Color(0xFF666666);

  // ── Resolvers por contexto (dark / light automático) ──────────────────────
  // Usar estos en widgets que deben adaptarse al tema actual.
  static Color background(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF111111) : lightBackground;

  static Color surfaceOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? surface : lightSurface;

  static Color surface2Of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? surface2 : lightSurface2;

  static Color borderOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? border : lightBorder;

  static Color border2Of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? border2 : lightBorder2;

  static Color iconMutedOf(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? iconMuted : lightIconMuted;

  static Color textPrimary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? Colors.white : lightTextPrimary;

  static Color textSecondary(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFFCCCCCC) : lightTextSecondary;

  // ── Aliases de compatibilidad (deprecated — migrar a tokens semánticos) ──
  /// @deprecated Use [surface]
  static const surfaceDark = surface;
  /// @deprecated No light mode
  static const surfaceLight = Colors.white;
  /// @deprecated Use [surface2]
  static const surfaceVariantDark = surface2;
  /// @deprecated No light mode
  static const surfaceVariantLight = Color(0xFFF9FAFB);
  /// @deprecated Use [Color(0xFF111111)] or [serieBackground]
  static const backgroundDark = Color(0xFF111111);
  /// @deprecated No light mode
  static const backgroundLight = Color(0xFFF4F6F8);
  /// @deprecated No light mode
  static const textPrimaryLight = Color(0xFF1C1C1E);
  /// @deprecated Use [Colors.white]
  static const textPrimaryDark = Colors.white;
  /// @deprecated No light mode
  static const textSecondaryLight = Color(0xFF6B7280);
  /// @deprecated Use [serieMetricsSecondary] or [iconMuted]
  static const textSecondaryDark = Color(0xFF8E8E93);
  /// @deprecated No light mode
  static const textTertiaryLight = Color(0xFF9CA3AF);
  /// @deprecated Use [serieMetricsSecondary]
  static const textTertiaryDark = Color(0xFF636366);
  /// @deprecated No light mode
  static const borderLight = Color(0xFFE5E7EB);
  /// @deprecated Use [border]
  static const borderDark = border;
  /// @deprecated Use [brandLight]
  static const brandPurpleLight = brandLight;
  /// @deprecated Use [rpeLow]
  static const paceFast = rpeLow;
  /// @deprecated Use [rpeMid]
  static const paceMedium = rpeMid;
  /// @deprecated Use [rpeMax]
  static const paceSlow = rpeMax;
  /// @deprecated Use [brand]
  static const brandPurple = brand;

  // ── Retos — color según tipo ──────────────────────────────────────
  // Retos — color según tipo
  static const retoDistanciaBg     = Color(0xFF2A1208); // effortSurfaceConst
  static const retoDistanciaAccent = effort;
  static const retoTiempoBg        = Color(0xFF0A1825);
  static const retoTiempoAccent    = rest;
  static const retoRpeBg           = brandSurface;
  static const retoRpeAccent       = brand;
}
