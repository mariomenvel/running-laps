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
  late FakeFirebaseFirestore db;
  late _TestableConsent service;

  setUp(() {
    db = FakeFirebaseFirestore();
    service = _TestableConsent(firestore: db, uid: uid);
    HealthConsentService.consentGranted.value = null;
  });

  group('HealthConsentService', () {
    test('sin documento previo no hay consentimiento', () async {
      expect(await service.hasConsent(), isFalse);
      expect(HealthConsentService.consentGranted.value, isFalse);
    });

    test('grant persiste el consentimiento con auditoría', () async {
      await service.grant();

      expect(await service.hasConsent(), isTrue);
      expect(HealthConsentService.consentGranted.value, isTrue);

      final doc = await db
          .collection('users')
          .doc(uid)
          .collection('settings')
          .doc('healthConsent')
          .get();
      expect(doc.data()!['granted'], isTrue);
      expect(doc.data()!['grantedAt'], isNotNull);
      expect(doc.data()!['policyVersion'], HealthConsentService.policyVersion);
    });

    test('revoke retira el consentimiento y lo audita', () async {
      await service.grant();
      await service.revoke();

      expect(await service.hasConsent(), isFalse);
      expect(HealthConsentService.consentGranted.value, isFalse);

      final doc = await db
          .collection('users')
          .doc(uid)
          .collection('settings')
          .doc('healthConsent')
          .get();
      expect(doc.data()!['granted'], isFalse);
      expect(doc.data()!['revokedAt'], isNotNull);
    });

    test('el consentimiento sobrevive entre instancias (persistido)', () async {
      await service.grant();

      final otherInstance = _TestableConsent(firestore: db, uid: uid);
      expect(await otherInstance.hasConsent(), isTrue);
    });

    test('sin usuario autenticado no hay consentimiento ni escritura', () async {
      final anon = _TestableConsent(firestore: db, uid: null);

      expect(await anon.hasConsent(), isFalse);
      await anon.grant(); // no debe lanzar ni escribir nada
      final docs = await db.collectionGroup('settings').get();
      expect(docs.docs, isEmpty);
    });
  });
}
