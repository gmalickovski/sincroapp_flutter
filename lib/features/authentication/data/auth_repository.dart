import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:sincro_app_flutter/common/constants/api_constants.dart';

class AuthRepository {
  final GoTrueClient _auth = Supabase.instance.client.auth;

  // Stream para o AuthCheck. Mapeia AuthState para User?
  Stream<User?> get authStateChanges {
     return _auth.onAuthStateChange.map((state) {
        return state.session?.user;
     });
  }
  
  User? get currentUser => _auth.currentUser;

  // Método para a LoginScreen
  Future<AuthResponse> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      debugPrint('[AuthRepository] Iniciando signIn email=${email.trim()}');
      final response = await _auth.signInWithPassword(
        email: email.trim(),
        password: password.trim(),
      );
      debugPrint('[AuthRepository] signIn concluído. currentUser=${response.user?.id}');
      return response;
    } catch (e) {
      debugPrint('[AuthRepository] Erro no signIn: $e');
      rethrow;
    }
  }

  // Método para a RegisterScreen
  Future<AuthResponse> createUserWithEmailAndPassword({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final response = await _auth.signUp(
        email: email.trim(),
        password: password.trim(),
        data: {'full_name': displayName.trim()}, 
      );
      
      // Notificar N8N MOVED: Now handled in UserDetailsScreen after analysis data
      // if (response.user != null) {
      //   _notifySignup(...)
      // }

      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> sendSignupWebhook({
    required String email,
    required String userId,
    required String displayName,
  }) async {
    try {
      final url = Uri.parse(ApiConstants.signupNotify);
      await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'email': email,
          'name': displayName,
        }),
      );
    } catch (e) {
      debugPrint('[AuthRepository] Failed to notify signup: $e');
      // Non-blocking error
    }
  }

  // Método para o DashboardScreen
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Envia email de redefinição de senha
  Future<void> sendPasswordResetEmail({required String email}) async {
    final url = Uri.parse(ApiConstants.resetPassword);

    try {
      debugPrint('[AuthRepository] Requesting password reset via REST: $url');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email.trim()}),
      );

      if (response.statusCode != 200) {
        throw 'Falha ao solicitar reset (${response.statusCode}): ${response.body}';
      }
    } catch (e) {
      debugPrint('Erro na função requestPasswordReset (REST): $e');
      rethrow;
    }
  }
}
