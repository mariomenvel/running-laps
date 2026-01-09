class AuthFailure implements Exception {
  late String message;

  AuthFailure(String messageParam) {
    message = messageParam;
  }

  @override
  String toString() {
    return message;
  }

  static AuthFailure fromCode(String code, String? rawMessage) {
    if (code == "invalid-email") {
      return AuthFailure("El correo electrónico no es válido.");
    } else if (code == "user-disabled") {
      return AuthFailure("Este usuario ha sido deshabilitado.");
    } else if (code == "user-not-found") {
      return AuthFailure("No encontramos ninguna cuenta con ese correo.");
    } else if (code == "wrong-password") {
      return AuthFailure("Contraseña incorrecta.");
    } else if (code == "email-already-in-use") {
      return AuthFailure("Este correo ya está registrado. Prueba a iniciar sesión o recuperar contraseña.");
    } else if (code == "weak-password") {
      return AuthFailure("La contraseña es demasiado débil.");
    } else if (code == "operation-not-allowed") {
      return AuthFailure("Operación no permitida.");
    } else if (code == "network-request-failed") {
      return AuthFailure('Error de conexión. Revisa tu internet.');
    } else if (code == "too-many-requests") {
      return AuthFailure('Demasiados intentos. Inténtalo más tarde.');
    } else {
      if (rawMessage != null) {
        return AuthFailure(rawMessage);
      }
      return AuthFailure("Error de autenticación desconocido.");
    }
  }
}

