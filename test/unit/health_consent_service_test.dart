import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_laps/core/services/health_consent_service.dart';

class _TestableConsent extends HealthConsentService {
  _TestableConsent({required FakeFirebaseFirestore firestore, this.uid})
      : super(firestore: firestore);

  final String? uid;

  @override
  String? get currentUserId => uid;
}

void main() {
  const uid = 'test-uid-123';
  const hr = HealthConsentScope.heartRate;
  const coach = HealthConsentScope.aiCoach;

  late FakeFirebaseFirestore db;
  late _TestableConsent service;

  Future<Map<String, dynamic>?> readDoc() async {
    final doc = await db
        .collection('users')
        .doc(uid)
        .collection('settings')
        .doc('healthConsent')
        .get();
    return doc.data();
  }

  setUp(() {
    db = FakeFirebaseFirestore();
    service = _TestableConsent(firestore: db, uid: uid);
    for (final scope in HealthConsentScope.values) {
      HealthConsentService.grantedNotifier(scope).value = null;
    }
  });

  group('HealthConsentService', () {
    test('sin documento previo no hay consentimiento', () async {
      expect(await service.hasConsent(hr), isFalse);
      expect(HealthConsentService.grantedNotifier(hr).value, isFalse);
    });

    test('grant persiste el consentimiento con auditoría', () async {
      await service.grant(hr);

      expect(await service.hasConsent(hr), isTrue);
      expect(HealthConsentService.grantedNotifier(hr).value, isTrue);

      final scope = (await readDoc())!['scopes'][hr.key] as Map;
      expect(scope['granted'], isTrue);
      expect(scope['grantedAt'], isNotNull);
      expect(scope['policyVersion'], HealthConsentService.policyVersion);
    });

    test('revoke retira el consentimiento y lo audita', () async {
      await service.grant(hr);
      await service.revoke(hr);

      expect(await service.hasConsent(hr), isFalse);
      expect(HealthConsentService.grantedNotifier(hr).value, isFalse);

      final scope = (await readDoc())!['scopes'][hr.key] as Map;
      expect(scope['granted'], isFalse);
      expect(scope['revokedAt'], isNotNull);
      // La marca de concesión no se pierde al retirar: para una reclamación
      // importa tanto cuándo se dio como cuándo se retiró.
      expect(scope['grantedAt'], isNotNull);
    });

    test('el consentimiento sobrevive entre instancias (persistido)', () async {
      await service.grant(hr);

      final otherInstance = _TestableConsent(firestore: db, uid: uid);
      expect(await otherInstance.hasConsent(hr), isTrue);
    });

    test('sin usuario autenticado no hay consentimiento ni escritura', () async {
      final anon = _TestableConsent(firestore: db, uid: null);

      expect(await anon.hasConsent(hr), isFalse);
      await anon.grant(hr); // no debe lanzar ni escribir nada
      final docs = await db.collectionGroup('settings').get();
      expect(docs.docs, isEmpty);
    });
  });

  group('ámbitos independientes (art. 9: consentimiento por finalidad)', () {
    test('aceptar el pulsómetro no autoriza al coach', () async {
      await service.grant(hr);

      expect(await service.hasConsent(hr), isTrue);
      expect(await service.hasConsent(coach), isFalse);
    });

    test('aceptar el coach no autoriza al pulsómetro', () async {
      await service.grant(coach);

      expect(await service.hasConsent(coach), isTrue);
      expect(await service.hasConsent(hr), isFalse);
    });

    test('retirar uno deja el otro intacto', () async {
      await service.grant(hr);
      await service.grant(coach);

      await service.revoke(coach);

      expect(await service.hasConsent(hr), isTrue);
      expect(await service.hasConsent(coach), isFalse);
    });

    test('hasConsent acepta un uid explícito (lo usa el planificador)',
        () async {
      await service.grant(coach);

      // Instancia sin sesión: solo puede resolverlo con el uid por parámetro.
      final headless = _TestableConsent(firestore: db, uid: null);
      expect(await headless.hasConsent(coach, uid: uid), isTrue);
      expect(await headless.hasConsent(coach, uid: 'otro-uid'), isFalse);
    });
  });

  group('compatibilidad con el consentimiento anterior a los ámbitos', () {
    // Antes del 4 ago 2026 el consentimiento del pulsómetro era un booleano
    // suelto en la raíz del documento. A quien ya lo dio no se le puede volver
    // a preguntar: sería pedir dos veces lo mismo.
    Future<void> seedLegacyDoc({required bool granted}) async {
      await db
          .collection('users')
          .doc(uid)
          .collection('settings')
          .doc('healthConsent')
          .set({
        'granted': granted,
        'grantedAt': DateTime(2026, 7, 11),
        'policyVersion': '2026-07-11',
      });
    }

    test('un consentimiento antiguo sigue valiendo para el pulsómetro',
        () async {
      await seedLegacyDoc(granted: true);

      expect(await service.hasConsent(hr), isTrue);
    });

    test('pero no se extiende al coach', () async {
      await seedLegacyDoc(granted: true);

      expect(await service.hasConsent(coach), isFalse);
    });

    test('un consentimiento antiguo retirado sigue retirado', () async {
      await seedLegacyDoc(granted: false);

      expect(await service.hasConsent(hr), isFalse);
    });

    test('el booleano de la raíz se mantiene al día para poder revertir',
        () async {
      await service.grant(hr);
      expect((await readDoc())!['granted'], isTrue);

      await service.revoke(hr);
      expect((await readDoc())!['granted'], isFalse);
    });

    test('el ámbito del coach no toca el booleano heredado', () async {
      await service.grant(coach);

      expect((await readDoc())!.containsKey('granted'), isFalse);
    });
  });
}
