import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:running_laps/features/avatar/models/avatar_config.dart';

// Regresión: antes había dos pantallas de edición de avatar escribiendo en
// campos distintos de Firestore (avatarConfig vs generativeAvatarConfig),
// lo que desincronizaba el avatar entre header, perfil y grupos. Este test
// fija el contrato: todo escritor de avatar usa 'generativeAvatarConfig' y
// el campo legado 'avatarConfig' no se vuelve a escribir.
void main() {
  const uid = 'test-uid-avatar';

  test('avatar guardado por el editor es legible bajo generativeAvatarConfig', () async {
    final firestore = FakeFirebaseFirestore();
    final config = AvatarConfig.random();

    // Simula avatar_editor_wraper_view.dart._saveAvatarToFirebase()
    await firestore.collection('users').doc(uid).set({
      'profilePicType': 'avatar',
      'generativeAvatarConfig': config.toMap(),
    }, SetOptions(merge: true));

    final doc = await firestore.collection('users').doc(uid).get();
    final data = doc.data()!;

    // Consumidores: AvatarHelper (app_theme.dart), profile_view.dart,
    // group_detail_repository.dart, challenge_detail_controller.dart,
    // group_rewards_controller.dart — todos leen esta misma clave.
    expect(data['generativeAvatarConfig'], isNotNull);
    final parsed = AvatarConfig.fromMap(
      data['generativeAvatarConfig'] as Map<String, dynamic>,
    );
    expect(parsed.toMap(), equals(config.toMap()));

    // El campo legado no debe volver a escribirse.
    expect(data.containsKey('avatarConfig'), isFalse);
  });

  test('admin_repository cuenta onboarding sobre el campo unificado', () async {
    final firestore = FakeFirebaseFirestore();

    await firestore.collection('users').doc('with-avatar').set({
      'generativeAvatarConfig': AvatarConfig.random().toMap(),
    });
    await firestore.collection('users').doc('without-avatar').set({
      'nombre': 'Sin avatar',
    });

    final onboardedSnap = await firestore
        .collection('users')
        .where('generativeAvatarConfig', isNull: false)
        .count()
        .get();

    expect(onboardedSnap.count, 1);
  });

  test('AvatarConfig.fromMap es estable en un round-trip toMap/fromMap', () {
    final original = AvatarConfig.random();
    final roundTripped = AvatarConfig.fromMap(original.toMap());

    expect(roundTripped.toMap(), equals(original.toMap()));
  });
}
