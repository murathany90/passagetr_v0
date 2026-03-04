import 'dictionary_entry.dart';

class DictionaryLookupResult {
  const DictionaryLookupResult({
    required this.entries,
    required this.fallbackTranslatedText,
    required this.fromServerCache,
    required this.fromDeepL,
    this.error,
  });

  final List<DictionaryEntry> entries;
  final String? fallbackTranslatedText;
  final bool fromServerCache;
  final bool fromDeepL;
  final String? error;

  bool get hasLocalEntries => entries.isNotEmpty;

  bool get hasFallback => (fallbackTranslatedText ?? '').trim().isNotEmpty;

  bool get hasError => (error ?? '').trim().isNotEmpty;

  factory DictionaryLookupResult.empty() {
    return const DictionaryLookupResult(
      entries: <DictionaryEntry>[],
      fallbackTranslatedText: null,
      fromServerCache: false,
      fromDeepL: false,
      error: null,
    );
  }

  factory DictionaryLookupResult.local(List<DictionaryEntry> entries) {
    return DictionaryLookupResult(
      entries: entries,
      fallbackTranslatedText: null,
      fromServerCache: false,
      fromDeepL: false,
      error: null,
    );
  }

  factory DictionaryLookupResult.fallback({
    required String translatedText,
    required bool fromServerCache,
    required bool fromDeepL,
  }) {
    return DictionaryLookupResult(
      entries: const <DictionaryEntry>[],
      fallbackTranslatedText: translatedText,
      fromServerCache: fromServerCache,
      fromDeepL: fromDeepL,
      error: null,
    );
  }

  factory DictionaryLookupResult.error(String message) {
    return DictionaryLookupResult(
      entries: const <DictionaryEntry>[],
      fallbackTranslatedText: null,
      fromServerCache: false,
      fromDeepL: false,
      error: message,
    );
  }
}
