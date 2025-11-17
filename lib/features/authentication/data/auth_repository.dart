import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

// Chave do Site reCAPTCHA v3 para Web
const String kReCaptchaSiteKey = String.fromEnvironment(
  'RECAPTCHA_V3_SITE_KEY',
  defaultValue: '6LeC__ArAAAAAJUbYkba086MP-cCJBolbjLcm_uU',
);

class AuthRepository {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  bool _appCheckActivated = false;

  // Stream para o AuthCheck em main.dart
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  // Método para obter o utilizador atual para o Dashboard
  User? getCurrentUser() {
    return _firebaseAuth.currentUser;
  }

  /// Ativa App Check APÓS login bem-sucedido
  Future<void> _activateAppCheckIfNeeded() async {
    if (_appCheckActivated) return;

    try {
      debugPrint('🔧 Ativando App Check pós-login...');

      if (kDebugMode) {
        await FirebaseAppCheck.instance.activate(
          webProvider: ReCaptchaV3Provider(kReCaptchaSiteKey),
          androidProvider: AndroidProvider.debug,
          appleProvider: AppleProvider.debug,
        );
      } else {
        await FirebaseAppCheck.instance.activate(
          webProvider: ReCaptchaV3Provider(kReCaptchaSiteKey),
          androidProvider: AndroidProvider.playIntegrity,
          appleProvider: AppleProvider.appAttest,
        );
      }

      _appCheckActivated = true;
      debugPrint('✅ App Check ativado com sucesso');

      // CRÍTICO: Aguarda o token estar disponível antes de continuar
      // Isso evita erro 400 quando Firestore tentar acessar dados
      try {
        await FirebaseAppCheck.instance.getToken();
        debugPrint('✅ Token App Check obtido e pronto para uso');
      } catch (e) {
        debugPrint('⚠️ Erro ao obter token App Check: $e');
      }
    } catch (e, s) {
      debugPrint('⚠️ Erro ao ativar App Check: $e');
      debugPrint('$s');
    }
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

      // Ativa App Check APÓS login bem-sucedido
      await _activateAppCheckIfNeeded();
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

      // Ativa App Check APÓS registro bem-sucedido
      await _activateAppCheckIfNeeded();
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
