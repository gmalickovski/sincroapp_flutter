import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class SpeechService {
  static final SpeechService _instance = SpeechService._internal();
  factory SpeechService() => _instance;
  SpeechService._internal();

  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _available = false;
  
  // Timer manual para garantir que pare após silêncio (essencial para web/android)
  Timer? _silenceTimer;

  bool get isAvailable => _available;
  bool get isListening => _speech.isListening;

  String? _detectedLocaleId;

  Future<bool> init() async {
    try {
      _available = await _speech.initialize(
        onStatus: (status) {
          debugPrint('Speech status: $status');
          if (status == 'done' || status == 'notListening') {
            _cancelSilenceTimer();
          }
        },
        onError: (errorNotification) {
          debugPrint('Speech error: $errorNotification');
          _cancelSilenceTimer();
        },
      );

      if (_available) {
        _detectedLocaleId = await _findBestPortugueseLocale();
        debugPrint('Locale detectado para fala: $_detectedLocaleId');
      }
    } catch (e) {
      debugPrint('Erro ao inicializar speech: $e');
      _available = false;
    }
    return _available;
  }

  Future<String> _findBestPortugueseLocale() async {
    try {
      var locales = await _speech.locales();
      debugPrint('Locales disponíveis: ${locales.map((l) => l.localeId).join(', ')}');
      
      // 1. Tenta pt_BR exato
      var exact = locales.where((l) => l.localeId == 'pt_BR').firstOrNull;
      if (exact != null) return exact.localeId;

      // 2. Tenta qualquer pt_BR (case insensitive ou com traço)
      var loose = locales.where((l) => l.localeId.toLowerCase().replaceAll('-', '_') == 'pt_br').firstOrNull;
      if (loose != null) return loose.localeId;

      // 3. Tenta qualquer português
      var anyPt = locales.where((l) => l.localeId.toLowerCase().startsWith('pt')).firstOrNull;
      if (anyPt != null) return anyPt.localeId;

    } catch (e) {
      debugPrint('Erro ao buscar locales: $e');
    }
    return 'pt_BR'; // Fallback forte
  }

  Future<void> start({
    required Function(String text) onResult,
    VoidCallback? onDone,
  }) async {
    if (!_available) {
      debugPrint('SpeechService: Start chamado mas serviço não está disponível');
      onDone?.call();
      return;
    }

    // Configurações de silêncio
    // Web: usa timer manual pois o nativo é inconsistente
    // Mobile: usa pauseFor nativo, mas mantemos o timer como segurança
    final pauseFor = kIsWeb ? const Duration(seconds: 3) : const Duration(seconds: 5);
    final listenFor = const Duration(seconds: 30);
    
    // Garante que o locale seja pt_BR se a detecção falhou ou ainda é nula
    final localeId = _detectedLocaleId ?? 'pt_BR';
    debugPrint('Iniciando reconhecimento de voz com locale: $localeId');

    _startSilenceTimer(onDone);

    await _speech.listen(
      onResult: (result) {
        debugPrint('Speech Result: ${result.recognizedWords} (Final: ${result.finalResult})');
        
        if (result.finalResult) {
           _cancelSilenceTimer();
           // No Web, as vezes o finalResult vem mas o status não muda para done imediatamente
           if (kIsWeb) {
             stop(); // Força parada no Web ao receber resultado final
             onDone?.call();
           }
        } else {
           _resetSilenceTimer(onDone);
        }
        
        onResult(result.recognizedWords);
      },
      listenFor: listenFor,
      pauseFor: pauseFor,
      localeId: localeId,
      cancelOnError: true,
      partialResults: true,
    );
  }

  Future<void> stop() async {
    debugPrint('SpeechService: Parando...');
    _cancelSilenceTimer();
    await _speech.stop();
  }

  void _startSilenceTimer(VoidCallback? onDone) {
    _cancelSilenceTimer();
    // Timer de segurança
    // Web: 3 segundos de silêncio = fim
    // Mobile: 5 segundos (dá chance pro pauseFor nativo agir antes)
    final duration = kIsWeb ? const Duration(seconds: 3) : const Duration(seconds: 5);
    
    _silenceTimer = Timer(duration, () {
      debugPrint('SpeechService: Silêncio detectado pelo timer manual ($duration). Parando.');
      stop();
      onDone?.call();
    });
  }

  void _resetSilenceTimer(VoidCallback? onDone) {
    _startSilenceTimer(onDone);
  }

  void _cancelSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = null;
  }
}
