import 'dart:convert';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:sincro_app_flutter/features/assistant/models/assistant_models.dart';
import 'package:sincro_app_flutter/features/assistant/services/assistant_prompt_builder.dart';
import 'package:sincro_app_flutter/features/goals/models/goal_model.dart';
import 'package:sincro_app_flutter/features/journal/models/journal_entry_model.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';

class AssistantService {
  static GenerativeModel? _model;
  static DateTime? _lastInteractionDate;

  static GenerativeModel _getModel() {
    if (_model != null) return _model!;
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw Exception(
          'Usuário não autenticado. Faça login para usar o assistente.');
    }
    final model = FirebaseAI.vertexAI(
      auth: FirebaseAuth.instance,
      appCheck: FirebaseAppCheck.instance,
    ).generativeModel(model: 'gemini-2.5-flash-lite');
    _model = model;
    return model;
  }

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

    final response = await _getModel().generateContent([Content.text(prompt)]);
    var text = response.text ?? '';
    
    // Remove markdown code blocks if present
    text = text.replaceAll(RegExp(r'```json\s*'), '').replaceAll(RegExp(r'```\s*'), '');
    
    // Find the first opening brace and the last closing brace
    final startIndex = text.indexOf('{');
    final endIndex = text.lastIndexOf('}');

    if (startIndex == -1 || endIndex == -1 || startIndex > endIndex) {
      throw Exception('A IA não retornou um objeto JSON válido.');
    }

    final jsonStr = text.substring(startIndex, endIndex + 1);

    Map<String, dynamic> data;
    try {
      data = jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      // try compute isolate if needed, but decode here for simplicity
      debugPrint('Erro ao decodificar JSON do assistente: $e');
      rethrow;
    }

    return AssistantAnswer.fromJson(data);
  }
}
