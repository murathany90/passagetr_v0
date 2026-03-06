import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/services/tts_service.dart';

/// Provides the singleton [TtsService] instance.
final Provider<TtsService> ttsServiceProvider = Provider<TtsService>(
  (Ref ref) => TtsService.instance,
);

enum WordInfoFrequency {
  off('Kapali'),
  low('Dusuk'),
  medium('Orta'),
  high('Yuksek');

  const WordInfoFrequency(this.label);
  final String label;
}

class ReadingAudioPreferences {
  const ReadingAudioPreferences({
    required this.speechRate,
    required this.wordInfoFrequency,
    required this.stopOnInteraction,
  });

  const ReadingAudioPreferences.defaults()
      : speechRate = 1.0,
        wordInfoFrequency = WordInfoFrequency.medium,
        stopOnInteraction = true;

  final double speechRate;
  final WordInfoFrequency wordInfoFrequency;
  final bool stopOnInteraction;

  ReadingAudioPreferences copyWith({
    double? speechRate,
    WordInfoFrequency? wordInfoFrequency,
    bool? stopOnInteraction,
  }) {
    return ReadingAudioPreferences(
      speechRate: speechRate ?? this.speechRate,
      wordInfoFrequency: wordInfoFrequency ?? this.wordInfoFrequency,
      stopOnInteraction: stopOnInteraction ?? this.stopOnInteraction,
    );
  }
}

class ReadingAudioPreferencesNotifier
    extends StateNotifier<ReadingAudioPreferences> {
  ReadingAudioPreferencesNotifier(this._ttsService)
      : super(const ReadingAudioPreferences.defaults()) {
    unawaited(_load());
  }

  static const String _prefRateKey = 'reading_audio_rate_v1';
  static const String _prefFrequencyKey = 'reading_word_info_freq_v1';
  static const String _prefStopOnTapKey = 'reading_stop_on_tap_v1';

  final TtsService _ttsService;

  Future<void> _load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final double savedRate = prefs.getDouble(_prefRateKey) ?? 1.0;
    final String savedFrequency =
        prefs.getString(_prefFrequencyKey) ?? 'medium';
    final bool savedStopOnTap = prefs.getBool(_prefStopOnTapKey) ?? true;

    final WordInfoFrequency frequency = WordInfoFrequency.values.firstWhere(
      (WordInfoFrequency value) => value.name == savedFrequency,
      orElse: () => WordInfoFrequency.medium,
    );

    state = ReadingAudioPreferences(
      speechRate: _sanitizeRate(savedRate),
      wordInfoFrequency: frequency,
      stopOnInteraction: savedStopOnTap,
    );

    await _ttsService.setSpeechRate(state.speechRate);
    await _ttsService.setStopOnInteraction(state.stopOnInteraction);
  }

  Future<void> setSpeechRate(double rate) async {
    final double next = _sanitizeRate(rate);
    if (next == state.speechRate) {
      return;
    }
    state = state.copyWith(speechRate: next);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_prefRateKey, next);
    await _ttsService.setSpeechRate(next);
  }

  Future<void> setWordInfoFrequency(WordInfoFrequency frequency) async {
    if (frequency == state.wordInfoFrequency) {
      return;
    }
    state = state.copyWith(wordInfoFrequency: frequency);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefFrequencyKey, frequency.name);
  }

  Future<void> setStopOnInteraction(bool value) async {
    if (value == state.stopOnInteraction) {
      return;
    }
    state = state.copyWith(stopOnInteraction: value);
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefStopOnTapKey, value);
    await _ttsService.setStopOnInteraction(value);
  }

  double _sanitizeRate(double value) {
    const List<double> allowed = <double>[0.5, 1.0, 1.25, 1.5];
    double selected = allowed.first;
    double delta = (selected - value).abs();
    for (final double candidate in allowed.skip(1)) {
      final double currentDelta = (candidate - value).abs();
      if (currentDelta < delta) {
        selected = candidate;
        delta = currentDelta;
      }
    }
    return selected;
  }
}

final StateNotifierProvider<ReadingAudioPreferencesNotifier,
        ReadingAudioPreferences> readingAudioPreferencesProvider =
    StateNotifierProvider<ReadingAudioPreferencesNotifier,
        ReadingAudioPreferences>(
  (Ref ref) => ReadingAudioPreferencesNotifier(
    ref.watch(ttsServiceProvider),
  ),
);
