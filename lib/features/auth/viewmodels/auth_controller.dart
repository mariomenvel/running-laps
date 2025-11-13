import 'package:flutter/material.dart';
import '../data/auth_repository.dart';
// import 'package:firebase_auth/firebase_auth.dart'; // No se necesita aquí si AuthRepository retorna Credenciales

// Renombrado de AuthViewModel a AuthController para mantener consistencia con tu original
class AuthController {
  final AuthRepository _repo = AuthRepository();

  // 1. Estados Observables (ValueNotifiers para ser consumidos por la View)
  final ValueNotifier<bool> isLoading = ValueNotifier<bool>(false);
  final ValueNotifier<bool> isLoginView = ValueNotifier<bool>(true);

  // 2. Controladores (Gestionados por el Controller)
  final TextEditingController emailCtrl = TextEditingController();
  final TextEditingController passCtrl = TextEditingController();
  final TextEditingController usernameCtrl = TextEditingController();
  final TextEditingController confirmPassCtrl = TextEditingController();

  // Lógica de Autenticación
  Future<void> signIn() async {
    isLoading.value = true;
    try {
      if (emailCtrl.text.trim().isEmpty || passCtrl.text.isEmpty) {
        throw Exception('Todos los campos son obligatorios.');
      }
      // Llamada al Repository
      await _repo.signIn(emailCtrl.text, passCtrl.text);
    } catch (e) {
      // El Controller solo lanza la excepción; la View se encarga de mostrar el error.
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> signUp() async {
    isLoading.value = true;
    try {
      // 1. Comprobar si las contraseñas coinciden
      if (passCtrl.text != confirmPassCtrl.text) {
        throw Exception("Las contraseñas no coinciden");
      }
      if (emailCtrl.text.trim().isEmpty || passCtrl.text.isEmpty || usernameCtrl.text.isEmpty) {
        throw Exception('Todos los campos son obligatorios.');
      }

      // 2. Llamada al Repository
      await _repo.signUp(
        emailCtrl.text,
        passCtrl.text,
        usernameCtrl.text,
      );

      // 3. Después de registrarse, volvemos al Login
      toggleView();

    } catch (e) {
      rethrow;
    } finally {
      isLoading.value = false;
    }
  }

  // Lógica de UI (Cambio de Vista)
  void toggleView() {
    // Limpiar todos los campos al cambiar de vista
    emailCtrl.clear();
    passCtrl.clear();
    usernameCtrl.clear();
    confirmPassCtrl.clear();

    // Invertir la vista
    isLoginView.value = !isLoginView.value;
  }
  
  // Limpieza de recursos
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    usernameCtrl.dispose();
    confirmPassCtrl.dispose();
    isLoading.dispose();
    isLoginView.dispose();
  }
}