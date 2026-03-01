import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:sincro_app_flutter/features/strategy/models/strategy_mode.dart';
import 'package:sincro_app_flutter/models/user_model.dart';

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
    // Failover: Try dotenv, then fallback to hardcoded
    String? webhookUrl = dotenv.env[_webhookEnvKey];
    if (webhookUrl == null || webhookUrl.isEmpty) {
      webhookUrl = 'https://n8n.studiomlk.com.br/webhook/sincroapp-sincroflow';
      debugPrint('⚠️ .env not loaded. Using Hardcoded Sincroflow Webhook.');
    }

    if (webhookUrl.isEmpty) {
      debugPrint('⚠️ N8N Webhook URL not found in .env ($_webhookEnvKey)');
      throw Exception('Configuration Error: N8N Webhook URL missing.');
    }

    // Construct the Structured Payload (Sincroflow expects this at root)
    final payload = {
      'user': {
        'name': '${user.primeiroNome} ${user.sobrenome}', // Full Name
        'firstName': user.primeiroNome,
        'lastName': user.sobrenome,
        'analysisName': user.nomeAnalise,
        'id': user.uid,
        'gender': user.gender, // Nullable
        'numerology': {
          'personalDay': personalDay,
          'mode': mode.name,
        }
      },
      'tasks': tasksCompact,
      'context': {
        'modeTitle': modeTitle,
        'modeDescription': modeDescription,
        'sincroflowMode': mode.name, // Explicit mode name for context
        'timestamp': DateTime.now().toIso8601String(),
      }
    };

    try {
      debugPrint('🚀 Sending Strategy Request to N8N: $webhookUrl');

      // REVERTED: Send payload directly to body (no chatInput wrapper)
      // This is the format that was working on January 15th commit.
      final encodedPayload = jsonEncode(payload);
      debugPrint('--- STRATEGY AI PAYLOAD ---');
      debugPrint(encodedPayload);
      debugPrint('---------------------------');

      final response = await http
          .post(
            Uri.parse(webhookUrl),
            headers: {'Content-Type': 'application/json'},
            body: encodedPayload,
          )
          .timeout(const Duration(seconds: 45)); // N8N might take time with AI

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
        throw Exception(
            'Failed to communicate with N8N (Status: ${response.statusCode})');
      }
    } catch (e) {
      debugPrint('❌ Error contacting N8N: $e');
      rethrow;
    }
}
}
