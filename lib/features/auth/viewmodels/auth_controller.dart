import 'package:flutter/material.dart';
import '../data/auth_repository.dart';
import 'package:running_laps/core/services/user_service.dart';

class AuthController {
  final AuthRepository _repo = AuthRepository();
  final UserService _userService = UserService();

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
  // GESTIÓN DE USUARIO (UserService delegates)
  // ==========================
  bool isGoogleUser() => _userService.isGoogleUser();

  Future<void> updateName(String newName) async {
    isLoading.value = true;
    try {
      await _userService.updateNombre(newName);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> reauthenticate(String password) async {
    isLoading.value = true;
    try {
      if (isGoogleUser()) {
        await _userService.reauthenticateWithGoogle();
      } else {
        await _userService.reauthenticate(password);
      }
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> updatePassword(String newPassword) async {
    isLoading.value = true;
    try {
      await _userService.updatePassword(newPassword);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> deleteAccount() async {
    isLoading.value = true;
    try {
      await _userService.deleteAccount();
    } finally {
      isLoading.value = false;
    }
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

