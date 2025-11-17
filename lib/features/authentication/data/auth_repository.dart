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
      await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
    } catch (e) {
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
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException {
      // Repassa para a UI decidir a mensagem
      rethrow;
    } catch (e) {
      rethrow;
    }
  }
}
