import 'package:cloud_firestore/cloud_firestore.dart';

class UserLookupService {
  final FirebaseFirestore _firestore;

  UserLookupService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Busca un usuario por email y devuelve su UID.
  /// Retorna null si no existe.
  /// NOTA: Esto requiere que la colección 'users' tenga el campo 'email'.
  Future<String?> lookupUserUidByEmail(String email) async {
    try {
      final query = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        return query.docs.first.id;
      }
      return null;
    } catch (e) {
      print("Error looking up user by email: $e");
      return null;
    }
  }
}
