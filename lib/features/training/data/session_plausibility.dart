/// ¿Tiene sentido esta sesión, o el cronómetro se quedó corriendo?
///
/// El cronómetro de la sesión mide **tiempo de reloj**, no tiempo corriendo:
/// si alguien empieza un entreno y se olvida de terminarlo, la sesión sigue
/// contando con el móvil en el bolsillo. En el historial apareció un "Rodaje
/// 45 min" de **17 h 06 m y 0,0 km**.
///
/// No es solo una fila fea en el historial: ese tiempo entra en el volumen
/// semanal, en el TRIMP, en la distribución de intensidad y en el contexto que
/// lee el Coach IA, que planifica la semana siguiente a partir de ahí. Una
/// sesión así desplaza la carga del atleta durante semanas.
///
/// Esto **no corrige el dato ni lo descarta**: solo lo señala para que la
/// persona decida. Recortar el tiempo por nuestra cuenta sería inventarnos un
/// entreno que no sabemos cómo fue.
library;

/// Motivo por el que una sesión parece mal medida.
enum ImplausibleReason {
  /// Mucho tiempo sin apenas distancia — el caso del cronómetro olvidado.
  sinDistancia,

  /// Ritmo más lento que andar, sostenido durante mucho rato.
  ritmoImposible,

  /// Duración fuera de lo que dura un entreno, incluso uno muy largo.
  duracionExcesiva,
}

class ImplausibleSession {
  const ImplausibleSession(this.reason, this.message);

  final ImplausibleReason reason;

  /// Texto para enseñar al atleta, en su idioma y sin jerga.
  final String message;
}

/// Umbrales. Deliberadamente generosos: es preferible dejar pasar una sesión
/// rara a acusar de error a alguien que de verdad hizo una tirada larga.
class SessionPlausibility {
  /// Nadie corre más de esto de una sentada. Un maratón popular ronda las 5 h;
  /// se deja margen de sobra para ultras y marchas.
  static const maxDurationHours = 9;

  /// Por debajo de esta distancia consideramos que no hubo desplazamiento.
  static const minMeters = 200;

  /// Media hora quieto ya no es un despiste, es un cronómetro olvidado.
  static const maxStillMinutes = 30;

  /// Andar rápido ronda los 10 min/km; andar despacio, 15. Por encima de 25
  /// min/km sostenidos durante más de una hora, no se estaba entrenando.
  static const maxPaceSecPerKm = 25 * 60;
  static const minHoursForPaceCheck = 1;

  /// Devuelve null si la sesión es plausible.
  static ImplausibleSession? check({
    required double durationSec,
    required int distanceM,
  }) {
    if (durationSec <= 0) return null;

    final horas = durationSec / 3600;

    if (horas > maxDurationHours) {
      return ImplausibleSession(
        ImplausibleReason.duracionExcesiva,
        'Esta sesión dura ${_horasYMinutos(durationSec)}. ¿Se quedó el '
        'cronómetro en marcha?',
      );
    }

    if (distanceM < minMeters && durationSec / 60 > maxStillMinutes) {
      return ImplausibleSession(
        ImplausibleReason.sinDistancia,
        'Esta sesión dura ${_horasYMinutos(durationSec)} y apenas registra '
        'distancia. ¿Se quedó el cronómetro en marcha?',
      );
    }

    if (distanceM >= minMeters && horas > minHoursForPaceCheck) {
      final ritmo = durationSec / (distanceM / 1000);
      if (ritmo > maxPaceSecPerKm) {
        return ImplausibleSession(
          ImplausibleReason.ritmoImposible,
          'El ritmo de esta sesión es más lento que caminar durante '
          '${_horasYMinutos(durationSec)}. ¿Se quedó el cronómetro en marcha?',
        );
      }
    }

    return null;
  }

  static String _horasYMinutos(double segundos) {
    final total = segundos.round();
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    if (h == 0) return '$m min';
    return m == 0 ? '${h}h' : '${h}h ${m}min';
  }
}
