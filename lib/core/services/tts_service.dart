import 'package:flutter_tts/flutter_tts.dart';

/// Singleton TTS service for pronouncing English words and sentences.
///
/// Uses the device's built-in TTS engine with a learner-friendly speech rate.
class TtsService {
  TtsService._();

  /// Shared singleton instance.
  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;

  Future<void> _ensureInit() async {
    if (_initialized) {
      return;
    }
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45); // Learner-friendly pace
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _initialized = true;
  }

  /// Speaks the given [text] in English.
  /// Stops any ongoing speech before starting.
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) {
      return;
    }
    await _ensureInit();
    await _tts.stop();
    await _tts.speak(text);
  }

  /// Stops any ongoing speech.
  Future<void> stop() async {
    await _tts.stop();
  }
}
