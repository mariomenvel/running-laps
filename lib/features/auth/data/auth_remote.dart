import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
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

  Future<UserCredential> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final result = await _auth.signInWithPopup(GoogleAuthProvider());
        final user = result.user;
        print('WEB LOGIN: user=${user?.uid}, email=${user?.email}');
        if (user != null) {
          // Force token refresh so Firestore rules can verify request.auth
          await user.getIdToken(true);
          print('WEB LOGIN: token refreshed');
          try {
            final doc = await _db.collection("users").doc(user.uid).get();
            print('WEB LOGIN: doc.exists=${doc.exists}');
            if (!doc.exists) {
              await _db.collection("users").doc(user.uid).set({
                "nombre": user.displayName ?? "Usuario",
                "email": user.email,
                "createdAt": FieldValue.serverTimestamp(),
                "photoUrl": user.photoURL,
                "totalSessions": 0,
                "totalKm": 0.0,
                "totalTimeMinutes": 0.0,
                "lastTrainingDate": null,
              });
              print('WEB LOGIN: document created successfully');
            }
          } catch (e) {
            print('WEB LOGIN ERROR: $e');
          }
        }
        return result;
      }

      final GoogleSignIn googleSignIn = GoogleSignIn();
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        throw AuthFailure.fromCode('aborted-by-user', 'Sign in aborted by user');
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return await _auth.signInWithCredential(credential);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure.fromCode(e.code, e.message);
    } catch (e) {
      if (e is AuthFailure) rethrow;
      throw AuthFailure(e.toString());
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {

      
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


      await _auth.sendPasswordResetEmail(email: email);

    } on FirebaseAuthException catch (e) {
      throw AuthFailure.fromCode(e.code, e.message);
    } catch (e) {
      if (e is AuthFailure) rethrow; // Si ya es AuthFailure (lanzado manualmente), lo dejamos pasar

      throw AuthFailure(e.toString());
    }
  }

  Future<void> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
      }
    } on FirebaseAuthException catch (e) {
      throw AuthFailure.fromCode(e.code, e.message);
    } catch (e) {

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

    return null;
  }
}

Future<bool> isUserAdmin() async {
  try {
    User? userActual = _auth.currentUser;
    if (userActual == null) return false;

    DocumentSnapshot doc = await _db.collection("users").doc(userActual.uid).get();
    if (doc.exists) {
       final data = doc.data() as Map<String, dynamic>?;
       return data?['isAdmin'] == true;
    }
    return false;
  } catch (e) {

    return false;
  }
}

}

