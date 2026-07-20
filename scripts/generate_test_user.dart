// ignore_for_file: avoid_print
// Script de generación de datos de prueba realistas para Running Laps.
//
// Ejecutar con (necesita plataforma con plugins Firebase — usar Chrome):
//   flutter run -t scripts/generate_test_user.dart -d chrome
//
// Crea/reutiliza el usuario test@runninglaps.dev / Test123456! y regenera
// TODOS sus datos (borra trainings/athleteSessions/templates/tags previos):
//
//   - 6 meses de entrenamientos con periodización real (3 semanas carga + 1
//     descarga), progresión de ritmo (~5:50 → ~5:15 /km en rodaje) y 4
//     competiciones (5K y 10K) con marcas que mejoran → rellenan los récords.
//   - Series con calentamiento/intervalos/vuelta a la calma, RPE coherente,
//     FC media + fcReadings punto a punto (gráficas de FC) y gpsPoints
//     sintéticos en los entrenos recientes y carreras (mapas + gráfica ritmo).
//   - Tags de usuario (Rodaje, Series, Tempo, Largo, Cuestas, Competición).
//   - Sesiones planificadas próximas 2 semanas (algunas generadas "por IA",
//     una competición objetivo) → calendario y hub atleta.
//   - Plantillas de entrenamiento con el esquema real de TrainingTemplate.
//   - Perfil + uso del Coach IA (objetivo 10K con fecha = carrera planificada).
//   - Stats agregados en users/{uid}.

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'package:running_laps/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Misma activación de App Check que main.dart — si Firestore tiene App
  // Check con enforcement, un script sin esto recibiría permission-denied
  // aunque las reglas lo permitan.
  if (kIsWeb) {
    await FirebaseAppCheck.instance.activate(
      providerWeb: ReCaptchaV3Provider('6LcH2acsAAAAAGdH2Wi1X39xnD3EB6o40ZsVjnIo'),
    );
  } else if (defaultTargetPlatform == TargetPlatform.android) {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: const AndroidDebugProvider(),
    );
  }

  print('Generando usuario de prueba realista...');
  await _generateTestUser();
  print('Usuario generado exitosamente');
}

// ─── Constantes ───────────────────────────────────────────────────────────────

const _email    = 'test@runninglaps.dev';
const _password = 'Test123456!';
const _nombre   = 'Álex Ferrer';

const _fcMax    = 188.0;
const _fcReposo = 52.0;

// Centro de rutas GPS sintéticas (Parque del Retiro, Madrid)
const _routeLat = 40.41317;
const _routeLon = -3.68307;

// Días de historial y ventana con GPS/FC detallados (docs más pesados)
const _daysBack        = 180;
const _detailedDaysMax = 21;

// Competiciones pasadas: díasAtrás → distancia (m). Las marcas mejoran con
// el tiempo → progresión de récords 5K/10K.
const _raceDays = {150: 5000, 90: 10000, 30: 5000, 10: 10000};

final _random = Random(42); // seed fijo → reproducible

// ─── Entrada principal ────────────────────────────────────────────────────────

