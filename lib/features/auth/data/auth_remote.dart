import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/auth_failure.dart';

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
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthFailure.fromCode(e.code, e.message);
    } catch (e) {
      throw AuthFailure(e.toString());
    }
  }

  Future<UserCredential> signIn(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthFailure.fromCode(e.code, e.message);
    } catch (e) {
      throw AuthFailure(e.toString());
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
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
        throw AuthFailure.fromCode('user-not-found', null);
      }

      print("DEBUG: Usuario encontrado. Intentando enviar correo de restablecimiento.");
      await _auth.sendPasswordResetEmail(email: email);
      print("DEBUG: Correo de restablecimiento enviado correctamente.");
    } on FirebaseAuthException catch (e) {
      throw AuthFailure.fromCode(e.code, e.message);
    } catch (e) {
      if (e is AuthFailure) rethrow; // Si ya es AuthFailure (lanzado manualmente), lo dejamos pasar
      print("DEBUG: Error al enviar correo de restablecimiento: $e");
      throw AuthFailure(e.toString());
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
    } on FirebaseAuthException catch (e) {
      throw AuthFailure.fromCode(e.code, e.message);
    } catch (e) {
      print("DEBUG: Error al enviar verificación: $e");
      throw AuthFailure(e.toString());
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
