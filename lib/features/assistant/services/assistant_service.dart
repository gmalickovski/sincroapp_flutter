import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sincro_app_flutter/features/assistant/models/assistant_models.dart';
import 'package:sincro_app_flutter/features/assistant/services/n8n_service.dart';
import 'package:sincro_app_flutter/features/goals/models/goal_model.dart';
import 'package:sincro_app_flutter/features/journal/models/journal_entry_model.dart';
import 'package:sincro_app_flutter/features/tasks/models/task_model.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';
import 'package:sincro_app_flutter/features/strategy/models/strategy_mode.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sincro_app_flutter/core/services/navigation_service.dart';
import 'package:sincro_app_flutter/features/tasks/utils/task_parser.dart';
import 'package:sincro_app_flutter/services/harmony_service.dart'; // 🚀 Import
import 'package:intl/intl.dart';


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
    int? inputTokens, // Precise
    int? outputTokens, // Precise
  }) async {
    try {
      // Usa valor preciso se vier, senão estima
      final int finalInputTokens = inputTokens ?? (promptLength / 4).ceil();
      final int finalOutputTokens = outputTokens ?? (outputLength / 4).ceil();
      
      await Supabase.instance.client
          .schema('sincroapp')
          .from('ai_usage_logs')
          .insert({
        'user_id': userId,
        'created_at': DateTime.now().toIso8601String(),
        'type': type,
        'prompt_length': promptLength,
        'output_length': outputLength,
        'estimated_input_tokens': finalInputTokens, // Usando coluna existente
        'estimated_output_tokens': finalOutputTokens,
      });
    } catch (e) {
      // Ignora erro de tabela inexistente (PGRST205) para não poluir logs
      if (e.toString().contains('PGRST205') || e.toString().contains('ai_usage_logs')) {
         return;
      }
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
    String? activeContext, // New parameter
  }) async {
    final isFirstOfDay = _isFirstMessageOfDay();

    // 1. Get Current Context (Page Awareness)
    final currentRoute = NavigationService.currentRoute;
    final routeArgs = NavigationService.routeArguments;

    // 2. Parse Mentions using TaskParser
    final parsed = TaskParser.parse(question);
    
    // Construct Mentions list for N8n
    // 3. Build Rich Context Data
    final mentionsList = <Map<String, dynamic>>[];
    final harmonyService = HarmonyService();
    final dateFormat = DateFormat('dd/MM/yyyy');

    // Process Contacts (@Mentions)
    for (var contactName in parsed.sharedWith) {
      final Map<String, dynamic> mentionData = {
        'type': 'contact',
        'id': contactName, // In real app, this would be a UUID
        'label': '@$contactName',
      };

      try {
        // TODO: Replace with real ContactService lookup
        // Mocking birthdate for demonstration. 
        // In production, fetch: await contactService.getByName(contactName)
        final contactBirthDate = DateTime(1990, 5, 20); 

        // Current User Date
        DateTime? userBirthDate;
        try {
          userBirthDate = dateFormat.parse(user.dataNasc);
        } catch (_) {}

        if (userBirthDate != null) {
          // Current User Profile
          final userProfile = numerology; // Already calculated and passed in args

          // Contact Profile
          final contactEngine = NumerologyEngine(
            nomeCompleto: contactName, 
            dataNascimento: dateFormat.format(contactBirthDate)
          );
          final contactProfile = contactEngine.calculateProfile();

          // 1. Calculate Synastry
          final synastry = harmonyService.calculateSynastry(
            profileA: userProfile, 
            profileB: contactProfile
          );

          // 2. Calculate Today's Compatibility
          final todayScore = harmonyService.calculateCompatibilityScore(
            date: DateTime.now(), 
            birthDateA: userBirthDate, 
            birthDateB: contactBirthDate
          );

          // 3. Find Next Best Dates
          final nextDates = harmonyService.findNextCompatibleDates(
            startDate: DateTime.now().add(const Duration(days: 1)), 
            birthDateA: userBirthDate, 
            birthDateB: contactBirthDate,
            limit: 3
          );

          mentionData['compatibility'] = {
            'synastryScore': synastry['score'],
            'status': synastry['status'],
            'description': synastry['description'],
            'todayScore': double.parse(todayScore.toStringAsFixed(2)),
            'isFavorableToday': todayScore > 0.6,
            'nextBestDates': nextDates.map((d) => DateFormat('yyyy-MM-dd').format(d)).toList(),
          };
        }
      } catch (e) {
        debugPrint('Error calculating compatibility for @$contactName: $e');
      }
      mentionsList.add(mentionData);
    }

    // Process Goals (!Mentions)
    for (var goal in parsed.goals) {
      mentionsList.add({'type': 'goal', 'id': goal, 'label': '!$goal'});
    }
    
    // Calculate Personal Year/Day manually to ensure it's in the payload
    int anoPessoalVal = 0;
    int diaPessoalVal = 0;
    try {
        final dob = dateFormat.parse(user.dataNasc);
        final today = DateTime.now();
        
        // Personal Day (using static helper)
        diaPessoalVal = NumerologyEngine.calculatePersonalDay(today, user.dataNasc);
        
        // Personal Year (Logic replicated to ensure availability)
        final anniversaryCurrentYear = DateTime(today.year, dob.month, dob.day);
        final calcYear = today.isBefore(anniversaryCurrentYear) ? today.year - 1 : today.year;
        
        // Simple reduce function
        int reduce(int n) {
           n = n.abs();
           if (n == 0) return 0;
           while (n > 9) {
             int sum = 0;
             while (n > 0) {
               sum += n % 10; // Sum digits
               n ~/= 10;
             }
             n = sum;
           }
           return n;
        }
        anoPessoalVal = reduce(dob.day + dob.month + calcYear);
    } catch (e) {
      debugPrint('Error calculating personal dates for payload: $e');
    }

    // 3. Compact Context Payload (Optimized for Llama 3.1 & Token Usage)
    final compactNumerology = {
      'numeros': numerology.numeros, // Key numbers (Life Path, Expression, etc.)
      'listas': {
        'diasFavoraveis': numerology.listas['diasFavoraveis'],
        'licoesCarmicas': numerology.listas['licoesCarmicas'],
        'debitosCarmicos': numerology.listas['debitosCarmicos'],
        'tendenciasOcultas': numerology.listas['tendenciasOcultas'],
      },
      'estruturas': {
        'anoPessoal': anoPessoalVal,
        'diaPessoal': diaPessoalVal,
      }
    };

    final contextData = {
      'user': {
        'primeiroNome': user.primeiroNome,
        'sobrenome': user.sobrenome,
        'dataNasc': user.dataNasc,
        'plan': user.subscription.plan.name, // Fix: Use .name for Enum serialization
        'gender': user.gender, // 📌 Added Gender
      },
      'currentDate': DateTime.now().toLocal().toIso8601String(),
      'currentTime': DateFormat('HH:mm').format(DateTime.now()),
      'currentWeekDay': DateFormat('EEEE', 'pt_BR').format(DateTime.now()),
      'numerology': compactNumerology, // 🚀 Optimized Payload
      'tasks': tasks.map((t) => {
        'id': t.id,
        'title': t.text,
        'date': t.dueDate?.toIso8601String(),
        'status': t.completed ? 'done' : 'pending'
      }).toList(),
      'goals': goals.map((g) => {'id': g.id, 'title': g.title}).toList(),
      'mentions': mentionsList,
    };
    
    // 4. Serialize (Clean Map)
    final payload = {
      'question': question,
      'context': contextData,
    };
    // serialized only for logging
    final payloadJson = jsonEncode(payload); 

    final n8n = N8nService();
    // 5. Call N8n
    final text = await n8n.chat(payload: payload, userId: user.uid);
    
    // Tentativa de Extrair Token Usage antes de logar
    int? preciseInputTokens;
    int? preciseOutputTokens;
    
    try {
       // Quick scan for usage block to avoid full double parse if possible, 
       // but full parse is safer given we need it below anyway.
       // We'll just do a lightweight regex check or parse explicitly if simple
       // Logic: _logUsage is async fire-and-forget, but we want the data.
       // We can defer logging until AFTER standard parsing below?
       // But existing code structure has logging first.
       // Let's refactor to Parse First -> Log -> Return.
    } catch (_) {}

    // --- REFACTORED PARSE & LOG LOGIC ---

    // 1. Remove markdown
    final cleanText = text.replaceAll(RegExp(r'```json\s*'), '').replaceAll(RegExp(r'```\s*'), '');
    
    // 2. Locate JSON
    final startIndex = cleanText.indexOf('{');
    final endIndex = cleanText.lastIndexOf('}');
    
    Map<String, dynamic>? parsedData;

    if (startIndex != -1 && endIndex != -1 && startIndex <= endIndex) {
       final jsonStr = cleanText.substring(startIndex, endIndex + 1);
       try {
         parsedData = jsonDecode(jsonStr) as Map<String, dynamic>;
         
         // Extract Usage
         if (parsedData.containsKey('usage')) {
            final u = parsedData['usage'];
            if (u is Map) {
              preciseInputTokens = u['input'] ?? u['prompt_tokens'];
              preciseOutputTokens = u['output'] ?? u['completion_tokens'];
            }
         }
       } catch (e) {
         debugPrint('Erro parse JSON pré-log: $e');
       }
    }

    // 3. Log NOW
    _logUsage(
      userId: user.uid,
      type: 'assistant_chat',
      promptLength: payloadJson.length,
      outputLength: text.length,
      inputTokens: preciseInputTokens,
      outputTokens: preciseOutputTokens,
    );
     
    // 4. Return handling (Legacy Logic adapted)
    if (parsedData == null) {
       // Fallback Text
       if (cleanText.isNotEmpty) {
           return AssistantAnswer(answer: cleanText, actions: []);
       }
       throw Exception('A IA não retornou um objeto JSON válido.');
    }
    
    final data = parsedData; // Safe now

    // Hande N8n/AI specific errors
    if (data.containsKey('errorMessage') || data.containsKey('errorDescription')) {
      final errorMsg = data['errorDescription'] ?? data['errorMessage'] ?? 'Erro desconhecido.';
      return AssistantAnswer(
          answer: "⚠️ *Erro Técnico (N8n)*:\n$errorMsg\n\nIsso geralmente acontece quando o modelo de IA falha ao tentar estruturar a resposta. Tente simplificar a pergunta ou verifique os logs do N8n.",
          actions: []);
    }

    // 🚀 FIX: Auto-Create Action if suggestedDates exist but actions is empty
    if (data['suggestedDates'] is List && (data['suggestedDates'] as List).isNotEmpty) {
      final hasActions = data['actions'] is List && (data['actions'] as List).isNotEmpty;
      
      if (!hasActions) {
         // Create synthetic action
         final syntheticAction = {
           'type': 'create_task',
           'title': 'Agendar Sugestão',
           'needsUserInput': true,
           'suggestedDates': data['suggestedDates'],
           'data': {'isSynthetic': true}
         };
         
         if (data['actions'] == null) {
           data['actions'] = [syntheticAction];
         } else {
           (data['actions'] as List).add(syntheticAction);
         }
      }
    }

    return AssistantAnswer.fromJson(data);
  }

  // --- Persistence & History Management ---

  static Future<List<AssistantMessage>> fetchHistory(String userId) async {
    try {
      final response = await Supabase.instance.client
          .schema('sincroapp') // Use correct schema
          .from('assistant_messages')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false) // Latest first
          .limit(30); // Load last 30 for UI

      final List<AssistantMessage> history = [];
      for (final row in response) {
        final actionsList = <AssistantAction>[];
        // Parse from 'actions' column (JSONB)
        if (row['actions'] != null) {
          final acts = row['actions'] as List;
          actionsList.addAll(acts.map((e) => AssistantAction.fromJson(e)));
        }

        history.add(AssistantMessage(
            id: row['id'].toString(),
            role: row['role'],
            content: row['content'],
            time: DateTime.parse(row['created_at']),
            actions: actionsList));
      }
      return history.reversed.toList(); // Return oldest -> newest
    } catch (e) {
      debugPrint('Erro ao buscar histórico: $e');
      return [];
    }
  }

  static Future<void> saveMessage(
      String userId, AssistantMessage message) async {
    try {
      final actionsJson = message.actions.map((e) => e.toJson()).toList();
      
      await Supabase.instance.client
          .schema('sincroapp') // Use correct schema
          .from('assistant_messages')
          .insert({
        'user_id': userId,
        'role': message.role,
        'content': message.content,
        //'created_at': message.time.toIso8601String(), // Let DB handle default now()
        'actions': actionsJson // Use 'actions' column directly
      });

      // Fire & Forget Cleanup to save VPS space
      _cleanupOldMessages(userId);
    } catch (e) {
      debugPrint('Erro ao salvar mensagem: $e');
    }
  }

  /// Limpa mensagens antigas para economizar espaço (Mantém apenas as últimas 50)
  static Future<void> _cleanupOldMessages(String userId) async {
    // Strategy: Non-blocking optimization
    try {
       // 1. Count total
       final count = await Supabase.instance.client
           .schema('sincroapp') // Use correct schema
           .from('assistant_messages')
           .count(CountOption.exact) // Returns int directly in newer SDKs
           .eq('user_id', userId);
           
       if (count > 50) {
         final overflow = count - 50;
         
         // 2. Get IDs to delete (Oldest)
         final idsToDeleteResponse = await Supabase.instance.client
             .schema('sincroapp') // Use correct schema
             .from('assistant_messages')
             .select('id')
             .eq('user_id', userId)
             .order('created_at', ascending: true) // Oldest first
             .limit(overflow);
             
         final ids = (idsToDeleteResponse as List).map((e) => e['id']).toList();
         
         // 3. Delete
         if (ids.isNotEmpty) {
            await Supabase.instance.client
                .schema('sincroapp') // Use correct schema
                .from('assistant_messages')
                .delete()
                .filter('id', 'in', ids);
            debugPrint('🧹 Limpeza de histórico: ${ids.length} mensagens removidas.');
         }
       }
    } catch (_) {
      // Fail silently, not critical
    }
  }

  static Future<List<String>> generateStrategySuggestions({
    required UserModel user,
    required List<TaskModel> tasks,
    required int personalDay,
    required StrategyMode mode,
  }) async {
    final contextData = {
      'user': user.toJson(),
      'tasks': tasks.map((t) => t.toJson()).toList(),
      'personalDay': personalDay,
      'mode': mode.toString(),
      'currentDate': DateTime.now().toLocal().toIso8601String(),
      'currentTime': DateFormat('HH:mm').format(DateTime.now()),
      'currentWeekDay': DateFormat('EEEE', 'pt_BR').format(DateTime.now()),
    };
    final payload = {
      'context': contextData,
      'chatInput': 'Gere uma estratégia...', // Placeholder (not used by agent logic directly but good for logging)
    };
    final promptJson = jsonEncode(payload);

    try {
      final n8n = N8nService();
      // O endpoint de estrategia pode esperar 'chatInput' ou 'context' direto. 
      // Vamos padronizar enviando o payload.
      // Se o N8n strategy flow espera 'chatInput' explicitamente, pode precisar ajustar.
      // Assumindo que o fluxo principal unificado trata tudo.
      final text = await n8n.chat(payload: payload, userId: user.uid);

      // Log Usage AFTER response
      _logUsage(
        userId: user.uid,
        type: 'strategy_flow',
        promptLength: promptJson.length,
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
