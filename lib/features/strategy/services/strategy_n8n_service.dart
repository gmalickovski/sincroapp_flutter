import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:sincro_app_flutter/features/strategy/models/strategy_mode.dart';
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';

class StrategyN8NService {
  static const String _webhookEnvKey = 'SINCROFLOW_WEBHOOK';

  /// Fetches strategy recommendations from N8N webhook.
  /// Returns a list of strings (suggestions) or throws an exception.
  static Future<List<String>> fetchStrategyRecommendation({
    required UserModel user,
    required int personalDay,
    required StrategyMode mode,
    required List<Map<String, dynamic>> tasksCompact,
    required String modeTitle,
    required String modeDescription,
  }) async {
    final webhookUrl = dotenv.env[_webhookEnvKey];

    if (webhookUrl == null || webhookUrl.isEmpty) {
      debugPrint('⚠️ N8N Webhook URL not found in .env ($_webhookEnvKey)');
      throw Exception('Configuration Error: N8N Webhook URL missing.');
    }

    // Construct the Structured Payload (Sincroflow expects this at root)
    final payload = {
      'user': {
        'name': user.primeiroNome,
        'id': user.uid,
        'numerology': {
          'personalDay': personalDay,
          'mode': mode.name,
        }
      },
      'tasks': tasksCompact,
      'context': {
        'modeTitle': modeTitle,
        'modeDescription': modeDescription,
        'timestamp': DateTime.now().toIso8601String(),
      }
    };

    try {
      debugPrint('🚀 Sending Strategy Request to N8N: $webhookUrl');
      
      // REVERTED: Send payload directly to body (no chatInput wrapper)
      // This is the format that was working on January 15th commit.
      final encodedPayload = jsonEncode(payload);
      print('--- STRATEGY AI PAYLOAD ---');
      print(encodedPayload);
      print('---------------------------');

      final response = await http.post(
        Uri.parse(webhookUrl),
        headers: {'Content-Type': 'application/json'},
        body: encodedPayload,
      ).timeout(const Duration(seconds: 45)); // N8N might take time with AI

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        
        // Expecting { "suggestions": ["Suggestion 1", "Suggestion 2"] }
        if (data.containsKey('suggestions') && data['suggestions'] is List) {
          final List<dynamic> rawSuggestions = data['suggestions'];
          return rawSuggestions.map((e) => e.toString()).toList();
        } else if (data.containsKey('output') && data['output'] is String) {
           // Fallback if N8N returns a single string (try to parse or wrap)
           return [data['output'].toString()];
        } else {
           debugPrint('⚠️ Unexpected N8N response format: ${response.body}');
           throw Exception('Invalid response format from N8N.');
        }
      } else {
        debugPrint('❌ N8N Error: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to communicate with N8N (Status: ${response.statusCode})');
      }
    } catch (e) {
      debugPrint('❌ Error contacting N8N: $e');
      rethrow;
    }
  }

  /// Analyzes professional compatibility using AI via N8N.
  static Future<String> analyzeProfessionCompatibility({
    required UserModel user,
    required NumerologyResult profile,
    required String professionName,
  }) async {
    final webhookUrl = dotenv.env['PROFESSIONAL_APTITUDE_WEBHOOK'];

    if (webhookUrl == null || webhookUrl.isEmpty) {
      debugPrint('⚠️ Professional Aptitude Webhook URL not found in .env');
      throw Exception('Configuration Error: Webhook URL missing.');
    }

    final payload = {
      'user': {
        'name': user.primeiroNome,
        'numerology': {
          'expression': NumerologyEngine.reduceNumber(profile.numeros['expressao'] ?? 0, mestre: true),
          'destiny': NumerologyEngine.reduceNumber(profile.numeros['destino'] ?? 0, mestre: true),
          'path': NumerologyEngine.reduceNumber(profile.numeros['missao'] ?? 0, mestre: true), // Mission (Correctly Reduced)
        }
      },
      'profession': professionName,
      'formatting_instructions': '''
1. Calcule o Score de Compatibilidade em degraus de 5% (ex: 55%, 60%, 85%...).
2. Forneça a análise detalhada como de costume.
3. CONDICIONAL "Profissões Ideais":
   - Se Score >= 90%: NÃO inclua esta seção.
   - Se Score < 90%: Sugira 3 profissões que teriam compatibilidade de 90% a 100% com o perfil numerológico.
     IMPORTANTE: As profissões sugeridas DEVEM ser calculadas para ter um Score ALTO (>= 90%). Não sugira algo que resultaria em 70%.
   Misture áreas correlatas e distintas.
''',
      'timestamp': DateTime.now().toIso8601String(),
    };

    try {
      debugPrint('🚀 Sending Professional Aptitude Request to N8N: $webhookUrl');
      
      // REVERTED: Send payload directly to body (no chatInput wrapper)
      final response = await http.post(
        Uri.parse(webhookUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      ).timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        
        if (data.containsKey('analysis') && data['analysis'] is String) {
          return data['analysis'];
        } else if (data.containsKey('output') && data['output'] is String) {
           return data['output'];
        } else {
           debugPrint('⚠️ Unexpected N8N response format: ${response.body}');
           throw Exception('Invalid response format from AI.');
        }
      } else {
        debugPrint('❌ N8N Error: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to communicate with N8N (Status: ${response.statusCode})');
      }
    } catch (e) {
      debugPrint('❌ Error contacting N8N: $e');
      rethrow;
    }
  }
}
