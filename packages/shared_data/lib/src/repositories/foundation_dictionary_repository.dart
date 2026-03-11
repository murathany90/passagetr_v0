import 'package:shared_core/shared_core.dart';
import 'package:shared_domain/shared_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../bootstrap/supabase_bootstrap.dart';
import '../dictionary/dictionary_asset_store.dart';
import '../dictionary/dictionary_local_lookup.dart';

typedef DictionaryLocalPathProvider = Future<String?> Function();
typedef DictionaryLocalLookup =
    Future<DictionaryEntry?> Function({
      required String databasePath,
      required String normalizedQuery,
    });
typedef DictionaryRemoteLookup =
    Future<DictionaryEntry?> Function(String normalizedQuery);

class FoundationDictionaryRepository implements DictionaryRepository {
  FoundationDictionaryRepository({
    required AppConfig config,
    DictionaryLocalPathProvider? localPathProvider,
    DictionaryLocalLookup? localLookupOverride,
    DictionaryRemoteLookup? remoteLookupOverride,
  }) : _config = config,
       _localPathProvider = localPathProvider ?? resolveDictionaryDatabasePath,
       _localLookupOverride = localLookupOverride,
       _remoteLookupOverride = remoteLookupOverride;

  FoundationDictionaryRepository.preview({
    DictionaryLocalPathProvider? localPathProvider,
    DictionaryLocalLookup? localLookupOverride,
    DictionaryRemoteLookup? remoteLookupOverride,
  }) : _config = null,
       _localPathProvider = localPathProvider,
       _localLookupOverride = localLookupOverride,
       _remoteLookupOverride = remoteLookupOverride;

  final AppConfig? _config;
  final DictionaryLocalPathProvider? _localPathProvider;
  final DictionaryLocalLookup? _localLookupOverride;
  final DictionaryRemoteLookup? _remoteLookupOverride;

  static final RegExp _edgePunctuationPattern = RegExp(
    r'^[^A-Za-z0-9]+|[^A-Za-z0-9]+$',
  );

  @override
  Future<DictionaryEntry?> lookupWord(String query) async {
    final normalizedQuery = _normalizeQuery(query);
    if (normalizedQuery.isEmpty) {
      return null;
    }

    final localEntry = await _lookupLocal(normalizedQuery);
    if (localEntry != null) {
      return localEntry;
    }

    return _lookupRemote(normalizedQuery);
  }

  Future<DictionaryEntry?> _lookupLocal(String normalizedQuery) async {
    final localPathProvider = _localPathProvider;
    if (localPathProvider == null) {
      return null;
    }

    try {
      final databasePath = await localPathProvider();
      if (databasePath == null || databasePath.isEmpty) {
        return null;
      }

      final localLookup = _localLookupOverride ?? lookupLocalDictionaryEntry;
      return await localLookup(
        databasePath: databasePath,
        normalizedQuery: normalizedQuery,
      );
    } catch (_) {
      return null;
    }
  }

  Future<DictionaryEntry?> _lookupRemote(String normalizedQuery) async {
    final remoteLookupOverride = _remoteLookupOverride;
    if (remoteLookupOverride != null) {
      return remoteLookupOverride(normalizedQuery);
    }

    final config = _config;
    if (config == null || !config.supabaseEnabled) {
      return null;
    }

    try {
      await SupabaseBootstrap.initialize(config);
      final rows =
          (await Supabase.instance.client
                  .from('dictionary_entries')
                  .select('en_word,tr_meaning,pos')
                  .eq('en_word_normalized', normalizedQuery)
                  .eq('is_active', true)
                  .limit(1))
              as List<dynamic>;
      if (rows.isEmpty) {
        return null;
      }

      final row = rows.first;
      if (row is! Map<String, dynamic>) {
        return null;
      }

      return _mapRow(
        enWord: row['en_word']?.toString(),
        trMeaning: row['tr_meaning']?.toString(),
        pos: row['pos']?.toString(),
      );
    } catch (_) {
      return null;
    }
  }

  DictionaryEntry? _mapRow({
    required String? enWord,
    required String? trMeaning,
    required String? pos,
  }) {
    final resolvedWord = enWord?.trim() ?? '';
    final resolvedMeaning = trMeaning?.trim() ?? '';
    if (resolvedWord.isEmpty || resolvedMeaning.isEmpty) {
      return null;
    }

    final resolvedPos = pos?.trim();
    return DictionaryEntry(
      enWord: resolvedWord,
      trMeaning: resolvedMeaning,
      pos: resolvedPos == null || resolvedPos.isEmpty ? null : resolvedPos,
    );
  }

  String _normalizeQuery(String query) {
    return query
        .trim()
        .toLowerCase()
        .replaceAll('’', "'")
        .replaceAll(_edgePunctuationPattern, '');
  }
}
