import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:sincro_app_flutter/services/supabase_service.dart';

class N8nService {
  // Agora lê do arquivo .env
  // failover
  static String get _webhookUrl {
     final envUrl = dotenv.env['ASSISTANT_WEBHOOK_URL'];
     if (envUrl != null && envUrl.isNotEmpty) return envUrl;
     return 'https://n8n.studiomlk.com.br/webhook/sincroapp-assistant';
  }

  /// Envia o payload estruturado para o n8n
  Future<String> chat({
    required Map<String, dynamic> payload,
    required String userId,
  }) async {
    try {
      if (_webhookUrl.isEmpty) {
        throw Exception('ASSISTANT_WEBHOOK_URL not configured in .env');
      }
      debugPrint('[N8nService] Enviando payload para $_webhookUrl...');
      
      final bodyMap = {
        ...payload,
        'userId': userId,
        // 'timestamp': DateTime.now().toIso8601String(),
      };
      
      final response = await http.post(
        Uri.parse(_webhookUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(bodyMap),
      );

      if (response.statusCode == 200) {
        // O n8n geralmente retorna um JSON. Dependendo do nó final (Respond to Webhook),
        // pode ser { "output": "text" } ou direto o texto.
        // Vamos assumir que o n8n retorna o JSON do Agent.
        
        // Se o n8n retornar uma lista de objetos (comum em alguns workflows), pegamos o primeiro.
        final dynamic decoded = jsonDecode(response.body);
        
        String outputText = '';
        if (decoded is List && decoded.isNotEmpty) {
           // As vezes n8n retorna [{ "output": "..." }]
           final first = decoded.first as Map<String, dynamic>;
           final dynamic content = first['output'] ?? first['text'];
           
           if (content is Map || content is List) {
             outputText = jsonEncode(content);
           } else {
             outputText = content?.toString() ?? jsonEncode(first);
           }
        } // End if(decoded is List)

        // Extrair e logar uso de tokens (Fire and forget)
        try {
          Map<String, dynamic>? usageData;
          if (decoded is Map<String, dynamic> && decoded.containsKey('token_usage')) {
             usageData = decoded['token_usage'];
          } else if (decoded is List && decoded.isNotEmpty && decoded[0] is Map && (decoded[0] as Map).containsKey('token_usage')) {
             usageData = decoded[0]['token_usage'];
          }

          if (usageData != null) {
             final int total = usageData['total_tokens'] is int ? usageData['total_tokens'] : 0;
             if (total > 0) {
               SupabaseService().logUsage(
                 requestType: 'chat_message', 
                 totalTokens: total,
                 modelName: 'gpt-4o-mini',
               );
             }
          }
        } catch (e) {
          debugPrint('[N8nService] Erro ao processar token_usage: $e');
        }

        // Output parsing logic (continuing from previous if/else structure logic)
        if (decoded is Map) {
           final dynamic content = decoded['output'] ?? decoded['text'] ?? decoded['response'];
            if (content is Map || content is List) {
             outputText = jsonEncode(content);
           } else {
             outputText = content?.toString() ?? jsonEncode(decoded);
           }
        } else if (outputText.isEmpty) { 
           // If outputText is still empty and it wasn't a list handled above or a map handled here
           outputText = decoded.toString();
        }

        debugPrint('[N8nService] Resposta recebida (len=${outputText.length})');
        return outputText;
      } else {
        throw Exception('Erro n8n: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      debugPrint('[N8nService] Falha na requisição: $e');
      rethrow;
    }
  }
}
