import '../entities/dictionary_bootstrap_state.dart';
import '../entities/dictionary_entry.dart';
import '../entities/dictionary_lookup_result.dart';

abstract class DictionaryRepository {
  Future<DictionaryBootstrapState> ensureBootstrapped({
    bool forceRefresh = false,
  });

  Future<DictionaryBootstrapState> getBootstrapState();

  Future<List<DictionaryEntry>> searchLocal({
    required String query,
    int limit = 30,
  });

  Future<DictionaryLookupResult> lookup({
    required String query,
    String sourceLang = 'en',
    String targetLang = 'tr',
  });
}
