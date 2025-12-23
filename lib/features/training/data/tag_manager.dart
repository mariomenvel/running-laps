import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'tag_model.dart';

/// Repositorio para gestionar las etiquetas personalizadas del usuario
class TagManager {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const int maxTagsPerUser = 20;
  static const int maxTagNameLength = 20;

  String _requireUid() {
    final User? u = _auth.currentUser;
    if (u == null) {
      throw Exception('No hay usuario autenticado');
    }
    return u.uid;
  }

  CollectionReference<Map<String, dynamic>> _userTags(String uid) {
    return _db.collection('users').doc(uid).collection('tags');
  }

  /// Obtiene todas las etiquetas del usuario actual
  Future<List<TrainingTag>> getUserTags() async {
    final String uid = _requireUid();

    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await _userTags(uid).get();

    final List<TrainingTag> tags = [];
    for (var doc in snapshot.docs) {
      tags.add(TrainingTag.fromMap(doc.data()));
    }

    // Ordenar alfabéticamente
    tags.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return tags;
  }

  /// Crea una nueva etiqueta
  Future<void> createTag(TrainingTag tag) async {
    final String uid = _requireUid();

    // Validaciones
    if (tag.name.trim().isEmpty) {
      throw Exception('El nombre de la etiqueta no puede estar vacío');
    }

    if (tag.name.length > maxTagNameLength) {
      throw Exception(
          'El nombre de la etiqueta no puede tener más de $maxTagNameLength caracteres');
    }

    // Verificar que no existe ya
    final existing = await _userTags(uid).doc(tag.name).get();
    if (existing.exists) {
      throw Exception('Ya existe una etiqueta con ese nombre');
    }

    // Verificar límite de etiquetas
    final currentTags = await getUserTags();
    if (currentTags.length >= maxTagsPerUser) {
      throw Exception('No puedes crear más de $maxTagsPerUser etiquetas');
    }

    // Crear etiqueta
    await _userTags(uid).doc(tag.name).set(tag.toMap());
  }

  /// Actualiza una etiqueta existente (solo el color)
  Future<void> updateTag(TrainingTag tag) async {
    final String uid = _requireUid();

    final existing = await _userTags(uid).doc(tag.name).get();
    if (!existing.exists) {
      throw Exception('La etiqueta no existe');
    }

    await _userTags(uid).doc(tag.name).update(tag.toMap());
  }

  /// Elimina una etiqueta
  /// NOTA: Esto NO elimina la etiqueta de los entrenamientos que la usan
  Future<void> deleteTag(String tagName) async {
    final String uid = _requireUid();

    await _userTags(uid).doc(tagName).delete();
  }

  /// Verifica si existe una etiqueta con el nombre dado
  Future<bool> tagExists(String tagName) async {
    final String uid = _requireUid();

    final doc = await _userTags(uid).doc(tagName).get();
    return doc.exists;
  }
}
