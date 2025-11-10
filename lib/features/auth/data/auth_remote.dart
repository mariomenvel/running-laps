// ============================================================
// Clase: AuthRemote
// ------------------------------------------------------------
// Responsable de manejar TODAS las operaciones remotas de
// autenticación y almacenamiento de perfil en Firebase.
// Se comunica directamente con:
//   - Firebase Authentication  → registro, login, logout.
//   - Cloud Firestore           → guardar datos del usuario.
// ------------------------------------------------------------
// Esta clase NO maneja lógica de interfaz ni validaciones de
// formularios. Solo se encarga de la comunicación con Firebase.
// ============================================================

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthRemote {
  // Instancia de FirebaseAuth (para autenticación)
  FirebaseAuth _auth;
  // Instancia de Firestore (para base de datos de usuarios)
  FirebaseFirestore _db;

  // ------------------------------------------------------------
  // Constructor clásico:
  // Si no se pasa una instancia externa (por test o mock),
  // usa las instancias por defecto de Firebase.
  // ------------------------------------------------------------
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

  // ------------------------------------------------------------
  // -------------------- MÉTODOS DE AUTH -----------------------
  // ------------------------------------------------------------

  // Devuelve un stream que emite eventos cada vez que el estado
  // de autenticación cambia (login, logout, etc.).
  Stream<User?> authStateChanges() {
    return _auth.authStateChanges();
  }

  // Devuelve el usuario actualmente autenticado (o null si no hay ninguno).
  User? getCurrentUser() {
    return _auth.currentUser;
  }

  // Crea un nuevo usuario en Firebase Authentication con email y contraseña.
  // Devuelve un objeto UserCredential (contiene info del usuario creado).
  Future<UserCredential> createUser(String email, String password) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // Inicia sesión con email y contraseña.
  // Devuelve también un UserCredential (usuario logueado).
  Future<UserCredential> signIn(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // Cierra la sesión del usuario actual.
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // ------------------------------------------------------------
  // -------------------- MÉTODOS DE FIRESTORE ------------------
  // ------------------------------------------------------------

  // Guarda (o reemplaza) el documento del usuario en la colección “users”.
  // - uid: identificador del usuario autenticado.
  // - data: mapa con los campos del perfil (nombre, email, fecha, etc.)
  Future<void> saveUserDoc(String uid, Map<String, dynamic> data) async {
    await _db.collection("users").doc(uid).set(data);
  }
}
