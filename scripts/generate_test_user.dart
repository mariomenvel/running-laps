// ignore_for_file: avoid_print
// Script de generación de datos de prueba realistas para Running Laps.
// Ejecutar con: dart run scripts/generate_test_user.dart
//
// Requiere que el proyecto esté configurado con Firebase (firebase_options.dart).
// Crea/reutiliza el usuario test@runninglaps.dev / Test123456!

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';

import 'package:running_laps/firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  print('Generando usuario de prueba realista...');
  await _generateTestUser();
  print('Usuario generado exitosamente');
}

// ─── Constantes ───────────────────────────────────────────────────────────────

const _email    = 'test@runninglaps.dev';
const _password = 'Test123456!';

final _random = Random(42); // seed fijo → reproducible

// ─── Entrada principal ────────────────────────────────────────────────────────

Future<void> _generateTestUser() async {
  final auth      = FirebaseAuth.instance;
  final firestore = FirebaseFirestore.instance;

  // 1. Auth: crear o reutilizar usuario
  final uid = await _ensureUser(auth);
  print('UID: $uid');

  // 2. Documento users/{uid}
  await firestore.collection('users').doc(uid).set({
    'nombre':           'Test Runner',
    'email':            _email,
    'photoUrl':         null,
    'profilePicType':   'none',
    'totalSessions':    0,
    'totalKm':          0.0,
    'totalTimeMinutes': 0.0,
    'lastTrainingDate': null,
    'fcMax':            185,
    'fcReposo':         60,
    'birthDate':        '1990-01-15',
    'sex':              'M',
    'isAdmin':          false,
    'isAthleteMode':    true,
    'createdAt':        FieldValue.serverTimestamp(),
  }, SetOptions(merge: true));
  print('Documento de usuario creado/actualizado');

  // 3. Entrenamientos (últimos 90 días)
  final trainings = _generateTrainings(uid);
  await _saveBatch(firestore, 'users/$uid/trainings', trainings);
  print('${trainings.length} entrenamientos generados');

  // 4. Sesiones planificadas (próximas 4 semanas)
  final planned = _generatePlannedSessions();
  await _saveBatch(firestore, 'users/$uid/athleteSessions', planned);
  print('${planned.length} sesiones planificadas generadas');

  // 5. Plantillas
  final templates = _generateTemplates(uid);
  await _saveBatch(firestore, 'users/$uid/templates', templates);
  print('${templates.length} plantillas generadas');

  // 6. Actualizar stats agregados
  final totalKm  = trainings.fold(0.0, (s, t) => s + (t['distanciaTotalM'] as int) / 1000.0);
  final totalMin = trainings.fold(0, (s, t) => s + ((t['tiempoTotalSec'] as double) / 60).toInt());
  await firestore.collection('users').doc(uid).update({
    'totalSessions':    trainings.length,
    'totalKm':          double.parse(totalKm.toStringAsFixed(2)),
    'totalTimeMinutes': totalMin,
    'lastTrainingDate': DateTime.now().toIso8601String(),
  });

  print('\nResumen:');
  print('  Email:    $_email');
  print('  Password: $_password');
  print('  UID:      $uid');
  print('  km totales: ${totalKm.toStringAsFixed(1)}');
  print('  sesiones:   ${trainings.length}');
  print('  minutos:    $totalMin');
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

// ─── Entrenamientos ───────────────────────────────────────────────────────────

List<Map<String, dynamic>> _generateTrainings(String uid) {
  final now      = DateTime.now();
  final result   = <Map<String, dynamic>>[];

  // Patrón de carga: base + picos + recuperación
  for (int dayBack = 90; dayBack >= 0; dayBack--) {
    final date = now.subtract(Duration(days: dayBack));

    // No entrenar en ~35% de los días; más descanso en domingo
    final restChance = date.weekday == DateTime.sunday ? 0.60 : 0.38;
    if (_random.nextDouble() < restChance) continue;

    final type = _pickType(dayBack, date.weekday);
    result.add(_buildTraining(date, type));
  }

  return result;
}

String _pickType(int daysAgo, int weekday) {
  // Martes/jueves → series/tempo más probable; sábado → largo
  if (weekday == DateTime.saturday) return 'largo';
  if (weekday == DateTime.tuesday || weekday == DateTime.thursday) {
    return _random.nextDouble() < 0.5 ? 'series' : 'tempo';
  }
  // Resto: mayormente rodaje con algo de variedad
  final r = _random.nextDouble();
  if (r < 0.60) return 'rodaje';
  if (r < 0.75) return 'tempo';
  if (r < 0.88) return 'series';
  return 'largo';
}

Map<String, dynamic> _buildTraining(DateTime date, String type) {
  final (distM, durMin, rpe, serieCount, tags) = _typeParams(type);

  // Añadir variación aleatoria ±15%
  final variation = 0.85 + _random.nextDouble() * 0.30;
  final finalDistM = (distM * variation).toInt();
  final finalDurMin = (durMin * variation).toInt().clamp(5, 300);

  final series = _buildSeries(finalDistM, finalDurMin * 60.0, serieCount, rpe);

  final tiempoTotalSec = series.fold(0.0, (s, e) => s + (e['tiempoSec'] as double));
  final distanciaTotalM = series.fold(0, (s, e) => s + (e['distanciaM'] as int));
  final rpePromedio = series.fold(0.0, (s, e) => s + (e['rpe'] as double)) / series.length;
  final loadScore = (distanciaTotalM / 1000.0) * rpePromedio * 10;
  final fcMedia = 138.0 + _random.nextInt(25);

  // Usar tipos compatibles con Entrenamiento.fromMap()
  return {
    'titulo':           _capitalize(type),
    'fecha':            date.toIso8601String(),
    'gps':              _random.nextDouble() > 0.25,
    'series':           series,
    'distanciaTotalM':  distanciaTotalM,
    'tiempoTotalSec':   tiempoTotalSec,
    'rpePromedio':      double.parse(rpePromedio.toStringAsFixed(1)),
    'ritmoMedioSecKm':  distanciaTotalM > 0
        ? (tiempoTotalSec / (distanciaTotalM / 1000.0)).toInt()
        : null,
    'loadScore':        double.parse(loadScore.toStringAsFixed(1)),
    'fcMediaSesion':    fcMedia,
    'isManual':         _random.nextDouble() > 0.75,
    'tags':             tags,
    'notas':            null,
    'createdAt':        date.toIso8601String(),
    'updatedAt':        date.toIso8601String(),
  };
}

// Devuelve (distanciaM, duracionMin, rpeBase, numSeries, tags)
(int, int, double, int, List<String>) _typeParams(String type) {
  switch (type) {
    case 'series':
      return (6000 + _random.nextInt(3000), 35 + _random.nextInt(15),
          7.5 + _random.nextDouble() * 1.5, 5 + _random.nextInt(4),
          ['series']);
    case 'tempo':
      return (8000 + _random.nextInt(4000), 45 + _random.nextInt(20),
          6.5 + _random.nextDouble() * 1.5, 2 + _random.nextInt(2),
          ['tempo']);
    case 'largo':
      return (16000 + _random.nextInt(9000), 90 + _random.nextInt(40),
          5.0 + _random.nextDouble(), 1,
          ['largo']);
    default: // rodaje
      return (6000 + _random.nextInt(7000), 35 + _random.nextInt(25),
          4.0 + _random.nextDouble() * 1.5, 1 + _random.nextInt(2),
          ['rodaje']);
  }
}

List<Map<String, dynamic>> _buildSeries(
  int totalDistM, double totalTimeSec, int count, double baseRpe,
) {
  final distPerSerie = totalDistM ~/ count;
  final timePerSerie = totalTimeSec / count;

  return List.generate(count, (_) {
    final rpe = (baseRpe + (_random.nextDouble() - 0.5)).clamp(1.0, 10.0);
    return {
      'distanciaM':  distPerSerie,
      'tiempoSec':   double.parse(timePerSerie.toStringAsFixed(1)),
      'descansoSec': count > 2 ? 60 + _random.nextInt(60) : 0,
      'rpe':         double.parse(rpe.toStringAsFixed(1)),
      'fcMedia':     138.0 + _random.nextInt(30),
      'usedGps':     _random.nextBool(),
    };
  });
}

// ─── Sesiones planificadas ────────────────────────────────────────────────────

List<Map<String, dynamic>> _generatePlannedSessions() {
  final now     = DateTime.now();
  final result  = <Map<String, dynamic>>[];

  for (int i = 1; i <= 28; i++) {
    final date = now.add(Duration(days: i));
    // Solo lunes-sábado; descanso domingo; saltar ~20% de días
    if (date.weekday == DateTime.sunday) continue;
    if (_random.nextDouble() > 0.80) continue;

    final type     = _pickType(0, date.weekday);
    final category = _typeToCategory(type);
    final distM    = 3000 + _random.nextInt(8000);

    final dateStr = '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';

    result.add({
      'date':     dateStr,
      'time':     '${6 + _random.nextInt(13)}:00',
      'category': category,
      'status':   'planned',
      'blocks': [
        {
          'type':            'continuousDistance',
          'distanceM':       distM,
          'targetPaceMinMin': 5,
          'targetPaceMaxMin': 6,
          'targetRpe':       5.0,
        }
      ],
      'planningNotes': null,
      'createdAt':     DateTime.now().toIso8601String(),
      'updatedAt':     DateTime.now().toIso8601String(),
    });
  }

  return result;
}

String _typeToCategory(String type) => switch (type) {
  'series' => 'series_medias',
  'tempo'  => 'tempo',
  'largo'  => 'rodaje_largo',
  _        => 'rodaje_base',
};

// ─── Plantillas ───────────────────────────────────────────────────────────────

List<Map<String, dynamic>> _generateTemplates(String uid) => [
  _template('5×1000m con descanso 90s', 'series', [
    for (int i = 0; i < 5; i++) ...[
      _block('distance', 1000, pace: [4, 30, 4, 45]),
      if (i < 4) _block('time', 90, isRest: true),
    ],
  ]),
  _template('Rodaje base 8km', 'rodaje', [
    _block('distance', 8000, pace: [5, 15, 5, 45]),
  ]),
  _template('Tempo 3×2km', 'tempo', [
    _block('distance', 2000, pace: [4, 30, 4, 45]),
    _block('time', 120, isRest: true),
    _block('distance', 2000, pace: [4, 30, 4, 45]),
    _block('time', 120, isRest: true),
    _block('distance', 2000, pace: [4, 30, 4, 45]),
  ]),
  _template('Largo 20km', 'largo', [
    _block('distance', 20000, pace: [5, 30, 6, 0]),
  ]),
  _template('Fartlek 45min', 'rodaje', [
    _block('time', 2700, pace: [5, 0, 5, 30]),
  ]),
];

Map<String, dynamic> _template(
  String nombre, String type, List<Map<String, dynamic>> blocks,
) => {
  'nombre':     nombre,
  'tipo':       type,
  'blocks':     blocks,
  'createdAt':  DateTime.now().toIso8601String(),
  'updatedAt':  DateTime.now().toIso8601String(),
};

Map<String, dynamic> _block(
  String type, int value, {
  List<int> pace = const [],
  bool isRest = false,
}) => {
  'type':    type,
  'value':   value,
  'isRest':  isRest,
  if (pace.length == 4) 'alerts': {
    'paceMinMin': pace[0],
    'paceMinSec': pace[1],
    'paceMaxMin': pace[2],
    'paceMaxSec': pace[3],
    'enabled':    true,
  },
};

// ─── Helpers ──────────────────────────────────────────────────────────────────

Future<void> _saveBatch(
  FirebaseFirestore fs, String collectionPath, List<Map<String, dynamic>> docs,
) async {
  // Firestore batch limit: 500 operaciones
  for (int i = 0; i < docs.length; i += 400) {
    final chunk = docs.sublist(i, (i + 400).clamp(0, docs.length));
    final batch  = fs.batch();
    for (final doc in chunk) {
      final ref = fs.collection(collectionPath).doc();
      batch.set(ref, doc);
    }
    await batch.commit();
  }
}

String _capitalize(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';
