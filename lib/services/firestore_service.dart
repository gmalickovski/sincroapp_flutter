import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:sincro_app_flutter/models/user_model.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<UserModel?> getUserData(String uid) async {
    // Mensagem de diagnóstico 1
    print("FirestoreService: A verificar dados no Firestore para o UID: $uid");

    final docRef = _db.collection('users').doc(uid);

    try {
      final docSnap = await docRef.get();

      // Mensagem de diagnóstico 2
      print(
          "FirestoreService: Verificação concluída. Documento existe: ${docSnap.exists}");

      if (docSnap.exists) {
        // Mensagem de diagnóstico 3
        print("FirestoreService: A retornar dados do utilizador existente.");
        return UserModel.fromFirestore(docSnap.data()!, docSnap.id);
      }

      // Mensagem de diagnóstico 4
      print("FirestoreService: Utilizador novo. A retornar null.");
      return null;
    } catch (e) {
      // Mensagem de diagnóstico de ERRO
      print("FirestoreService: OCORREU UM ERRO AO ACEDER AO FIRESTORE: $e");
      return null;
    }
  }

  Future<void> saveUserData(UserModel user) async {
    final docRef = _db.collection('users').doc(user.uid);
    await docRef.set(user.toFirestore());
  }
}
