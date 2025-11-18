import 'package:speech_to_text/speech_to_text.dart';
import 'package:flutter/foundation.dart';

/// Serviço simples para encapsular inicialização e uso do speech_to_text.
/// Permite futura troca de engine (ex.: Web API nativa) sem alterar UI.
class SpeechService {
  SpeechToText? _speech;
  bool _available = false;

  bool get isAvailable => _available;
  bool get isListening => _speech?.isListening ?? false;

  Future<bool> init() async {
    if (_speech != null) return _available;
    _speech = SpeechToText();
    _available = await _speech!.initialize(
      onError: (e) => debugPrint('Speech error: $e'),
      onStatus: (s) => debugPrint('Speech status: $s'),
    );
    return _available;
  }

  Future<void> start({
    String localeId = 'pt_BR',
    required Function(String text, bool isFinal) onResult,
  }) async {
    if (_speech == null) await init();
    if (!_available) return;
    await _speech!.listen(
      localeId: localeId,
      onResult: (result) {
        onResult(result.recognizedWords, result.finalResult);
      },
      partialResults: true,
      listenMode: ListenMode.dictation,
    );
  }

  Future<void> stop() async {
    if (_speech == null) return;
    await _speech!.stop();
  }
}
