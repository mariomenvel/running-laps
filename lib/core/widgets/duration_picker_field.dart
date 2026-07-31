import 'package:flutter/material.dart';
import 'package:running_laps/core/widgets/wheel_value_field.dart';
import 'package:running_laps/core/widgets/wheel_sheets.dart';

/// Campo de duración **mm:ss** con rueda doble, para marcas personales y
/// cualquier tiempo objetivo. Contraparte de [NumberPickerField] cuando el
/// número es un tiempo y no una magnitud suelta.
///
/// Sustituye al par de `TextField` con `keyboardType: number` que había
/// duplicado en el onboarding y en los ajustes del Coach. Aquel par, además de
/// incumplir la convención de "ningún número se teclea", creaba dos
/// `TextEditingController` **dentro del `build`**: se recreaban en cada
/// reconstrucción y no los liberaba nadie.
///
/// El valor es nullable porque una marca en blanco significa "no la tengo",
/// que no es lo mismo que 00:00. Como la rueda no puede devolver "nada", el
/// botón de limpiar es la única vía de vuelta a ese estado.
class DurationPickerField extends StatelessWidget {
  const DurationPickerField({
    super.key,
    required this.label,
    required this.valueSeconds,
    required this.onChanged,
    this.maxMinutes = 359,
    this.fallbackSeconds = 25 * 60,
    this.labelWidth = 110,
  });

  final String label;

  /// Duración en segundos, o null si no está definida.
  final int? valueSeconds;

  final ValueChanged<int?> onChanged;

  /// Tope de la rueda de minutos. Por defecto 359 (5 h 59 min), de sobra para
  /// un maratón.
  final int maxMinutes;

  /// Dónde arranca la rueda la primera vez, sin valor previo.
  final int fallbackSeconds;

  final double labelWidth;

  static String format(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  Future<void> _openPicker(BuildContext context) async {
    final inicial = (valueSeconds ?? fallbackSeconds).clamp(0, maxMinutes * 60 + 59);
    final elegido = await showDurationWheelSheet(
      context: context,
      initialSeconds: inicial,
      title: label,
      maxMinutes: maxMinutes,
    );
    if (elegido != null) onChanged(elegido);
  }

  @override
  Widget build(BuildContext context) {
    return WheelValueField(
      label: label,
      display: valueSeconds != null ? format(valueSeconds!) : '--:--',
      hasValue: valueSeconds != null,
      labelWidth: labelWidth,
      onTap: () => _openPicker(context),
      onClear: () => onChanged(null),
    );
  }
}

/// Campo de **distancia** con rueda doble (km + hectómetros). Contraparte de
/// [DurationPickerField] cuando el número son metros.
class DistancePickerField extends StatelessWidget {
  const DistancePickerField({
    super.key,
    required this.label,
    required this.valueMeters,
    required this.onChanged,
    this.emptyLabel = '--',
    this.fallbackMeters = 5000,
    this.labelWidth = 110,
  });

  final String label;

  /// Distancia en metros, o null si no está definida.
  final int? valueMeters;

  final ValueChanged<int?> onChanged;

  /// Qué mostrar sin valor (ej. 'Sin límite' en un filtro).
  final String emptyLabel;

  /// Dónde arranca la rueda la primera vez, sin valor previo.
  final int fallbackMeters;

  final double labelWidth;

  /// '7,5 km' para distancias de km o más; '400 m' por debajo.
  static String format(int meters) {
    if (meters < 1000) return '$meters m';
    final km = meters / 1000;
    final texto = km.toStringAsFixed(km == km.roundToDouble() ? 0 : 1);
    return '${texto.replaceAll('.', ',')} km';
  }

  Future<void> _openPicker(BuildContext context) async {
    final elegido = await showDistanceWheelSheet(
      context: context,
      initialMeters: valueMeters ?? fallbackMeters,
      title: label,
    );
    if (elegido != null) onChanged(elegido);
  }

  @override
  Widget build(BuildContext context) {
    return WheelValueField(
      label: label,
      display: valueMeters != null ? format(valueMeters!) : emptyLabel,
      hasValue: valueMeters != null,
      labelWidth: labelWidth,
      onTap: () => _openPicker(context),
      onClear: () => onChanged(null),
    );
  }
}
