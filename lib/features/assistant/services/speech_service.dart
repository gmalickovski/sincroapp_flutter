import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter/foundation.dart';

class SpeechService {
  // Singleton pattern para garantir uma única instância do serviço
  static final SpeechService _instance = SpeechService._internal();
  factory SpeechService() => _instance;
  SpeechService._internal();

  SpeechToText? _speech;
  bool _available = false;
  String? _detectedLocaleId;

  bool get isAvailable => _available;
  bool get isListening => _speech?.isListening ?? false;

  Future<bool> init() async {
    if (_speech != null) return _available;

    _speech = SpeechToText();
    try {
      _available = await _speech!.initialize(
        onError: (e) => debugPrint('Speech error: $e'),
        onStatus: (s) => debugPrint('Speech status: $s'),
        debugLogging: kDebugMode, // Ajuda a ver erros no console
      );

      if (_available) {
        // Tenta detectar automaticamente o melhor locale para Português
        _detectedLocaleId = await _findBestPortugueseLocale();
        debugPrint('Locale de voz configurado para: $_detectedLocaleId');
      }
    } catch (e) {
      debugPrint('Erro fatal ao iniciar SpeechToText: $e');
      _available = false;
    }
    return _available;
  }

  /// Busca os idiomas instalados no dispositivo e prioriza pt_BR ou pt_PT
  Future<String> _findBestPortugueseLocale() async {
    try {
      var locales = await _speech!.locales();

      // 1. Tenta encontrar exatamente pt_BR
      try {
        var ptBR = locales.firstWhere((l) => l.localeId == 'pt_BR');
        return ptBR.localeId;
      } catch (_) {}

      // 2. Se não achar, tenta qualquer um que comece com 'pt' (ex: pt_PT)
      try {
        var anyPt = locales
            .firstWhere((l) => l.localeId.toLowerCase().startsWith('pt'));
        return anyPt.localeId;
      } catch (_) {}

      // 3. Se não tiver português instalado, retorna vazio (usa o padrão do sistema)
      // Aviso: Se o padrão for inglês, ele ouvirá em inglês.
      return '';
    } catch (e) {
      return '';
    }
  }

  Future<void> start({
    required Function(String text) onResult,
  }) async {
    if (_speech == null) await init();
    if (!_available) return;

    await _speech!.listen(
      // Usa o locale detectado ou força pt_BR se a detecção falhou mas queremos tentar
      localeId: _detectedLocaleId ?? 'pt_BR',
      onResult: (result) {
        // Retorna o texto reconhecido em tempo real
        onResult(result.recognizedWords);
      },
      cancelOnError: true,
      partialResults:
          true, // ESSENCIAL: Isso faz o texto aparecer enquanto você fala
      listenMode: ListenMode.dictation,
      pauseFor: const Duration(
          seconds: 3), // Para automaticamente após 3s de silêncio
    );
  }

  Future<void> stop() async {
    if (_speech == null) return;
    await _speech!.stop();
  }
}
