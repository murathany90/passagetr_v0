import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/dictionary_bootstrap_state.dart';
import '../../../domain/entities/dictionary_entry.dart';
import '../../../domain/entities/dictionary_lookup_result.dart';
import '../../../domain/repositories/dictionary_repository.dart';
import '../../../state/providers.dart';

final dictionarySearchQueryProvider =
    StateProvider.autoDispose<String>((Ref ref) => '');

final dictionaryBootstrapProvider =
    FutureProvider<DictionaryBootstrapState>((Ref ref) async {
  final DictionaryRepository repository =
      ref.watch(dictionaryRepositoryProvider);
  return repository.ensureBootstrapped();
});

final dictionaryLocalSearchProvider =
    FutureProvider.autoDispose.family<List<DictionaryEntry>, String>(
  (Ref ref, String query) async {
    final DictionaryRepository repository =
        ref.watch(dictionaryRepositoryProvider);
    return repository.searchLocal(query: query, limit: 30);
  },
);

final dictionaryLookupProvider =
    FutureProvider.autoDispose.family<DictionaryLookupResult, String>(
  (Ref ref, String query) async {
    final DictionaryRepository repository =
        ref.watch(dictionaryRepositoryProvider);
    return repository.lookup(query: query);
  },
);
