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

      await _repo.signUp(emailCtrl.text, passCtrl.text, usernameCtrl.text);

      // Volver a la vista de login
      toggleView();
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
