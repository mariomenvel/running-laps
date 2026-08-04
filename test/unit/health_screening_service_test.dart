import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_laps/core/services/health_screening_service.dart';

class _TestableScreening extends HealthScreeningService {
  _TestableScreening({required FakeFirebaseFirestore firestore, this.uid})
      : super(firestore: firestore);

  final String? uid;

  @override
  String? get currentUserId => uid;
}

void main() {
  const uid = 'test-uid-123';
  late FakeFirebaseFirestore db;
  late _TestableScreening service;

  setUp(() {
    db = FakeFirebaseFirestore();
    service = _TestableScreening(firestore: db, uid: uid);
  });

  group('HealthScreening (modelo)', () {
    test('todo a "no" no levanta ninguna bandera', () {
      const screening = HealthScreening(
        answers: HealthScreening.allNegative,
        version: 'v1',
      );

      expect(screening.anyPositive, isFalse);
      expect(screening.hasCardiacFlag, isFalse);
    });

    test('una lesión activa no es bandera cardíaca', () {
      // Sin `const`: el spread trae activeInjury en false y sobrescribirla en
      // un mapa constante es un error de compilación, no un override.
      final screening = HealthScreening(
        answers: {
          ...HealthScreening.allNegative,
          HealthScreeningQuestion.activeInjury: true,
        },
        version: 'v1',
      );

      // El consejo no es el mismo: una molestia se gestiona bajando carga.
      expect(screening.anyPositive, isTrue);
      expect(screening.hasCardiacFlag, isFalse);
    });

    for (final q in [
      HealthScreeningQuestion.medicalSupervision,
      HealthScreeningQuestion.chestPain,
      HealthScreeningQuestion.heartMedication,
    ]) {
      test('${q.key} sí levanta bandera cardíaca', () {
        final screening = HealthScreening(
          answers: {...HealthScreening.allNegative, q: true},
          version: 'v1',
        );

        expect(screening.hasCardiacFlag, isTrue);
      });
    }

    test('una respuesta ausente cuenta como "no"', () {
      const screening = HealthScreening(answers: {}, version: 'v1');

      expect(screening.answer(HealthScreeningQuestion.chestPain), isFalse);
      expect(screening.anyPositive, isFalse);
    });
  });

  group('HealthScreeningService', () {
    test('sin cribado previo no hay nada guardado', () async {
      expect(await service.load(), isNull);
      expect(await service.hasCompleted(), isFalse);
    });

    test('save persiste respuestas, versión y fecha', () async {
      await service.save({
        ...HealthScreening.allNegative,
        HealthScreeningQuestion.chestPain: true,
      });

      final doc = await db
          .collection('users')
          .doc(uid)
          .collection('settings')
          .doc('healthScreening')
          .get();

      expect(doc.data()!['completedAt'], isNotNull);
      expect(
        doc.data()!['version'],
        HealthScreeningService.questionnaireVersion,
      );
      expect(doc.data()!['anyPositive'], isTrue);
      expect(doc.data()!['hasCardiacFlag'], isTrue);
      expect(
        doc.data()!['answers'][HealthScreeningQuestion.chestPain.key],
        isTrue,
      );
    });

    test('el cribado se relee tal cual se guardó', () async {
      await service.save({
        ...HealthScreening.allNegative,
        HealthScreeningQuestion.activeInjury: true,
      });

      final loaded = await service.load();

      expect(loaded, isNotNull);
      expect(loaded!.answer(HealthScreeningQuestion.activeInjury), isTrue);
      expect(loaded.answer(HealthScreeningQuestion.chestPain), isFalse);
      expect(loaded.hasCardiacFlag, isFalse);
      expect(await service.hasCompleted(), isTrue);
    });

    test('una clave desconocida no rompe la lectura', () async {
      // Si algún día se retira una pregunta, los cribados viejos siguen
      // leyéndose: lo que no se reconoce se ignora.
      await db
          .collection('users')
          .doc(uid)
          .collection('settings')
          .doc('healthScreening')
          .set({
        'version': 'v0',
        'answers': {'preguntaRetirada': true, 'chestPain': true},
      });

      final loaded = await service.load();

      expect(loaded!.answer(HealthScreeningQuestion.chestPain), isTrue);
      expect(loaded.answers.length, 1);
    });

    test('sin usuario autenticado no se escribe nada', () async {
      final anon = _TestableScreening(firestore: db, uid: null);

      await anon.save(HealthScreening.allNegative);

      final docs = await db.collectionGroup('settings').get();
      expect(docs.docs, isEmpty);
      expect(await anon.load(), isNull);
    });
  });
}
