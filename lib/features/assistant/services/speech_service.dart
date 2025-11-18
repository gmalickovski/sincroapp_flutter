import 'dart:async';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter/foundation.dart';

class SpeechService {
  static final SpeechService _instance = SpeechService._internal();
  factory SpeechService() => _instance;
  SpeechService._internal();

  SpeechToText? _speech;
  bool _available = false;
  String? _detectedLocaleId;

  Timer? _silenceTimer;

  bool get isAvailable => _available;
  bool get isListening => _speech?.isListening ?? false;

  Future<bool> init() async {
    if (_speech != null) return _available;

    _speech = SpeechToText();
    try {
      _available = await _speech!.initialize(
        onError: (e) => debugPrint('Speech error: $e'),
        onStatus: (s) => debugPrint('Speech status: $s'),
        debugLogging: kDebugMode,
      );

      if (_available) {
        _detectedLocaleId = await _findBestPortugueseLocale();
      }
    } catch (e) {
      debugPrint('Erro fatal ao iniciar SpeechToText: $e');
      _available = false;
    }
    return _available;
  }

  Future<String> _findBestPortugueseLocale() async {
    try {
      var locales = await _speech!.locales();
      try {
        var ptBR = locales.firstWhere((l) => l.localeId == 'pt_BR');
        return ptBR.localeId;
      } catch (_) {}
      try {
        var anyPt = locales
            .firstWhere((l) => l.localeId.toLowerCase().startsWith('pt'));
        return anyPt.localeId;
      } catch (_) {}
      return '';
    } catch (e) {
      return '';
    }
  }

  Future<void> start({
    required Function(String text) onResult,
    VoidCallback? onDone,
  }) async {
    if (_speech == null) await init();
    if (!_available) return;

    _resetSilenceTimer(onDone);

    await _speech!.listen(
      localeId: _detectedLocaleId ?? 'pt_BR',
      onResult: (result) {
        _resetSilenceTimer(onDone);
        // Retorna apenas as palavras reconhecidas na sessão atual
        onResult(result.recognizedWords);

        if (result.finalResult) {
          stop();
          onDone?.call();
        }
      },
      cancelOnError: true,
      partialResults: true,
      listenMode: ListenMode.dictation,
      pauseFor: const Duration(seconds: 3),
    );
  }

  Future<void> stop() async {
    _silenceTimer?.cancel();
    if (_speech == null) return;
    await _speech!.stop();
  }

  void _resetSilenceTimer(VoidCallback? onDone) {
    _silenceTimer?.cancel();
    // Timeout de segurança manual (5s) caso o nativo falhe
    _silenceTimer = Timer(const Duration(seconds: 5), () {
      stop();
      onDone?.call();
    });
  }
}
