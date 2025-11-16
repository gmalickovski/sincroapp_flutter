// lib/services/ai_service.dart
// (ARQUIVO COMPLETO ATUALIZADO v8 - Corrigido com goal_model.dart)

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
// 1. IMPORTA O PROMPT BUILDER
import 'package:sincro_app_flutter/services/ai_prompt_builder.dart';
import 'package:sincro_app_flutter/features/goals/models/goal_model.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';

class AIService {
  static GenerativeModel? _cachedModel;

  // --- MUDANÇA (v8): _getModel SEM generationConfig ---
  // Isso permite que a IA responda com texto (que será um JSON)
  // em vez de forçar um JSON que conflita com o prompt.
  static GenerativeModel _getModel() {
    if (_cachedModel != null) {
      return _cachedModel!;
    }
    try {
      debugPrint("=== Inicializando modelo Gemini ===");
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception(
            "❌ Usuário não autenticado. FirebaseAuth.instance.currentUser é null.");
      }
      debugPrint("✅ Usuário autenticado: ${currentUser.uid}");

      final model = FirebaseAI.vertexAI(
        auth: FirebaseAuth.instance,
        appCheck: FirebaseAppCheck.instance,
      ).generativeModel(
        // Usando o modelo do seu JS que funciona
        model: 'gemini-2.5-flash-lite',
        // --- generationConfig REMOVIDO (Esta é a correção principal do erro "Com certeza!") ---
      );

      _cachedModel = model;
      debugPrint("✅ Modelo Gemini inicializado com sucesso!");
      debugPrint("📦 Provider: vertexAI (com App Check)");
      debugPrint("🤖 Modelo: ${model.model}");
      debugPrint("===================================");
      return model;
    } catch (e, stackTrace) {
      // Mantém seu tratamento de erro
      debugPrint("❌ ERRO ao inicializar o modelo Gemini: $e");
      debugPrint("📍 StackTrace: $stackTrace");
      throw Exception("Falha ao inicializar o modelo de IA.\n\n"
          "Checklist de verificação:\n"
          "✓ Firebase Auth configurado? ${FirebaseAuth.instance.currentUser != null ? 'SIM' : 'NÃO'}\n"
          "✓ App Check ativado? Verifique o console\n"
          "✓ Vertex AI API habilitada no Cloud Console?\n"
          "✓ Token de debug registrado no Firebase Console?\n\n"
          "Erro técnico: ${e.toString()}");
    }
  }

  // --- MÉTODO generateSuggestions ATUALIZADO (v8) ---
  static Future<List<Map<String, String>>> generateSuggestions({
    required Goal goal,
    required UserModel user,
    required NumerologyResult numerologyResult,
    required List<TaskModel> userTasks,
    String additionalInfo = '',
  }) async {
    try {
      debugPrint("🚀 AIService (v8): Iniciando geração de sugestões...");
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception(
            "❌ Usuário não autenticado. Por favor, faça login novamente.");
      }
      debugPrint("✅ Usuário autenticado: ${currentUser.uid}");

      // --- PASSO 1: Construir o Prompt (usando o builder v8) ---
      final prompt = AIPromptBuilder.buildTaskSuggestionPrompt(
        goal: goal,
        user: user,
        additionalInfo: additionalInfo,
        numerologyResult: numerologyResult,
        userTasks: userTasks,
        // --- CORREÇÃO (v8): Passa a lista List<SubTask> do objeto Goal ---
        existingSubTasks: goal.subTasks,
      );

      debugPrint("📝 Prompt (v8) preparado (${prompt.length} caracteres)");
      // Descomente para depuração completa do prompt
      // debugPrint("--- INÍCIO DO PROMPT v8 ---");
      // debugPrint(prompt);
      // debugPrint("--- FIM DO PROMPT v8 ---");

      final generativeModel = _getModel(); // Modelo sem generationConfig
      final content = [Content.text(prompt)];

      debugPrint("🤖 Chamando modelo Gemini para idear tarefas e datas...");
      final response = await generativeModel.generateContent(content);
      debugPrint("✅ Resposta recebida do modelo");

      String text = response.text ?? '';
      debugPrint(
          "📄 Resposta bruta (${text.length} caracteres): ${text.substring(0, text.length > 200 ? 200 : text.length)}...");

      // --- PASSO 3: Limpar e Parsear (Lógica do JS) ---
      text = text.replaceAll('```json', '').replaceAll('```', '').trim();

      // Tenta extrair APENAS o array JSON, mesmo que haja texto antes/depois
      // (Esta é a correção para a resposta "Com certeza! [...]")
      final jsonMatch =
          RegExp(r'\[\s*\{.*?\}\s*\]', dotAll: true).firstMatch(text);

      if (jsonMatch != null) {
        text = jsonMatch.group(0)!;
        debugPrint(
            "✅ JSON extraído com sucesso: ${text.substring(0, text.length > 100 ? 100 : text.length)}...");
      } else {
        debugPrint(
            "❌ Falha ao extrair JSON da resposta. Resposta completa: $text");
        throw FormatException("A IA não retornou um array JSON válido.");
      }

      // --- PASSO 4: Validar e Formatar a Saída ---
      final List<dynamic> suggestionsJson = await compute(parseJsonList, text);
      final List<Map<String, String>> suggestions = suggestionsJson
          .map((item) {
            if (item is Map &&
                item.containsKey('title') &&
                item.containsKey('date')) {
              final dateStr = item['date'].toString();
              // Valida formato YYYY-MM-DD
              if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(dateStr)) {
                try {
                  // Verifica se a data é futura (ou hoje)
                  final suggestedDate = DateTime.parse(dateStr);
                  final today = DateTime.now();
                  final startOfToday =
                      DateTime(today.year, today.month, today.day);
                  if (!suggestedDate.isBefore(startOfToday)) {
                    return <String, String>{
                      'title': item['title'].toString(),
                      'date': dateStr,
                    };
                  } else {
                    debugPrint("⚠️ Data passada ignorada ($dateStr)");
                    return null;
                  }
                } catch (e) {
                  debugPrint("⚠️ Data inválida ignorada ($dateStr): $e");
                  return null;
                }
              } else {
                debugPrint("⚠️ Formato de data inválido ignorado: $dateStr");
                return null;
              }
            } else {
              debugPrint(
                  "⚠️ Item inválido ignorado (faltando title ou date): $item");
              return null;
            }
          })
          .whereType<Map<String, String>>()
          .toList();

      debugPrint(
          "✅ ${suggestions.length} sugestões VÁLIDAS geradas com sucesso!");
      if (suggestions.isEmpty && suggestionsJson.isNotEmpty) {
        debugPrint(
            "🤔 Nenhuma sugestão válida foi extraída, embora o JSON inicial parecesse ok.");
      } else if (suggestions.isEmpty) {
        debugPrint("🤔 A IA não retornou nenhuma sugestão.");
        throw Exception("A IA não conseguiu gerar sugestões para esta meta.");
      }

      return suggestions;
    } catch (e, s) {
      // Seu tratamento de erro v2 (que é excelente)
      debugPrint("❌ ERRO ao gerar sugestões: $e");
      debugPrint("📍 StackTrace: $s");
      final errorString = e.toString().toLowerCase();
      if (errorString.contains("app check") ||
          errorString.contains("unauthenticated") ||
          errorString.contains("401") ||
          errorString.contains("403") ||
          errorString.contains("permission denied") ||
          errorString.contains("unauthorized") ||
          errorString.contains("invalid api key")) {
        throw Exception(
            "🔒 Erro de Autenticação/Permissão\n\nPossíveis causas:\n1. Token de debug do App Check não registrado\n2. App Check não configurado corretamente (reCAPTCHA v3 na Web)\n3. Vertex AI API não habilitada no projeto Cloud\n4. Chave de API inválida ou restrita\n5. Usuário não autenticado no Firebase Auth\n\nAções:\n• Verifique o console do navegador para o token de debug\n• Registre o token no Firebase Console > App Check\n• Confirme as configurações do App Check e Vertex AI\n• Limpe o cache e recarregue (Ctrl+Shift+R)");
      }
      if (e is FormatException || errorString.contains("json")) {
        // Este erro agora pode acontecer se a IA falar SÓ chat e nenhum JSON for encontrado
        throw Exception(
            "📋 A IA retornou um formato JSON inválido ou a extração falhou. Tente novamente.");
      }
      if (errorString.contains("model not found") ||
          errorString.contains("invalid model name") ||
          errorString.contains("404")) {
        throw Exception(
            "🤖 Modelo Gemini ('gemini-1.5-flash-lite') não encontrado ou inválido.\n\nVerifique:\n• Vertex AI API está habilitada no Google Cloud Console\n• O nome do modelo está correto\n• Sua região/projeto suporta este modelo");
      }
      if (errorString.contains("quota") ||
          errorString.contains("rate limit") ||
          errorString.contains("429")) {
        throw Exception(
            "⏳ Limite de uso da API Atingido.\n\nVocê pode ter excedido a cota gratuita ou os limites de requisição por minuto. Verifique seu uso no Google Cloud Console e considere habilitar o faturamento ou otimizar as chamadas.");
      }
      // O erro de 'mime type' não deve mais acontecer
      throw Exception(
          "💥 Erro ao comunicar com a IA\n\nDetalhes técnicos: ${e.toString()}\n\nSe o problema persistir, verifique a conexão e as configurações do Firebase/Google Cloud.");
    }
  }

  // Método parseJsonList (Mantido - não precisa alterar)
  static List<dynamic> parseJsonList(String text) {
    try {
      debugPrint("📄 JSON limpo recebido para parse: $text");
      return jsonDecode(text) as List<dynamic>;
    } catch (e) {
      debugPrint("❌ Erro ao decodificar JSON: $e");
      debugPrint("📄 Texto que causou o erro: $text");
      throw const FormatException(
          "JSON inválido recebido da IA."); // Lança FormatException
    }
  }
}
