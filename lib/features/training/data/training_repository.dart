// ============================================================
// Clase: TrainingRepository
// ------------------------------------------------------------
// Responsable de gestionar las operaciones CRUD (crear, leer,
// actualizar, borrar) relacionadas con los entrenamientos
// del usuario en Firestore.
//
// Estructura de Firestore utilizada:
//   users/{uid}/trainings/{trainingId}
//
// Esta clase requiere que el usuario esté autenticado, ya que
// cada entrenamiento se guarda bajo su propio UID.
// ============================================================

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'entrenamiento.dart'; // Modelo de datos del entrenamiento

class TrainingRepository {
  // Instancias principales de Firebase
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ------------------------------------------------------------
  // Método privado: _requireUid
  // ------------------------------------------------------------
  // Devuelve el UID del usuario autenticado.
  // Si no hay usuario logueado, lanza una excepción.
  String _requireUid() {
    final User? u = _auth.currentUser;
    if (u == null) {
      throw Exception('No hay usuario autenticado');
    }
    return u.uid;
  }

  // ------------------------------------------------------------
  // Método privado: _userTrainings
  // ------------------------------------------------------------
  // Devuelve una referencia a la subcolección de entrenamientos
  // dentro del documento del usuario actual:
  //   users/{uid}/trainings
  //
  // Esto permite mantener la base de datos organizada por usuario.
  CollectionReference<Map<String, dynamic>> _userTrainings(String uid) {
    return _db.collection('users').doc(uid).collection('trainings');
  }

  // ------------------------------------------------------------
  // Método público: createTraining
  // ------------------------------------------------------------
  // Crea un nuevo documento de entrenamiento dentro de la
  // subcolección “trainings” del usuario actual.
  //
  // Parámetros:
  //   e → objeto Entrenamiento (ya completo, con series).
  //
  // Flujo:
  //   1. Verifica que hay usuario autenticado.
  //   2. Convierte el entrenamiento a Map.
  //   3. Añade timestamps de creación y actualización.
  //   4. Inserta el documento en Firestore.
  //   5. Devuelve el ID del nuevo documento (para futuras consultas).
  Future<String> createTraining(Entrenamiento e) async {
    final String uid = _requireUid(); // 1️⃣ Obtener UID del usuario actual
    final Map<String, dynamic> data = e
        .toMap(); // 2️⃣ Convertir entrenamiento a Map

    // 3️⃣ Añadir metadatos automáticos
    data['createdAt'] = FieldValue.serverTimestamp();
    data['updatedAt'] = FieldValue.serverTimestamp();

    // 4️⃣ Insertar el documento en la subcolección
    final DocumentReference<Map<String, dynamic>> doc = await _userTrainings(
      uid,
    ).add(data);

    // 5️⃣ Devolver el ID autogenerado por Firestore
    return doc.id;
  }
}
