import '../../core/services/translation_service.dart';
import '../../core/utils/dictionary_text_normalizer.dart';
import '../../domain/entities/dictionary_bootstrap_state.dart';
import '../../domain/entities/dictionary_entry.dart';
import '../../domain/entities/dictionary_lookup_result.dart';
import '../../domain/repositories/dictionary_repository.dart';
import '../local/dictionary_local_datasource.dart';
import '../remote/dictionary_supabase_datasource.dart';

class OfflineDictionaryRepository implements DictionaryRepository {
  OfflineDictionaryRepository({
    required DictionaryLocalDataSource localDataSource,
    required DictionarySupabaseDataSource remoteDataSource,
    required TranslationService translationService,
  })  : _local = localDataSource,
        _remote = remoteDataSource,
        _translationService = translationService;

  final DictionaryLocalDataSource _local;
  final DictionarySupabaseDataSource _remote;
  final TranslationService _translationService;

  static const int _remoteChunkSize = 2000;
  static const int _localWriteChunkSize = 500;

  @override
  Future<DictionaryBootstrapState> ensureBootstrapped({
    bool forceRefresh = false,
  }) async {
    DictionaryBootstrapState localState = await _local.getBootstrapState();
    final bool hasLocal = await _local.hasLocalDictionaryData();

    // Prebuilt asset yuku varsa startup'ta ag baglantisini beklemeyiz.
    if (!forceRefresh && hasLocal && localState.isReady) {
      return localState;
    }

    try {
      final DictionaryRemoteManifest manifest = await _remote.fetchManifest();
      final bool hasManifest = manifest.datasetVersion.trim().isNotEmpty;

      if (!hasManifest) {
        if (hasLocal && localState.isReady) {
          return localState;
        }
        return localState;
      }

      final bool sameVersion =
          manifest.datasetVersion.trim() == localState.datasetVersion.trim();

      if (!forceRefresh && sameVersion && localState.isReady) {
        return localState;
      }

      int afterSeqId = localState.lastSeqId;
      int downloaded = localState.downloadedCount;

      if (forceRefresh || !sameVersion) {
        await _local.resetDictionaryForVersion(
          datasetVersion: manifest.datasetVersion,
          batchId: manifest.batchId,
          rowCount: manifest.rowCount,
        );
        afterSeqId = 0;
        downloaded = 0;
      } else {
        await _local.markBootstrapInProgress(
          datasetVersion: manifest.datasetVersion,
          batchId: manifest.batchId,
          rowCount: manifest.rowCount,
          downloadedCount: downloaded,
          lastSeqId: afterSeqId,
        );
      }

      while (true) {
        final List<DictionaryEntry> rows = await _remote.fetchEntriesPage(
          afterSeqId: afterSeqId,
          limit: _remoteChunkSize,
        );

        if (rows.isEmpty) {
          break;
        }

        for (int i = 0; i < rows.length; i += _localWriteChunkSize) {
          final int end = (i + _localWriteChunkSize) > rows.length
              ? rows.length
              : (i + _localWriteChunkSize);
          await _local.upsertEntries(rows.sublist(i, end));
        }

        afterSeqId = rows.last.seqId;
        downloaded += rows.length;

        await _local.updateBootstrapProgress(
          downloadedCount: downloaded,
          lastSeqId: afterSeqId,
        );
      }

      await _local.markBootstrapReady(
        downloadedCount: downloaded,
        lastSeqId: afterSeqId,
      );

      return _local.getBootstrapState();
    } catch (error) {
      localState = await _local.getBootstrapState();
      if (hasLocal && localState.isReady) {
        return localState;
      }

      await _local.markBootstrapFailed(error.toString());
      rethrow;
    }
  }

  @override
  Future<DictionaryBootstrapState> getBootstrapState() {
    return _local.getBootstrapState();
  }

  @override
  Future<List<DictionaryEntry>> searchLocal({
    required String query,
    int limit = 30,
  }) {
    return _local.searchEntries(query: query, limit: limit);
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

    final List<DictionaryEntry> localEntries = await _local.searchEntries(
      query: normalizedQuery,
      limit: 30,
    );
    if (localEntries.isNotEmpty) {
      return DictionaryLookupResult.local(localEntries);
    }

    final String cleanSourceLang = sourceLang.trim().toLowerCase();
    final String cleanTargetLang = targetLang.trim().toLowerCase();

    LocalFallbackCacheEntry? localFallback;

    try {
      final DictionaryRemoteFallbackCacheEntry? remoteFallback =
          await _remote.getFallbackCache(
        queryNormalized: normalizedQuery,
        sourceLang: cleanSourceLang,
        targetLang: cleanTargetLang,
      );

      if (remoteFallback != null && remoteFallback.translatedText.isNotEmpty) {
        await _local.upsertFallbackCache(
          queryText: query,
          queryNormalized: normalizedQuery,
          sourceLang: cleanSourceLang,
          targetLang: cleanTargetLang,
          provider: remoteFallback.provider,
          translatedText: remoteFallback.translatedText,
          fromServerCache: true,
        );

        return DictionaryLookupResult.fallback(
          translatedText: remoteFallback.translatedText,
          fromServerCache: true,
          fromDeepL: false,
        );
      }

      localFallback = await _local.getFallbackCache(
        queryNormalized: normalizedQuery,
        sourceLang: cleanSourceLang,
        targetLang: cleanTargetLang,
      );

      if (!_translationService.isConfigured) {
        if (localFallback != null && localFallback.translatedText.isNotEmpty) {
          return DictionaryLookupResult.fallback(
            translatedText: localFallback.translatedText,
            fromServerCache: false,
            fromDeepL: false,
          );
        }
        return DictionaryLookupResult.error('Ceviri su an alinamadi.');
      }

      final String translated = await _translationService.translate(
        text: query,
        sourceLang: cleanSourceLang,
        targetLang: cleanTargetLang,
      );

      await _local.upsertFallbackCache(
        queryText: query,
        queryNormalized: normalizedQuery,
        sourceLang: cleanSourceLang,
        targetLang: cleanTargetLang,
        provider: 'deepl_edge_function',
        translatedText: translated,
        fromServerCache: false,
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
        // Server cache yazma hatasi local sonucu etkilemez.
      }

      return DictionaryLookupResult.fallback(
        translatedText: translated,
        fromServerCache: false,
        fromDeepL: true,
      );
    } on TranslationException catch (error) {
      if (localFallback != null && localFallback.translatedText.isNotEmpty) {
        return DictionaryLookupResult.fallback(
          translatedText: localFallback.translatedText,
          fromServerCache: false,
          fromDeepL: false,
        );
      }
      return DictionaryLookupResult.error(error.message);
    } catch (error) {
      if (localFallback != null && localFallback.translatedText.isNotEmpty) {
        return DictionaryLookupResult.fallback(
          translatedText: localFallback.translatedText,
          fromServerCache: false,
          fromDeepL: false,
        );
      }
      return DictionaryLookupResult.error('Sozluk sorgusu basarisiz: $error');
    } finally {
      try {
        await _remote.bumpMissingQuery(
          queryText: query,
          queryNormalized: normalizedQuery,
          sourceLang: cleanSourceLang,
          targetLang: cleanTargetLang,
        );
      } catch (_) {
        // Telemetry yazimi best-effort.
      }
    }
  }
}
