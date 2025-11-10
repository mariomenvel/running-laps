// ============================================================
// Clase: Entrenamiento
// ------------------------------------------------------------
// Representa un entrenamiento completo realizado por el usuario.
//
// Contiene:
//   - título: nombre del entrenamiento ("Series 400m", "Rodaje 5K", etc.)
//   - fecha: día y hora del entrenamiento
//   - gps: si se usó o no GPS para registrar el recorrido
//   - series: lista de objetos Serie (cada una con distancia, tiempo, RPE, descanso...)
// ------------------------------------------------------------
// También ofrece varios métodos de cálculo (distancia total, ritmo medio, etc.)
// y conversión a/desde Map para guardar o leer desde Firestore.
// ============================================================

import 'serie.dart'; // Cada entrenamiento contiene una lista de Series

class Entrenamiento {
  // Propiedades inmutables del entrenamiento
  final String titulo;
  final DateTime fecha;
  final bool gps;
  final List<Serie> series;

  // ------------------------------------------------------------
  // Constructor clásico
  // ------------------------------------------------------------
  Entrenamiento({
    required this.titulo,
    required this.fecha,
    required this.gps,
    required this.series,
  });

  // ------------------------------------------------------------
  // MÉTODOS DE CÁLCULO
  // ------------------------------------------------------------

  // Suma la distancia total de todas las series (en metros)
  int distanciaTotalM() {
    int total = 0;
    for (var serie in series) {
      total += serie.distanciaM;
    }
    return total;
  }

  // Calcula el tiempo total del entrenamiento (en segundos),
  // incluyendo los descansos entre series.
  double tiempoTotalSec() {
    double total = 0;
    for (var serie in series) {
      total += serie.tiempoSec + serie.descansoSec;
    }
    return total;
  }

  // Devuelve el valor promedio del esfuerzo percibido (RPE)
  // de todas las series. Si no hay series, devuelve 0.
  double rpePromedio() {
    if (series.isEmpty) return 0;
    double total = 0;
    for (var serie in series) {
      total += serie.rpe;
    }
    return total / series.length;
  }

  // Calcula el ritmo medio expresado en segundos por kilómetro.
  // Si la distancia total es 0, lanza un error.
  int ritmoMedioSecPorKm() {
    final int distanciaM = distanciaTotalM();
    final double tiempoSec = tiempoTotalSec();

    if (distanciaM <= 0) {
      throw StateError('distanciaTotalM debe ser > 0 para calcular ritmo');
    }

    final double km = distanciaM / 1000.0;
    final double secPerKm = tiempoSec / km;

    return secPerKm.round(); // redondeado al segundo más cercano
  }

  // Devuelve el ritmo medio en formato legible, por ejemplo: "4:35 /km".
  String ritmoMedioTexto() {
    final int secKm = ritmoMedioSecPorKm();
    final int mm = secKm ~/ 60;
    final int ss = secKm % 60;
    final String ss2 = ss < 10 ? '0' + ss.toString() : ss.toString();
    return mm.toString() + ':' + ss2 + ' /km';
  }

  // ------------------------------------------------------------
  // CONVERSIÓN A MAP (para guardar en Firestore)
  // ------------------------------------------------------------

  // Convierte el objeto Entrenamiento a un Map (clave-valor),
  // incluyendo datos derivados para facilitar consultas.
  Map<String, dynamic> toMap() {
    // Convierte cada Serie a un Map
    final List<Map<String, dynamic>> listaSeries = <Map<String, dynamic>>[];
    for (int i = 0; i < series.length; i = i + 1) {
      listaSeries.add(series[i].toMap());
    }

    // Datos base + campos derivados
    final Map<String, dynamic> base = <String, dynamic>{
      'titulo': titulo,
      'fecha': fecha.toIso8601String(),
      'gps': gps,
      'series': listaSeries,
      'distanciaTotalM': distanciaTotalM(),
      'tiempoTotalSec': tiempoTotalSec(),
      'rpePromedio': rpePromedio(),
    };

    // (Opcional) ritmo medio, puede fallar si no hay distancia
    try {
      base['ritmoMedioSecKm'] = ritmoMedioSecPorKm();
    } catch (_) {
      base['ritmoMedioSecKm'] = null; // sin distancia no hay ritmo
    }

    return base;
  }

  // ------------------------------------------------------------
  // CONVERSIÓN DESDE MAP (para leer de Firestore)
  // ------------------------------------------------------------

  static Entrenamiento fromMap(Map<String, dynamic> map) {
    // Carga la lista de series contenida en el documento
    final List<dynamic> rawSeries = map['series'] as List<dynamic>;
    final List<Serie> cargadas = <Serie>[];
    for (int i = 0; i < rawSeries.length; i = i + 1) {
      final Map<String, dynamic> m = rawSeries[i] as Map<String, dynamic>;
      cargadas.add(Serie.fromMap(m));
    }

    // Parseo flexible de la fecha (String ISO o epoch)
    final dynamic f = map['fecha'];
    final DateTime fechaParsed = _parseFechaFlexible(f);

    return Entrenamiento(
      titulo: map['titulo'] as String,
      fecha: fechaParsed,
      gps: map['gps'] as bool,
      series: cargadas,
    );
  }

  // ------------------------------------------------------------
  // MÉTODO PRIVADO: parseo de fecha
  // ------------------------------------------------------------
  // Admite varios formatos: ISO8601 (String) o epoch (int).
  // Es útil para evitar errores si cambian los formatos en Firestore.
  static DateTime _parseFechaFlexible(dynamic v) {
    if (v is String) {
      return DateTime.parse(v);
    }
    if (v is int) {
      return DateTime.fromMillisecondsSinceEpoch(v);
    }
    // Si más adelante se usa Timestamp de Firestore, se puede adaptar aquí.
    return DateTime.now(); // Fallback seguro
  }
}
