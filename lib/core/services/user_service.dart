import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:running_laps/core/auth_failure.dart';

class UserService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  User? get currentUser => _auth.currentUser;

  /// Uid del usuario autenticado, o null. Punto único para las vistas: no
  /// deben instanciar `FirebaseAuth.instance` (ver CLAUDE.md § Arquitectura).
  String? get currentUid => _auth.currentUser?.uid;

  /// Uid esperando a que Firebase restaure la sesión al arrancar.
  ///
  /// `currentUser` es síncrono y está disponible si ya había sesión, pero en
  /// un arranque en frío puede tardar: por eso el fallback al stream con
  /// timeout. Este patrón estaba copiado en home, calendario y analytics.
  Future<String?> awaitCurrentUid({
    Duration timeout = const Duration(seconds: 5),
  }) async {
    final user = _auth.currentUser ??
        await _auth
            .authStateChanges()
            .firstWhere((u) => u != null)
            .timeout(timeout, onTimeout: () => _auth.currentUser);
    return user?.uid;
  }

  /// Checks if the user is signed in with Google
  bool isGoogleUser() => _hasProvider('google.com');

  /// Checks if the user is signed in with Apple
  bool isAppleUser() => _hasProvider('apple.com');

  bool _hasProvider(String providerId) {
    final user = currentUser;
    if (user == null) return false;
    for (final provider in user.providerData) {
      if (provider.providerId == providerId) return true;
    }
    return false;
  }

  // ==========================================
  // NAME MANAGEMENT
  // ==========================================

  Future<void> updateNombre(String newName) async {
    final user = currentUser;
    if (user == null) throw AuthFailure('No hay usuario autenticado');

    try {
      // 1. Update Firestore
      await _db.collection('users').doc(user.uid).update({
        'nombre': newName.trim(),
      });
      
      // 2. Optional: Update display name in Auth
      await user.updateDisplayName(newName.trim());
    } catch (e) {
      throw AuthFailure('Error al actualizar nombre: ${e.toString()}');
    }
  }

  // ==========================================
  // REAUTHENTICATION
  // ==========================================

  Future<void> reauthenticate(String password) async {
    final user = currentUser;
    if (user == null) throw AuthFailure('No hay usuario autenticado');
    if (user.email == null) throw AuthFailure('Email no disponible');

    try {
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure.fromCode(e.code, e.message);
    } catch (e) {
      throw AuthFailure(e.toString());
    }
  }

  Future<void> reauthenticateWithGoogle() async {
    final user = currentUser;
    if (user == null) throw AuthFailure('No hay usuario autenticado');

    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      
      if (googleUser == null) {
        throw AuthFailure.fromCode('aborted-by-user', 'Reautenticación cancelada');
      }
      
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await user.reauthenticateWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure.fromCode(e.code, e.message);
    } catch (e) {
      throw AuthFailure(e.toString());
    }
  }

  Future<void> reauthenticateWithApple() async {
    final user = currentUser;
    if (user == null) throw AuthFailure('No hay usuario autenticado');

    try {
      await user.reauthenticateWithProvider(AppleAuthProvider());
    } on FirebaseAuthException catch (e) {
      throw AuthFailure.fromCode(e.code, e.message);
    } catch (e) {
      throw AuthFailure(e.toString());
    }
  }

  // ==========================================
  // PASSWORD MANAGEMENT
  // ==========================================

  Future<void> updatePassword(String newPassword) async {
    final user = currentUser;
    if (user == null) throw AuthFailure('No hay usuario autenticado');
    if (isGoogleUser() || isAppleUser()) {
      throw AuthFailure(
          'Las cuentas de Google o Apple no pueden cambiar contraseña aquí');
    }

    try {
      await user.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure.fromCode(e.code, e.message);
    } catch (e) {
      throw AuthFailure(e.toString());
    }
  }

  // ==========================================
  // ATHLETE MODE
  // ==========================================

  Future<bool> getIsAthleteMode(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data()?['isAthleteMode'] as bool? ?? false;
  }

  Future<void> setAthleteMode(String uid, {required bool value}) async {
    await _db.collection('users').doc(uid).update({'isAthleteMode': value});
  }

  // ==========================================
  // DOCUMENTO DE USUARIO
  // ==========================================
  // Punto único de acceso a users/{uid} desde la UI: las vistas no deben
  // instanciar FirebaseFirestore (ver CLAUDE.md § Arquitectura).

  /// Datos del perfil, o mapa vacío si el documento no existe todavía.
  Future<Map<String, dynamic>> getUserData(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data() ?? {};
  }

  /// Emite los datos del perfil en cada cambio. `null` significa que el
  /// documento **aún no existe** (usuario recién creado, Firestore todavía
  /// escribiendo) — quien escucha debe distinguirlo de un perfil vacío.
  Stream<Map<String, dynamic>?> watchUserData(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists ? (doc.data() ?? <String, dynamic>{}) : null);
  }

  /// Marca el onboarding como terminado. `AuthWrapper` escucha este campo.
  Future<void> completeOnboarding(String uid) async {
    await _db.collection('users').doc(uid).update({'onboardingCompleted': true});
  }

  /// Guarda el avatar generativo y deja el tipo de foto coherente con él.
  Future<void> saveGenerativeAvatar(
    String uid,
    Map<String, dynamic> config,
  ) async {
    await _db.collection('users').doc(uid).set({
      'profilePicType': 'generative_avatar',
      'generativeAvatarConfig': config,
    }, SetOptions(merge: true));
  }

  /// Actualiza campos sueltos del perfil (fecha de nacimiento, sexo…).
  /// No hace nada si [fields] viene vacío.
  Future<void> updateProfileFields(
    String uid,
    Map<String, dynamic> fields,
  ) async {
    if (fields.isEmpty) return;
    await _db.collection('users').doc(uid).update(fields);
  }

  // ==========================================
  // AJUSTES EN users/{uid}/settings
  // ==========================================

  /// Distancia sobre la que se calcula la marca personal destacada, o null si
  /// el usuario nunca la ha configurado.
  Future<int?> getBestMarkDistanceM(String uid) async {
    final doc = await _db
        .collection('users')
        .doc(uid)
        .collection('settings')
        .doc('bestMarkDistance')
        .get();
    final value = doc.data()?['distanceM'];
    return value is num ? value.toInt() : null;
  }

  Future<void> setBestMarkDistanceM(String uid, int distanceM) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('settings')
        .doc('bestMarkDistance')
        .set({'distanceM': distanceM}, SetOptions(merge: true));
  }

  // ==========================================
  // ACCOUNT DELETION
  // ==========================================

  Future<void> deleteAccount() async {
    final user = currentUser;
    if (user == null) throw AuthFailure('No hay usuario autenticado');

    try {
      // Cloud Function con Admin SDK (functions/src/deleteUserData.ts):
      // borra recursivamente users/{uid} con todas sus subcolecciones,
      // limpia sus artefactos en grupos y elimina el usuario de Auth.
      final callable = FirebaseFunctions.instance.httpsCallable(
        'deleteUserData',
        options: HttpsCallableOptions(timeout: const Duration(minutes: 5)),
      );
      await callable.call();

      // El usuario de Auth ya no existe en el servidor — limpiar la sesión
      // local para que AuthWrapper navegue fuera.
      await _auth.signOut();
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'not-found' || e.code == 'unimplemented') {
        // Función aún no desplegada: fallback al borrado parcial antiguo.
        // Deja subcolecciones huérfanas — desplegar deleteUserData cuanto antes.
        debugPrint('[UserService] deleteUserData no desplegada, '
            'usando borrado parcial cliente');
        await _deleteAccountClientSide(user);
        return;
      }
      if (e.message == 'requires-recent-login' ||
          e.code == 'failed-precondition') {
        throw AuthFailure(
          'Por seguridad, vuelve a iniciar sesión antes de borrar la cuenta.',
        );
      }
      throw AuthFailure('Error al borrar la cuenta: ${e.message ?? e.code}');
    } on FirebaseAuthException catch (e) {
      throw AuthFailure.fromCode(e.code, e.message);
    } catch (e) {
      if (e is AuthFailure) rethrow;
      throw AuthFailure(e.toString());
    }
  }

  /// Borrado antiguo 100% cliente: solo users/{uid} + Auth user.
  /// Mantiene la cuenta funcional como fallback mientras la Cloud Function
  /// no esté desplegada, a costa de dejar subcolecciones huérfanas.
  Future<void> _deleteAccountClientSide(User user) async {
    try {
      await _db.collection('users').doc(user.uid).delete();
      await user.delete();
    } on FirebaseAuthException catch (e) {
      throw AuthFailure.fromCode(e.code, e.message);
    } catch (e) {
      throw AuthFailure(e.toString());
    }
  }
}
