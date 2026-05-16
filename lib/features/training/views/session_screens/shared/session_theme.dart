import 'package:flutter/material.dart';
import 'package:running_laps/core/theme/app_colors.dart';
import 'package:running_laps/features/templates/data/workout_session.dart';

/// Tema visual para una sesión de entrenamiento.
/// Cada tipo de sesión tiene su propia personalidad visual.
abstract class SessionTheme {
  WorkoutType get sessionType;

  // Paleta principal
  Color primary(BuildContext context);
  Color accent(BuildContext context);
  Color background(BuildContext context);
  Gradient? backgroundGradient(BuildContext context);

  // Decoración de fondo (pista, montaña, etc.)
  Widget? backgroundDecoration(BuildContext context);

  // Estilo del texto hero (la métrica grande)
  TextStyle heroMetricStyle(BuildContext context);

  // Modo dual (solo fartlek)
  bool get hasDualMode => false;
  SessionTheme dualMode(bool isHighIntensity) => this;

  /// Factory: devuelve el tema correspondiente al tipo
  factory SessionTheme.forType(WorkoutType type) {
    switch (type) {
      case WorkoutType.intervals:   return _IntervalsTheme();
      case WorkoutType.continuous:  return _ContinuousTheme();
      case WorkoutType.fartlek:     return _FartlekTheme();
      case WorkoutType.hills:       return _HillsTheme();
      case WorkoutType.competition: return _CompetitionTheme();
      case WorkoutType.free:        return _FreeTheme();
    }
  }
}

// ─── INTERVALS — ocre/terracota (tartán de pista) ───
class _IntervalsTheme implements SessionTheme {
  @override
  WorkoutType get sessionType => WorkoutType.intervals;

  @override
  Color primary(BuildContext context) => const Color(0xFFB85C38); // terracota
  @override
  Color accent(BuildContext context) => const Color(0xFF8B3A1F);  // terracota oscuro
  @override
  Color background(BuildContext context) =>
      Theme.of(context).scaffoldBackgroundColor;
  @override
  Gradient? backgroundGradient(BuildContext context) => null;
  @override
  Widget? backgroundDecoration(BuildContext context) => null;
  @override
  TextStyle heroMetricStyle(BuildContext context) => TextStyle(
        fontSize: 88,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary(context),
        height: 1.0,
      );
  @override
  bool get hasDualMode => false;
  @override
  SessionTheme dualMode(bool isHighIntensity) => this;
}

// ─── CONTINUOUS — azul-verde suave, sin gradient (calma, constancia) ───
class _ContinuousTheme implements SessionTheme {
  @override
  WorkoutType get sessionType => WorkoutType.continuous;

  @override
  Color primary(BuildContext context) => const Color(0xFF4A90A4); // azul-verde
  @override
  Color accent(BuildContext context) => const Color(0xFF6BA88A);  // verde tranquilo
  @override
  Color background(BuildContext context) =>
      Theme.of(context).scaffoldBackgroundColor;
  @override
  Gradient? backgroundGradient(BuildContext context) => null;
  @override
  Widget? backgroundDecoration(BuildContext context) => null;
  @override
  TextStyle heroMetricStyle(BuildContext context) => TextStyle(
        fontSize: 96,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary(context),
        height: 1.0,
      );
  @override
  bool get hasDualMode => false;
  @override
  SessionTheme dualMode(bool isHighIntensity) => this;
}

// ─── FARTLEK — DUAL (rápido/suave) ───
class _FartlekTheme implements SessionTheme {
  final bool _isHighIntensity;
  _FartlekTheme({bool isHighIntensity = false})
      : _isHighIntensity = isHighIntensity;

  @override
  WorkoutType get sessionType => WorkoutType.fartlek;

  @override
  Color primary(BuildContext context) => _isHighIntensity
      ? const Color(0xFFE76F51) // naranja intenso
      : const Color(0xFF4A90A4); // azul tranquilo
  @override
  Color accent(BuildContext context) => _isHighIntensity
      ? const Color(0xFFD62828) // rojo
      : const Color(0xFF7FB069); // verde
  @override
  Color background(BuildContext context) =>
      Theme.of(context).scaffoldBackgroundColor;
  @override
  Gradient? backgroundGradient(BuildContext context) => _isHighIntensity
      ? const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x33E76F51), Color(0x00E76F51)],
        )
      : const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x334A90A4), Color(0x004A90A4)],
        );
  @override
  Widget? backgroundDecoration(BuildContext context) => null;
  @override
  TextStyle heroMetricStyle(BuildContext context) => TextStyle(
        fontSize: 88,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary(context),
        height: 1.0,
      );
  @override
  bool get hasDualMode => true;
  @override
  SessionTheme dualMode(bool isHighIntensity) =>
      _FartlekTheme(isHighIntensity: isHighIntensity);
}

// ─── HILLS — marrón tierra con gradient hacia rojo arriba (esfuerzo creciente) ───
class _HillsTheme implements SessionTheme {
  @override
  WorkoutType get sessionType => WorkoutType.hills;

  @override
  Color primary(BuildContext context) => const Color(0xFF8B5A3C); // marrón tierra
  @override
  Color accent(BuildContext context) => const Color(0xFFC1502E);  // rojo cuesta
  @override
  Color background(BuildContext context) =>
      Theme.of(context).scaffoldBackgroundColor;
  @override
  Gradient? backgroundGradient(BuildContext context) =>
      const LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [Color(0x228B5A3C), Color(0x33C1502E)],
      );
  @override
  Widget? backgroundDecoration(BuildContext context) => null;
  @override
  TextStyle heroMetricStyle(BuildContext context) => TextStyle(
        fontSize: 88,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary(context),
        height: 1.0,
      );
  @override
  bool get hasDualMode => false;
  @override
  SessionTheme dualMode(bool isHighIntensity) => this;
}

// ─── COMPETITION — dorado sólido, sin gradient (medalla/trofeo) ───
class _CompetitionTheme implements SessionTheme {
  @override
  WorkoutType get sessionType => WorkoutType.competition;

  @override
  Color primary(BuildContext context) => const Color(0xFFC9A227); // dorado mate
  @override
  Color accent(BuildContext context) => const Color(0xFF8B0000);  // rojo de meta
  @override
  Color background(BuildContext context) =>
      Theme.of(context).scaffoldBackgroundColor;
  @override
  Gradient? backgroundGradient(BuildContext context) => null;
  @override
  Widget? backgroundDecoration(BuildContext context) => null;
  @override
  TextStyle heroMetricStyle(BuildContext context) => TextStyle(
        fontSize: 96,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary(context),
        height: 1.0,
      );
  @override
  bool get hasDualMode => false;
  @override
  SessionTheme dualMode(bool isHighIntensity) => this;
}

// ─── FREE — gris neutro, sin tema (sin objetivo, sin presión) ───
class _FreeTheme implements SessionTheme {
  @override
  WorkoutType get sessionType => WorkoutType.free;

  @override
  Color primary(BuildContext context) => const Color(0xFF6B7280); // gris medio
  @override
  Color accent(BuildContext context) => AppColors.textSecondary(context);
  @override
  Color background(BuildContext context) =>
      Theme.of(context).scaffoldBackgroundColor;
  @override
  Gradient? backgroundGradient(BuildContext context) => null;
  @override
  Widget? backgroundDecoration(BuildContext context) => null;
  @override
  TextStyle heroMetricStyle(BuildContext context) => TextStyle(
        fontSize: 96,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary(context),
        height: 1.0,
      );
  @override
  bool get hasDualMode => false;
  @override
  SessionTheme dualMode(bool isHighIntensity) => this;
}
