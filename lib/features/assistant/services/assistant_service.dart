import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sincro_app_flutter/features/assistant/models/assistant_models.dart';
import 'package:sincro_app_flutter/features/assistant/services/assistant_prompt_builder.dart';
import 'package:sincro_app_flutter/features/assistant/services/n8n_service.dart';
import 'package:sincro_app_flutter/features/goals/models/goal_model.dart';
import 'package:sincro_app_flutter/features/journal/models/journal_entry_model.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';
import 'package:sincro_app_flutter/features/strategy/models/strategy_mode.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AssistantService {
  static DateTime? _lastInteractionDate;

  static bool _isFirstMessageOfDay() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    if (_lastInteractionDate == null) {
      _lastInteractionDate = today;
      return true;
    }

    final lastDay = DateTime(
      _lastInteractionDate!.year,
      _lastInteractionDate!.month,
      _lastInteractionDate!.day,
    );

    if (today.isAfter(lastDay)) {
      _lastInteractionDate = today;
      return true;
    }

    return false;
  }

  static Future<void> _logUsage({
    required String userId,
    required String type,
    required int promptLength,
    required int outputLength,
  }) async {
    try {
      // Estimativa grosseira: 1 token ~= 4 caracteres
      final estimatedInputTokens = (promptLength / 4).ceil();
      final estimatedOutputTokens = (outputLength / 4).ceil();
      
      await Supabase.instance.client.from('ai_usage_logs').insert({
        'user_id': userId,
        'created_at': DateTime.now().toIso8601String(),
        'type': type,
        'prompt_length': promptLength,
        'output_length': outputLength,
        'estimated_input_tokens': estimatedInputTokens,
        'estimated_output_tokens': estimatedOutputTokens,
      });
    } catch (e) {
      debugPrint('Erro ao logar uso de IA no Supabase: $e');
    }
  }

  static Future<AssistantAnswer> ask({
    required String question,
    required UserModel user,
    required NumerologyResult numerology,
    required List<TaskModel> tasks,
    required List<Goal> goals,
    required List<JournalEntry> recentJournal,
    List<AssistantMessage> chatHistory = const [],
  }) async {
    final isFirstOfDay = _isFirstMessageOfDay();

    final prompt = AssistantPromptBuilder.build(
      question: question,
      user: user,
      numerology: numerology,
      tasks: tasks,
      goals: goals,
      recentJournal: recentJournal,
      isFirstMessageOfDay: isFirstOfDay,
      chatHistory: chatHistory,
    );

    final n8n = N8nService();
    // Chama o n8n passando o prompt completo (incluindo contexto)
    final text = await n8n.chat(prompt: prompt, userId: user.uid);
    
    // Log Usage AFTER response
    _logUsage(
      userId: user.uid,
      type: 'assistant_chat',
      promptLength: prompt.length,
      outputLength: text.length,
    );

    // Remove markdown code blocks if present (o n8n pode retornar ```json ...)
    final cleanText = text.replaceAll(RegExp(r'```json\s*'), '').replaceAll(RegExp(r'```\s*'), '');
    
    // Find the first opening brace and the last closing brace
    final startIndex = cleanText.indexOf('{');
    final endIndex = cleanText.lastIndexOf('}');

    if (startIndex == -1 || endIndex == -1 || startIndex > endIndex) {
      // Se não achou JSON, tenta retornar como texto simples encapsulado
      // Isso é útil se o n8n responder apenas texto sem formatação JSON
      if (cleanText.isNotEmpty) {
          return AssistantAnswer(answer: cleanText, actions: []);
      }
      throw Exception('A IA não retornou um objeto JSON válido.');
    }

    final jsonStr = cleanText.substring(startIndex, endIndex + 1);

    Map<String, dynamic> data;
    try {
      data = jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Erro ao decodificar JSON do assistente (n8n): $e');
      // Fallback: tratar como texto corrido se falhar o parse
      return AssistantAnswer(answer: cleanText, actions: []);
    }

    return AssistantAnswer.fromJson(data);
  }

  static Future<List<String>> generateStrategySuggestions({
    required UserModel user,
    required List<TaskModel> tasks,
    required int personalDay,
    required StrategyMode mode,
  }) async {
    final prompt = AssistantPromptBuilder.buildStrategyPrompt(
      user: user,
      tasks: tasks,
      personalDay: personalDay,
      mode: mode,
    );

    try {
      final n8n = N8nService();
      final text = await n8n.chat(prompt: prompt, userId: user.uid);

      // Log Usage AFTER response
      _logUsage(
        userId: user.uid,
        type: 'strategy_flow',
        promptLength: prompt.length,
        outputLength: text.length,
      );

      // Clean up markdown
      final cleanText = text
          .replaceAll(RegExp(r'```json\s*'), '')
          .replaceAll(RegExp(r'```\s*'), '');

      final startIndex = cleanText.indexOf('[');
      final endIndex = cleanText.lastIndexOf(']');

      if (startIndex == -1 || endIndex == -1 || startIndex > endIndex) {
        return [];
      }

      final jsonStr = cleanText.substring(startIndex, endIndex + 1);
      final List<dynamic> data = jsonDecode(jsonStr);
      return data.map((e) => e.toString()).toList();
    } catch (e) {
      debugPrint('Erro ao gerar sugestões de estratégia (n8n): $e');
      return [];
    }
  }
}
