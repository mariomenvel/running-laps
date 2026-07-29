// ignore_for_file: avoid_print
// Crea (o deja como recién registrada) una cuenta de prueba VACÍA.
//
// Ejecutar con (necesita plataforma con plugins Firebase — usar Chrome):
//   flutter run -t scripts/create_empty_test_user.dart -d chrome
//
// Para qué sirve: el onboarding y el wizard del Coach IA son flujos de una sola
// vez. Una vez completados no hay forma de volver a verlos con esa cuenta, así
// que probarlos otra vez exige un usuario nuevo. Este script deja la cuenta
// exactamente como la deja un alta real: documento creado por el mismo código
// de producción (`AuthRepository.signUp`) y `onboardingCompleted: false`, que
// es lo que hace que `AuthWrapper` mande a `WelcomeView`.
//
// Es idempotente: si la cuenta ya existe, borra sus datos y la devuelve al
// estado de recién registrada en vez de fallar.
//
// ⚠️ El email queda SIN verificar (Firebase solo lo marca al pulsar el enlace).
// Como `AuthWrapper` bloquea a los no verificados, después de este script hay
// que marcarlo a mano una vez:
//
//   firebase auth:export users.json --project running-laps-mario-2025 --format=json
//   (poner "emailVerified": true en ese usuario, dejar el resto igual)
//   firebase auth:import users.json --project running-laps-mario-2025
//
// Verificar luego que el login sigue funcionando antes de dar por buena la
// cuenta: el import puede tocar el hash de la contraseña.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';

import 'package:running_laps/features/auth/data/auth_repository.dart';
import 'package:running_laps/firebase_options.dart';

// ─── Credenciales de la cuenta vacía ──────────────────────────────────────────

const _email    = 'nuevo@runninglaps.dev';
const _password = 'Test123456!';
const _nombre   = 'Nuevo Runner';

/// Subcolecciones que se vacían al reutilizar la cuenta. Es la misma lista que
/// limpia `generate_test_user.dart`, más las del Coach: sin ellas la cuenta
/// arrastraría plan y mesociclo de una prueba anterior.
const _subcollections = [
  'trainings',
  'athleteSessions',
  'templates',
  'tags',
  'aiCoachFeedback',
  'raceGoals',
  'savedBlocks',
  'settings', // aiCoachProfile, aiCoachUsage, aiCoachMesocycle, aiCoachVdot...
];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  print('Preparando cuenta de prueba vacía...');
  await _createEmptyUser();
}

Future<void> _createEmptyUser() async {
  final auth      = FirebaseAuth.instance;
  final firestore = FirebaseFirestore.instance;

  String uid;
  var reused = false;

  try {
    // Camino feliz: alta con el MISMO código que usa la app en producción, así
    // el documento no se desvía si algún día cambian los campos iniciales.
    await AuthRepository().signUp(_email, _password, _nombre);
    uid = auth.currentUser!.uid;
    print('Usuario creado desde cero');
  } on FirebaseAuthException catch (e) {
    if (e.code != 'email-already-in-use') rethrow;
    final cred = await auth.signInWithEmailAndPassword(
      email: _email, password: _password,
    );
    uid = cred.user!.uid;
    reused = true;
    print('La cuenta ya existía — devolviéndola al estado inicial');
  }

  if (reused) {
    for (final name in _subcollections) {
      final deleted = await _clearCollection(firestore, 'users/$uid/$name');
      if (deleted > 0) print('  $name: $deleted docs eliminados');
    }

    // Reescribir el documento con los mismos campos que pone `signUp`, para
    // que no sobreviva nada de una prueba anterior (nombre cambiado, FC
    // configurada, stats acumuladas...). Se conserva el avatar generado.
    final snap = await firestore.collection('users').doc(uid).get();
    final avatar = snap.data()?['generativeAvatarConfig'];

    await firestore.collection('users').doc(uid).set({
      'nombre':              _nombre,
      'email':               _email,
      'createdAt':           FieldValue.serverTimestamp(),
      'totalSessions':       0,
      'totalKm':             0.0,
      'totalTimeMinutes':    0.0,
      'lastTrainingDate':    null,
      'fcMax':               null,
      'fcReposo':            null,
      'birthDate':           null,
      'sex':                 null,
      'onboardingCompleted': false,
      if (avatar != null) 'generativeAvatarConfig': avatar,
    });
    print('Documento de usuario reiniciado');
  }

  final verified = auth.currentUser?.emailVerified ?? false;

  print('\nCuenta lista:');
  print('  Email:    $_email');
  print('  Password: $_password');
  print('  UID:      $uid');
  print('  Email verificado: ${verified ? "sí" : "NO — marcar con auth:import"}');
  print('  Onboarding: pendiente (arranca en WelcomeView)');
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
