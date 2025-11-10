// ============================================================
// Clase: AuthFailure
// ------------------------------------------------------------
// Representa un error de autenticación de Firebase de forma
// amigable y manejable dentro de la aplicación.
//
// Objetivo:
//   - Traducir los códigos de error de FirebaseAuth (como
//     "user-not-found" o "wrong-password") a mensajes claros
//     en español.
//   - Permitir lanzar excepciones personalizadas en lugar de
//     mostrar mensajes genéricos del SDK.
// ------------------------------------------------------------
// Esta clase se utiliza principalmente dentro de AuthRepository.
// ============================================================

class AuthFailure implements Exception {
  // Mensaje legible del error
  late String message;

  // Constructor que recibe el mensaje a mostrar
  AuthFailure(String messageParam) {
    message = messageParam;
  }

  // ------------------------------------------------------------
  // Sobrescribe toString() para que el error sea imprimible
  // directamente en consola o en logs.
  // ------------------------------------------------------------
  @override
  String toString() {
    return message;
  }

  // ------------------------------------------------------------
  // Método estático: fromCode
  // ------------------------------------------------------------
  // Convierte los códigos de error devueltos por FirebaseAuth
  // en instancias de AuthFailure con mensajes personalizados.
  //
  // Parámetros:
  //   - code: el código de error (p.ej., "user-not-found").
  //   - rawMessage: mensaje crudo original (opcional).
  //
  // Ejemplo de uso:
  //   } on FirebaseAuthException catch (e) {
  //       throw AuthFailure.fromCode(e.code, e.message);
  //     }
  // ------------------------------------------------------------
  static AuthFailure fromCode(String code, String? rawMessage) {
    if (code == "invalid-email") {
      return AuthFailure("Email inválido.");
    } else if (code == "user-disabled") {
      return AuthFailure("Este usuario está deshabilitado.");
    } else if (code == "user-not-found") {
      return AuthFailure("No existe una cuenta con ese email.");
    } else if (code == "wrong-password") {
      return AuthFailure("Contraseña incorrecta.");
    } else if (code == "email-already-in-use") {
      return AuthFailure("Ese email ya está registrado.");
    } else if (code == "weak-password") {
      return AuthFailure("La contraseña es demasiado débil.");
    } else if (code == "operation-not-allowed") {
      return AuthFailure("Operación no permitida en el proyecto.");
    } else {
      // Si el código no coincide con ninguno conocido,
      // usa el mensaje original o un texto genérico.
      if (rawMessage != null) {
        return AuthFailure(rawMessage);
      }
      return AuthFailure("Error de autenticación desconocido.");
    }
  }
}
