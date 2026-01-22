import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  // ACCOUNT DELETION
  // ==========================================

  Future<void> deleteAccount() async {
    final user = currentUser;
    if (user == null) throw AuthFailure('No hay usuario autenticado');

    final uid = user.uid;

    try {
      // 1. Delete user data from Firestore
      // (Optional: You might want to delete their training history first or in a trigger)
      await _db.collection('users').doc(uid).delete();

      // 2. Delete user from Firebase Auth
      await user.delete();
    } on FirebaseAuthException catch (e) {
      // If error is 'requires-recent-login', it should have been caught by the UI reauth flow
      throw AuthFailure.fromCode(e.code, e.message);
    } catch (e) {
      throw AuthFailure(e.toString());
    }
  }
}
