import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_domain/shared_domain.dart';
import '../features/readings/reading_translation_seed.dart';

class StudentTranslationController extends StateNotifier<Map<String, String>> {
  StudentTranslationController({required this.readingRepository})
    : super(const <String, String>{});

  final ReadingRepository readingRepository;

  String? cachedTranslation(String readingId, int sectionIndex) {
    return state[_cacheKey(readingId, sectionIndex)];
  }

  Future<String> loadTranslation({
    required String readingId,
    required int sectionIndex,
  }) async {
    final key = _cacheKey(readingId, sectionIndex);
    final cached = state[key];
    if (cached != null) {
      return cached;
    }

    String? translated = await readingRepository.fetchSentenceTranslation(
      readingId,
      sectionIndex,
    );
    translated ??= readingTranslationFor(readingId, sectionIndex);
    translated ??= 'Cumle cevirisi bulunamadi.';

    state = <String, String>{...state, key: translated};
    return translated;
  }

  static String _cacheKey(String readingId, int sectionIndex) =>
      '$readingId::$sectionIndex';
}
