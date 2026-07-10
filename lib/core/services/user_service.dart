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

  /// Checks if the user is signed in with Google
  bool isGoogleUser() {
    final user = currentUser;
    if (user == null) return false;
    for (final provider in user.providerData) {
      if (provider.providerId == 'google.com') return true;
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

  // ==========================================
  // PASSWORD MANAGEMENT
  // ==========================================

  Future<void> updatePassword(String newPassword) async {
    final user = currentUser;
    if (user == null) throw AuthFailure('No hay usuario autenticado');
    if (isGoogleUser()) throw AuthFailure('Los usuarios de Google no pueden cambiar contraseña localmente');

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
