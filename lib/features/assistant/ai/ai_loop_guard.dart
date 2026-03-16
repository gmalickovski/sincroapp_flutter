// lib/features/assistant/ai/ai_loop_guard.dart
//
// Sistema de segurança contra loops de chamadas de IA.
// Cada sessão de chat tem um contador de iterações de ferramentas.
// Se o limite for ultrapassado, lança AiLoopException.

import 'package:flutter/foundation.dart';
import 'package:sincro_app_flutter/features/assistant/ai/ai_config.dart';

/// Exceção lançada quando o guardrail anti-loop é acionado.
class AiLoopException implements Exception {
  final String message;
  final int iterations;

  const AiLoopException({
    required this.message,
    required this.iterations,
  });

  @override
  String toString() => 'AiLoopException($iterations iterações): $message';
}

/// Guarda o estado de iterações de uma sessão de IA.
/// Crie uma instância por chamada ao `AssistantService.ask()` e
/// passe-a pelo pipeline de ferramentas.
class AiLoopGuard {
  int _iterations = 0;
  final int limit;
  final String sessionId;

  /// Rastreia chamadas anteriores: "toolName|argsJson" → número de chamadas
  final Map<String, int> _toolCallHistory = {};

  AiLoopGuard({
    required this.sessionId,
    int? limit,
  }) : limit = limit ?? AiConfig.maxIterations;

  /// Incrementa o contador. Lança [AiLoopException] se o limite for atingido
  /// ou se a mesma ferramenta for chamada com os mesmos argumentos mais de uma vez.
  void tick(String toolName, {Map<String, dynamic>? args}) {
    _iterations++;
    debugPrint(
      '[AiLoopGuard] Sessão=$sessionId | Iteração=$_iterations/$limit | Ferramenta=$toolName',
    );

    // Detecta chamada duplicada (mesma tool + mesmos args)
    if (args != null) {
      final key = '$toolName|${args.toString()}';
      final prev = _toolCallHistory[key] ?? 0;
      _toolCallHistory[key] = prev + 1;
      if (prev >= 1) {
        debugPrint(
          '[AiLoopGuard] ⚠️  CHAMADA DUPLICADA detectada: $toolName (${prev + 1}x com mesmos args)',
        );
        throw AiLoopException(
          message:
              'O assistente chamou "$toolName" repetidamente com os mesmos argumentos. '
              'Por favor, tente reformular sua pergunta.',
          iterations: _iterations,
        );
      }
    }

    if (_iterations > limit) {
      debugPrint(
        '[AiLoopGuard] ⚠️  LOOP DETECTADO na sessão $sessionId após $_iterations iterações!',
      );
      throw AiLoopException(
        message:
            'O assistente entrou em loop após $_iterations tentativas. '
            'Por favor, tente reformular sua pergunta.',
        iterations: _iterations,
      );
    }
  }

  /// Número atual de iterações consumidas.
  int get count => _iterations;

  /// Reseta o contador (use após resposta final ser emitida).
  void reset() {
    _iterations = 0;
  }
}
