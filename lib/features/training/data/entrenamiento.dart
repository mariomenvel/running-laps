import 'serie.dart';

class Entrenamiento {
  final String titulo;
  final DateTime fecha;
  final bool gps;
  final List<Serie> series;

  Entrenamiento({
    required this.titulo,
    required this.fecha,
    required this.gps,
    required this.series,
  });

  int distanciaTotalM() {
    int total = 0;
    for (var serie in series) {
      total += serie.distanciaM;
    }
    return total;
  }

  double tiempoTotalSec() {
    double total = 0;
    for (var serie in series) {
      total += serie.tiempoSec + serie.descansoSec;
    }
    return total;
  }

  double rpePromedio() {
    if (series.isEmpty) return 0;
    double total = 0;
    for (var serie in series) {
      total += serie.rpe;
    }
    return total / series.length;
  }

  int ritmoMedioSecPorKm() {
    final int distanciaM = distanciaTotalM();
    final double tiempoSec = tiempoTotalSec();
    if (distanciaM <= 0) {
      throw StateError('distanciaTotalM debe ser > 0 para calcular ritmo');
    }
    final double km = distanciaM / 1000.0;
    final double secPerKm = tiempoSec / km;
    return secPerKm.round();
  }

  String ritmoMedioTexto() {
    final int secKm = ritmoMedioSecPorKm();
    final int mm = secKm ~/ 60;
    final int ss = secKm % 60;
    final String ss2 = ss < 10 ? '0' + ss.toString() : ss.toString();
    return mm.toString() + ':' + ss2 + ' /km';
  }

  Map<String, dynamic> toMap() {
    final List<Map<String, dynamic>> listaSeries = <Map<String, dynamic>>[];
    for (int i = 0; i < series.length; i = i + 1) {
      listaSeries.add(series[i].toMap());
    }

    final Map<String, dynamic> base = <String, dynamic>{
      'titulo': titulo,
      'fecha': fecha.toIso8601String(),
      'gps': gps,
      'series': listaSeries,
      // Derivadas (opcional pero útil para consultas rápidas):
      'distanciaTotalM': distanciaTotalM(),
      'tiempoTotalSec': tiempoTotalSec(),
      'rpePromedio': rpePromedio(),
    };

    // Si quieres guardar también el ritmo medio (opcional):
    try {
      base['ritmoMedioSecKm'] = ritmoMedioSecPorKm();
    } catch (_) {
      base['ritmoMedioSecKm'] = null; // sin distancia no hay ritmo
    }

    return base;
  }

  static Entrenamiento fromMap(Map<String, dynamic> map) {
    final List<dynamic> rawSeries = map['series'] as List<dynamic>;
    final List<Serie> cargadas = <Serie>[];
    for (int i = 0; i < rawSeries.length; i = i + 1) {
      final Map<String, dynamic> m = rawSeries[i] as Map<String, dynamic>;
      cargadas.add(Serie.fromMap(m));
    }

    final dynamic f = map['fecha'];
    final DateTime fechaParsed = _parseFechaFlexible(f);

    return Entrenamiento(
      titulo: map['titulo'] as String,
      fecha: fechaParsed,
      gps: map['gps'] as bool,
      series: cargadas,
    );
  }

  // Acepta ISO-8601 (String) o miliSecundos epoch (int).
  static DateTime _parseFechaFlexible(dynamic v) {
    if (v is String) {
      return DateTime.parse(v);
    }
    if (v is int) {
      return DateTime.fromMillisecondsSinceEpoch(v);
    }
    // Si más adelante usas Timestamp de Firestore, adapta aquí.
    // Por ahora, fallback:
    return DateTime.now();
  }
}
