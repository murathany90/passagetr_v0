import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passagetr/domain/entities/pack.dart';
import 'package:passagetr/domain/entities/passage_sentence.dart';
import 'package:passagetr/domain/entities/reading_passage.dart';
import 'package:passagetr/domain/entities/reading_resume_item.dart';
import 'package:passagetr/domain/entities/sentence_translation.dart';
import 'package:passagetr/domain/entities/user_reading_progress.dart';
import 'package:passagetr/domain/entities/word_item.dart';
import 'package:passagetr/domain/repositories/reading_repository.dart';
import 'package:passagetr/domain/value_objects/paged_result.dart';
import 'package:passagetr/features/readings/reading_home_page.dart';
import 'package:passagetr/state/pack_providers.dart';
import 'package:passagetr/state/reading_providers.dart';

void main() {
  const Pack pack = Pack(
    id: 'pack-1',
    name: 'YDS Set 001',
    fromLang: 'en',
    toLang: 'tr',
    wordCount: 100,
  );

  const ReadingPassage shortTitlePassage = ReadingPassage(
    id: 'passage-short',
    packId: 'pack-1',
    packName: 'YDS Set 001',
    title: 'Short title',
    level: 'A2',
    tagsRaw: 'daily',
    category: 'general',
  );

  const ReadingPassage longTitlePassage = ReadingPassage(
    id: 'passage-long',
    packId: 'pack-1',
    packName: 'YDS Set 001',
    title: 'This is a much longer reading title that should still stretch fully',
    level: 'B2',
    tagsRaw: 'science',
    category: 'science',
  );

  testWidgets('renders feed cards at equal full width with visible badges', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: <Override>[
          packListProvider.overrideWith((Ref ref) async => const <Pack>[pack]),
          readingRepositoryProvider.overrideWith(
            (Ref ref) => _FakeReadingRepository(
              feedItems: const <ReadingPassage>[
                shortTitlePassage,
                longTitlePassage,
              ],
            ),
          ),
        ],
        child: const MaterialApp(
          home: Scaffold(body: ReadingHomePage()),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final Finder shortCard = find.byKey(
      const ValueKey<String>('reading-feed-card-passage-short'),
    );
    final Finder longCard = find.byKey(
      const ValueKey<String>('reading-feed-card-passage-long'),
    );

    expect(shortCard, findsOneWidget);
    expect(longCard, findsOneWidget);

    final Rect shortRect = tester.getRect(shortCard);
    final Rect longRect = tester.getRect(longCard);
    expect(shortRect.width, equals(longRect.width));
    expect(shortRect.width, greaterThan(900));

    expect(find.text('A2'), findsOneWidget);
    expect(find.text('B2'), findsOneWidget);
    expect(find.text('general'), findsOneWidget);
    expect(find.text('science'), findsOneWidget);
  });
}

class _FakeReadingRepository implements ReadingRepository {
  _FakeReadingRepository({
    required this.feedItems,
  });

  final List<ReadingPassage> feedItems;

  @override
  Future<PagedResult<ReadingPassage>> getPassagesByPack({
    required String packId,
    Set<String>? levels,
    int limit = 20,
    int offset = 0,
  }) async {
    return const PagedResult<ReadingPassage>(
      items: <ReadingPassage>[],
      hasMore: false,
      nextOffset: 0,
    );
  }

  @override
  Future<PagedResult<ReadingPassage>> getReadingFeed({
    String? category,
    String? level,
    int limit = 20,
    int offset = 0,
  }) async {
    return PagedResult<ReadingPassage>(
      items: feedItems,
      hasMore: false,
      nextOffset: 0,
    );
  }

  @override
  Future<List<PassageSentence>> getSentences({
    required String passageId,
  }) async {
    return const <PassageSentence>[];
  }

  @override
  Future<SentenceTranslation?> getCachedTranslation({
    required String sentenceId,
    required String provider,
    String targetLang = 'tr',
  }) async {
    return null;
  }

  @override
  Future<void> saveTranslation({
    required String sentenceId,
    required String provider,
    String targetLang = 'tr',
    required String translatedText,
  }) async {}

  @override
  Future<UserReadingProgress?> getUserReadingProgress({
    required String passageId,
  }) async {
    return null;
  }

  @override
  Future<void> upsertUserReadingProgress({
    required String passageId,
    required int lastIdx,
    required bool completed,
  }) async {}

  @override
  Future<Map<String, UserReadingProgress>> getProgressMapForPassages(
    List<String> passageIds,
  ) async {
    return const <String, UserReadingProgress>{};
  }

  @override
  Future<int> getTodayReadSentenceCount() async => 0;

  @override
  Future<ReadingResumeItem?> getLatestIncompleteReading() async => null;

  @override
  Future<List<WordItem>> getPassageWords({
    required String passageId,
    int limit = 20,
  }) async {
    return const <WordItem>[];
  }

  @override
  Future<void> toggleBookmark(String passageId) async {}

  @override
  Future<void> toggleFavorite(String passageId) async {}

  @override
  Future<PagedResult<ReadingPassage>> getBookmarkedPassages({
    int limit = 20,
    int offset = 0,
  }) async {
    return const PagedResult<ReadingPassage>(
      items: <ReadingPassage>[],
      hasMore: false,
      nextOffset: 0,
    );
  }

  @override
  Future<PagedResult<ReadingPassage>> getFavoritePassages({
    int limit = 20,
    int offset = 0,
  }) async {
    return const PagedResult<ReadingPassage>(
      items: <ReadingPassage>[],
      hasMore: false,
      nextOffset: 0,
    );
  }

  @override
  Future<bool> isPassageBookmarked(String passageId) async => false;

  @override
  Future<bool> isPassageFavorited(String passageId) async => false;
}
