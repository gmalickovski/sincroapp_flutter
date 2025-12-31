import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class N8nService {
  static const String _webhookUrl = 'https://n8n.studiomlk.com.br/webhook/sincroflow';

  /// Envia o prompt para o n8n e retorna a resposta bruta (String)
  Future<String> chat({
    required String prompt,
    required String userId,
  }) async {
    try {
      debugPrint('[N8nService] Enviando prompt para $_webhookUrl...');
      
      final response = await http.post(
        Uri.parse(_webhookUrl),
        headers: {
          'Content-Type': 'application/json',
          // 'Authorization': 'Bearer ...' // Se adicionar auth no futuro
        },
        body: jsonEncode({
          'chatInput': prompt,
          'userId': userId,
          // Podemos enviar metadados adicionais se o n8n for otimizado para usá-los separado
          // 'timestamp': DateTime.now().toIso8601String(),
        }),
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
           final first = decoded.first;
           outputText = first['output'] ?? first['text'] ?? jsonEncode(first);
        } else if (decoded is Map) {
           outputText = decoded['output'] ?? decoded['text'] ?? jsonEncode(decoded);
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
