class Serie {
  final double tiempoSec;   // tiempo activo de la serie (Secundos)
  final int distanciaM;     // distancia recorrida en metros (>= 1 para ritmo)
  final int descansoSec;    // descanso en Secundos (obligatorio; si no hay, 0)
  final double rpe;         // escala 1..10 (puede ser decimal)
  
  // Campos GPS opcionales
  final bool? usedGps;           // ¿Se activó GPS para esta serie?
  final bool? usedGpsDistance;   // ¿Se eligió la distancia GPS al guardar?
  final List<Map<String, dynamic>>? gpsPoints;  // Puntos GPS del recorrido
  
  // New: timestamp for when series finished 
  final DateTime? finishedAt; 

  Serie({
    required this.tiempoSec,
    required this.distanciaM,
    required this.descansoSec,
    required this.rpe,
    this.usedGps,
    this.usedGpsDistance,
    this.gpsPoints,
    this.finishedAt,
  }):assert(tiempoSec >= 0),
     assert(distanciaM >= 0),
     assert(descansoSec >= 0),
     assert(rpe >= 1 && rpe <= 10);


  /// Secundos por kilómetro (ritmo) como entero.
  /// Lanza excepción si distancia es 0 o negativa.
  int ritmoSecPorKm() {
    if (distanciaM <= 0) {
      throw StateError('distanciaM debe ser > 0 para calcular ritmo');
    }
    final double km = distanciaM / 1000.0;
    final double secPerKm = tiempoSec / km;
    return secPerKm.round(); // o .toInt() si prefieres truncar
  }


  /// Ritmo formateado "mm:ss /km"
  String ritmoTexto() {
    final int secKm = ritmoSecPorKm();
    final int mm = secKm ~/ 60;
    final int ss = secKm % 60;
    final String ss2 = ss < 10 ? '0' + ss.toString() : ss.toString();
    return mm.toString() + ':' + ss2 + ' /km';
  }


  Map<String, dynamic> toMap() {
    // Por defecto NO guardo el ritmo; es derivado.
    // Si quieres guardarlo también para consultas rápidas:
    // 'ritmoSecKm': ritmoSecPorKm(),
    return <String, dynamic>{
      'tiempoSec': tiempoSec,
      'distanciaM': distanciaM,
      'descansoSec': descansoSec,
      'rpe': rpe,
      if (usedGps != null) 'usedGps': usedGps,
      if (usedGpsDistance != null) 'usedGpsDistance': usedGpsDistance,
      if (gpsPoints != null) 'gpsPoints': gpsPoints,
      if (finishedAt != null) 'finishedAt': finishedAt!.toIso8601String(),
    };
  }


  static Serie fromMap(Map<String, dynamic> map) {
    return Serie(
      tiempoSec: (map['tiempoSec'] as num).toDouble(),
      distanciaM: (map['distanciaM'] as num).toInt(),
      descansoSec: (map['descansoSec'] as num).toInt(),
      rpe: (map['rpe'] as num).toDouble(),
      usedGps: map['usedGps'] as bool?,
      usedGpsDistance: map['usedGpsDistance'] as bool?,
      gpsPoints: map['gpsPoints'] != null 
        ? List<Map<String, dynamic>>.from(map['gpsPoints'] as List)
        : null,
      finishedAt: map['finishedAt'] != null 
          ? DateTime.tryParse(map['finishedAt']) 
          : null,
    );
  }
}




