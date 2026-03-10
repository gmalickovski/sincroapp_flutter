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

  AiLoopGuard({
    required this.sessionId,
    int? limit,
  }) : limit = limit ?? AiConfig.maxIterations;

  /// Incrementa o contador. Lança [AiLoopException] se o limite for atingido.
  void tick(String toolName) {
    _iterations++;
    debugPrint(
      '[AiLoopGuard] Sessão=$sessionId | Iteração=$_iterations/$limit | Ferramenta=$toolName',
    );
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