Future<void> _generateTestUser() async {
  final auth      = FirebaseAuth.instance;
  final firestore = FirebaseFirestore.instance;

  // 1. Auth: crear o reutilizar usuario
  final uid = await _ensureUser(auth);
  print('UID: $uid');

  // 2. Limpiar datos previos (idempotente: re-ejecutar no duplica)
  for (final col in ['trainings', 'athleteSessions', 'templates', 'tags']) {
    final deleted = await _clearCollection(firestore, 'users/$uid/$col');
    if (deleted > 0) print('  $col: $deleted docs previos eliminados');
  }

  // 3. Documento users/{uid}
  await firestore.collection('users').doc(uid).set({
    'nombre':           _nombre,
    'email':            _email,
    'photoUrl':         null,
    'profilePicType':   'none',
    'fcMax':            _fcMax.toInt(),
    'fcReposo':         _fcReposo.toInt(),
    'birthDate':        '1992-03-14',
    'sex':              'M',
    'isAdmin':          false,
    'isAthleteMode':    true,
    'createdAt':        FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
  print('Documento de usuario creado/actualizado');

  // 4. Tags de usuario (doc id = nombre, como TagManager)
  for (final e in _tagDefs.entries) {
    await firestore
        .collection('users').doc(uid)
        .collection('tags').doc(e.key)
        .set({'name': e.key, 'color': e.value});
  }
  print('${_tagDefs.length} tags creados');

  // 5. Entrenamientos (últimos $_daysBack días)
  final trainings = _generateTrainings();
  await _saveBatch(firestore, 'users/$uid/trainings', trainings);
  print('${trainings.length} entrenamientos generados');

  // 6. Sesiones planificadas (próximas 2 semanas, con carrera objetivo)
  final raceDate = DateTime.now().add(const Duration(days: 13));
  final planned  = _generatePlannedSessions(uid, raceDate);
  await _saveBatch(firestore, 'users/$uid/athleteSessions', planned);
  print('${planned.length} sesiones planificadas generadas');

  // 7. Plantillas (esquema real de TrainingTemplate)
  await _saveBatch(firestore, 'users/$uid/templates', _generateTemplates());
  print('Plantillas generadas');

  // 8. Coach IA: perfil + uso
  await _generateAiCoach(firestore, uid, raceDate);
  print('Perfil del Coach IA generado');

  // 9. Stats agregados
  final totalKm  = trainings.fold(0.0, (s, t) => s + (t['distanciaTotalM'] as int) / 1000.0);
  final totalMin = trainings.fold(0, (s, t) => s + ((t['tiempoTotalSec'] as double) / 60).toInt());
  await firestore.collection('users').doc(uid).update({
    'totalSessions':    trainings.length,
    'totalKm':          double.parse(totalKm.toStringAsFixed(2)),
    'totalTimeMinutes': totalMin,
    'lastTrainingDate': DateTime.now().toUtc().toIso8601String(),
  });

  print('\nResumen:');
  print('  Email:    $_email');
  print('  Password: $_password');
  print('  UID:      $uid');
  print('  km totales: ${totalKm.toStringAsFixed(1)}');
  print('  sesiones:   ${trainings.length}');
}

// ─── Auth ─────────────────────────────────────────────────────────────────────

Future<String> _ensureUser(FirebaseAuth auth) async {
  try {
    final cred = await auth.createUserWithEmailAndPassword(
      email: _email, password: _password,
    );
    print('Usuario Auth creado');
    return cred.user!.uid;
  } on FirebaseAuthException catch (e) {
    if (e.code == 'email-already-in-use') {
      final cred = await auth.signInWithEmailAndPassword(
        email: _email, password: _password,
      );
      print('Usuario Auth ya existe, reutilizando');
      return cred.user!.uid;
    }
    rethrow;
  }
}

// ─── Tags ─────────────────────────────────────────────────────────────────────

const _tagDefs = {
  'Rodaje':      0xFF1976D2, // azul
  'Series':      0xFFE53935, // rojo
  'Tempo':       0xFFFF6F00, // naranja
  'Largo':       0xFF43A047, // verde
  'Cuestas':     0xFF8E24AA, // morado
  'Competición': 0xFFD81B60, // rosa
};

// ─── Entrenamientos ───────────────────────────────────────────────────────────

List<Map<String, dynamic>> _generateTrainings() {
  final today  = DateTime.now();
  final result = <Map<String, dynamic>>[];

  for (int dayBack = _daysBack; dayBack >= 1; dayBack--) {
    final date = DateTime(today.year, today.month, today.day)
        .subtract(Duration(days: dayBack));

    // Progresión de forma: 0.0 (hace 6 meses) → 1.0 (hoy).
    // Ritmo de rodaje: 5:50/km → 5:15/km.
    final t        = (_daysBack - dayBack) / _daysBack;
    final easyPace = 350.0 - 35.0 * t + (_random.nextDouble() - 0.5) * 8;

    final weeksBack = dayBack ~/ 7;
    final recovery  = weeksBack % 4 == 3; // semana de descarga

    Map<String, dynamic>? training;

    if (_raceDays.containsKey(dayBack)) {
      training = _buildRace(date, _raceDays[dayBack]!, easyPace, dayBack);
    } else {
      switch (date.weekday) {
        case DateTime.tuesday:
          training = recovery
              ? _buildRodaje(date, 7000, easyPace)
              : (weeksBack.isEven
                  ? _buildSeriesCortas(date, easyPace)
                  : _buildSeriesLargas(date, easyPace));
          break;
        case DateTime.wednesday:
          training = _buildRodaje(date, 7000 + _random.nextInt(3000), easyPace);
          break;
        case DateTime.thursday:
          training = recovery
              ? _buildRegenerativo(date, easyPace)
              : (weeksBack % 3 == 2
                  ? _buildCuestas(date, easyPace)
                  : _buildTempo(date, easyPace));
          break;
        case DateTime.saturday:
          final largoKm = recovery ? 12.0 : min(13.0 + 9.0 * t, 22.0);
          training = _buildLargo(date, (largoKm * 1000).toInt(), easyPace, t);
          break;
        case DateTime.sunday:
          if (_random.nextDouble() < 0.55) {
            training = _buildRodaje(date, 6000 + _random.nextInt(2000), easyPace + 15);
          }
          break;
        case DateTime.monday:
          if (_random.nextDouble() < 0.15) {
            training = _buildRegenerativo(date, easyPace);
          }
          break;
        default: // viernes: descanso
          break;
      }
    }

    if (training != null) result.add(training);
  }

  return result;
}

// ── Constructores por tipo ────────────────────────────────────────────────────

Map<String, dynamic> _buildRodaje(DateTime date, int distM, double easyPace) {
  final start = _at(date, 7, 45);
  final serie = _serie(start, distM, easyPace, rpe: 3.6 + _random.nextDouble(),
      fc: 142, detailed: _isDetailed(date));
  return _training('Rodaje ${_km(distM)}', start, [serie], ['Rodaje'],
      notas: _maybeNota());
}

Map<String, dynamic> _buildRegenerativo(DateTime date, double easyPace) {
  final start = _at(date, 8, 0);
  final serie = _serie(start, 5000, easyPace + 25,
      rpe: 2.5 + _random.nextDouble() * 0.6, fc: 128, detailed: _isDetailed(date));
  return _training('Regenerativo 5 km', start, [serie], ['Rodaje']);
}

Map<String, dynamic> _buildLargo(DateTime date, int distM, double easyPace, double t) {
  final start = _at(date, 9, 0);
  final serie = _serie(start, distM, easyPace + 8,
      rpe: 5.0 + t * 1.5 + _random.nextDouble() * 0.5, fc: 152,
      detailed: _isDetailed(date));
  return _training('Tirada larga ${_km(distM)}', start, [serie], ['Largo'],
      notas: _maybeNota());
}

Map<String, dynamic> _buildSeriesCortas(DateTime date, double easyPace) {
  final start    = _at(date, 18, 30);
  final detailed = _isDetailed(date);
  final series   = <Map<String, dynamic>>[
    _serie(start, 2000, easyPace + 15, rpe: 3.0, fc: 135,
        descanso: 60, detailed: detailed),
  ];
  var cursor = start.add(const Duration(minutes: 13));
  for (int i = 0; i < 10; i++) {
    series.add(_serie(cursor, 400, easyPace - 80,
        rpe: 7.5 + i * 0.17, fc: 168 + i.toDouble(),
        descanso: 75, detailed: detailed));
    cursor = cursor.add(const Duration(minutes: 3));
  }
  series.add(_serie(cursor, 1500, easyPace + 20, rpe: 3.0, fc: 140,
      detailed: detailed));
  return _training('Series 10×400 m', start, series, ['Series'],
      notas: _maybeNota());
}

Map<String, dynamic> _buildSeriesLargas(DateTime date, double easyPace) {
  final start    = _at(date, 18, 30);
  final detailed = _isDetailed(date);
  final series   = <Map<String, dynamic>>[
    _serie(start, 2000, easyPace + 15, rpe: 3.0, fc: 135,
        descanso: 60, detailed: detailed),
  ];
  var cursor = start.add(const Duration(minutes: 13));
  for (int i = 0; i < 5; i++) {
    series.add(_serie(cursor, 1000, easyPace - 65,
        rpe: 7.5 + i * 0.3, fc: 168 + i * 2.0,
        descanso: 90, detailed: detailed));
    cursor = cursor.add(const Duration(minutes: 6));
  }
  series.add(_serie(cursor, 1500, easyPace + 20, rpe: 3.2, fc: 142,
      detailed: detailed));
  return _training('Series 5×1000 m', start, series, ['Series'],
      notas: _maybeNota());
}

Map<String, dynamic> _buildTempo(DateTime date, double easyPace) {
  final start    = _at(date, 18, 45);
  final detailed = _isDetailed(date);
  final series   = <Map<String, dynamic>>[
    _serie(start, 2000, easyPace + 15, rpe: 3.0, fc: 135,
        descanso: 60, detailed: detailed),
  ];
  var cursor = start.add(const Duration(minutes: 13));
  for (int i = 0; i < 3; i++) {
    series.add(_serie(cursor, 2000, easyPace - 45,
        rpe: 6.6 + i * 0.35, fc: 163 + i * 1.5,
        descanso: 120, detailed: detailed));
    cursor = cursor.add(const Duration(minutes: 11));
  }
  series.add(_serie(cursor, 1500, easyPace + 20, rpe: 3.2, fc: 144,
      detailed: detailed));
  return _training('Tempo 3×2 km', start, series, ['Tempo']);
}

Map<String, dynamic> _buildCuestas(DateTime date, double easyPace) {
  final start    = _at(date, 18, 30);
  final detailed = _isDetailed(date);
  final series   = <Map<String, dynamic>>[
    _serie(start, 2000, easyPace + 15, rpe: 3.0, fc: 135,
        descanso: 60, detailed: detailed),
  ];
  var cursor = start.add(const Duration(minutes: 13));
  for (int i = 0; i < 8; i++) {
    series.add(_serie(cursor, 200, easyPace - 60, // cuesta: ritmo "lento" pero RPE alto
        rpe: 8.0 + i * 0.15, fc: 170 + i.toDouble(),
        descanso: 90, detailed: detailed));
    cursor = cursor.add(const Duration(minutes: 3));
  }
  series.add(_serie(cursor, 1500, easyPace + 20, rpe: 3.0, fc: 141,
      detailed: detailed));
  return _training('Cuestas 8×200 m', start, series, ['Series', 'Cuestas']);
}

Map<String, dynamic> _buildRace(
    DateTime date, int distM, double easyPace, int dayBack) {
  final start = _at(date, 9, 30);
  // Ritmo de competición: 5K más rápido que 10K; ambos mejoran con la forma.
  final racePace = distM == 5000 ? easyPace - 70 : easyPace - 55;
  final warmup = _serie(start.subtract(const Duration(minutes: 25)), 1500,
      easyPace + 15, rpe: 3.0, fc: 138, descanso: 300, detailed: true);
  final race = _serie(start, distM, racePace,
      rpe: 9.3 + _random.nextDouble() * 0.4, fc: 178, detailed: true);
  final timeSec = (race['tiempoSec'] as double).round();
  final label   = distM == 5000 ? '5K' : '10K';
  return _training(
    'Carrera $label — ${_mmss(timeSec)}', start, [warmup, race],
    ['Competición'],
    notas: dayBack <= 30 ? '¡Marca personal! Sensaciones muy buenas.' : null,
  );
}

// ── Ensamblado de doc de entrenamiento ────────────────────────────────────────

Map<String, dynamic> _training(
  String titulo, DateTime fecha, List<Map<String, dynamic>> series,
  List<String> tags, {String? notas}
) {
  final tiempoTotalSec  = series.fold(0.0, (s, e) => s + (e['tiempoSec'] as double));
  final distanciaTotalM = series.fold(0, (s, e) => s + (e['distanciaM'] as int));
  final rpePromedio     = series.fold(0.0, (s, e) => s + (e['rpe'] as double)) / series.length;

  // FC media de sesión ponderada por duración de cada serie
  final fcMediaSesion = series.fold(0.0,
          (s, e) => s + (e['fcMedia'] as double) * (e['tiempoSec'] as double)) /
      tiempoTotalSec;

  // loadScore con la misma fórmula TRIMP que TrainingLoadService
  final ratio = (fcMediaSesion - _fcReposo) / (_fcMax - _fcReposo);
  final load  = (tiempoTotalSec / 60.0) * ratio * 0.64 * exp(1.92 * ratio);

  final fechaUtc = fecha.toUtc().toIso8601String();
  return {
    'titulo':          titulo,
    'fecha':           fechaUtc,
    'gps':             true,
    'series':          series,
    'distanciaTotalM': distanciaTotalM,
    'tiempoTotalSec':  double.parse(tiempoTotalSec.toStringAsFixed(1)),
    'rpePromedio':     double.parse(rpePromedio.toStringAsFixed(1)),
    'ritmoMedioSecKm': (tiempoTotalSec / (distanciaTotalM / 1000.0)).round(),
    'loadScore':       double.parse(load.toStringAsFixed(1)),
    'fcMediaSesion':   double.parse(fcMediaSesion.toStringAsFixed(1)),
    'isManual':        false,
    'tags':            tags,
    if (notas != null) 'notas': notas,
    'createdAt':       fechaUtc,
    'updatedAt':       fechaUtc,
  };
}

/// Serie con FC (readings cada 15 s) y, si [detailed], gpsPoints sintéticos.
Map<String, dynamic> _serie(
  DateTime start, int distM, double paceSecKm, {
  required double rpe,
  required double fc,
  int descanso = 0,
  bool detailed = false,
}) {
  final pace      = paceSecKm + (_random.nextDouble() - 0.5) * 6;
  final tiempoSec = distM / 1000.0 * pace;
  final fcFinal   = fc + (_random.nextDouble() - 0.5) * 6;

  return {
    'tiempoSec':   double.parse(tiempoSec.toStringAsFixed(1)),
    'distanciaM':  distM,
    'descansoSec': descanso,
    'rpe':         double.parse(rpe.clamp(1.0, 10.0).toStringAsFixed(1)),
    'usedGps':     true,
    'fcMedia':     double.parse(fcFinal.toStringAsFixed(1)),
    'finishedAt':  start.add(Duration(seconds: tiempoSec.round())).toUtc().toIso8601String(),
    if (detailed) 'fcReadings': _fcReadings(start, tiempoSec, fcFinal),
    if (detailed) 'gpsPoints':  _gpsRoute(start, distM, tiempoSec),
  };
}

/// Lecturas de FC cada 15 s: rampa inicial + meseta con ruido.
List<Map<String, dynamic>> _fcReadings(
    DateTime start, double tiempoSec, double fcAvg) {
  final n = min(tiempoSec ~/ 15, 80);
  return List.generate(max(n, 3), (i) {
    final progress = i / max(n - 1, 1);
    // Rampa durante el primer 30%, luego meseta ligeramente por encima de la media
    final base = progress < 0.3
        ? fcAvg - 16 + (progress / 0.3) * 18
        : fcAvg + 2;
    final bpm = (base + (_random.nextDouble() - 0.5) * 6).round();
    return {
      'bpm': bpm.clamp(90, _fcMax.toInt()),
      'ts':  start.add(Duration(seconds: i * 15)).toUtc().toIso8601String(),
    };
  });
}

/// Ruta GPS sintética: rumbo que gira suavemente → trazado curvo tipo parque.
/// Incluye 'speed' (m/s) para la gráfica de ritmo del detalle.
List<Map<String, dynamic>> _gpsRoute(DateTime start, int distM, double tiempoSec) {
  const dt = 10.0; // un punto cada 10 s
  final n  = min((tiempoSec / dt).ceil(), 150);
  if (n < 3) return const [];

  final speedAvg = distM / tiempoSec;
  var lat     = _routeLat + (_random.nextDouble() - 0.5) * 0.012;
  var lon     = _routeLon + (_random.nextDouble() - 0.5) * 0.012;
  var heading = _random.nextDouble() * 2 * pi;

  return List.generate(n, (i) {
    final speed = speedAvg * (0.92 + _random.nextDouble() * 0.16);
    heading += 0.055 + (_random.nextDouble() - 0.5) * 0.22;
    final step = speed * dt;
    lat += cos(heading) * step / 111320.0;
    lon += sin(heading) * step / (111320.0 * cos(lat * pi / 180));
    return {
      'latitude':  lat,
      'longitude': lon,
      'altitude':  660.0 + sin(i * 0.1) * 8,
      'timestamp': start.add(Duration(seconds: (i * dt).round())).toUtc().toIso8601String(),
      'speed':     double.parse(speed.toStringAsFixed(2)),
    };
  });
}

// ─── Sesiones planificadas (athleteSessions) ──────────────────────────────────

List<Map<String, dynamic>> _generatePlannedSessions(String uid, DateTime raceDate) {
  final today = DateTime.now();

  Map<String, dynamic> session({
    required int daysAhead,
    required String category,
    required String title,
    required String time,
    required List<Map<String, dynamic>> blocks,
    bool fromAi = false,
    String? rationale,
    String? raceName,
    int? raceDistanceM,
    int? targetTimeSeconds,
  }) {
    final date = today.add(Duration(days: daysAhead));
    final now  = Timestamp.now();
    return {
      'uid':      uid,
      'date':     _yyyymmdd(date),
      'time':     time,
      'category': category,
      'status':   'planned',
      'title':    title,
      'blocks':   blocks,
      'warmup':   {'description': 'Trote suave + movilidad', 'durationMinutes': 15},
      'cooldown': {'description': 'Trote muy suave', 'durationMinutes': 10},
      if (fromAi) 'suggestion': {
        'origin':        'ai',
        'status':        'accepted',
        'rationale':     rationale ?? 'Sesión generada según tu plan semanal.',
        'sourceModel':   'claude-sonnet',
        'estimatedLoad': 60.0 + _random.nextInt(40),
        'generatedAt':   now,
      },
      if (raceName          != null) 'raceName':          raceName,
      if (raceDistanceM     != null) 'raceDistanceM':     raceDistanceM,
      if (targetTimeSeconds != null) 'targetTimeSeconds': targetTimeSeconds,
      'createdAt': now,
      'updatedAt': now,
    };
  }

  Map<String, dynamic> seriesBlock(int order, int reps, int distM, int restSec,
      {int paceMin = 4, int paceSecA = 10, int paceSecB = 25, double rpe = 8.0}) => {
    'id':               'b$order',
    'order':            order,
    'type':             'series',
    'reps':             reps,
    'distanceM':        distM,
    'restSeconds':      restSec,
    'targetPaceMinMin': paceMin, 'targetPaceMinSec': paceSecA,
    'targetPaceMaxMin': paceMin, 'targetPaceMaxSec': paceSecB,
    'targetRpe':        rpe,
    'targetZone':       5,
  };

  Map<String, dynamic> continuousBlock(int order, int distM,
      {int minMin = 5, int minSec = 15, int maxMin = 5, int maxSec = 40,
       double rpe = 4.0, int zone = 2}) => {
    'id':               'b$order',
    'order':            order,
    'type':             'continuous_distance',
    'distanceM':        distM,
    'targetPaceMinMin': minMin, 'targetPaceMinSec': minSec,
    'targetPaceMaxMin': maxMin, 'targetPaceMaxSec': maxSec,
    'targetRpe':        rpe,
    'targetZone':       zone,
  };

  return [
    session(
      daysAhead: 1, category: 'rodaje_base', title: 'Rodaje suave 8 km',
      time: '07:45', blocks: [continuousBlock(0, 8000)],
      fromAi: true,
      rationale: 'Rodaje regenerativo tras la tirada del fin de semana.',
    ),
    session(
      daysAhead: 2, category: 'series_cortas', title: 'Series 10×400 m',
      time: '18:30',
      blocks: [seriesBlock(0, 10, 400, 75, rpe: 8.5)],
      fromAi: true,
      rationale: 'VO2max: repeticiones cortas a ritmo de 5K para afinar de cara a la carrera.',
    ),
    session(
      daysAhead: 4, category: 'tempo', title: 'Tempo 3×2 km',
      time: '18:45',
      blocks: [seriesBlock(0, 3, 2000, 120, paceMin: 4, paceSecA: 35, paceSecB: 45, rpe: 7.0)],
    ),
    session(
      daysAhead: 6, category: 'rodaje_base', title: 'Tirada larga 18 km',
      time: '09:00',
      blocks: [continuousBlock(0, 18000, minMin: 5, minSec: 20, maxMin: 5, maxSec: 45, rpe: 5.5)],
      fromAi: true,
      rationale: 'Última tirada larga antes de empezar la descarga pre-competición.',
    ),
    session(
      daysAhead: 8, category: 'rodaje_base', title: 'Rodaje 7 km',
      time: '07:45', blocks: [continuousBlock(0, 7000)],
    ),
    session(
      daysAhead: 9, category: 'series_largas', title: 'Series 4×1000 m',
      time: '18:30',
      blocks: [seriesBlock(0, 4, 1000, 90, paceMin: 4, paceSecA: 15, paceSecB: 25, rpe: 7.5)],
      fromAi: true,
      rationale: 'Volumen reducido: mantener chispa sin acumular fatiga (semana de descarga).',
    ),
    session(
      daysAhead: 11, category: 'regenerativo', title: 'Regenerativo 5 km',
      time: '08:00',
      blocks: [continuousBlock(0, 5000, minMin: 5, minSec: 50, maxMin: 6, maxSec: 20, rpe: 2.5, zone: 1)],
    ),
    session(
      daysAhead: 13, category: 'competicion', title: '10K Valencia',
      time: '09:00',
      blocks: [continuousBlock(0, 10000, minMin: 4, minSec: 20, maxMin: 4, maxSec: 24, rpe: 9.5, zone: 5)],
      raceName: '10K Valencia', raceDistanceM: 10000,
      targetTimeSeconds: 44 * 60,
    ),
  ];
}

// ─── Plantillas (esquema TrainingTemplate) ────────────────────────────────────

List<Map<String, dynamic>> _generateTemplates() {
  final nowIso = DateTime.now().toUtc().toIso8601String();

  Map<String, dynamic> alerts({bool enabled = false, int paceMin = 4, int paceSec = 30}) => {
    'enabled':         enabled,
    'mode':            'pace',
    'timeMin':         0,
    'timeSec':         0.0,
    'paceMin':         paceMin,
    'paceSec':         paceSec,
    'segmentDistance': 300,
  };

  Map<String, dynamic> block(int order, String type, int value, int rest,
      {Map<String, dynamic>? alertsMap, int? paceMin, int? paceSec, double? rpe}) => {
    'id':          'tb$order',
    'order':       order,
    'type':        type, // 'distance' | 'time'
    'value':       value,
    'restSeconds': rest,
    'alerts':      alertsMap ?? alerts(),
    if (paceMin != null) 'targetPaceMin': paceMin,
    if (paceSec != null) 'targetPaceSec': paceSec,
    if (rpe     != null) 'targetRpe':     rpe,
  };

  Map<String, dynamic> template(String name, int colorValue, String category,
      List<Map<String, dynamic>> blocks, {bool warmupCooldown = false}) => {
    'name':             name,
    'blocks':           blocks,
    'colorValue':       colorValue,
    'isWarmupCooldown': warmupCooldown,
    'category':         category,
    'createdAt':        nowIso,
    'updatedAt':        nowIso,
  };

  return [
    template('10×400 con 75″ rec', 0xFFE53935, 'series_cortas', [
      for (int i = 0; i < 10; i++)
        block(i, 'distance', 400, 75,
            alertsMap: alerts(enabled: true, paceMin: 4, paceSec: 5),
            paceMin: 4, paceSec: 5, rpe: 8.5),
    ]),
    template('5×1000 con 90″ rec', 0xFFFF6F00, 'series_largas', [
      for (int i = 0; i < 5; i++)
        block(i, 'distance', 1000, 90,
            alertsMap: alerts(enabled: true, paceMin: 4, paceSec: 15),
            paceMin: 4, paceSec: 15, rpe: 7.5),
    ]),
    template('Tempo 3×2 km', 0xFF1976D2, 'tempo', [
      for (int i = 0; i < 3; i++)
        block(i, 'distance', 2000, 120,
            alertsMap: alerts(enabled: true, paceMin: 4, paceSec: 40),
            paceMin: 4, paceSec: 40, rpe: 7.0),
    ]),
    template('Cuestas 8×200', 0xFF8E24AA, 'series_cuestas', [
      for (int i = 0; i < 8; i++)
        block(i, 'distance', 200, 90, rpe: 8.5),
    ]),
    template('Calentamiento 15′', 0xFF43A047, 'regenerativo', [
      block(0, 'time', 900, 0, rpe: 3.0),
    ], warmupCooldown: true),
  ];
}

// ─── Coach IA ─────────────────────────────────────────────────────────────────

Future<void> _generateAiCoach(
    FirebaseFirestore firestore, String uid, DateTime raceDate) async {
  final settings = firestore.collection('users').doc(uid).collection('settings');
  final now      = DateTime.now();

  await settings.doc('aiCoachProfile').set({
    'goal':                    'race_10k',
    'goalDescription':         'Bajar de 44:00 en el 10K Valencia',
    'targetDate':              Timestamp.fromDate(raceDate),
    'level':                   'intermediate',
    'availableWeekdays':       [2, 3, 4, 6, 7],
    'preferredWeeklySessions': 5,
    'preferredLongRunWeekday': 6,
    'recurringConstraints':    [],
    'temporaryStatuses':       [],
    'fcMax':                   _fcMax.toInt(),
    'pb5kSeconds':             20 * 60 + 50,
    'pb10kSeconds':            43 * 60 + 40,
    'trainingFocus':           'balanced',
    'createdAt':               Timestamp.fromDate(now.subtract(const Duration(days: 120))),
    'updatedAt':               Timestamp.fromDate(now),
  });

  final periodStart = DateTime(now.year, now.month, 1);
  await settings.doc('aiCoachUsage').set({
    'plan':              'basic',
    'messagesUsed':      3,
    'messagesLimit':     40,
    'previewsGenerated': 1,
    'periodStart':       Timestamp.fromDate(periodStart),
    'periodEnd':         Timestamp.fromDate(DateTime(now.year, now.month + 1, 1)),
  });
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

bool _isDetailed(DateTime date) =>
    DateTime.now().difference(date).inDays <= _detailedDaysMax;

DateTime _at(DateTime day, int hour, int minute) =>
    DateTime(day.year, day.month, day.day, hour, minute);

String _km(int meters) {
  final km = meters / 1000.0;
  return km == km.roundToDouble() ? '${km.toInt()} km'
      : '${km.toStringAsFixed(1)} km';
}

String _mmss(int totalSec) {
  final mm = totalSec ~/ 60;
  final ss = totalSec % 60;
  return '$mm:${ss.toString().padLeft(2, '0')}';
}

String _yyyymmdd(DateTime d) => '${d.year}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

String? _maybeNota() {
  if (_random.nextDouble() > 0.25) return null;
  const notas = [
    'Buenas sensaciones, ritmo cómodo.',
    'Piernas cargadas de la sesión anterior.',
    'Día ventoso, ritmo algo más lento de lo previsto.',
    'Muy buen día, podría haber apretado más.',
    'Molestia leve en el gemelo, vigilar.',
  ];
  return notas[_random.nextInt(notas.length)];
}

Future<int> _clearCollection(
    FirebaseFirestore fs, String collectionPath) async {
  int deleted = 0;
  while (true) {
    final snap = await fs.collection(collectionPath).limit(300).get();
    if (snap.docs.isEmpty) break;
    final batch = fs.batch();
    for (final doc in snap.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    deleted += snap.docs.length;
  }
  return deleted;
}

Future<void> _saveBatch(
  FirebaseFirestore fs, String collectionPath, List<Map<String, dynamic>> docs,
) async {
  // Firestore batch limit: 500 operaciones — pero los docs con gpsPoints
  // pesan; troceamos en 100 para no acercarnos al límite de 10 MB por batch.
  for (int i = 0; i < docs.length; i += 100) {
    final chunk = docs.sublist(i, min(i + 100, docs.length));
    final batch = fs.batch();
    for (final doc in chunk) {
      batch.set(fs.collection(collectionPath).doc(), doc);
    }
    await batch.commit();
  }
}
