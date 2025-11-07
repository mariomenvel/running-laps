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

  // ----- Firestore (perfil básico) -----
  Future<void> saveUserDoc(String uid, Map<String, dynamic> data) async {
    await _db.collection("users").doc(uid).set(data);
  }
}
