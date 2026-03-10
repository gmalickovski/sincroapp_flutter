// lib/features/assistant/ai/ai_provider.dart
//
// Camada HTTP que abstrai a comunicação com Groq e OpenAI.
// Ambos usam a API OpenAI-compatible (mesmo formato de request/response).
// Suporta function calling (tool use) nativo.

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:sincro_app_flutter/features/assistant/ai/ai_config.dart';

// ---------------------------------------------------------------------------
// Modelos de resposta
// ---------------------------------------------------------------------------

/// Resultado de uma chamada ao LLM.
class AiResponse {
  /// Texto da resposta final (null se a IA solicitou uma ferramenta).
  final String? content;

  /// Nome da ferramenta solicitada (null se não há tool call).
  final String? toolCallName;

  /// Argumentos da ferramenta em Map.
  final Map<String, dynamic>? toolCallArgs;

  /// ID do tool call (necessário para enviar o resultado de volta ao LLM).
  final String? toolCallId;

  /// Tokens consumidos nesta chamada.
  final AiUsage usage;

  const AiResponse({
    this.content,
    this.toolCallName,
    this.toolCallArgs,
    this.toolCallId,
    required this.usage,
  });

  bool get hasToolCall => toolCallName != null;
  bool get hasContent => content != null && content!.isNotEmpty;
}

/// Dados de consumo de tokens.
class AiUsage {
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;
  final String model;

  const AiUsage({
    this.promptTokens = 0,
    this.completionTokens = 0,
    this.totalTokens = 0,
    this.model = '',
  });

  AiUsage operator +(AiUsage other) => AiUsage(
        promptTokens: promptTokens + other.promptTokens,
        completionTokens: completionTokens + other.completionTokens,
        totalTokens: totalTokens + other.totalTokens,
        model: model.isNotEmpty ? model : other.model,
      );
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

/// Faz chamadas HTTP para o LLM ativo (Groq ou OpenAI — mesmo formato de API).
class AiProvider {
  final String _endpoint;
  final String _apiKey;
  final String _model;

  AiProvider()
      : _endpoint = AiConfig.activeEndpoint,
        _apiKey = AiConfig.activeApiKey,
        _model = AiConfig.activeModel;

  /// Envia uma lista de mensagens para o LLM e retorna a resposta parseada.
  /// [messages] devem seguir o formato OpenAI: [{"role": "...", "content": "..."}]
  /// Faz retry automático com backoff em rate limit (429).
  Future<AiResponse> chat({
    required List<Map<String, dynamic>> messages,
    List<Map<String, dynamic>>? tools,
    int maxRetries = 3,
  }) async {
    final body = {
      'model': _model,
      'temperature': AiConfig.temperature,
      'max_tokens': AiConfig.maxTokens,
      'messages': messages,
      if (tools != null && tools.isNotEmpty) 'tools': tools,
      if (tools != null && tools.isNotEmpty) 'tool_choice': 'auto',
    };

    debugPrint('[AiProvider] → $_endpoint | model=$_model | msgs=${messages.length}');

    // ── Retry com backoff para 429 ────────────────────────────────────────
    http.Response response;
    int attempt = 0;
    while (true) {
      response = await http.post(
        Uri.parse(_endpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode(body),
      );

      if (response.statusCode == 429 && attempt < maxRetries) {
        attempt++;
        // Extrair tempo de espera do header ou usar backoff exponencial
        final retryAfterHeader = response.headers['retry-after'];
        final waitSeconds = retryAfterHeader != null
            ? (double.tryParse(retryAfterHeader) ?? 2.0)
            : (attempt * 2.0);
        debugPrint('[AiProvider] ⏳ Rate limit (429). Retry $attempt/$maxRetries em ${waitSeconds}s...');
        await Future.delayed(Duration(milliseconds: (waitSeconds * 1000).toInt()));
        continue;
      }
      break;
    }

    if (response.statusCode != 200) {
      debugPrint('[AiProvider] ❌ Status ${response.statusCode}: ${response.body}');
      throw Exception(
        'Erro na API de IA (${response.statusCode}): ${response.body}',
      );
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;

    // Parse usage
    final usageRaw = decoded['usage'] as Map<String, dynamic>? ?? {};
    final usage = AiUsage(
      promptTokens: (usageRaw['prompt_tokens'] as int?) ?? 0,
      completionTokens: (usageRaw['completion_tokens'] as int?) ?? 0,
      totalTokens: (usageRaw['total_tokens'] as int?) ?? 0,
      model: _model,
    );

    debugPrint('[AiProvider] ✅ Tokens: ${usage.totalTokens} (prompt=${usage.promptTokens}, comp=${usage.completionTokens})');

    // Parse choice
    final choices = decoded['choices'] as List<dynamic>? ?? [];
    if (choices.isEmpty) {
      throw Exception('LLM retornou choices vazio.');
    }

    final message = choices.first['message'] as Map<String, dynamic>? ?? {};

    // Verificar se há tool call (Groq pode usar finish_reason='tool_calls' ou 'stop')
    final toolCalls = message['tool_calls'] as List<dynamic>?;
    if (toolCalls != null && toolCalls.isNotEmpty) {
      final tc = toolCalls.first as Map<String, dynamic>;
      final function = tc['function'] as Map<String, dynamic>? ?? {};
      final toolName = function['name']?.toString() ?? '';
      Map<String, dynamic> toolArgs = {};
      try {
        final argsStr = function['arguments']?.toString() ?? '{}';
        toolArgs = jsonDecode(argsStr) as Map<String, dynamic>;
      } catch (e) {
        debugPrint('[AiProvider] Erro ao parsear tool args: $e');
      }

      debugPrint('[AiProvider] 🔧 Tool call: $toolName | args=$toolArgs');

      return AiResponse(
        toolCallName: toolName,
        toolCallArgs: toolArgs,
        toolCallId: tc['id']?.toString(),
        usage: usage,
      );
    }

    // Resposta de texto final
    final content = message['content']?.toString() ?? '';
    debugPrint('[AiProvider] 💬 Resposta final (${content.length} chars)');

    return AiResponse(content: content, usage: usage);
  }
}

