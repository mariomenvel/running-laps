import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_remote.dart';

class AuthRepository {
  AuthRemote _remote;

  AuthRepository({AuthRemote? remote})
      : _remote = AuthRemote() {
    if (remote != null) {
      _remote = remote;
    }
  }

  // ==========================
  // Auth básico
  // ==========================

  Stream<User?> authStateChanges() {
    return _remote.authStateChanges();
  }

  User? getCurrentUser() {
    return _remote.getCurrentUser();
  }

  Future<void> signIn(String email, String password) async {
    await _remote.signIn(email, password);
  }

  Future<void> signInWithGoogle() async {
    UserCredential cred = await _remote.signInWithGoogle();
    User? user = cred.user;

    if (user != null) {
      // Verificar si el documento ya existe
      final name = await _remote.getUserName();
      if (name == null) {
        // Es la primera vez que inicia sesión con Google (o no tiene nombre en Firestore)
        await _remote.saveUserDoc(user.uid, <String, dynamic>{
          "nombre": user.displayName ?? "Usuario",
          "email": user.email,
          "createdAt": FieldValue.serverTimestamp(),
          "photoUrl": user.photoURL,
        });
      }
    }
  }

  Future<void> signUp(String email, String password, String nombre) async {
    // 1) Crear usuario en Firebase Auth
    UserCredential cred = await _remote.createUser(email, password);
    User? user = cred.user;

    if (user == null) {
      throw Exception("No se pudo crear el usuario.");
    }

    // 2) Guardar documento en Firestore
    await _remote.saveUserDoc(user.uid, <String, dynamic>{
      "nombre": nombre,
      "email": email.trim(),
      "createdAt": FieldValue.serverTimestamp(),
    });
  }

  Future<void> signOut() async {
    await _remote.signOut();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _remote.sendPasswordResetEmail(email);
  }

  Future<void> sendEmailVerification() async {
    await _remote.sendEmailVerification();
  }

  // ==========================
  // Obtener nombre
  // ==========================

  Future<String?> getUserName() async {
    return await _remote.getUserName();
  }

  Future<bool> isUserAdmin() async {
    return await _remote.isUserAdmin();
  }
}

