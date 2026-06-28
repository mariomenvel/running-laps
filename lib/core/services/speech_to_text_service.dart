import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Encapsula speech_to_text para dictado por voz (generador de
/// entrenamientos por IA y ajuste de plan con el coach).
/// Singleton: solo puede haber una sesión de escucha activa a la vez
/// en toda la app, lo cual es coherente con el uso real (un solo
/// micrófono, un solo campo dictado en cada momento).
class SpeechToTextService {
  static SpeechToTextService? _instance;
  factory SpeechToTextService() => _instance ??= SpeechToTextService._internal();

  SpeechToTextService._internal();

  final SpeechToText _speech = SpeechToText();

  final ValueNotifier<bool> isAvailable = ValueNotifier(false);
  final ValueNotifier<bool> isListening = ValueNotifier(false);
  final ValueNotifier<String> recognizedText = ValueNotifier('');
  final ValueNotifier<String?> lastError = ValueNotifier(null);

  bool _initialized = false;

  /// Inicializa el motor de reconocimiento y solicita los permisos de
  /// micrófono/reconocimiento de voz la primera vez que se llama.
  Future<bool> initialize() async {
    if (_initialized) return isAvailable.value;
    final available = await _speech.initialize(
      onError: (error) {
        lastError.value = error.errorMsg;
        isListening.value = false;
      },
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          isListening.value = false;
        }
      },
    );
    _initialized = true;
    isAvailable.value = available;
    if (!available) {
      lastError.value = 'Reconocimiento de voz no disponible en este dispositivo';
    }
    return available;
  }

  Future<void> startListening() async {
    if (!isAvailable.value) return;
    recognizedText.value = '';
    lastError.value = null;
    isListening.value = true;
    // Web no expone Platform — fallback a español en ese caso.
    final localeId = kIsWeb
        ? 'es-ES'
        : Platform.localeName.replaceAll('_', '-');

    await _speech.listen(
      onResult: (result) {
        recognizedText.value = result.recognizedWords;
        if (result.finalResult) isListening.value = false;
      },
      listenOptions: SpeechListenOptions(
        cancelOnError: true,
        localeId: localeId,
      ),
    );
  }

  Future<void> stopListening() async {
    await _speech.stop();
    isListening.value = false;
  }

  /// Detiene la escucha si está activa. No libera los ValueNotifier:
  /// el servicio es un singleton que vive durante toda la app, así
  /// que sus listenables no se deben dispose() al cerrar una pantalla.
  void dispose() {
    if (isListening.value) _speech.stop();
  }
}
