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
      if (rawMessage != null) {
        return AuthFailure(rawMessage);
      }
      return AuthFailure("Error de autenticación desconocido.");
    }
  }
}
