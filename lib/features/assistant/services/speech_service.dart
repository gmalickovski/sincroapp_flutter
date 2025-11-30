import 'dart:async';
import 'package:flutter/foundation.dart';

class SpeechService {
  static final SpeechService _instance = SpeechService._internal();
  factory SpeechService() => _instance;
  SpeechService._internal();

  bool _available = false;
  
  // Timer manual para garantir que pare após silêncio (essencial para web/android)
  Timer? _silenceTimer;

  bool get isAvailable => _available;
  bool get isListening => false;

  Future<bool> init() async {
    // STUB: Speech to text temporariamente desativado devido a incompatibilidade de plugin
    _available = false;
    return _available;
  }

  Future<void> start({
    required Function(String text) onResult,
    VoidCallback? onDone,
  }) async {
    // STUB: Não faz nada
    debugPrint('SpeechService: Start chamado mas serviço está desativado (Stub)');
    onDone?.call();
  }

  Future<void> stop() async {
    _silenceTimer?.cancel();
  }
}
