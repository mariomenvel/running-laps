import '../data/auth_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; 

class AuthController {
  final AuthRepository _repo = AuthRepository();

  Future<User?> login(String email, String password) async {
    if(email.trim().isEmpty){
      throw Exception('El email es obligatorio.');
    }
    if(password.isEmpty){
      throw Exception('La contraseña es obligatoria.');
    }
    final User? user = (await _repo.signIn(email, password) ).user;
    return user;
  }


}