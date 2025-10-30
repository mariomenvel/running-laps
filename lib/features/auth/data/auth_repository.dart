import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthRepository {
  // Instancia de FirebaseAuth
  FirebaseAuth _auth;
  // Instancia de Firestore (Base de datos)
  FirebaseFirestore _db;

  // Constructor clásico; asigno dentro del cuerpo (sin “:” y sin “??”)
  AuthRepository({FirebaseAuth? auth})
    : _auth = FirebaseAuth.instance,
      _db = FirebaseFirestore.instance {
    if (auth != null) {
      _auth = auth;
    }
  }

  // Flujo del estado de autenticación
  Stream<User?> authStateChanges() {
    return _auth.authStateChanges();
  }

  // Obtener usuario actual (puede ser null)
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Registro con email + contraseña
  Future<UserCredential> signUp(String email, String password , String nombre) async {
    try {
      String cleanedEmail = email.trim();
      UserCredential cred = await _auth.createUserWithEmailAndPassword(
        email: cleanedEmail,
        password: password,
      );
      User? user = cred.user;
      if (user != null) {
        await _db.collection('users').doc(user.uid).set({
          'email': cleanedEmail,
          'nombre': nombre,
          'createdAt': FieldValue.serverTimestamp(),
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
      UserCredential cred = await _auth.signInWithEmailAndPassword(
        email: cleanedEmail,
        password: password,
      );
      return cred;
    } on FirebaseAuthException catch (e) {
      throw AuthFailure.fromCode(e.code, e.message);
    }
  }

  // Cerrar sesión
  Future<void> signOut() async {
    await _auth.signOut();
  }
}

// Manejo de errores legibles
class AuthFailure implements Exception {
  final String message;

  AuthFailure(this.message);

  @override
  String toString() {
    return message;
  }

  static AuthFailure fromCode(String code, String? rawMessage) {
    if (code == 'invalid-email') {
      return AuthFailure('Email inválido.');
    } else if (code == 'user-disabled') {
      return AuthFailure('Este usuario está deshabilitado.');
    } else if (code == 'user-not-found') {
      return AuthFailure('No existe una cuenta con ese email.');
    } else if (code == 'wrong-password') {
      return AuthFailure('Contraseña incorrecta.');
    } else if (code == 'email-already-in-use') {
      return AuthFailure('Ese email ya está registrado.');
    } else if (code == 'weak-password') {
      return AuthFailure('La contraseña es demasiado débil.');
    } else if (code == 'operation-not-allowed') {
      return AuthFailure('Operación no permitida en el proyecto.');
    } else {
      if (rawMessage != null) {
        return AuthFailure(rawMessage);
      }
      return AuthFailure('Error de autenticación desconocido.');
    }
  }
}
