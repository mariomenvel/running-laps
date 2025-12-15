import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthRemote {
  FirebaseAuth _auth;
  FirebaseFirestore _db;

  AuthRemote({FirebaseAuth? auth, FirebaseFirestore? db})
    : _auth = FirebaseAuth.instance,
      _db = FirebaseFirestore.instance {
    if (auth != null) {
      _auth = auth;
    }
    if (db != null) {
      _db = db;
    }
  }

  // ----- Auth -----
  Stream<User?> authStateChanges() {
    return _auth.authStateChanges();
  }

  User? getCurrentUser() {
    return _auth.currentUser;
  }

  Future<UserCredential> createUser(String email, String password) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<UserCredential> signIn(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  // --- Helper de Errores ---
  String _mapFirebaseError(Object e) {
    if (e is FirebaseAuthException) {
      switch (e.code) {
        case 'user-not-found':
          return 'No encontramos ninguna cuenta con ese correo.';
        case 'invalid-email':
          return 'El correo electrónico no es válido.';
        case 'network-request-failed':
          return 'Error de conexión. Revisa tu internet.';
        case 'too-many-requests':
          return 'Demasiados intentos. Inténtalo más tarde.';
        default:
          return 'Ocurrió un error: ${e.message}';
      }
    }
    return 'Ocurrió un error inesperado.';
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      print("DEBUG: Verificando si el usuario existe en Firestore: $email");
      
      // 1. Verificar si existe en Firestore
      // Asumimos que el email es único y verificamos coincidencia exacta
      final querySnapshot = await _db
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
        // Lanzamos manualmente el error si no existe en nuestra base de datos
        throw FirebaseAuthException(code: 'user-not-found');
      }

      print("DEBUG: Usuario encontrado. Intentando enviar correo de restablecimiento.");
      await _auth.sendPasswordResetEmail(email: email);
      print("DEBUG: Correo de restablecimiento enviado correctamente.");
    } catch (e) {
      print("DEBUG: Error al enviar correo de restablecimiento: $e");
      // Utilizamos nuestro mapeador para asegurar mensajes amigables
      throw _mapFirebaseError(e);
    }
  }

  Future<void> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user != null && !user.emailVerified) {
        print("DEBUG: Enviando correo de verificación a ${user.email}");
        await user.sendEmailVerification();
        print("DEBUG: Correo de verificación enviado.");
      }
    } catch (e) {
      print("DEBUG: Error al enviar verificación: $e");
      throw _mapFirebaseError(e);
    }
  }

  // ----- Firestore (perfil básico) -----
  Future<void> saveUserDoc(String uid, Map<String, dynamic> data) async {
    await _db.collection("users").doc(uid).set(data);  
  }

  Future<String?> getUserName() async {
  try {
    User? userActual = _auth.currentUser;

    if (userActual == null) {
      return null;
    }

    String uid = userActual.uid;

    DocumentSnapshot doc =
        await _db.collection("users").doc(uid).get();

    if (doc.exists) {
      Map<String, dynamic>? data =
          doc.data() as Map<String, dynamic>?;

      if (data != null && data.containsKey("nombre")) {
        return data["nombre"];
      }
    }

    return null; // si no existe o no tiene nombre
  } catch (e) {
    print("Error obteniendo nombre: $e");
    return null;
  }
}

}
