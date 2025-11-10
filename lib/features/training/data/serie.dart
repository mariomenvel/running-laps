// ============================================================
// Clase: Serie
// ------------------------------------------------------------
// Representa una serie o bloque de entrenamiento.
//
// Contiene:
//   - tiempoSec: duración activa de la serie (en segundos)
//   - distanciaM: distancia recorrida en metros
//   - descansoSec: tiempo de descanso posterior (en segundos)
//   - rpe: nivel de esfuerzo percibido (1 a 10, puede ser decimal)
//
// Este modelo se usa dentro de la clase Entrenamiento.
// Ofrece métodos para calcular el ritmo y convertir a/desde Map.
// ============================================================

class Serie {
  // Duración del esfuerzo (en segundos)
  final double tiempoSec;

  // Distancia recorrida (en metros)
  final int distanciaM;

  // Descanso tras la serie (en segundos)
  final int descansoSec;

  // Esfuerzo percibido (escala 1–10, puede ser 6.5, 8.0, etc.)
  final double rpe;

  // ------------------------------------------------------------
  // Constructor clásico
  // ------------------------------------------------------------
  // Incluye aserciones (assert) para garantizar que los datos
  // son coherentes antes de crear el objeto.
  Serie({
    required this.tiempoSec,
    required this.distanciaM,
    required this.descansoSec,
    required this.rpe,
  }) : assert(tiempoSec >= 0),
       assert(distanciaM >= 0),
       assert(descansoSec >= 0),
       assert(rpe >= 1 && rpe <= 10);

  // ------------------------------------------------------------
  // CÁLCULOS
  // ------------------------------------------------------------

  /// Devuelve el ritmo medio de la serie en segundos por kilómetro.
  /// Lanza una excepción si la distancia es 0 o negativa.
  int ritmoSecPorKm() {
    if (distanciaM <= 0) {
      throw StateError('distanciaM debe ser > 0 para calcular ritmo');
    }
    final double km = distanciaM / 1000.0;
    final double secPerKm = tiempoSec / km;
    return secPerKm.round(); // Redondea al segundo más cercano
  }

  /// Devuelve el ritmo formateado como texto, por ejemplo: "4:32 /km"
  String ritmoTexto() {
    final int secKm = ritmoSecPorKm();
    final int mm = secKm ~/ 60;
    final int ss = secKm % 60;
    final String ss2 = ss < 10 ? '0' + ss.toString() : ss.toString();
    return mm.toString() + ':' + ss2 + ' /km';
  }

  // ------------------------------------------------------------
  // SERIALIZACIÓN
  // ------------------------------------------------------------

  /// Convierte el objeto Serie a un Map para guardar en Firestore o JSON.
  /// No incluye el ritmo, porque puede calcularse fácilmente al leer.
  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'tiempoSec': tiempoSec,
      'distanciaM': distanciaM,
      'descansoSec': descansoSec,
      'rpe': rpe,
      // Si quisieras almacenar también el ritmo medio:
      // 'ritmoSecKm': ritmoSecPorKm(),
    };
  }

  /// Crea una Serie a partir de un Map (por ejemplo, leído desde Firestore).
  static Serie fromMap(Map<String, dynamic> map) {
    return Serie(
      tiempoSec: (map['tiempoSec'] as num).toDouble(),
      distanciaM: map['distanciaM'] as int,
      descansoSec: map['descansoSec'] as int,
      rpe: (map['rpe'] as num).toDouble(),
    );
  }
}
