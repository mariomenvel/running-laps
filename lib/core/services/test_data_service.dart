import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

/// Resumen de lo generado, para el aviso de la UI.
class TestDataSummary {
  const TestDataSummary({required this.trainings, required this.totalKm});

  final int trainings;
  final double totalKm;
}

/// Generador de datos de prueba del panel de administración: **borra** los
/// entrenamientos del usuario y los sustituye por un histórico sintético
/// coherente (tipos por día de la semana, RPE y FC plausibles, etiquetas).
///
/// Vivía dentro de `profile_view.dart` hablando con Firestore desde el widget.
/// Solo lo usa la sección de admin.
class TestDataService {
  TestDataService({FirebaseFirestore? firestore})
      : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  /// Borra los entrenamientos del usuario y genera ~55 sesiones realistas
  /// repartidas en los últimos 90 días, más sesiones planificadas de -14 a
  /// +28 días. Devuelve el resumen para que la UI lo muestre.
  Future<TestDataSummary> regenerate(String uid) async {
    final firestore = _db;
    final col = firestore.collection('users').doc(uid).collection('trainings');

    // Borrar entrenamientos existentes
    final existing = await col.limit(500).get();
    final deleteBatch = firestore.batch();
    for (final doc in existing.docs) {
      deleteBatch.delete(doc.reference);
    }
    await deleteBatch.commit();

    // Generar nuevos (misma lógica que el script)
    final random = Random();
    final now = DateTime.now();
    const types = ['rodaje', 'series', 'tempo', 'largo'];

    final trainings = <Map<String, dynamic>>[];
    double totalKm = 0;
    int totalSec = 0;

    for (int dayBack = 90; dayBack >= 0; dayBack--) {
      final date = now.subtract(Duration(days: dayBack));
      final restChance = date.weekday == DateTime.sunday ? 0.60 : 0.38;
      if (random.nextDouble() < restChance) continue;

      final type = (date.weekday == DateTime.saturday)
          ? 'largo'
          : (date.weekday == DateTime.tuesday || date.weekday == DateTime.thursday)
              ? (random.nextBool() ? 'series' : 'tempo')
              : types[random.nextInt(types.length)];

      final (distM, durMin, rpe, serieCount) = switch (type) {
        'series' => (6000 + random.nextInt(3000), 35 + random.nextInt(15),
            7.5 + random.nextDouble() * 1.5, 5 + random.nextInt(4)),
        'tempo'  => (8000 + random.nextInt(4000), 45 + random.nextInt(20),
            6.5 + random.nextDouble() * 1.5, 2),
        'largo'  => (16000 + random.nextInt(9000), 90 + random.nextInt(40),
            5.0 + random.nextDouble(), 1),
        _        => (6000 + random.nextInt(7000), 35 + random.nextInt(25),
            4.0 + random.nextDouble() * 1.5, 1 + random.nextInt(2)),
      };

      final v = 0.85 + random.nextDouble() * 0.30;
      final finalDistM = (distM * v).toInt();
      final finalDurSec = ((durMin * v) * 60).toInt().clamp(300, 18000);
      final distPerSerie = finalDistM ~/ serieCount;
      final secPerSerie = finalDurSec / serieCount;

      final series = List.generate(serieCount, (_) => {
        'distanciaM':  distPerSerie,
        'tiempoSec':   double.parse(secPerSerie.toStringAsFixed(1)),
        'descansoSec': serieCount > 2 ? 60 + random.nextInt(60) : 0,
        'rpe':         double.parse((rpe + (random.nextDouble() - 0.5)).clamp(1.0, 10.0).toStringAsFixed(1)),
        'fcMedia':     138.0 + random.nextInt(30),
        'usedGps':     random.nextBool(),
      });

      final loadScore = (finalDistM / 1000.0) * rpe * 10;
      totalKm += finalDistM / 1000.0;
      totalSec += finalDurSec;

      trainings.add({
        'titulo':          '${type[0].toUpperCase()}${type.substring(1)}',
        'fecha':           date.toIso8601String(),
        'gps':             random.nextDouble() > 0.25,
        'series':          series,
        'distanciaTotalM': finalDistM,
        'tiempoTotalSec':  finalDurSec.toDouble(),
        'rpePromedio':     double.parse(rpe.toStringAsFixed(1)),
        'ritmoMedioSecKm': finalDistM > 0 ? (finalDurSec / (finalDistM / 1000.0)).toInt() : null,
        'loadScore':       double.parse(loadScore.toStringAsFixed(1)),
        'fcMediaSesion':   138.0 + random.nextInt(25),
        'isManual':        random.nextDouble() > 0.75,
        'tags':            _tagsForType(type, random),
        'createdAt':       date.toIso8601String(),
        'updatedAt':       date.toIso8601String(),
      });
    }

    // Guardar en batches de 400
    for (int i = 0; i < trainings.length; i += 400) {
      final chunk = trainings.sublist(i, (i + 400).clamp(0, trainings.length));
      final batch = firestore.batch();
      for (final t in chunk) {
        batch.set(col.doc(), t);
      }
      await batch.commit();
    }

    // Generar sesiones planificadas (próximas 4 semanas)
    await _generatePlannedSessions(firestore, uid, random);

    // Actualizar stats
    await firestore.collection('users').doc(uid).update({
      'totalSessions':    trainings.length,
      'totalKm':          double.parse(totalKm.toStringAsFixed(2)),
      'totalTimeMinutes': totalSec ~/ 60,
      'lastTrainingDate': now.toIso8601String(),
    });

    return TestDataSummary(
      trainings: trainings.length,
      totalKm: totalKm,
    );
  }

