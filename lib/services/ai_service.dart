// lib/services/ai_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sincro_app_flutter/services/ai_prompt_builder.dart';
import 'package:sincro_app_flutter/features/goals/models/goal_model.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AIService {
  // N8N Webhook URL placeholder - To be configured
  // static const String _n8nWebhookUrl = 'YOUR_N8N_WEBHOOK_URL';

  static Future<List<Map<String, String>>> generateSuggestions({
    required Goal goal,
    required UserModel user,
    required NumerologyResult numerologyResult,
    required List<TaskModel> userTasks,
    String additionalInfo = '',
  }) async {
    try {
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        throw Exception(
            "Usuário não autenticado. Por favor, faça login novamente.");
      }

      final prompt = AIPromptBuilder.buildTaskSuggestionPrompt(
        goal: goal,
        user: user,
        additionalInfo: additionalInfo,
        numerologyResult: numerologyResult,
        userTasks: userTasks,
        existingSubTasks: goal.subTasks,
      );

      // TODO: Implement N8N or Supabase Edge Function call here
      // For now, we stub this to avoid compilation errors and indicate missing config.
      debugPrint('AI Prompt generated: $prompt');

      // Simulate network delay
      await Future.delayed(const Duration(seconds: 2));

      // Mock response for testing/compilation
      // throw UnimplementedError("AI Service migration to N8N pending configuration.");

      // OR Call N8N (Example implementation)
      /*
      final response = await http.post(
        Uri.parse(_n8nWebhookUrl),
        body: jsonEncode({'prompt': prompt}),
        headers: {'Content-Type': 'application/json'},
      );
      if (response.statusCode == 200) {
         return _parseSuggestions(response.body);
      } else {
         throw Exception('Failed to generate suggestions via N8N');
      }
      */

      throw Exception(
          "O serviço de IA está sendo migrado para N8N. Por favor, aguarde a configuração final.");
    } catch (e) {
      debugPrint("❌ AI Service failed: $e");
      rethrow;
    }
  }

  // Método parseJsonList (Mantido para uso futuro)
  static List<dynamic> parseJsonList(String text) {
    try {
      return jsonDecode(text) as List<dynamic>;
    } catch (e) {
      debugPrint("❌ Erro ao decodificar JSON: $e");
      debugPrint("📄 Texto que causou o erro: $text");
      throw const FormatException("JSON inválido recebido da IA.");
    }
  }
}
