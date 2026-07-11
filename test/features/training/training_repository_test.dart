import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_laps/core/services/rate_limit_service.dart';
import 'package:running_laps/features/groups/data/repositories/challenges_repository.dart';
import 'package:running_laps/features/groups/data/services/training_challenge_sync_service.dart';
import 'package:running_laps/features/training/data/entrenamiento.dart';
import 'package:running_laps/features/training/data/fc_reading.dart';
import 'package:running_laps/features/training/data/serie.dart';
import 'package:running_laps/features/training/data/training_repository.dart';

// Mismo patrón que workout_repository_test: inyectar firestore falso y
// sobrescribir el uid sin necesidad de Firebase Auth real.
class _TestableRepo extends TrainingRepository {
  _TestableRepo({required FakeFirebaseFirestore firestore})
      : super(
          firestore: firestore,
          syncService: TrainingChallengeSyncService(
            firestore: firestore,
            challengesRepo: ChallengesRepository(firestore: firestore),
          ),
        );

  @override
  String? get currentUserId => _uid;
}

const _uid = 'test-uid-123';

void main() {
  late FakeFirebaseFirestore db;
  late _TestableRepo repo;

  Serie makeSerie({
    int distanciaM = 1000,
    double tiempoSec = 300,
    List<Map<String, dynamic>>? gpsPoints,
    double? fcMedia,
    List<FcReading>? fcReadings,
  }) {
    return Serie(
      tiempoSec: tiempoSec,
      distanciaM: distanciaM,
      descansoSec: 60,
      rpe: 6,
      gpsPoints: gpsPoints,
      fcMedia: fcMedia,
      fcReadings: fcReadings,
    );
  }

  Entrenamiento makeTraining({
    List<Serie>? series,
    DateTime? fecha,
    String titulo = 'Test',
  }) {
    return Entrenamiento(
      titulo: titulo,
      fecha: fecha ?? DateTime(2026, 7, 10, 18, 30),
      gps: true,
      series: series ?? [makeSerie()],
    );
  }

  // Traza recta: 0.0009° de latitud ≈ 100 m por paso
  List<Map<String, dynamic>> straightTrack(int steps) {
    final t0 = DateTime(2026, 7, 10, 18, 30);
    return List.generate(steps + 1, (i) {
      return <String, dynamic>{
        'latitude': 40.0 + i * 0.0009,
        'longitude': -3.7,
        'timestamp': t0.add(Duration(seconds: i * 30)).toIso8601String(),
      };
    });
  }

  setUp(() async {
    db = FakeFirebaseFirestore();
    repo = _TestableRepo(firestore: db);
    // El rate limit de guardado es un singleton — limpiarlo entre tests
    RateLimitService().clearKey('training:save');
    // Doc de usuario para los contadores agregados
    await db.collection('users').doc(_uid).set({
      'nombre': 'Tester',
      'totalSessions': 0,
      'totalKm': 0.0,
      'totalTimeMinutes': 0.0,
    });
  });

  group('TrainingRepository.createTraining', () {
    test('persiste el doc con los campos derivados y fecha en UTC', () async {
      final id = await repo.createTraining(makeTraining(
        series: [makeSerie(distanciaM: 1000, tiempoSec: 300)],
      ));

      final doc =
          await db.collection('users').doc(_uid).collection('trainings').doc(id).get();
      expect(doc.exists, isTrue);
      final data = doc.data()!;
      expect(data['titulo'], 'Test');
      expect(data['distanciaTotalM'], 1000);
      expect(data['tiempoTotalSec'], 300);
      expect(data['ritmoMedioSecKm'], 300);
      // fecha en UTC con sufijo Z — convención documentada (CLAUDE.md deuda #8)
      expect(data['fecha'], endsWith('Z'));
    });

    test('actualiza los contadores agregados del usuario', () async {
      await repo.createTraining(makeTraining(
        series: [makeSerie(distanciaM: 5000, tiempoSec: 1500)],
      ));

      final user = await db.collection('users').doc(_uid).get();
      expect(user.data()!['totalSessions'], 1);
      expect(user.data()!['totalKm'], closeTo(5.0, 0.001));
      expect(user.data()!['totalTimeMinutes'], closeTo(25.0, 0.001));
    });

    test(
        'REGRESIÓN: el suavizado RDP conserva fcMedia y fcReadings de la serie',
        () async {
      // Bug real (jul 2026): series con >10 puntos GPS perdían el pulsómetro
      // al reconstruirse la Serie a mano en vez de usar copyWith.
      final readings = [
        FcReading(bpm: 150, timestamp: DateTime(2026, 7, 10, 18, 30)),
        FcReading(bpm: 165, timestamp: DateTime(2026, 7, 10, 18, 31)),
      ];
      final id = await repo.createTraining(makeTraining(
        series: [
          makeSerie(
            gpsPoints: straightTrack(15), // >10 → dispara el suavizado
            fcMedia: 158.5,
            fcReadings: readings,
          ),
        ],
      ));

      final doc =
          await db.collection('users').doc(_uid).collection('trainings').doc(id).get();
      final loaded = Entrenamiento.fromMap(doc.data()!, id: doc.id);
      final serie = loaded.series.single;

      expect(serie.fcMedia, 158.5);
      expect(serie.fcReadings, isNotNull);
      expect(serie.fcReadings!.length, 2);
      expect(serie.fcReadings!.first.bpm, 150);
      // Y el suavizado realmente actuó (línea recta → colapsa puntos)
      expect(serie.gpsPoints!.length, lessThan(16));
    });

    test('el rate limit bloquea un segundo guardado inmediato', () async {
      await repo.createTraining(makeTraining());
      expect(
        () => repo.createTraining(makeTraining()),
        throwsA(isA<RateLimitExceededException>()),
      );
    });

    test('sin usuario autenticado lanza excepción', () async {
      // Repo sin override de uid y sin Firebase → currentUserId inaccesible;
      // simulamos con un testable cuyo uid es null.
      final anonRepo = _NullUidRepo(firestore: db);
      expect(
        () => anonRepo.createTraining(makeTraining()),
        throwsA(isA<Exception>()),
      );
    });
  });

  group('TrainingRepository.getTrainings — paginación', () {
    Future<void> seed(int count) async {
      for (var i = 0; i < count; i++) {
        final e = makeTraining(
          titulo: 'T$i',
          fecha: DateTime(2026, 6, 1).add(Duration(days: i)),
        );
        final data = e.toMap();
        await db
            .collection('users')
            .doc(_uid)
            .collection('trainings')
            .add(data);
      }
    }

    test('devuelve páginas de pageSize con hasMore y sin duplicados', () async {
      await seed(25);

      final page1 = await repo.getTrainings(uid: _uid, pageSize: 20);
      expect(page1.trainings.length, 20);
      expect(page1.hasMore, isTrue);
      expect(page1.lastDocument, isNotNull);

      final page2 = await repo.getTrainings(
        uid: _uid,
        pageSize: 20,
        startAfter: page1.lastDocument,
      );
      expect(page2.trainings.length, 5);
      expect(page2.hasMore, isFalse);

      final all = [...page1.trainings, ...page2.trainings];
      final titles = all.map((e) => e.titulo).toSet();
      expect(titles.length, 25, reason: 'sin duplicados entre páginas');
    });

    test('ordena por fecha descendente (más reciente primero)', () async {
      await seed(5);
      final page = await repo.getTrainings(uid: _uid, pageSize: 10);
      expect(page.trainings.first.titulo, 'T4');
      expect(page.trainings.last.titulo, 'T0');
      for (var i = 0; i < page.trainings.length - 1; i++) {
        expect(
          page.trainings[i].fecha.isAfter(page.trainings[i + 1].fecha),
          isTrue,
        );
      }
    });

    test('colección vacía: página vacía y hasMore false', () async {
      final page = await repo.getTrainings(uid: _uid, pageSize: 20);
      expect(page.trainings, isEmpty);
      expect(page.hasMore, isFalse);
      expect(page.lastDocument, isNull);
    });
  });

  group('TrainingRepository — otros', () {
    test('updateTrainingTags reemplaza las etiquetas', () async {
      final id = await repo.createTraining(makeTraining());

      await repo.updateTrainingTags(id, ['series', 'pista']);

      final doc =
          await db.collection('users').doc(_uid).collection('trainings').doc(id).get();
      expect(List<String>.from(doc.data()!['tags'] as List), ['series', 'pista']);
    });

    test('getTrainingById devuelve el entreno o null si no existe', () async {
      final id = await repo.createTraining(makeTraining(titulo: 'Único'));

      final found = await repo.getTrainingById(id);
      expect(found?.titulo, 'Único');

      final missing = await repo.getTrainingById('no-existe');
      expect(missing, isNull);
    });

    test('updateTrainingAnalysis persiste solo los campos no nulos', () async {
      final id = await repo.createTraining(makeTraining());

      await repo.updateTrainingAnalysis(
        uid: _uid,
        trainingId: id,
        loadScore: 42.5,
      );

      final doc =
          await db.collection('users').doc(_uid).collection('trainings').doc(id).get();
      expect(doc.data()!['loadScore'], 42.5);
      expect(doc.data()!.containsKey('plannedComparison'), isFalse);
    });
  });
}

class _NullUidRepo extends TrainingRepository {
  _NullUidRepo({required FakeFirebaseFirestore firestore})
      : super(
          firestore: firestore,
          syncService: TrainingChallengeSyncService(
            firestore: firestore,
            challengesRepo: ChallengesRepository(firestore: firestore),
          ),
        );

  @override
  String? get currentUserId => null;
}
