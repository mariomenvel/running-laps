/// Tipos de datos puros para series temporales (pace, FC...) extraídas de un
/// entrenamiento. Viven en la capa de datos para que los extractores y sus
/// tests no dependan de widgets (fl_chart).
library;

/// Punto temporal genérico — eje X en segundos desde inicio
class TemporalPoint {
  final double tSec;   // tiempo en segundos
  final double value;  // valor (pace, bpm, etc.)

  const TemporalPoint({required this.tSec, required this.value});
}

/// Marcador vertical (línea + label) para indicar eventos
class TemporalMarker {
  final double tSec;
  final String label;

  const TemporalMarker({required this.tSec, required this.label});
}
