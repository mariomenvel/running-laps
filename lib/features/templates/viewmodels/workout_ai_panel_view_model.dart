import 'package:flutter/foundation.dart';
import 'package:running_laps/core/services/speech_to_text_service.dart';

/// Estado del dictado por voz del panel "Crear con IA" en
/// WorkoutEditorScreen. Mantiene la View sin acceso directo a
/// SpeechToText — delega en SpeechToTextService.
class WorkoutAiPanelViewModel {
  final _speech = SpeechToTextService();

  ValueNotifier<bool> get speechAvailable => _speech.isAvailable;
  ValueNotifier<bool> get isListening => _speech.isListening;
  ValueNotifier<String> get recognizedText => _speech.recognizedText;
  ValueNotifier<String?> get speechError => _speech.lastError;

  Future<bool> initSpeech() => _speech.initialize();

  Future<void> toggleListening() {
    return isListening.value ? _speech.stopListening() : _speech.startListening();
  }

  void dispose() {
    _speech.dispose();
  }
}
