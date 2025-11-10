// ============================================================
// Clase: AuthRepository
// ------------------------------------------------------------
// Esta clase actúa como “puente” entre la interfaz (UI/ViewModel)
// y la capa de comunicación remota (AuthRemote).
//
// Su misión es:
//   - Manejar la lógica de negocio básica relacionada con auth.
//   - Centralizar la gestión de errores (AuthFailure).
//   - Asegurar consistencia entre Firebase Auth y Firestore.
//
// Es parte del patrón “Repository” dentro del enfoque MVVM o Clean Architecture.
// ============================================================

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/auth_failure.dart'; // Manejo de errores personalizado
import 'auth_remote.dart'; // Capa remota (Firebase)

class AuthRepository {
  // Dependencia hacia la capa remota.
  AuthRemote _remote;

  // ------------------------------------------------------------
  // Constructor clásico con inyección opcional de dependencias.
  // - Permite sustituir el comportamiento en tests (mocking).
  // - Si no se pasa un remote, se crea con instancias por defecto.
  // ------------------------------------------------------------
  AuthRepository({
    AuthRemote? remote,
    FirebaseAuth? auth,
    FirebaseFirestore? db,
  }) : _remote = AuthRemote(auth: auth, db: db) {
    if (remote != null) {
      _remote = remote;
    }
  }

  // ------------------------------------------------------------
  // ----------------- FLUJO DE AUTENTICACIÓN -------------------
  // ------------------------------------------------------------

  // Stream que emite cambios del estado de autenticación (login/logout).
  // Permite que la app reaccione automáticamente a los cambios.
  Stream<User?> authStateChanges() {
    return _remote.authStateChanges();
  }

  // Devuelve el usuario autenticado actual (o null si no hay ninguno).
  User? getCurrentUser() {
    return _remote.getCurrentUser();
  }

  // ------------------------------------------------------------
  // ---------------------- REGISTRO -----------------------------
  // ------------------------------------------------------------

  // Registra un nuevo usuario con email y contraseña.
  // Además, crea un documento “users/{uid}” en Firestore con datos básicos.
  //
  // Parámetros:
  //  - email: correo electrónico del usuario.
  //  - password: contraseña.
  //  - nombre: nombre visible del usuario (guardado en Firestore).
  //
  // Flujo:
  // 1. Limpia espacios del email.
  // 2. Crea usuario en Firebase Auth.
  // 3. Si se crea correctamente, guarda el documento del perfil.
  // 4. Maneja los errores específicos con AuthFailure.
  Future<UserCredential> signUp(
    String email,
    String password,
    String nombre,
  ) async {
    try {
      String cleanedEmail = email.trim(); // Normaliza el email
      UserCredential cred = await _remote.createUser(cleanedEmail, password);

      User? user = cred.user;
      if (user != null) {
        // Guardamos el documento del perfil en la colección "users"
        await _remote.saveUserDoc(user.uid, <String, dynamic>{
          "email": cleanedEmail,
          "nombre": nombre,
          "createdAt": FieldValue.serverTimestamp(),
        });
      }

      return cred;
    } on FirebaseAuthException catch (e) {
      // Convierte el error de Firebase en una excepción manejable.
      throw AuthFailure.fromCode(e.code, e.message);
    }
  }

  // ------------------------------------------------------------
  // ------------------------ LOGIN -----------------------------
  // ------------------------------------------------------------

  // Inicia sesión con email y contraseña.
  // Devuelve el UserCredential si todo va bien.
  Future<UserCredential> signIn(String email, String password) async {
    try {
      String cleanedEmail = email.trim(); // Normaliza el email
      UserCredential cred = await _remote.signIn(cleanedEmail, password);
      return cred;
    } on FirebaseAuthException catch (e) {
      // Cualquier error (credenciales incorrectas, usuario no existe, etc.)
      // se transforma en un AuthFailure para mostrar mensajes personalizados.
      throw AuthFailure.fromCode(e.code, e.message);
    }
  }

  // ------------------------------------------------------------
  // ---------------------- LOGOUT -------------------------------
  // ------------------------------------------------------------

  // Cierra la sesión del usuario actual.
  Future<void> signOut() async {
    await _remote.signOut();
  }
}
