import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:passagetr/core/services/offline_sync_controller.dart';
import 'package:passagetr/data/local/offline_sync_queue_store.dart';
import 'package:passagetr/domain/entities/pack.dart';
import 'package:passagetr/domain/entities/passage_sentence.dart';
import 'package:passagetr/domain/entities/reading_passage.dart';
import 'package:passagetr/domain/entities/reading_resume_item.dart';
import 'package:passagetr/domain/entities/sentence_translation.dart';
import 'package:passagetr/domain/entities/user_reading_progress.dart';
import 'package:passagetr/domain/entities/user_word_progress.dart';
import 'package:passagetr/domain/entities/word_item.dart';
import 'package:passagetr/domain/repositories/progress_repository.dart';
import 'package:passagetr/domain/repositories/reading_repository.dart';
import 'package:passagetr/domain/value_objects/flashcard_answer.dart';
import 'package:passagetr/domain/value_objects/paged_result.dart';
import 'package:passagetr/features/readings/reading_detail_page.dart';
import 'package:passagetr/state/content_providers.dart';
import 'package:passagetr/state/offline_sync_providers.dart';
import 'package:passagetr/state/reading_providers.dart';
import 'package:passagetr/state/translation_providers.dart';
import 'package:passagetr/state/word_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/fake_repositories.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  const Pack pack = Pack(
    id: 'pack-1',
    name: 'YDS Set 001',
    fromLang: 'en',
    toLang: 'tr',
    wordCount: 100,
  );

  const ReadingPassage passage = ReadingPassage(
    id: 'passage-1',
    packId: 'pack-1',
    packName: 'YDS Set 001',
    title: 'Reading 001',
    level: 'B1',
    tagsRaw: 'daily',
    category: 'general',
  );

  const PassageSentence firstSentence = PassageSentence(
    id: 's1',
    passageId: 'passage-1',
    passageTitle: 'Reading 001',
    idx: 1,
    sentenceEn: 'The clean place is calm.',
    sentenceTr: null,
  );

  const PassageSentence thirdSentence = PassageSentence(
    id: 's3',
    passageId: 'passage-1',
    passageTitle: 'Reading 001',
    idx: 3,
    sentenceEn: 'The final note is brief.',
    sentenceTr: null,
  );

  const WordItem knownWord = WordItem(
    id: 'w-clean',
    packId: 'pack-1',
    enWord: 'clean',
    trMeaning: 'temiz',
    pos: 'adj',
    exampleEn: 'The room is clean.',
    exampleTr: 'Oda temiz.',
    synonymsRaw: null,
    antonymsRaw: null,
    level: 'A2',
    tagsRaw: null,
    notes: null,
  );

  testWidgets(
    'opens translation on sentence long press and dictionary on word tap',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final FakeReadingRepository readingRepository = FakeReadingRepository(
        sentences: const <PassageSentence>[firstSentence, thirdSentence],
        passageWords: const <WordItem>[knownWord],
        translationMap: <String, SentenceTranslation>{
          's1|fake|tr': SentenceTranslation(
            id: 'tr-1',
            sentenceId: 's1',
            provider: 'fake',
            targetLang: 'tr',
            translatedText: 'Temiz yer sakin.',
            createdAt: DateTime(2026, 3, 6),
          ),
        },
      );
      final FakeWordRepository wordRepository = FakeWordRepository(
        globalWords: const <String, WordItem>{'clean': knownWord},
        globalIndex: const <WordItem>[knownWord],
      );
      final OfflineSyncController controller = OfflineSyncController(
        queueStore: OfflineSyncQueueStore(),
        readingRemote: _NoopReadingRepository(),
        progressRemote: _NoopProgressRepository(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: <Override>[
            appContentDatasetVersionProvider.overrideWith(
              (Ref ref) async => 'v-test',
            ),
            readingRepositoryProvider
                .overrideWith((Ref ref) => readingRepository),
            wordRepositoryProvider.overrideWith((Ref ref) => wordRepository),
            translationServiceProvider.overrideWith(
              (Ref ref) => FakeTranslationService(
                key: 'fake',
                translation: 'dummy',
              ),
            ),
            offlineSyncControllerProvider.overrideWith(
              (Ref ref) => controller,
            ),
          ],
          child: const MaterialApp(
            home: ReadingDetailPage(
              passage: passage,
              pack: pack,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Ceviriyi Goster'), findsNothing);
      expect(find.textContaining('... 2-2'), findsOneWidget);
      expect(find.text('Odak Kelimeler'), findsOneWidget);

      await tester.longPress(
        find.byKey(const ValueKey<String>('sentence-tap-target-s1')),
      );
      await tester.pumpAndSettle();

      final Finder translationPopup = find.byKey(
        const ValueKey<String>('sentence-translation-popup'),
      );
      expect(translationPopup, findsOneWidget);
      expect(find.text('Temiz yer sakin.'), findsOneWidget);
      expect(
        find.descendant(
          of: translationPopup,
          matching: find.byWidgetPredicate(
            (Widget widget) =>
                widget is RichText &&
                widget.text.toPlainText() == firstSentence.sentenceEn,
          ),
        ),
        findsNothing,
      );

      await tester.dragFrom(
        const Offset(80, 220),
        const Offset(0, -120),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('sentence-translation-popup')),
        findsNothing,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('interactive-word-clean-4')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('word-meaning-popup')),
        findsOneWidget,
      );
      expect(find.text('temiz'), findsOneWidget);

      await tester.tapAt(const Offset(24, 24));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ExpansionTile));
      await tester.pumpAndSettle();

      expect(find.text('Kelime Çalış'), findsOneWidget);
      expect(find.text('Mini Test'), findsOneWidget);
      expect(find.textContaining('dataset'), findsNothing);
      expect(find.text('x1'), findsNothing);
    },
  );
}

class _NoopReadingRepository implements ReadingRepository {
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
    return const PagedResult<ReadingPassage>(
      items: <ReadingPassage>[],
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

class _NoopProgressRepository implements ProgressRepository {
  @override
  Future<void> applyFlashcardResult({
    required String wordId,
    required FlashcardAnswer answer,
  }) async {}

  @override
  Future<void> applyTestResult({
    required String wordId,
    required bool isCorrect,
  }) async {}

  @override
  Future<Map<String, UserWordProgress>> getProgressMap({
    required List<String> wordIds,
  }) async {
    return const <String, UserWordProgress>{};
  }

  @override
  Future<int> getTodayWordCount() async => 0;

  @override
  Future<List<String>> getWeakWordIds({
    required String packId,
    int limit = 10,
  }) async {
    return const <String>[];
  }
}
