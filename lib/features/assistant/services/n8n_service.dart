import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:flutter_dotenv/flutter_dotenv.dart';

class N8nService {
  // Agora lê do arquivo .env
  static String get _webhookUrl => dotenv.env['ASSISTANT_WEBHOOK_URL'] ?? '';

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
        } else if (decoded is Map) {
           final dynamic content = decoded['output'] ?? decoded['text'];
            if (content is Map || content is List) {
             outputText = jsonEncode(content);
           } else {
             outputText = content?.toString() ?? jsonEncode(decoded);
           }
        } else {
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
