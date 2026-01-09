import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:sincro_app_flutter/models/user_model.dart';
import 'package:sincro_app_flutter/services/numerology_engine.dart';

class LoveCompatibilityService {
  static String get _webhookUrl => dotenv.env['COMPATIBILITY_WEBHOOK'] ?? '';

  /// Sends compatibility data to N8N AI for detailed analysis
  Future<String> getDetailedAnalysis({
    required UserModel currentUser,
    required NumerologyResult currentUserProfile,
    required String partnerName,
    required String partnerBirthDate, // dd/MM/yyyy
    required NumerologyResult partnerProfile,

    required Map<String, dynamic> synastryResult,
    Map<String, dynamic>? relationshipRules,
  }) async {
    if (_webhookUrl.isEmpty) {
      throw Exception('Webhook URL not configured (LOVE_COMPATIBILITY_WEBHOOK_URL)');
    }

    try {
      final payload = {
        'instructions': 'CRITICAL: You are an expert Numerologist. You MUST use the pre-calculated numbers provided in this JSON under "profile" and "synastry". DO NOT recalculate them based on names/dates. The provided numbers (Destiny, Expression, Synastry Score) are the ABSOLUTE TRUTH for this analysis. Ignore any internal calculation that differs. Focus on interpreting the provided numbers.',
        'user': {
          'name': currentUser.nomeAnalise, // Use explicit analysis name to avoid duplication
          'birthDate': currentUser.dataNasc,
          'profile': currentUserProfile.numeros,
        },
        'partner': {
          'name': partnerName,
          'birthDate': partnerBirthDate,
          'profile': partnerProfile.numeros,
        },
        'synastry': {
          'score': synastryResult['score'],
          'status': synastryResult['status'],
          'details': synastryResult['details'],
        },
        if (relationshipRules != null) 'relationshipRules': relationshipRules,
        'requestTime': DateTime.now().toIso8601String(),
      };

      print('--- AI REQUEST PAYLOAD ---');
      print(jsonEncode(payload));
      print('--------------------------');

      final response = await http.post(
        Uri.parse(_webhookUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        // Assume N8N returns { "analysis": "Markdown text..." } or { "output": "..." }
        final data = jsonDecode(response.body);
        return data['analysis'] ?? data['output'] ?? data['text'] ?? 'Análise concluída, mas sem texto retornado.';
      } else {
        throw Exception('Failed to get analysis: ${response.statusCode}');
      }
    } catch (e) {
      // In production, log to crashlytics
      print('Error getting compatibility analysis: $e');
      rethrow;
    }
  }
}
