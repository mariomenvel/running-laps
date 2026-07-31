import 'package:flutter/material.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/features/templates/data/workout_session.dart';

/// Tema visual de la pantalla de sesión activa.
///
/// **Antes** este fichero definía una paleta hardcodeada distinta por tipo de
/// sesión ("cada tipo tiene su propia personalidad visual"): terracota para
/// series, azul-verde para continuo, marrón para cuestas, dorado para
/// competición… Contradecía COLOR_SYSTEM.md § "Serie activa", que dice
/// `AppColors.brand` sólido para el botón de acción, y metía por la puerta de
/// atrás colores como el teal `0xFF4A90A4`.
///
/// Al revisarlo, además, la mayor parte de esa paleta **no se renderizaba**:
/// `accent()` y `heroMetricStyle()` no tenían un solo call site, y
/// `backgroundDecoration()` devolvía `null` en los seis tipos. Lo único
/// visible eran los seis `primary()` y tres degradados.
///
/// Ahora el acento es el de la marca en todos los tipos. La única distinción
/// que sobrevive es el **modo intenso del fartlek**, y sobrevive porque no es
/// decoración por tipo sino color-como-estado —la misma idea por la que el
/// descanso vira a azul—, y sale de un token (`AppColors.effort`), no de un
/// hex suelto.
abstract class SessionTheme {
  WorkoutType get sessionType;

  /// Acento de la pantalla: botón de acción, iconos, barra de progreso.
  Color primary(BuildContext context);

  Color background(BuildContext context);

  /// Tinte de fondo. Solo el fartlek en modo intenso devuelve algo.
  Gradient? backgroundGradient(BuildContext context);

  /// El fartlek alterna tramos fuertes y suaves; el resto se devuelve a sí
  /// mismo.
  SessionTheme dualMode(bool isHighIntensity) => this;

  factory SessionTheme.forType(WorkoutType type) {
    if (type == WorkoutType.fartlek) return _FartlekTheme();
    return _StandardTheme(type);
  }
}

/// Todos los tipos menos el fartlek: acento de marca, sin tinte de fondo.
class _StandardTheme implements SessionTheme {
  _StandardTheme(this.sessionType);

  @override
  final WorkoutType sessionType;

  // brandOf y no brand a secas: `primary` tiñe sobre todo iconos y texto, y en
  // modo oscuro el morado #8E24AA se queda en ~2.5:1 de contraste (regla de
  // COLOR_SYSTEM.md § "contraste del brand"). En claro —el único tema activo
  // hoy— brandOf devuelve exactamente brand.
  @override
  Color primary(BuildContext context) => AppColors.brandOf(context);

  @override
  Color background(BuildContext context) =>
      Theme.of(context).scaffoldBackgroundColor;

  @override
  Gradient? backgroundGradient(BuildContext context) => null;

  @override
  SessionTheme dualMode(bool isHighIntensity) => this;
}

/// Fartlek: el tramo fuerte se tiñe de esfuerzo, el suave es el acento normal.
/// Es el estado lo que colorea, no el tipo de sesión.
class _FartlekTheme implements SessionTheme {
  _FartlekTheme({bool isHighIntensity = false})
      : _isHighIntensity = isHighIntensity;

  final bool _isHighIntensity;

  @override
  WorkoutType get sessionType => WorkoutType.fartlek;

  @override
  Color primary(BuildContext context) =>
      _isHighIntensity ? AppColors.effort : AppColors.brandOf(context);

  @override
  Color background(BuildContext context) =>
      Theme.of(context).scaffoldBackgroundColor;

  @override
  Gradient? backgroundGradient(BuildContext context) {
    if (!_isHighIntensity) return null;
    // Tinte muy leve de arriba abajo: se nota el cambio de tramo sin taparlo.
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        AppColors.effort.withValues(alpha: 0.20),
        AppColors.effort.withValues(alpha: 0.0),
      ],
    );
  }

  @override
  SessionTheme dualMode(bool isHighIntensity) =>
      _FartlekTheme(isHighIntensity: isHighIntensity);
}
