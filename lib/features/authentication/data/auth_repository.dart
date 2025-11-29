import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthRepository {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;

  // Stream para o AuthCheck em main.dart
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  // Método para obter o utilizador atual para o Dashboard
  User? getCurrentUser() {
    return _firebaseAuth.currentUser;
  }

  // Método para a LoginScreen
  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('[AuthRepository] Iniciando signIn email=${email.trim()}');
      await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      debugPrint(
          '[AuthRepository] signIn concluído. currentUser=${_firebaseAuth.currentUser?.uid}');
    } catch (e) {
      debugPrint('[AuthRepository] Erro no signIn: $e');
      rethrow;
    }
  }

  // Método para a RegisterScreen (o que estava em falta)
  Future<void> createUserWithEmailAndPassword({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      // Atualiza o nome de exibição do utilizador recém-criado
      await userCredential.user?.updateDisplayName(displayName.trim());
    } catch (e) {
      rethrow;
    }
  }

  // Método para o DashboardScreen
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  // Envia email de redefinição de senha
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      // Chama a Cloud Function personalizada para enviar via n8n
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('requestPasswordReset');
      await callable.call({'email': email.trim()});
    } catch (e) {
      // Fallback: Se a função falhar (ex: offline), tenta o método nativo
      // Mas idealmente queremos forçar o n8n.
      debugPrint('Erro na função requestPasswordReset: $e');
      // Opcional: Descomente abaixo se quiser fallback
      // await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
      rethrow;
    }
  }
    } on FirebaseAuthException {
      // Repassa para a UI decidir a mensagem
      rethrow;
    } catch (e) {
      rethrow;
    }
  }
}
