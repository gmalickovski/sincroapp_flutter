// lib/features/assistant/services/assistant_service.dart
//
// Orquestra o pipeline de IA direto (sem N8N):
//   1. Monta contexto (usuário + data + numerologia)
//   2. Envia mensagens ao LLM com ferramentas disponíveis
//   3. Executa ferramentas se solicitadas (AiToolHandler)
//   4. Repete até resposta final ou limite do AiLoopGuard
//   5. Loga tokens reais no Supabase
//
// O formato de resposta JSON é mantido idêntico ao anterior:
//   {"answer": "...", "tasks": [...], "actions": {...}}
// para garantir compatibilidade total com a UI existente.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sincro_app_flutter/features/assistant/ai/ai_config.dart';
import 'package:sincro_app_flutter/features/assistant/ai/ai_loop_guard.dart';
import 'package:sincro_app_flutter/features/assistant/ai/ai_prompts.dart';
import 'package:sincro_app_flutter/features/assistant/ai/ai_provider.dart';
import 'package:sincro_app_flutter/features/assistant/ai/ai_tool_handler.dart';
import 'package:sincro_app_flutter/features/assistant/models/assistant_models.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/features/strategy/models/strategy_mode.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

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

  // ---------------------------------------------------------------------------
  // Loga uso de tokens no Supabase (usage_logs)
  // ---------------------------------------------------------------------------
  static Future<void> _logUsage({
    required String userId,
    required String type,
    required int promptLength,
    required int outputLength,
    int? inputTokens,
    int? outputTokens,
    String? modelName,
  }) async {
    try {
      final int finalInputTokens = inputTokens ?? (promptLength / 4).ceil();
      final int finalOutputTokens = outputTokens ?? (outputLength / 4).ceil();
      final int totalTokens = finalInputTokens + finalOutputTokens;

      await Supabase.instance.client
          .schema('sincroapp')
          .from('usage_logs')
          .insert({
        'user_id': userId,
        'request_type': type,
        'tokens_total': totalTokens,
        'tokens_input': finalInputTokens,
        'tokens_output': finalOutputTokens,
        'model_name': modelName ?? AiConfig.activeModel,
      });
    } catch (e) {
      if (e.toString().contains('PGRST205') ||
          e.toString().contains('usage_logs')) {
        return;
      }
      debugPrint('Erro ao logar uso de IA no Supabase: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // MÉTODO PRINCIPAL: ask()
  // Pipeline: contexto → LLM → [ferramentas → LLM]* → resposta final
  // ---------------------------------------------------------------------------
  static Future<AssistantAnswer> ask({
    required String question,
    required UserModel user,
    List<AssistantMessage> chatHistory = const [],
  }) async {
    final now = DateTime.now();
    final sessionId = const Uuid().v4();
    final guard = AiLoopGuard(sessionId: sessionId);
    final provider = AiProvider();
    final toolHandler = AiToolHandler(userId: user.uid);

    // ─── 1. Montar contexto do usuário ───────────────────────────────────────
    final contextBlock = _buildContextBlock(user, now);

    // ─── 2. Montar lista de mensagens (system + histórico + nova pergunta) ───
    // chatHistory chega em ordem cronológica (oldest→newest).
    // Pegamos as ÚLTIMAS 6 (mais recentes) para manter contexto relevante.
    final recentHistory = chatHistory.length > 6
        ? chatHistory.sublist(chatHistory.length - 6)
        : chatHistory;

    final messages = <Map<String, dynamic>>[
      {
        'role': 'system',
        'content': '${AiPrompts.systemPrompt}\n\n$contextBlock',
      },
      // Otimização: Oculta arrays pesados ("tasks", "actions") do histórico.
      ...recentHistory.map((m) {
        String safeContent = m.content;
        if (m.role == 'assistant') {
          try {
            // Tenta decodificar o JSON e remover as porções que estufam o log
            final decoded = jsonDecode(m.content) as Map<String, dynamic>;
            final minified = {'answer': decoded['answer'] ?? ''};
            safeContent = jsonEncode(minified);
          } catch (_) {
            // Se falhar (ex: erro de compilação na API), deixa o safeContent original
          }
        }
        return {
          'role': m.role,
          'content': safeContent,
        };
      }),
      {
        'role': 'user',
        'content': question,
      },
    ];

    AiUsage totalUsage = const AiUsage();
    String finalContent = '';
    // ── Captura de resultados de ferramentas para injeção no resultado final ──
    // Garante que tasks/actions apareçam mesmo se a IA não gerar o JSON correto.
    List<Map<String, dynamic>> capturedTasks = [];

    try {
      // ─── 3. Loop de Function Calling ────────────────────────────────────────
      while (true) {
        final response = await provider.chat(
          messages: messages,
          tools: AiConfig.toolDefinitions,
        );

        totalUsage = totalUsage + response.usage;

        if (response.hasContent) {
          // Resposta de texto final — sair do loop
          finalContent = response.content!;
          break;
        }

        if (response.hasToolCall) {
          // Verificar limite anti-loop
          guard.tick(response.toolCallName!);

          // Executar a ferramenta
          final toolResult = await toolHandler.dispatch(
            response.toolCallName!,
            response.toolCallArgs ?? {},
          );

          // ── Capturar resultados de buscar_tarefas_e_marcos ──
          if (response.toolCallName == 'buscar_tarefas_e_marcos') {
            final tasks = toolResult['tasks'];
            if (tasks is List) {
              capturedTasks = tasks
                  .whereType<Map<String, dynamic>>()
                  .toList();
              debugPrint('[AssistantService] 📋 Captured ${capturedTasks.length} tasks from tool');
            }
          }

          final toolResultStr = jsonEncode(toolResult);

          // Adicionar mensagens da rodada ao histórico interno
          messages.add({
            'role': 'assistant',
            'content': null,
            'tool_calls': [
              {
                'id': response.toolCallId ?? 'call_${messages.length}',
                'type': 'function',
                'function': {
                  'name': response.toolCallName,
                  'arguments': jsonEncode(response.toolCallArgs),
                },
              }
            ],
          });

          messages.add({
            'role': 'tool',
            'tool_call_id': response.toolCallId ?? 'call_${messages.length - 1}',
            'content': toolResultStr,
          });

          // Continuar o loop para obter resposta pós-ferramenta
          continue;
        }

        // Se chegou aqui sem content e sem tool call, algo errado
        throw Exception('LLM retornou resposta vazia.');
      }
    } on AiLoopException catch (e) {
      debugPrint('[AssistantService] 🚨 Loop detectado: $e');
      // Log tokens parciais
      unawaited(_logUsage(
        userId: user.uid,
        type: 'assistant_chat_loop_error',
        promptLength: question.length,
        outputLength: 0,
        inputTokens: totalUsage.promptTokens,
        outputTokens: totalUsage.completionTokens,
        modelName: totalUsage.model,
      ));
      return AssistantAnswer(
        answer: AiPrompts.loopErrorAnswer,
        actions: [],
      );
    } catch (e, stack) {
      debugPrint('[AssistantService] ❌ Erro no pipeline de IA: $e\n$stack');
      // Log tokens parciais
      unawaited(_logUsage(
        userId: user.uid,
        type: 'assistant_chat_error',
        promptLength: question.length,
        outputLength: 0,
        inputTokens: totalUsage.promptTokens,
        outputTokens: totalUsage.completionTokens,
        modelName: totalUsage.model,
      ));
      return AssistantAnswer(
        answer: AiPrompts.apiErrorAnswer,
        actions: [],
      );
    }

    // ─── 4. Processar resposta de texto final ────────────────────────────────
    // Log de tokens reais
    unawaited(_logUsage(
      userId: user.uid,
      type: 'assistant_chat',
      promptLength: question.length,
      outputLength: finalContent.length,
      inputTokens: totalUsage.promptTokens,
      outputTokens: totalUsage.completionTokens,
      modelName: totalUsage.model,
    ));

    return _parseAiOutput(finalContent, capturedTasks: capturedTasks, userQuestion: question);
  }

  // ---------------------------------------------------------------------------
  // Output Parser — Filtro Blindado + Post-Processor (como o Node Code do N8N)
  // capturedTasks: tasks capturados server-side da ferramenta buscar_tarefas_e_marcos
  // userQuestion: pergunta original do usuário para detectar intent de agendamento
  // ---------------------------------------------------------------------------
  static AssistantAnswer _parseAiOutput(
    String rawText, {
    List<Map<String, dynamic>> capturedTasks = const [],
    String userQuestion = '',
  }) {
    debugPrint('[OutputParser] RAW (${rawText.length} chars): ${rawText.substring(0, rawText.length > 500 ? 500 : rawText.length)}...');

    // 1. Limpar markdown se a IA incluiu (defensivo)
    final cleanText = rawText
        .replaceAll(RegExp(r'```json\s*'), '')
        .replaceAll(RegExp(r'```\s*'), '')
        .trim();

    // 2. Tentar extrair o bloco {...}
    final startIndex = cleanText.indexOf('{');
    final endIndex = cleanText.lastIndexOf('}');

    AssistantAnswer? result;

    if (startIndex == -1) {
      // Sem JSON — texto puro
      debugPrint('[OutputParser] ⚠️ Sem JSON detectado, retornando texto puro.');
      result = AssistantAnswer(
        answer: cleanText.isNotEmpty ? cleanText : AiPrompts.apiErrorAnswer,
        actions: [],
        embeddedTasks: capturedTasks,
      );
    } else {
      // Se endIndex for menor, assumimos truncado
      final jsonStr = cleanText.substring(
          startIndex,
          endIndex != -1 && endIndex >= startIndex
              ? endIndex + 1
              : cleanText.length);

      // 3. Tentativas progressivas de parse
      final fixAttempts = [
        jsonStr, '$jsonStr}', '$jsonStr]}', '$jsonStr]}}', '$jsonStr"]}', '$jsonStr"]}}'
      ];

      for (final attempt in fixAttempts) {
        try {
          final parsedData = jsonDecode(attempt) as Map<String, dynamic>;
          if (!parsedData.containsKey('answer')) {
            parsedData['answer'] = 'Aqui estão suas informações.';
          }
          if (!parsedData.containsKey('tasks') || parsedData['tasks'] is! List) {
            parsedData['tasks'] = [];
          }
          if (!parsedData.containsKey('actions')) {
            parsedData['actions'] = {};
          }

          debugPrint('[OutputParser] ✅ JSON parsed OK. tasks=${(parsedData['tasks'] as List).length}, actions=${parsedData['actions']}');
          result = AssistantAnswer.fromJson(parsedData);
          break;
        } catch (_) {}
      }

      // 4. Fallback: Regex Extractor & Multi-JSON Merger
      if (result == null) {
        debugPrint('[OutputParser] ⚠️ Falha no parse JSON. Usando Regex.');
        final answerMatches = RegExp(r'"answer"\s*:\s*"([^"\\]*(?:\\.[^"\\]*)*)"').allMatches(cleanText);
        String mergedAnswer = '';
        if (answerMatches.isNotEmpty) {
          mergedAnswer = answerMatches.map((m) => m.group(1)!
              .replaceAll('\\n', '\n').replaceAll('\\"', '"')).join('\n\n');
        } else {
          mergedAnswer = cleanText;
        }

        Map<String, dynamic> mergedActions = {};
        final actionsMatch = RegExp(r'"actions"\s*:\s*(\{[^}]+\})').allMatches(cleanText);
        if (actionsMatch.isNotEmpty) {
           try {
             mergedActions = jsonDecode(actionsMatch.last.group(1)!) as Map<String, dynamic>;
           } catch(_) {}
        }
        result = AssistantAnswer.fromJson({
          'answer': mergedAnswer,
          'actions': mergedActions,
          'tasks': []
        });
      }
    }

    // ═══════════════════════════════════════════════════════════════════════════
    // POST-PROCESSOR (Equivalente ao Node Code do N8N)
    // Garante que a estrutura final tenha os modais corretos.
    // ═══════════════════════════════════════════════════════════════════════════

    // ── MERGE TASKS: Injetar tasks capturadas APENAS se for cenário de LISTAGEM ──
    if (result.embeddedTasks.isEmpty && capturedTasks.isNotEmpty && result.actions.isEmpty) {
      debugPrint('[OutputParser] 📋 Injetando ${capturedTasks.length} tasks capturadas');
      result = AssistantAnswer(
        answer: result.answer,
        actions: result.actions,
        embeddedTasks: capturedTasks,
      );
    } else if (capturedTasks.isNotEmpty && result.actions.isNotEmpty) {
      debugPrint('[OutputParser] ⏭️ Tasks capturadas IGNORADAS (actions presente)');
    }

    // ── DETECT SCHEDULING: Se IA não gerou actions mas user pediu agendamento ──
    if (result.actions.isEmpty && _isSchedulingIntent(userQuestion)) {
      debugPrint('[OutputParser] 🔧 Post-processor: detectou intent de agendamento');
      final extracted = _extractSchedulingData(result.answer, userQuestion);
      if (extracted != null) {
        debugPrint('[OutputParser] 🔧 Criando action: title="${extracted['title']}", date="${extracted['date']}"');
        final extractedDateStr = extracted['date'] as String?;
        final parsedDate = extractedDateStr != null ? DateTime.parse(extractedDateStr) : null;
        
        result = AssistantAnswer(
          answer: result.answer,
          actions: [
            AssistantAction(
              type: AssistantActionType.create_task,
              title: extracted['title'] as String,
              date: parsedDate,
              data: {
                'type': 'create_task',
                'payload': {
                  'title': extracted['title'],
                  'time_specified': extracted['timeSpecified'] ?? true,
                },
              },
              suggestedDates: (extracted['suggestedDates'] as List<dynamic>?)
                      ?.map((s) => DateTime.parse(s.toString()))
                      .toList() ??
                  [],
            ),
          ],
          embeddedTasks: [],  // Limpar tasks se virou agendamento
        );
      }
    }

    debugPrint('[OutputParser] ✅ Final: embeddedTasks=${result.embeddedTasks.length}, actions=${result.actions.length}');
    return result;
  }

  // ---------------------------------------------------------------------------
  // Detecta se a pergunta do usuário é sobre AGENDAR/CRIAR algo
  // ---------------------------------------------------------------------------
  static bool _isSchedulingIntent(String question) {
    if (question.isEmpty) return false;
    final q = question.toLowerCase();

    // Se o usuário está pedindo para listar seus dados, NÃO é criação/agendamento
    final listKeywords = [
      'mostr', 'listar', 'lista', 'quais', 'ver', 'ler', 'pendent',
      'meus agendamentos', 'minhas tarefas', 'os agendamentos', 'as tarefas',
      'tenho hoje', 'tenho amanhã', 'que eu tenho', 'temos hoje'
    ];
    
    // Se a intenção primária for listar, ignora o fluxo de criação.
    if (listKeywords.any((k) => q.contains(k))) {
      return false; 
    }

    final keywords = [
      'agend', 'agende', 'agendar', 'agenda', // Isso pode pegar 'agendamentos', mas listKeywords filtra antes.
      'marcar', 'marque',
      'criar', 'crie', 'criar tarefa', 'criar compromisso', 'criar agendamento',
      'registr', 'registre',
      'melhor dia', 'melhor data', 'melhor horário',
      'sugestão de', 'sugestões de', 'sugerir data', 'sugerir dia',
      'quando devo',
    ];
    return keywords.any((k) => q.contains(k));
  }

  // ---------------------------------------------------------------------------
  // Extrai título e data do texto da IA para criar actions automaticamente
  // ---------------------------------------------------------------------------
  static Map<String, dynamic>? _extractSchedulingData(String aiAnswer, String userQuestion) {
    // ── Extrair título ──
    // 1. Tentar extrair do userQuestion primeiro (É a fonte mais confiável)
    String? title = _extractTitleFromQuestion(userQuestion);
    
    // 2. Fallback: pegar texto em **negrito** na resposta da IA
    if (title == null || title.isEmpty || title == "Novo Compromisso") {
      final boldMatches = RegExp(r'\*\*([^*]+)\*\*').allMatches(aiAnswer).toList();
      if (boldMatches.isNotEmpty) {
        // Pegar o primeiro bold que não parece ser uma data ou hora
        for (final m in boldMatches) {
          final text = m.group(1)!;
          final isTime = RegExp(r'^\d{1,2}h').hasMatch(text) || RegExp(r'^\d{1,2}:\d{2}').hasMatch(text);
          final isDate = text.toLowerCase().contains('feira') || text.toLowerCase().contains('de março');
          if (!isTime && !isDate) {
            title = text;
            break;
          }
        }
      }
    }
    
    if (title == null || title.isEmpty) return null;

    // ── Extrair data ──
    DateTime? date;
    final now = DateTime.now();
    List<DateTime> suggestedDates = [];

    // Mapeamento de meses para buscar sugestões
    final monthNames = {
      'janeiro': 1, 'fevereiro': 2, 'março': 3, 'marco': 3, 'abril': 4,
      'maio': 5, 'junho': 6, 'julho': 7, 'agosto': 8, 'setembro': 9,
      'outubro': 10, 'novembro': 11, 'dezembro': 12
    };

    // Extrair múltiplas datas das sugestões da IA (ex: "13 de março às 14h")
    final suggestionMatches = RegExp(r'(\d{1,2})\s*de\s*([a-zA-Zç]+)(?:\s*(?:[àa]s?)\s*(\d{1,2})h?)?', caseSensitive: false).allMatches(aiAnswer);
    
    for (final match in suggestionMatches) {
        final dayStr = match.group(1);
        final monthStr = match.group(2)?.toLowerCase();
        final hourStr = match.group(3);
        
        if (dayStr != null && monthStr != null && monthNames.containsKey(monthStr)) {
            final day = int.parse(dayStr);
            final month = monthNames[monthStr]!;
            final hour = hourStr != null ? int.parse(hourStr) : 0;
            
            var year = now.year;
            if (month < now.month || (month == now.month && day < now.day - 7)) {
                year++;
            }
            suggestedDates.add(DateTime(year, month, day, hour, 0));
        }
    }

    // 1. Tentar "amanhã às XXh"
    final tomorrowMatch = RegExp(r'amanh[ãa]\s+[àa]s?\s*(\d{1,2})\s*h', caseSensitive: false)
        .firstMatch(aiAnswer) ?? RegExp(r'amanh[ãa]\s+[àa]s?\s*(\d{1,2})\s*h', caseSensitive: false)
        .firstMatch(userQuestion);
    if (tomorrowMatch != null) {
      final hour = int.tryParse(tomorrowMatch.group(1)!) ?? 9;
      final tomorrow = now.add(const Duration(days: 1));
      date = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, hour, 0);
    }

    // 2. Tentar "hoje às XXh"
    if (date == null) {
      final todayMatch = RegExp(r'hoje\s+[àa]s?\s*(\d{1,2})\s*h', caseSensitive: false)
          .firstMatch(aiAnswer) ?? RegExp(r'hoje\s+[àa]s?\s*(\d{1,2})\s*h', caseSensitive: false)
          .firstMatch(userQuestion);
      if (todayMatch != null) {
        final hour = int.tryParse(todayMatch.group(1)!) ?? 9;
        date = DateTime(now.year, now.month, now.day, hour, 0);
      }
    }

    // 3. Tentar "dia DD/MM às XXh"
    if (date == null) {
      final dateMatch = RegExp(r'(\d{1,2})[/\-](\d{1,2})(?:[/\-](\d{4}))?\s*(?:[àa]s?\s*(\d{1,2})\s*h)?', caseSensitive: false)
          .firstMatch(aiAnswer) ?? RegExp(r'(\d{1,2})[/\-](\d{1,2})(?:[/\-](\d{4}))?\s*(?:[àa]s?\s*(\d{1,2})\s*h)?', caseSensitive: false)
          .firstMatch(userQuestion);
      if (dateMatch != null) {
        final day = int.tryParse(dateMatch.group(1)!) ?? now.day;
        final month = int.tryParse(dateMatch.group(2)!) ?? now.month;
        final year = int.tryParse(dateMatch.group(3) ?? '') ?? now.year;
        final hour = int.tryParse(dateMatch.group(4) ?? '') ?? 0;
        date = DateTime(year, month, day, hour, 0);
      }
    }

    // 4. Tentar "amanhã" sem hora
    if (date == null) {
      if (aiAnswer.toLowerCase().contains('amanhã') || userQuestion.toLowerCase().contains('amanhã') || userQuestion.toLowerCase().contains('amanha')) {
        final tomorrow = now.add(const Duration(days: 1));
        date = DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 0, 0);
      }
    }

    // Identificar se o usuário está pedindo apenas sugestões
    final q = userQuestion.toLowerCase();
    final isJustAskingForSuggestions = q.contains('sugest') || q.contains('melhor');

    // 5. Fallback apenas se NÃO for apenas um pedido de sugestões
    if (!isJustAskingForSuggestions && suggestedDates.isEmpty) {
      date ??= DateTime(now.year, now.month, now.day + 1, 9, 0);
    }
    
    // Se o user pediu sugestão de data e não deu para parsear nada, forçar a usar as extraídas se não tiver date
    if (isJustAskingForSuggestions && date == null && suggestedDates.isNotEmpty) {
      // date fica null mesmo para que apareçam apenas as bolhas de sugestões
    }

    final bool timeSpecified = date?.hour != 0 || date?.minute != 0;

    return {
      'title': title,
      'date': date?.toUtc().toIso8601String(), // Pode ser null agora
      'timeSpecified': timeSpecified,
      'suggestedDates': suggestedDates.map((d) => d.toUtc().toIso8601String()).toList(),
    };
  }

  // ---------------------------------------------------------------------------
  // Extrai título provável da pergunta do usuário
  // ---------------------------------------------------------------------------
  static String? _extractTitleFromQuestion(String question) {
    if (question.isEmpty) return null;
    final q = question.toLowerCase();

    // 1. Check for explicit dash/hyphen (e.g., "marque para amanhã - Consulta Dentista")
    final dashParts = question.split(RegExp(r'\s*-\s*'));
    if (dashParts.length > 1) {
      final possibleTitle = dashParts.last.trim();
      if (possibleTitle.isNotEmpty && possibleTitle.length > 3) {
        return possibleTitle[0].toUpperCase() + possibleTitle.substring(1);
      }
    }

    // Padrões comuns
    final patterns = [
      RegExp(r'agend\w*\s+(?:para\s+mim\s+)?(.+?)(?:\s+para\s+|\s+amanh[ãa]|\s+hoje|\s+dia\s+\d|\s+[àa]s?\s+\d)', caseSensitive: false),
      RegExp(r'(?:marcar|criar|registrar|marque)\s+(?:um\s+|uma\s+compromisso\s+|uma?\s+)?(.+?)(?:\s+para\s+|\s+amanh[ãa]|\s+hoje|\s+dia\s+\d|\s+[àa]s?\s+\d)', caseSensitive: false),
      RegExp(r'agend\w*\s+(.+?)$', caseSensitive: false),
    ];

    for (final p in patterns) {
      final match = p.firstMatch(q);
      if (match != null && match.groupCount >= 1) {
        var raw = match.group(1)!.trim();
        // Remove artigos indefinidos do início ("um", "uma", "uns", "umas")
        raw = raw.replaceFirst(RegExp(r'^(um|uma|uns|umas)\s+', caseSensitive: false), '');
        
        if (raw.length > 3 && raw.length < 100) {
          // Capitalizar primeira letra
          return raw[0].toUpperCase() + raw.substring(1);
        }
      }
    }
    
    // Fallback genérico se falhar tudo
    return "Novo Compromisso";
  }

  // ---------------------------------------------------------------------------
  // Constrói o bloco de contexto do usuário (injetado no system prompt)
  // ---------------------------------------------------------------------------
  static String _buildContextBlock(UserModel user, DateTime now) {
    final dateStr = DateFormat('dd/MM/yyyy').format(now);
    final timeStr = DateFormat('HH:mm').format(now);
    final weekday = DateFormat('EEEE', 'pt_BR').format(now);
    final isFirst = _isFirstMessageOfDay();

    return '''
# CONTEXTO DO USUÁRIO
- Nome: ${user.primeiroNome} ${user.sobrenome}
- Nome para análise: ${user.nomeAnalise}
- Data de nascimento: ${user.dataNasc}
- Gênero: ${user.gender ?? 'não informado'}
- Data atual: $dateStr ($weekday)
- Hora atual: $timeStr
- Primeira interação do dia: ${isFirst ? 'SIM (cumprimente com carinho)' : 'NÃO (não reintroduza)'}
''';
  }

  // ---------------------------------------------------------------------------
  // SUGESTÕES DE ESTRATÉGIA — Usadas pelo StrategyFlow/FocoDoDia
  // ---------------------------------------------------------------------------
  static Future<List<String>> generateStrategySuggestions({
    required UserModel user,
    required List<TaskModel> tasks,
    required int personalDay,
    required StrategyMode mode,
  }) async {
    final now = DateTime.now();
    final provider = AiProvider();
    final guard = AiLoopGuard(sessionId: 'strategy_${const Uuid().v4()}');
    final toolHandler = AiToolHandler(userId: user.uid);

    final tasksJson = tasks
        .take(15)
        .map((t) => {'title': t.text, 'due_date': t.dueDate?.toIso8601String()})
        .toList();

    final messages = <Map<String, dynamic>>[
      {
        'role': 'system',
        'content': AiPrompts.systemPrompt,
      },
      {
        'role': 'user',
        'content': '''
Gere 3 sugestões de estratégia para o usuário ${user.primeiroNome}.
Dia pessoal: $personalDay
Modo: ${mode.toString()}
Data: ${DateFormat('dd/MM/yyyy').format(now)}
Tarefas do dia: ${jsonEncode(tasksJson)}

Responda SOMENTE com um array JSON de strings: ["sugestão 1", "sugestão 2", "sugestão 3"]
''',
      },
    ];

    AiUsage totalUsage = const AiUsage();
    String finalContent = '';

    try {
      while (true) {
        final response = await provider.chat(
          messages: messages,
          tools: AiConfig.toolDefinitions,
        );
        totalUsage = totalUsage + response.usage;

        if (response.hasContent) {
          finalContent = response.content!;
          break;
        }

        if (response.hasToolCall) {
          guard.tick(response.toolCallName!);
          final toolResult = await toolHandler.dispatch(
            response.toolCallName!,
            response.toolCallArgs ?? {},
          );
          messages.add({
            'role': 'assistant',
            'content': null,
            'tool_calls': [
              {
                'id': response.toolCallId ?? 'call_s',
                'type': 'function',
                'function': {
                  'name': response.toolCallName,
                  'arguments': jsonEncode(response.toolCallArgs),
                },
              }
            ],
          });
          messages.add({
            'role': 'tool',
            'tool_call_id': response.toolCallId ?? 'call_s',
            'content': jsonEncode(toolResult),
          });
          continue;
        }
        break;
      }
    } catch (e) {
      debugPrint('[AssistantService] Erro em generateStrategySuggestions: $e');
      return [];
    }

    // Log usage
    unawaited(_logUsage(
      userId: user.uid,
      type: 'strategy_flow',
      promptLength: 200,
      outputLength: finalContent.length,
      inputTokens: totalUsage.promptTokens,
      outputTokens: totalUsage.completionTokens,
      modelName: totalUsage.model,
    ));

    // Parsear array JSON
    final cleanText = finalContent
        .replaceAll(RegExp(r'```json\s*'), '')
        .replaceAll(RegExp(r'```\s*'), '');

    final startIndex = cleanText.indexOf('[');
    final endIndex = cleanText.lastIndexOf(']');

    if (startIndex == -1 || endIndex == -1 || startIndex > endIndex) return [];

    try {
      final jsonStr = cleanText.substring(startIndex, endIndex + 1);
      final List<dynamic> data = jsonDecode(jsonStr);
      return data.map((e) => e.toString()).toList();
    } catch (e) {
      debugPrint('[AssistantService] Erro ao parsear sugestões: $e');
      return [];
    }
  }

  // ---------------------------------------------------------------------------
  // CONVERSAS E HISTÓRICO — Lógica inalterada
  // ---------------------------------------------------------------------------

  static Future<String?> createConversation(
      String userId, String title) async {
    return const Uuid().v4();
  }

  static Future<void> deleteConversation(String conversationId) async {
    try {
      await Supabase.instance.client
          .schema('sincroapp')
          .from('assistant_messages')
          .delete()
          .eq('conversation_id', conversationId);
    } catch (e) {
      debugPrint('Erro ao deletar conversa: $e');
      rethrow;
    }
  }

  static Future<List<AssistantConversation>> fetchConversations(
      String userId) async {
    try {
      final response = await Supabase.instance.client
          .schema('sincroapp')
          .from('view_conversations')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return response
          .map<AssistantConversation>(
              (row) => AssistantConversation.fromJson(row))
          .toList();
    } catch (e) {
      debugPrint('Erro ao buscar conversas: $e');
      return [];
    }
  }

  static Future<List<AssistantMessage>> fetchMessages(
      String userId, String conversationId) async {
    try {
      final response = await Supabase.instance.client
          .schema('sincroapp')
          .from('assistant_messages')
          .select()
          .eq('conversation_id', conversationId)
          .order('created_at', ascending: false)
          .limit(50);

      final List<AssistantMessage> history = [];
      for (final row in response) {
        final actionsList = <AssistantAction>[];
        if (row['actions'] != null && row['actions'] is List) {
          final acts = row['actions'] as List;
          actionsList.addAll(acts.map((e) => AssistantAction.fromJson(Map<String, dynamic>.from(e))));
        }
        // Carregar embedded_tasks do banco
        final embeddedTasks = <Map<String, dynamic>>[];
        if (row['embedded_tasks'] != null && row['embedded_tasks'] is List) {
          for (final t in (row['embedded_tasks'] as List)) {
            if (t is Map) embeddedTasks.add(Map<String, dynamic>.from(t));
          }
        }
        history.add(AssistantMessage(
          id: row['id'].toString(),
          role: row['role'],
          content: row['content'],
          time: DateTime.parse(row['created_at']),
          actions: actionsList,
          embeddedTasks: embeddedTasks,
        ));
      }
      return history;
    } catch (e) {
      debugPrint('Erro ao buscar mensagens: $e');
      return [];
    }
  }

  static Future<void> saveMessage(
      String userId, AssistantMessage message, String? conversationId) async {
    try {
      final actionsJson = message.actions.map((e) => e.toJson()).toList();
      final tasksJson = message.embeddedTasks;
      await Supabase.instance.client
          .schema('sincroapp')
          .from('assistant_messages')
          .insert({
        'user_id': userId,
        'conversation_id': conversationId,
        'role': message.role,
        'content': message.content,
        'actions': actionsJson,
        'embedded_tasks': tasksJson,
      });
      _cleanupOldMessages(userId);
    } catch (e) {
      debugPrint('Erro ao salvar mensagem: $e');
    }
  }

  static Future<void> _cleanupOldMessages(String userId) async {
    try {
      final count = await Supabase.instance.client
          .schema('sincroapp')
          .from('assistant_messages')
          .count(CountOption.exact)
          .eq('user_id', userId);

      if (count > 50) {
        final overflow = count - 50;
        final idsToDeleteResponse = await Supabase.instance.client
            .schema('sincroapp')
            .from('assistant_messages')
            .select('id')
            .eq('user_id', userId)
            .order('created_at', ascending: true)
            .limit(overflow);
        final ids = (idsToDeleteResponse as List).map((e) => e['id']).toList();
        if (ids.isNotEmpty) {
          await Supabase.instance.client
              .schema('sincroapp')
              .from('assistant_messages')
              .delete()
              .filter('id', 'in', ids);
          debugPrint('🧹 Limpeza de histórico: ${ids.length} mensagens removidas.');
        }
      }
    } catch (_) {}
  }
}

// Evita warning de unawaited Future
void unawaited(Future<void> future) {}
