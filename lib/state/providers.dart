import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/auth/auth_session_service.dart';
import '../core/config/app_config.dart';
import '../core/services/translation_service.dart';
import '../data/repositories/supabase_pack_repository.dart';
import '../data/repositories/supabase_progress_repository.dart';
import '../data/repositories/supabase_reading_repository.dart';
import '../data/repositories/supabase_word_repository.dart';
import '../domain/entities/pack.dart';
import '../domain/entities/passage_sentence.dart';
import '../domain/entities/reading_passage.dart';
import '../domain/entities/sentence_translation.dart';
import '../domain/repositories/pack_repository.dart';
import '../domain/repositories/progress_repository.dart';
import '../domain/repositories/reading_repository.dart';
import '../domain/repositories/word_repository.dart';
import '../domain/value_objects/paged_result.dart';

final Provider<SupabaseClient> supabaseClientProvider =
    Provider<SupabaseClient>((Ref ref) {
  return Supabase.instance.client;
});

final Provider<AuthSessionService> authSessionServiceProvider =
    Provider<AuthSessionService>((Ref ref) {
  final SupabaseClient client = ref.watch(supabaseClientProvider);
  return AuthSessionService(client);
});

final FutureProvider<void> authBootstrapProvider = FutureProvider<void>((
  Ref ref,
) async {
  await ref.watch(authSessionServiceProvider).ensureAnonymousSession();
});

final Provider<PackRepository> packRepositoryProvider =
    Provider<PackRepository>((Ref ref) {
  final SupabaseClient client = ref.watch(supabaseClientProvider);
  return SupabasePackRepository(client);
});

final Provider<WordRepository> wordRepositoryProvider =
    Provider<WordRepository>((Ref ref) {
  final SupabaseClient client = ref.watch(supabaseClientProvider);
  return SupabaseWordRepository(client);
});

final Provider<ProgressRepository> progressRepositoryProvider =
    Provider<ProgressRepository>((Ref ref) {
  final SupabaseClient client = ref.watch(supabaseClientProvider);
  return SupabaseProgressRepository(client);
});

final Provider<ReadingRepository> readingRepositoryProvider =
    Provider<ReadingRepository>((Ref ref) {
  final SupabaseClient client = ref.watch(supabaseClientProvider);
  return SupabaseReadingRepository(client);
});

final Provider<TranslationService> translationServiceProvider =
    Provider<TranslationService>((Ref ref) {
  final TranslationProvider provider =
      TranslationProvider.fromRaw(AppConfig.translateProvider);

  switch (provider) {
    case TranslationProvider.libre:
      return LibreTranslateService(
        endpoint: AppConfig.translateEndpoint,
        apiKey: AppConfig.translateApiKey,
      );
    case TranslationProvider.google:
      return GoogleCloudTranslateService(
        endpoint: AppConfig.translateEndpoint,
        apiKey: AppConfig.translateApiKey,
      );
  }
});

final FutureProvider<List<Pack>> packListProvider = FutureProvider<List<Pack>>((
  Ref ref,
) async {
  final PackRepository repository = ref.watch(packRepositoryProvider);
  return repository.getPacksWithWordCount();
});

class ReadingListRequest {
  const ReadingListRequest({
    required this.packId,
    this.limit = 20,
    this.offset = 0,
  });

  final String packId;
  final int limit;
  final int offset;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is ReadingListRequest &&
            other.packId == packId &&
            other.limit == limit &&
            other.offset == offset);
  }

  @override
  int get hashCode => Object.hash(packId, limit, offset);
}

final readingListProvider =
    FutureProvider.family<PagedResult<ReadingPassage>, ReadingListRequest>(
  (Ref ref, ReadingListRequest request) async {
    final ReadingRepository repository = ref.watch(readingRepositoryProvider);
    return repository.getPassagesByPack(
      packId: request.packId,
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
