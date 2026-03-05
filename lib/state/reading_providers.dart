import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/app_config.dart';
import '../data/local/app_content_local_datasource.dart';
import '../data/repositories/hybrid_reading_repository.dart';
import '../data/repositories/supabase_reading_repository.dart';
import '../domain/entities/passage_sentence.dart';
import '../domain/entities/reading_passage.dart';
import '../domain/entities/sentence_translation.dart';
import '../domain/entities/user_reading_progress.dart';
import '../domain/entities/word_item.dart';
import '../domain/repositories/reading_repository.dart';
import '../domain/value_objects/paged_result.dart';
import 'auth_providers.dart';
import 'content_providers.dart';

final Provider<ReadingRepository> readingRepositoryProvider =
    Provider<ReadingRepository>((Ref ref) {
  final SupabaseClient client = ref.watch(supabaseClientProvider);
  if (AppConfig.useLocalStaticContent) {
    final AppContentLocalDataSource local = ref.watch(
      appContentLocalDataSourceProvider,
    );
    return HybridReadingRepository(
      localDataSource: local,
      remoteDataSource: SupabaseReadingRepository(client),
    );
  }
  return SupabaseReadingRepository(client);
});

class ReadingListRequest {
  const ReadingListRequest({
    required this.packId,
    this.selectedLevels = const <String>{},
    this.limit = 20,
    this.offset = 0,
  });

  final String packId;
  final Set<String> selectedLevels;
  final int limit;
  final int offset;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is ReadingListRequest &&
            other.packId == packId &&
            _setEquals(other.selectedLevels, selectedLevels) &&
            other.limit == limit &&
            other.offset == offset);
  }

  @override
  int get hashCode => Object.hash(
        packId,
        Object.hashAll(selectedLevels.toList()..sort()),
        limit,
        offset,
      );
}

bool _setEquals(Set<String> a, Set<String> b) {
  if (identical(a, b)) {
    return true;
  }
  if (a.length != b.length) {
    return false;
  }
  for (final String item in a) {
    if (!b.contains(item)) {
      return false;
    }
  }
  return true;
}

final readingListProvider =
    FutureProvider.family<PagedResult<ReadingPassage>, ReadingListRequest>(
  (Ref ref, ReadingListRequest request) async {
    final ReadingRepository repository = ref.watch(readingRepositoryProvider);
    return repository.getPassagesByPack(
      packId: request.packId,
      levels: request.selectedLevels,
      limit: request.limit,
      offset: request.offset,
    );
  },
);

final readingDetailProvider =
    FutureProvider.family<List<PassageSentence>, String>(
  (Ref ref, String passageId) async {
    final ReadingRepository repository = ref.watch(readingRepositoryProvider);
    return repository.getSentences(passageId: passageId);
  },
);

class SentenceTranslationLookup {
  const SentenceTranslationLookup({
    required this.sentenceId,
    required this.provider,
    this.targetLang = 'tr',
  });

  final String sentenceId;
  final String provider;
  final String targetLang;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is SentenceTranslationLookup &&
            other.sentenceId == sentenceId &&
            other.provider == provider &&
            other.targetLang == targetLang);
  }

  @override
  int get hashCode => Object.hash(sentenceId, provider, targetLang);
}

final sentenceTranslationControllerProvider =
    FutureProvider.family<SentenceTranslation?, SentenceTranslationLookup>(
  (Ref ref, SentenceTranslationLookup lookup) async {
    final ReadingRepository repository = ref.watch(readingRepositoryProvider);
    return repository.getCachedTranslation(
      sentenceId: lookup.sentenceId,
      provider: lookup.provider,
      targetLang: lookup.targetLang,
    );
  },
);

final readingProgressProvider =
    FutureProvider.family<UserReadingProgress?, String>(
  (Ref ref, String passageId) async {
    final ReadingRepository repository = ref.watch(readingRepositoryProvider);
    return repository.getUserReadingProgress(passageId: passageId);
  },
);

final passageWordsProvider = FutureProvider.family<List<WordItem>, String>(
  (Ref ref, String passageId) async {
    final ReadingRepository repository = ref.watch(readingRepositoryProvider);
    return repository.getPassageWords(passageId: passageId, limit: 400);
  },
);
