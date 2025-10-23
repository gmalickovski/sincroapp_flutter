// lib/services/ai_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:firebase_ai/firebase_ai.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_app_check/firebase_app_check.dart'; // ⬅️ ADICIONE ESTE IMPORT
import 'package:intl/intl.dart';
import 'package:sincro_app_flutter/features/authentication/data/content_data.dart';
import 'package:sincro_app_flutter/features/goals/models/goal_model.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';

class AIService {
  static GenerativeModel? _cachedModel;

  /// Método corrigido para inicializar o modelo Gemini com App Check
  static GenerativeModel _getModel() {
    if (_cachedModel != null) {
      return _cachedModel!;
    }

    try {
      debugPrint("=== Inicializando modelo Gemini ===");

      // 1. Verifica autenticação
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception(
            "❌ Usuário não autenticado. FirebaseAuth.instance.currentUser é null.");
      }
      debugPrint("✅ Usuário autenticado: ${currentUser.uid}");
      debugPrint("📧 Email: ${currentUser.email}");

      // 2. CORREÇÃO CRÍTICA: Use vertexAI() para Web em vez de googleAI()
      // E PASSE O APP CHECK EXPLICITAMENTE (obrigatório para Flutter)
      final model = FirebaseAI.vertexAI(
        auth: FirebaseAuth.instance,
        appCheck: FirebaseAppCheck.instance, // ⬅️ CRÍTICO PARA FLUTTER!
      ).generativeModel(
        model: 'gemini-2.5-flash-lite',
      );

      _cachedModel = model;
      debugPrint("✅ Modelo Gemini inicializado com sucesso!");
      debugPrint("📦 Provider: vertexAI (com App Check)");
      debugPrint("🤖 Modelo: gemini-2.5-flash-lite");
      debugPrint("===================================");

      return model;
    } catch (e, stackTrace) {
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

  // Helper para obter descrições (sem alterações)
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

  // Monta o prompt (sem alterações)
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

  /// Gera sugestões de marcos usando IA
  static Future<List<Map<String, String>>> generateSuggestions({
    required Goal goal,
    required UserModel user,
    required NumerologyResult numerologyResult,
    required List<TaskModel> userTasks,
    String additionalInfo = '',
  }) async {
    try {
      debugPrint("🚀 AIService: Iniciando geração de sugestões...");

      // Verifica autenticação
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        throw Exception(
            "❌ Usuário não autenticado. Por favor, faça login novamente.");
      }

      debugPrint("✅ Usuário autenticado: ${currentUser.uid}");

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

      debugPrint("📝 Prompt preparado (${prompt.length} caracteres)");

      final generativeModel = _getModel();
      final content = [Content.text(prompt)];

      debugPrint("🤖 Chamando modelo Gemini...");
      final response = await generativeModel.generateContent(content);
      debugPrint("✅ Resposta recebida do modelo");

      String text = response.text ?? '';
      debugPrint(
          "📄 Resposta bruta (${text.length} caracteres): ${text.substring(0, text.length > 200 ? 200 : text.length)}...");

      // Limpa a resposta
      text = text.replaceAll('```json', '').replaceAll('```', '').trim();

      // Valida formato JSON
      if (!text.startsWith('[') || !text.endsWith(']')) {
        debugPrint(
            "⚠️ Resposta não é um JSON array válido. Tentando extrair...");
        final jsonMatch =
            RegExp(r'\[\s*\{.*\}\s*\]', dotAll: true).firstMatch(text);
        if (jsonMatch != null) {
          text = jsonMatch.group(0)!;
          debugPrint("✅ JSON extraído com sucesso");
        } else {
          throw Exception("A IA retornou um formato de texto inesperado.");
        }
      }

      // Parse do JSON em isolate
      final List<dynamic> suggestionsJson = await compute(parseJsonList, text);

      // Converte para formato esperado
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
              debugPrint("⚠️ Item inválido ignorado: $item");
              return null;
            }
          })
          .whereType<Map<String, String>>()
          .toList();

      debugPrint("✅ ${suggestions.length} sugestões geradas com sucesso!");
      return suggestions;
    } catch (e, s) {
      debugPrint("❌ ERRO ao gerar sugestões: $e");
      debugPrint("📍 StackTrace: $s");

      final errorString = e.toString().toLowerCase();

      // Tratamento específico de erros
      if (errorString.contains("app check") ||
          errorString.contains("unauthenticated") ||
          errorString.contains("401") ||
          errorString.contains("unauthorized") ||
          errorString.contains("invalid")) {
        throw Exception("🔒 Erro de Autenticação Firebase App Check\n\n"
            "Possíveis causas:\n"
            "1. Token de debug não foi registrado no Firebase Console\n"
            "2. App Check não está configurado corretamente\n"
            "3. reCAPTCHA v3 não está ativo para Web\n"
            "4. Usuário não está autenticado\n\n"
            "Ações:\n"
            "• Verifique o console do navegador para o token de debug\n"
            "• Registre o token em: Firebase Console > App Check\n"
            "• Limpe o cache e recarregue a página (Ctrl+Shift+R)");
      }

      if (e is FormatException) {
        throw Exception(
            "📋 A IA retornou um formato JSON inválido. Tente novamente.");
      }

      if (errorString.contains("model not found") ||
          errorString.contains("invalid model") ||
          errorString.contains("404")) {
        throw Exception("🤖 Modelo 'gemini-2.5-flash-lite' não encontrado.\n\n"
            "Verifique:\n"
            "• Vertex AI API está habilitada no Google Cloud Console\n"
            "• O nome do modelo está correto\n"
            "• Sua região suporta este modelo");
      }

      // Erro genérico
      throw Exception("💥 Erro ao comunicar com a IA\n\n"
          "Detalhes técnicos: ${e.toString()}\n\n"
          "Se o problema persistir, entre em contato com o suporte.");
    }
  }

  /// Parse JSON em isolate para não bloquear a UI
  static List<dynamic> parseJsonList(String text) {
    try {
      return jsonDecode(text) as List<dynamic>;
    } catch (e) {
      debugPrint("❌ Erro ao decodificar JSON: $e");
      debugPrint("📄 Texto recebido: $text");
      throw FormatException("JSON inválido recebido da IA.");
    }
  }
}
