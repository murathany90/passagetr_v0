import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/readings/reading_translation_seed.dart';

class StudentTranslationController extends StateNotifier<Map<String, String>> {
  StudentTranslationController() : super(const <String, String>{});

  String? cachedTranslation(String readingId, int sectionIndex) {
    return state[_cacheKey(readingId, sectionIndex)];
  }

  Future<String> loadTranslation({
    required String readingId,
    required int sectionIndex,
    required String sourceText,
  }) async {
    final key = _cacheKey(readingId, sectionIndex);
    final cached = state[key];
    if (cached != null) {
      return cached;
    }

    final translated =
        readingTranslationFor(readingId, sectionIndex) ??
        'Çeviri önbelleği henüz hazır değil. Kaynak metin: $sourceText';
    state = <String, String>{...state, key: translated};
    return translated;
  }

  static String _cacheKey(String readingId, int sectionIndex) =>
      '$readingId::$sectionIndex';
}
