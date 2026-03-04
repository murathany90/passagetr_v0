import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../domain/entities/dictionary_lookup_result.dart';
import '../../../domain/repositories/dictionary_repository.dart';
import '../../../state/providers.dart';

class DictionaryLookupController
    extends StateNotifier<AsyncValue<DictionaryLookupResult>> {
  DictionaryLookupController(this._ref)
      : super(AsyncValue<DictionaryLookupResult>.data(
          DictionaryLookupResult.empty(),
        ));

  final Ref _ref;

  Future<void> lookup(String query) async {
    final String trimmed = query.trim();
    if (trimmed.isEmpty) {
      state = AsyncValue<DictionaryLookupResult>.data(
        DictionaryLookupResult.empty(),
      );
      return;
    }

    state = const AsyncValue.loading();

    try {
      final DictionaryRepository repository =
          _ref.read(dictionaryRepositoryProvider);
      final DictionaryLookupResult result =
          await repository.lookup(query: trimmed);
      state = AsyncValue<DictionaryLookupResult>.data(result);
    } catch (error, stackTrace) {
      state = AsyncValue<DictionaryLookupResult>.error(error, stackTrace);
    }
  }
}

final dictionaryLookupControllerProvider = StateNotifierProvider.autoDispose<
    DictionaryLookupController, AsyncValue<DictionaryLookupResult>>((Ref ref) {
  return DictionaryLookupController(ref);
});
