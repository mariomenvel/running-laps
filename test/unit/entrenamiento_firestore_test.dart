import 'package:flutter_test/flutter_test.dart';
import 'package:running_laps/features/training/data/entrenamiento.dart';
import 'package:running_laps/features/training/data/fc_reading.dart';
import 'package:running_laps/features/training/data/serie.dart';
import 'package:running_laps/features/templates/data/template_models.dart';

/// Tope de claves del `allow create` de `users/{uid}/trainings/{id}`
/// en `firestore.rules`. Si se sube un campo nuevo al modelo y este test se
/// pone en rojo, hay que subir **también** el número en las reglas y
/// desplegarlas — si no, el entreno se deniega en silencio al guardar.
const _firestoreCreateKeyLimit = 30;

/// Claves que `createTraining()` añade por su cuenta al mapa del modelo.
const _keysAddedByRepository = 2; // createdAt + updatedAt (serverTimestamp)

/// Entrenamiento con **todos** los campos opcionales rellenos: el peor caso
/// que puede llegar a Firestore.
Entrenamiento _fullyPopulated() {
  return Entrenamiento(
    id: 'abc123',
    titulo: 'Series 6x800',
    fecha: DateTime.utc(2026, 7, 29, 18, 30),
    gps: true,
    series: [
      Serie(
        tiempoSec:   180,
        distanciaM:  800,
        descansoSec: 90,
        rpe:         8,
        usedGps:     true,
        fcMedia:     165,
        fcReadings: [FcReading(bpm: 165, timestamp: DateTime.utc(2026, 7, 29))],
      ),
    ],
    tags: const ['series'],
    loadScore: 120.5,
    createdAt: DateTime.utc(2026, 7, 29),
    updatedAt: DateTime.utc(2026, 7, 29),
    source: TemplateSource(type: 'template', templateId: 't1'),
    isManual: true,
    notas: 'Buenas sensaciones',
    fcMediaSesion: 165.0,
    fcMaxSesion: 182,
    plannedComparison: const {'plannedTitle': 'Series'},
    coachAnalysis: const {'verdict': 'ok'},
  );
}

void main() {
  group('Entrenamiento.toMap vs límite de firestore.rules', () {
    test('un entreno completo cabe en el allow create', () {
      // Como lo guarda TrainingRepository.createTraining: sin trazas (viven en
      // la subcolección `track/data`) pero con createdAt/updatedAt forzados.
      final keys = _fullyPopulated().toMap(includeTrack: false).keys.length +
          _keysAddedByRepository;

      expect(
        keys,
        lessThan(_firestoreCreateKeyLimit),
        reason: 'toMap() escribe $keys claves y firestore.rules solo admite '
            'menos de $_firestoreCreateKeyLimit en el create de trainings. '
            'Sube el límite en firestore.rules Y despliégalas.',
      );
    });

    test('con trazas embebidas también cabe (entrenos antiguos)', () {
      // `overwriteTraining` es un update (sin tope de claves), pero un mapa con
      // trackPoints puede llegar a un create en flujos legados.
      final keys = _fullyPopulated().toMap().keys.length +
          _keysAddedByRepository;
      expect(keys, lessThan(_firestoreCreateKeyLimit));
    });

    test('los campos de FC de sesión llegan al mapa', () {
      final map = _fullyPopulated().toMap(includeTrack: false);
      expect(map['fcMediaSesion'], 165.0);
      expect(map['fcMaxSesion'], 182);
    });

    test('sin datos de FC no se escriben esas claves', () {
      final sinFc = Entrenamiento(
        titulo: 'Rodaje',
        fecha: DateTime.utc(2026, 7, 29),
        gps: true,
        series: [
          Serie(tiempoSec: 1800, distanciaM: 6000, descansoSec: 0, rpe: 4),
        ],
      );
      final map = sinFc.toMap(includeTrack: false);
      expect(map.containsKey('fcMediaSesion'), isFalse);
      expect(map.containsKey('fcMaxSesion'), isFalse);
    });

    test('fcMaxSesion sobrevive al round-trip toMap/fromMap', () {
      final original = _fullyPopulated();
      final restored = Entrenamiento.fromMap(
        original.toMap(includeTrack: false),
        id: original.id,
      );
      expect(restored.fcMaxSesion, 182);
      expect(restored.fcMediaSesion, 165.0);
    });
  });
}
