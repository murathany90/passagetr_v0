import '../../core/services/translation_service.dart';
import '../../core/utils/dictionary_text_normalizer.dart';
import '../../domain/entities/dictionary_bootstrap_state.dart';
import '../../domain/entities/dictionary_entry.dart';
import '../../domain/entities/dictionary_lookup_result.dart';
import '../../domain/repositories/dictionary_repository.dart';
import '../remote/dictionary_supabase_datasource.dart';

class WebRemoteDictionaryRepository implements DictionaryRepository {
  WebRemoteDictionaryRepository({
    required DictionarySupabaseDataSource remoteDataSource,
    required TranslationService translationService,
  })  : _remote = remoteDataSource,
        _translationService = translationService;

  final DictionarySupabaseDataSource _remote;
  final TranslationService _translationService;

  @override
  Future<DictionaryBootstrapState> ensureBootstrapped({
    bool forceRefresh = false,
  }) {
    return getBootstrapState();
  }

  @override
  Future<DictionaryBootstrapState> getBootstrapState() async {
    return DictionaryBootstrapState.initial().copyWith(
      status: DictionaryBootstrapStatus.ready,
      datasetVersion: 'remote-web',
    );
  }

  @override
  Future<List<DictionaryEntry>> searchLocal({
    required String query,
    int limit = 30,
  }) {
    return _remote.searchEntries(query: query, limit: limit);
  }

  @override
  Future<DictionaryLookupResult> lookup({
    required String query,
    String sourceLang = 'en',
    String targetLang = 'tr',
  }) async {
    final String normalizedQuery = normalizeDictionaryQuery(query);
    if (normalizedQuery.isEmpty) {
      return DictionaryLookupResult.empty();
    }

    try {
      final List<DictionaryEntry> remoteEntries = await _remote.searchEntries(
        query: normalizedQuery,
        limit: 30,
      );
      if (remoteEntries.isNotEmpty) {
        return DictionaryLookupResult.local(remoteEntries);
      }

      final String cleanSourceLang = sourceLang.trim().toLowerCase();
      final String cleanTargetLang = targetLang.trim().toLowerCase();

      final DictionaryRemoteFallbackCacheEntry? remoteFallback =
          await _remote.getFallbackCache(
        queryNormalized: normalizedQuery,
        sourceLang: cleanSourceLang,
        targetLang: cleanTargetLang,
      );

      if (remoteFallback != null && remoteFallback.translatedText.isNotEmpty) {
        return DictionaryLookupResult.fallback(
          translatedText: remoteFallback.translatedText,
          fromServerCache: true,
          fromDeepL: false,
        );
      }

      if (!_translationService.isConfigured) {
        return DictionaryLookupResult.error('Ceviri su an alinamadi.');
      }

      final String translated = await _translationService.translate(
        text: query,
        sourceLang: cleanSourceLang,
        targetLang: cleanTargetLang,
      );

      try {
        await _remote.upsertFallbackCache(
          queryText: query,
          queryNormalized: normalizedQuery,
          sourceLang: cleanSourceLang,
          targetLang: cleanTargetLang,
          provider: 'deepl_edge_function',
          translatedText: translated,
        );
      } catch (_) {
        // Remote cache best-effort.
      }

      return DictionaryLookupResult.fallback(
        translatedText: translated,
        fromServerCache: false,
        fromDeepL: true,
      );
    } on TranslationException catch (error) {
      return DictionaryLookupResult.error(error.message);
    } catch (error) {
      return DictionaryLookupResult.error('Sozluk sorgusu basarisiz: $error');
    } finally {
      try {
        await _remote.bumpMissingQuery(
          queryText: query,
          queryNormalized: normalizedQuery,
          sourceLang: sourceLang.trim().toLowerCase(),
          targetLang: targetLang.trim().toLowerCase(),
        );
      } catch (_) {
        // Telemetry best-effort.
      }
    }
  }
}
