import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum SpeechLanguage { english, turkish }

/// Singleton TTS service for pronouncing English words and sentences.
///
/// Uses the device's built-in TTS engine with a learner-friendly speech rate.
class TtsService {
  TtsService._();

  /// Shared singleton instance.
  static final TtsService instance = TtsService._();

  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;
  bool _available = true;
  double _speechRateMultiplier = 1.0;
  bool _stopOnInteraction = true;
  Map<String, String>? _englishVoice;

  double get speechRateMultiplier => _speechRateMultiplier;
  bool get stopOnInteraction => _stopOnInteraction;

  Future<void> _ensureInit() async {
    if (_initialized || !_available) {
      return;
    }
    try {
      await _tts.awaitSpeakCompletion(true);
      _englishVoice = await _resolvePreferredVoice(
        language: SpeechLanguage.english,
      );
      await _applyLanguage(SpeechLanguage.english);
      await _tts.setSpeechRate(_resolvedSpeechRate(_speechRateMultiplier));
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
      _initialized = true;
    } catch (_) {
      _available = false;
    }
  }

  Future<void> setSpeechRate(double multiplier) async {
    final double normalized = _normalizeMultiplier(multiplier);
    _speechRateMultiplier = normalized;
    await _ensureInit();
    if (!_available) {
      return;
    }
    try {
      await _tts.setSpeechRate(_resolvedSpeechRate(normalized));
    } catch (_) {
      _available = false;
    }
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
  Future<void> speak(
    String text, {
    SpeechLanguage language = SpeechLanguage.english,
  }) async {
    if (text.trim().isEmpty) {
      return;
    }
    await _ensureInit();
    if (!_available) {
      return;
    }
    try {
      await _tts.stop();
      await _applyLanguage(language);
      await _tts.speak(text);
    } catch (_) {
      _available = false;
    }
  }

  /// Stops any ongoing speech.
  Future<void> stop() async {
    if (!_available) {
      return;
    }
    try {
      await _tts.stop();
    } catch (_) {
      _available = false;
    }
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

  Future<void> _applyLanguage(SpeechLanguage language) async {
    if (kIsWeb && language == SpeechLanguage.english) {
      final Map<String, String>? voice =
          _englishVoice ??
          await _resolvePreferredVoice(language: SpeechLanguage.english);
      _englishVoice = voice ?? _englishVoice;
      if (voice != null) {
        await _tts.setVoice(voice);
        return;
      }
    }

    final String code = switch (language) {
      SpeechLanguage.english => 'en-US',
      SpeechLanguage.turkish => 'tr-TR',
    };
    await _tts.setLanguage(code);
  }

  Future<Map<String, String>?> _resolvePreferredVoice({
    required SpeechLanguage language,
  }) async {
    if (!kIsWeb) {
      return null;
    }

    try {
      final dynamic rawVoices = await _tts.getVoices;
      if (rawVoices is! List) {
        return null;
      }

      final List<Map<String, String>> voices = rawVoices
          .whereType<Map<dynamic, dynamic>>()
          .map(
            (Map<dynamic, dynamic> item) => item.map(
              (dynamic key, dynamic value) => MapEntry('$key', '$value'),
            ),
          )
          .toList(growable: false);

      return selectPreferredVoice(voices, language: language);
    } catch (_) {
      return null;
    }
  }

  @visibleForTesting
  static Map<String, String>? selectPreferredVoice(
    List<Map<String, String>> voices, {
    required SpeechLanguage language,
  }) {
    if (voices.isEmpty) {
      return null;
    }

    final List<String> preferredLocales = switch (language) {
      SpeechLanguage.english => <String>['en-US', 'en-GB', 'en'],
      SpeechLanguage.turkish => <String>['tr-TR', 'tr'],
    };

    for (final String locale in preferredLocales) {
      for (final Map<String, String> voice in voices) {
        final String rawLocale = (voice['locale'] ?? '').trim();
        if (rawLocale.isEmpty) {
          continue;
        }
        final String normalizedLocale = rawLocale.toLowerCase();
        final String desired = locale.toLowerCase();
        if (normalizedLocale == desired ||
            normalizedLocale.startsWith('$desired-') ||
            (desired.length == 2 && normalizedLocale.startsWith(desired))) {
          return voice;
        }
      }
    }

    return null;
  }
}
