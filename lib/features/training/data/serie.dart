class Serie {
  final double tiempoSec;   // tiempo activo de la serie (Secundos)
  final int distanciaM;     // distancia recorrida en metros (>= 1 para ritmo)
  final int descansoSec;    // descanso en Secundos (obligatorio; si no hay, 0)
  final double rpe;         // escala 1..10 (puede ser decimal)


  Serie({
    required this.tiempoSec,
    required this.distanciaM,
    required this.descansoSec,
    required this.rpe,
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
    };
  }


  static Serie fromMap(Map<String, dynamic> map) {
    return Serie(
      tiempoSec: (map['tiempoSec'] as num).toDouble(),
      distanciaM: map['distanciaM'] as int,
      descansoSec: map['descansoSec'] as int,
      rpe: (map['rpe'] as num).toDouble(),
    );
  }
}



