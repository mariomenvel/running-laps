import 'package:flutter/material.dart';
import '../data/auth_repository.dart';

class AuthController {
  final AuthRepository _repo = AuthRepository();

  // 1. Estados Observables
  final ValueNotifier<bool> isLoading = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isLoginView = ValueNotifier<bool>(true);

  // 2. Controladores
  final TextEditingController emailCtrl = TextEditingController();
  final TextEditingController passCtrl = TextEditingController();
  final TextEditingController usernameCtrl = TextEditingController();
  final TextEditingController confirmPassCtrl = TextEditingController();

  // ==========================
  // NUEVO: obtener nombre
  // ==========================
  Future<String?> getUserName() async {
    return await _repo.getUserName();
  }

  Future<bool> isUserAdmin() async {
    return await _repo.isUserAdmin();
  }

  // ==========================
  // LOGIN
  // ==========================
  Future<void> signIn() async {
    isLoading.value = true;
    try {
      if (emailCtrl.text.trim().isEmpty || passCtrl.text.isEmpty) {
        throw Exception('Todos los campos son obligatorios.');
      }
      await _repo.signIn(emailCtrl.text, passCtrl.text);

      // VERIFICACIÓN DE EMAIL
      final user = _repo.getCurrentUser();
      if (user != null && !user.emailVerified) {
        await _repo.signOut(); // No dejarle entrar
        throw Exception('Debes verificar tu correo electrónico antes de iniciar sesión. Revisalo.');
      }

    } catch (e) {
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> signInWithGoogle() async {
    isLoading.value = true;
    try {
      await _repo.signInWithGoogle();
    } catch (e) {
      if (e.toString().contains('aborted-by-user')) {
        // Ignorar si el usuario simplemente canceló el diálogo
        return;
      }
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> resendVerificationEmail(String email, String password) async {
      isLoading.value = true;
      try {
        // Necesitamos iniciar sesión temporalmente para enviar el correo si no hay usuario activo
         await _repo.signIn(email, password);
         await _repo.sendEmailVerification();
         await _repo.signOut();
      } catch (e) {
        rethrow;
      } finally {
        isLoading.value = false;
      }
  }

  // ==========================
  // REGISTRO
  // ==========================
  Future<void> signUp() async {
    isLoading.value = true;
    try {
      if (passCtrl.text != confirmPassCtrl.text) {
        throw Exception('Las contraseñas no coinciden');
      }
      if (emailCtrl.text.trim().isEmpty ||
          passCtrl.text.isEmpty ||
          usernameCtrl.text.isEmpty) {
        throw Exception('Todos los campos son obligatorios.');
      }

      // VALIDACIÓN DE CONTRASEÑA
      final password = passCtrl.text;
      final hasMinLength = password.length >= 8;
      final hasUppercase = password.contains(RegExp(r'[A-Z]'));
      final hasDigits = password.contains(RegExp(r'[0-9]'));

      if (!hasMinLength || !hasUppercase || !hasDigits) {
        throw Exception(
            'La contraseña no cumple los requisitos.'); 
      }

      await _repo.signUp(emailCtrl.text, passCtrl.text, usernameCtrl.text);

      // Enviar email de verificación
      await _repo.sendEmailVerification();

      // Volver a la vista de login
      toggleView();
    } catch (e) {
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  // ==========================
  // RECUPERAR CONTRASEÑA
  // ==========================
  Future<void> recoverPassword(String email) async {
    if (email.trim().isEmpty) {
      throw Exception('Por favor, introduce tu correo electrónico.');
    }
    isLoading.value = true;
    try {
      await _repo.sendPasswordResetEmail(email.trim());
    } catch (e) {
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  // ==========================
  // LOGOUT
  // ==========================
  Future<void> signOut() async {
    isLoading.value = true;
    try {
      await _repo.signOut();

      // Limpiamos campos por si acaso
      emailCtrl.clear();
      passCtrl.clear();
      usernameCtrl.clear();
      confirmPassCtrl.clear();
    } catch (e) {
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  // ==========================
  // Cambio de vista (login / registro)
  // ==========================
  void toggleView() {
    emailCtrl.clear();
    passCtrl.clear();
    usernameCtrl.clear();
    confirmPassCtrl.clear();

    isLoginView.value = !isLoginView.value;
  }

  // ==========================
  // Limpieza
  // ==========================
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    usernameCtrl.dispose();
    confirmPassCtrl.dispose();
    isLoading.dispose();
    isLoginView.dispose();
  }
}

