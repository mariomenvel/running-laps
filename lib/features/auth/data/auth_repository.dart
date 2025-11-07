import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/auth_failure.dart';
import 'auth_remote.dart';

class AuthRepository {
  AuthRemote _remote;

  // Constructor clásico con inyección opcional para tests
  AuthRepository({
    AuthRemote? remote,
    FirebaseAuth? auth,
    FirebaseFirestore? db,
  }) : _remote = AuthRemote(auth: auth, db: db) {
    if (remote != null) {
      _remote = remote;
    }
  }

  // Flujo del estado de autenticación
  Stream<User?> authStateChanges() {
    return _remote.authStateChanges();
  }

  // Obtener usuario actual (puede ser null)
  User? getCurrentUser() {
    return _remote.getCurrentUser();
  }

  // Registro con email + contraseña (+ guardar doc en users)
  Future<UserCredential> signUp(
    String email,
    String password,
    String nombre,
  ) async {
    try {
      String cleanedEmail = email.trim();
      UserCredential cred = await _remote.createUser(cleanedEmail, password);

      User? user = cred.user;
      if (user != null) {
        await _remote.saveUserDoc(user.uid, <String, dynamic>{
          "email": cleanedEmail,
          "nombre": nombre,
          "createdAt": FieldValue.serverTimestamp(),
        });
      }

      return cred;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure.fromCode(e.code, e.message);
    }
  }

  // Login con email + contraseña
  Future<UserCredential> signIn(String email, String password) async {
    try {
      String cleanedEmail = email.trim();
      UserCredential cred = await _remote.signIn(cleanedEmail, password);
      return cred;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure.fromCode(e.code, e.message);
    }
  }

  // Cerrar sesión
  Future<void> signOut() async {
    await _remote.signOut();
  }
}
