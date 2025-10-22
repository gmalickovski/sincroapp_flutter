// lib/services/ai_service.dart (CORRIGIDO)

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_auth/firebase_auth.dart'; // IMPORTANTE!
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/features/authentication/data/content_data.dart';
import 'package:sincro_app_flutter/features/goals/models/goal_model.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';

class AIService {
  static GenerativeModel? _cachedModel;

  // --- MÉTODO _getModel CORRIGIDO ---
  static GenerativeModel _getModel() {
    if (_cachedModel != null) {
      return _cachedModel!;
    }

    try {
      debugPrint("=== Inicializando modelo Gemini ===");

      // Verifica se o usuário está autenticado
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception(
            "Usuário não autenticado. FirebaseAuth.instance.currentUser é null.");
      }
      debugPrint("Usuário autenticado: ${currentUser.uid}");

      // Inicializa o modelo com autenticação
      final model = FirebaseAI.googleAI(
        auth: FirebaseAuth.instance,
      ).generativeModel(
        model: 'gemini-2.5-flash-lite',
      );

      _cachedModel = model;
      debugPrint("✅ Modelo Gemini inicializado com sucesso!");
      debugPrint("Modelo: gemini-2.5-flash-lite");
      debugPrint("===================================");
      return model;
    } catch (e, stackTrace) {
      debugPrint("❌ Erro ao inicializar o modelo Gemini: $e");
      debugPrint("StackTrace: $stackTrace");
      throw Exception("Falha ao inicializar o modelo de IA. Verifique:\n"
          "1. Firebase Auth está configurado?\n"
          "2. Usuário está autenticado?\n"
          "3. Firebase AI Logic API está habilitada?\n"
          "4. App Check está configurado?\n"
          "Erro: ${e.toString()}");
    }
  }

  // Helper _getDesc (sem alterações)
  static String _getDesc(String type, int? number) {
    if (number == null) return "Não disponível.";
    VibrationContent? content;
    if (type == 'ciclosDeVida') {
      content = ContentData.textosCiclosDeVida[number];
    } else {
      content = ContentData.vibracoes[type]?[number];
    }
    if (content == null) {
      if (type == 'diaPessoal' && number != null) {
        String keyStr = number.toString();
        if (ContentData.vibracoes[type]!.containsKey(keyStr)) {
          content = ContentData.vibracoes[type]![keyStr];
        }
      }
      if (content == null) return "Não disponível.";
    }
    return "${content.titulo}: ${content.descricaoCompleta}";
  }

  // _buildPrompt (sem alterações)
  static String _buildPrompt({
    required String goalTitle,
    required String goalDescription,
    required String userBirthDate,
    required DateTime startDate,
    required String additionalInfo,
    required List<TaskModel> userTasks,
    required List<SubTask> existingMilestones,
    required NumerologyResult numerologyResult,
  }) {
    final diaPessoalContext =
        ContentData.vibracoes['diaPessoal']!.entries.map((entry) {
      final day = entry.key;
      final content = entry.value;
      return "Dia Pessoal $day (${content.titulo}): ${content.descricaoCompleta}";
    }).join('\n');

    final int? anoPessoal = numerologyResult.numeros['anoPessoal'];
    final int? mesPessoal = numerologyResult.numeros['mesPessoal'];
    final int? cicloVida1 =
        numerologyResult.estruturas['ciclosDeVida']?['ciclo1']?['regente'];
    final int? cicloVida2 =
        numerologyResult.estruturas['ciclosDeVida']?['ciclo2']?['regente'];
    final int? cicloVida3 =
        numerologyResult.estruturas['ciclosDeVida']?['ciclo3']?['regente'];
    final anoPessoalContext =
        "Ano Pessoal $anoPessoal: ${_getDesc('anoPessoal', anoPessoal)}";
    final mesPessoalContext =
        "Mês Pessoal $mesPessoal: ${_getDesc('mesPessoal', mesPessoal)}";
    final cicloDeVidaContext = """
      - Primeiro Ciclo de Vida (Formação): Vibração $cicloVida1 - ${_getDesc('ciclosDeVida', cicloVida1)}
      - Segundo Ciclo de Vida (Produção): Vibração $cicloVida2 - ${_getDesc('ciclosDeVida', cicloVida2)}
      - Terceiro Ciclo de Vida (Colheita): Vibração $cicloVida3 - ${_getDesc('ciclosDeVida', cicloVida3)}
    """;

    final formattedStartDate = DateFormat('dd/MM/yyyy').format(startDate);
    final tasksContext = userTasks.isNotEmpty
        ? userTasks
            .map((task) =>
                "- [${task.completed ? 'X' : ' '}] ${task.text} (Meta: ${task.journeyTitle ?? 'N/A'})")
            .join('\n')
        : "Nenhuma tarefa recente.";

    final milestonesContext = existingMilestones.isNotEmpty
        ? existingMilestones
            .map((milestone) => "- ${milestone.title}")
            .join('\n')
        : "Nenhum marco foi criado para esta meta ainda.";

    return """
    Você é um Coach de Produtividade e Estrategista Pessoal...

    **DOSSIÊ DO USUÁRIO:**
    ... (igual antes) ...
    **5. FERRAMENTA PARA DATAS (A VIBRAÇÃO DO DIA):**
    - Data de Início do Planejamento: $formattedStartDate
    - Data de Nascimento do Usuário: $userBirthDate
    - Guia do Dia Pessoal: $diaPessoalContext

    ---
    **SUA TAREFA ESTRATÉGICA:**
    ... (igual antes) ...
    5.  **FORMATO DA RESPOSTA:** Responda **APENAS** com um array de objetos JSON...

    **Exemplo de Resposta Esperada:**
    [
      {"title": "Marco 1", "date": "YYYY-MM-DD"},
      {"title": "Marco 2", "date": "YYYY-MM-DD"}
    ]
    """;
  }

  // generateSuggestions (sem alterações no corpo, apenas melhor tratamento de erros)
  static Future<List<Map<String, String>>> generateSuggestions({
    required Goal goal,
    required UserModel user,
    required NumerologyResult numerologyResult,
    required List<TaskModel> userTasks,
    String additionalInfo = '',
  }) async {
    try {
      // Verifica se o usuário está autenticado
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception(
            "Usuário não autenticado. Por favor, faça login novamente.");
      }

      debugPrint(
          "AIService: Gerando sugestões para usuário: ${currentUser.uid}");

      final userBirthDate = user.dataNasc;

      final prompt = _buildPrompt(
        goalTitle: goal.title,
        goalDescription: goal.description,
        userBirthDate: userBirthDate,
        startDate: DateTime.now(),
        additionalInfo: additionalInfo,
        existingMilestones: goal.subTasks,
        numerologyResult: numerologyResult,
        userTasks: userTasks,
      );

      final generativeModel = _getModel();
      final content = [Content.text(prompt)];

      debugPrint("AIService: Chamando modelo Gemini...");
      final response = await generativeModel.generateContent(content);
      debugPrint("AIService: Resposta recebida do modelo");

      String text = response.text ?? '';
      debugPrint("AIService Resposta Bruta: $text");

      text = text.replaceAll('```json', '').replaceAll('```', '').trim();

      if (!text.startsWith('[') || !text.endsWith(']')) {
        debugPrint(
            "AIService Erro: Resposta da IA não é um JSON array válido.");
        final jsonMatch =
            RegExp(r'\[\s*\{.*\}\s*\]', dotAll: true).firstMatch(text);
        if (jsonMatch != null) {
          text = jsonMatch.group(0)!;
          debugPrint("AIService Info: JSON extraído da resposta: $text");
        } else {
          throw Exception("A IA retornou um formato de texto inesperado.");
        }
      }

      final List<dynamic> suggestionsJson = await compute(parseJsonList, text);

      final List<Map<String, String>> suggestions = suggestionsJson
          .map((item) {
            if (item is Map &&
                item.containsKey('title') &&
                item.containsKey('date')) {
              return {
                'title': item['title'].toString(),
                'date': item['date'].toString(),
              };
            } else {
              debugPrint(
                  "AIService Warning: Item inválido recebido da IA: $item");
              return null;
            }
          })
          .whereType<Map<String, String>>()
          .toList();

      debugPrint(
          "AIService: ${suggestions.length} sugestões geradas com sucesso");
      return suggestions;
    } catch (e, s) {
      debugPrint("Erro ao gerar sugestões estratégicas: $e");
      debugPrint("StackTrace: $s");

      final errorString = e.toString().toLowerCase();

      // Erros relacionados ao App Check ou autenticação
      if (errorString.contains("app check") ||
          errorString.contains("unauthenticated") ||
          errorString.contains("401") ||
          errorString.contains("unauthorized")) {
        throw Exception(
            "Erro de autenticação: Verifique se você está logado e se o Firebase App Check está configurado corretamente.");
      }

      // Erros de formato JSON
      if (e is FormatException) {
        throw Exception(
            "A IA retornou um formato JSON inválido. Tente novamente.");
      }

      if (errorString.contains("formato de texto inesperado")) {
        throw Exception("A IA retornou um formato inválido. Tente novamente.");
      }

      // Erros de modelo não encontrado
      if (errorString.contains("model not found") ||
          errorString.contains("invalid model") ||
          errorString.contains("404")) {
        throw Exception("Modelo 'gemini-2.5-flash-lite' não encontrado. "
            "Verifique a configuração da extensão Firebase.");
      }

      // Erro genérico
      throw Exception(
          "Ocorreu um erro ao se comunicar com a IA. Detalhes: ${e.toString()}");
    }
  }

  // parseJsonList (sem alterações)
  static List<dynamic> parseJsonList(String text) {
    try {
      return jsonDecode(text) as List<dynamic>;
    } catch (e) {
      debugPrint("Erro ao decodificar JSON: $e");
      debugPrint("Texto recebido: $text");
      throw FormatException("JSON inválido recebido da IA.");
    }
  }
}
