import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_laps/features/athlete/data/progress_repository.dart';
import 'package:running_laps/features/training/data/entrenamiento.dart';
import 'package:running_laps/features/training/data/serie.dart';
import 'package:running_laps/features/training/data/training_repository.dart';

/// Récords personales: el rollup cacheado en
/// `users/{uid}/settings/personalRecordsRollup`.
///
/// Es una optimización (evita reescanear el historial en cada guardado) y por
/// eso mismo es peligrosa: si se equivoca, muestra marcas falsas sin que nada
/// falle. Estos tests fijan las dos cosas que importan — cuándo un entreno
/// mejora un récord y cuándo NO debe tocarlo.
class _TestableTrainingRepo extends TrainingRepository {
  // El sync de retos se inyecta también: su constructor por defecto toca
  // FirebaseFirestore.instance y en un test no hay Firebase inicializado.
  _TestableTrainingRepo({required FakeFirebaseFirestore firestore})
      : super(firestore: firestore);

  @override
  String? get currentUserId => _uid;
}

const _uid = 'test-uid-records';

void main() {
  late FakeFirebaseFirestore db;
  late ProgressRepository repo;

  setUp(() {
    db = FakeFirebaseFirestore();
    repo = ProgressRepository(
      firestore: db,
      trainingRepository: _TestableTrainingRepo(firestore: db),
    );
  });

  Entrenamiento trainingWith({
    required String id,
    required int distanciaM,
    required double tiempoSec,
    DateTime? fecha,
  }) {
    return Entrenamiento(
      id: id,
      titulo: 'Serie',
      fecha: fecha ?? DateTime(2026, 7, 10, 18),
      gps: true,
      series: [
        Serie(
          tiempoSec: tiempoSec,
          distanciaM: distanciaM,
          descansoSec: 60,
          rpe: 7,
        ),
      ],
    );
  }

  Future<void> seedRollup(int distanceM, double paceSecPerKm) async {
    await db
        .collection('users').doc(_uid)
        .collection('settings').doc('personalRecordsRollup')
        .set({
      'records': {
        '$distanceM': {
          'paceSecPerKm': paceSecPerKm,
          'date': DateTime(2026, 1, 1).toIso8601String(),
          'trainingId': 'viejo',
        },
      },
      'updatedAt': DateTime(2026, 1, 1).toIso8601String(),
    });
  }

  Future<Map<String, dynamic>?> readRollupRaw() async {
    final snap = await db
        .collection('users').doc(_uid)
        .collection('settings').doc('personalRecordsRollup')
        .get();
    return snap.data()?['records'] as Map<String, dynamic>?;
  }

  group('updateRollupAfterSave', () {
    test('un ritmo mejor sustituye el récord y lo devuelve como mejorado',
        () async {
      await seedRollup(1000, 300); // 5:00/km en 1000 m

      final improved = await repo.updateRollupAfterSave(
        _uid,
        // 1000 m en 4:30 → 270 s/km
        trainingWith(id: 'nuevo', distanciaM: 1000, tiempoSec: 270),
      );

      expect(improved.keys, [1000]);
      expect(improved[1000]!.paceSecPerKm, 270);
      expect(improved[1000]!.trainingId, 'nuevo');

      final stored = await readRollupRaw();
      expect(stored!['1000']['paceSecPerKm'], 270);
    });

    test('un ritmo peor no toca el rollup ni devuelve nada', () async {
      await seedRollup(1000, 270);

      final improved = await repo.updateRollupAfterSave(
        _uid,
        trainingWith(id: 'peor', distanciaM: 1000, tiempoSec: 330),
      );

      expect(improved, isEmpty);
      final stored = await readRollupRaw();
      expect(stored!['1000']['paceSecPerKm'], 270,
          reason: 'el récord anterior debe seguir intacto');
      expect(stored['1000']['trainingId'], 'viejo');
    });

    test('una serie cerca de la distancia estándar cuenta para ella', () async {
      // 950 m entra en la ventana de 1000 m (±10 %): el récord de 1000 se
      // calcula por ritmo, no por distancia exacta, o una serie de 950 m
      // rapidísima quedaría fuera del historial de marcas.
      await seedRollup(1000, 300);

      final improved = await repo.updateRollupAfterSave(
        _uid,
        // 950 m en 4:45 → 300 s/km exactos... un pelín mejor para asegurar
        trainingWith(id: 'casi-1k', distanciaM: 950, tiempoSec: 280),
      );

      expect(improved.keys, [1000]);
    });

    test('una serie fuera de toda ventana no genera récord', () async {
      // 700 m no está en ninguna ventana (400 llega a 480, 1000 empieza en 900).
      final improved = await repo.updateRollupAfterSave(
        _uid,
        trainingWith(id: 'raro', distanciaM: 700, tiempoSec: 200),
      );

      expect(improved, isEmpty);
    });

    test('series sin distancia o sin tiempo se ignoran', () async {
      final improved = await repo.updateRollupAfterSave(
        _uid,
        Entrenamiento(
          id: 'vacio',
          titulo: 'Sin datos',
          fecha: DateTime(2026, 7, 10),
          gps: false,
          series: [
            Serie(tiempoSec: 0, distanciaM: 1000, descansoSec: 0, rpe: 5),
            Serie(tiempoSec: 300, distanciaM: 0, descansoSec: 0, rpe: 5),
          ],
        ),
      );

      expect(improved, isEmpty);
    });

    test('un entreno sin id no hace nada (aún no está persistido)', () async {
      final improved = await repo.updateRollupAfterSave(
        _uid,
        Entrenamiento(
          titulo: 'Sin guardar',
          fecha: DateTime(2026, 7, 10),
          gps: true,
          series: [
            Serie(tiempoSec: 200, distanciaM: 1000, descansoSec: 0, rpe: 7),
          ],
        ),
      );

      expect(improved, isEmpty);
      expect(await readRollupRaw(), isNull,
          reason: 'tampoco debe crear el rollup');
    });

    test('sin rollup previo, la primera vez escanea el historial y lo crea',
        () async {
      // Un entreno ya guardado en el historial, más lento que el nuevo.
      await db
          .collection('users').doc(_uid).collection('trainings')
          .add(trainingWith(id: 'x', distanciaM: 1000, tiempoSec: 330).toMap());

      final improved = await repo.updateRollupAfterSave(
        _uid,
        trainingWith(id: 'nuevo', distanciaM: 1000, tiempoSec: 300),
      );

      expect(improved.keys, [1000],
          reason: 'mejora el récord que salió del escaneo inicial');
      final stored = await readRollupRaw();
      expect(stored!['1000']['paceSecPerKm'], 300);
    });
  });
}
