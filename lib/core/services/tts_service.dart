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
  double _speechRateMultiplier = 1.0;
  bool _stopOnInteraction = true;

  double get speechRateMultiplier => _speechRateMultiplier;
  bool get stopOnInteraction => _stopOnInteraction;

  Future<void> _ensureInit() async {
    if (_initialized) {
      return;
    }
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(_resolvedSpeechRate(_speechRateMultiplier));
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
    _initialized = true;
  }

  Future<void> setSpeechRate(double multiplier) async {
    final double normalized = _normalizeMultiplier(multiplier);
    _speechRateMultiplier = normalized;
    await _ensureInit();
    await _tts.setSpeechRate(_resolvedSpeechRate(normalized));
  }

  Future<void> setStopOnInteraction(bool value) async {
    _stopOnInteraction = value;
  }

  Future<void> stopIfInteractionEnabled() async {
    if (_stopOnInteraction) {
      await stop();
    }
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

  double _normalizeMultiplier(double value) {
    if (value <= 0.5) {
      return 0.5;
    }
    if (value <= 1.0) {
      return 1.0;
    }
    if (value <= 1.25) {
      return 1.25;
    }
    return 1.5;
  }

  double _resolvedSpeechRate(double multiplier) {
    if (multiplier <= 0.5) {
      return 0.30;
    }
    if (multiplier <= 1.0) {
      return 0.45;
    }
    if (multiplier <= 1.25) {
      return 0.56;
    }
    return 0.68;
  }
}
