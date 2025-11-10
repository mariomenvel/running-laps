// ============================================================
// Clase: AuthController
// ------------------------------------------------------------
// Responsable de coordinar la lógica de autenticación entre
// la capa de interfaz (por ejemplo, LoginPage) y el repositorio.
//
// Su misión principal es:
//   - Validar datos introducidos por el usuario (inputs).
//   - Delegar las operaciones de login / registro al AuthRepository.
//   - Manejar errores de validación antes de llamar al backend.
// ------------------------------------------------------------
// En este punto, no debería contener lógica de Firebase ni
// acceso a base de datos: eso ya lo gestiona AuthRepository.
// ============================================================

import '../data/auth_repository.dart'; // Lógica de conexión con Firebase
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // (no se usa aquí todavía)

class AuthController {
  // Instancia privada del repositorio
  final AuthRepository _repo = AuthRepository();

  // ------------------------------------------------------------
  // Método: login
  // ------------------------------------------------------------
  // Inicia sesión de usuario con email y contraseña.
  //
  // Flujo:
  // 1. Valida que el email y la contraseña no estén vacíos.
  // 2. Llama al método signIn del repositorio.
  // 3. Devuelve el objeto User (si el login fue exitoso).
  //
  // En caso de error (validación o Firebase), lanza una excepción.
  // ------------------------------------------------------------
  Future<User?> login(String email, String password) async {
    // Validación de campos
    if (email.trim().isEmpty) {
      throw Exception('El email es obligatorio.');
    }
    if (password.isEmpty) {
      throw Exception('La contraseña es obligatoria.');
    }

    // Llamada al repositorio para autenticar con Firebase
    final User? user = (await _repo.signIn(email, password)).user;

    // Devuelve el usuario autenticado o null
    return user;
  }
}