  List<String> _tagsForType(String type, Random random) {
    const customExtras = ['pista', 'montaña', 'lluvia'];
    final tags = switch (type) {
      'series' => ['series'],
      'tempo'  => ['tempo'],
      'largo'  => ['largo', 'rodaje'],
      _        => ['rodaje'],
    };
    if (random.nextDouble() < 0.30) {
      tags.add(customExtras[random.nextInt(customExtras.length)]);
    }
    return tags;
  }

  Future<void> _generatePlannedSessions(
    FirebaseFirestore firestore, String uid, Random random,
  ) async {
    // Borrar sesiones planificadas existentes
    final col = firestore.collection('users').doc(uid).collection('athleteSessions');
    final existing = await col.limit(500).get();
    if (existing.docs.isNotEmpty) {
      final deleteBatch = firestore.batch();
      for (final doc in existing.docs) {
        deleteBatch.delete(doc.reference);
      }
      await deleteBatch.commit();
    }

    final now = DateTime.now();
    const categories = ['rodaje_base', 'series_medias', 'tempo', 'rodaje_largo'];
    final sessions = <Map<String, dynamic>>[];

    // -14 días (pasadas, completadas) hasta +28 días (futuras, planificadas)
    for (int i = -14; i <= 28; i++) {
      final date = now.add(Duration(days: i));
      if (date.weekday == DateTime.sunday) continue;
      if (random.nextDouble() > 0.70) continue;

      final isPast   = i < 0;
      final status   = isPast ? 'completed' : 'planned';
      final category = categories[random.nextInt(categories.length)];
      final dateStr  = '${date.year}-'
          '${date.month.toString().padLeft(2, '0')}-'
          '${date.day.toString().padLeft(2, '0')}';

      sessions.add({
        'date':     dateStr,
        'time':     '${6 + random.nextInt(12)}:00',
        'category': category,
        'status':   status,
        if (isPast) 'completedTrainingId': null,
        'blocks': [
          {
            'type':            'continuousDistance',
            'distanceM':       3000 + random.nextInt(5000),
            'targetPaceMinMin': 5,
            'targetPaceMaxMin': 6,
            'targetRpe':       5.0,
          }
        ],
        'planningNotes': null,
        'createdAt':     FieldValue.serverTimestamp(),
        'updatedAt':     FieldValue.serverTimestamp(),
      });
    }

    for (int i = 0; i < sessions.length; i += 400) {
      final chunk = sessions.sublist(i, (i + 400).clamp(0, sessions.length));
      final batch = firestore.batch();
      for (final s in chunk) {
        batch.set(col.doc(), s);
      }
      await batch.commit();
    }
  }
}
