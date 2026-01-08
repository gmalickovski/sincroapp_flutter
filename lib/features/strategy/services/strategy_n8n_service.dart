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
    final webhookUrl = dotenv.env[_webhookEnvKey];

    if (webhookUrl == null || webhookUrl.isEmpty) {
      debugPrint('⚠️ N8N Webhook URL not found in .env ($_webhookEnvKey)');
      throw Exception('Configuration Error: N8N Webhook URL missing.');
    }

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
      
      final response = await http.post(
        Uri.parse(webhookUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
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
}
