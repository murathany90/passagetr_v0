import 'package:flutter_test/flutter_test.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_data/shared_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/fake_local_sync_store.dart';

void main() {
  test('maps zero-based section index to one-based sentence idx', () async {
    final database = FakeLocalSyncStore();
    await database.upsertContentEntity(
      ContentEntityRecord(
        scope: 'readings',
        entityType: 'reading_passage_sentences',
        entityId: 'sentence-1',
        payloadJson:
            '{"passage_id":"reading-1","idx":1,"sentence_tr":"Merhaba dunya"}',
        updatedAt: DateTime.utc(2026, 3, 10, 18, 0),
      ),
    );

    final repository = FoundationReadingRepository(
      database: database,
      config: const AppConfig(
        appName: 'PASSAGETR',
        environment: AppEnvironment.dev,
        platformMode: PlatformMode.mobile,
        supabaseUrl: '',
        supabaseAnonKey: '',
        adminConsoleUrl: '',
        adminPreviewEnabled: true,
      ),
    );

    final translation = await repository.fetchSentenceTranslation(
      'reading-1',
      0,
    );

    expect(translation, 'Merhaba dunya');
  });

  test('loads ordered english reading sections from local sync store', () async {
    final database = FakeLocalSyncStore();
    await database.upsertContentEntity(
      ContentEntityRecord(
        scope: 'readings',
        entityType: 'reading_passage_sentences',
        entityId: 'sentence-2',
        payloadJson:
            '{"passage_id":"reading-1","idx":2,"sentence_en":"Second sentence.","sentence_tr":"Ikinci cumle."}',
        updatedAt: DateTime.utc(2026, 3, 10, 18, 5),
      ),
    );
    await database.upsertContentEntity(
      ContentEntityRecord(
        scope: 'readings',
        entityType: 'reading_passage_sentences',
        entityId: 'sentence-1',
        payloadJson:
            '{"passage_id":"reading-1","idx":1,"sentence_en":"First sentence.","sentence_tr":"Birinci cumle."}',
        updatedAt: DateTime.utc(2026, 3, 10, 18, 4),
      ),
    );

    final repository = FoundationReadingRepository(
      database: database,
      config: const AppConfig(
        appName: 'PASSAGETR',
        environment: AppEnvironment.dev,
        platformMode: PlatformMode.mobile,
        supabaseUrl: '',
        supabaseAnonKey: '',
        adminConsoleUrl: '',
        adminPreviewEnabled: true,
      ),
    );

    final sections = await repository.fetchReadingSections('reading-1');

    expect(sections.map((item) => item.englishText).toList(growable: false), [
      'First sentence.',
      'Second sentence.',
    ]);
  });

  test('loads reading pack id from local sync store', () async {
    final database = FakeLocalSyncStore();
    await database.upsertContentEntity(
      ContentEntityRecord(
        scope: 'readings',
        entityType: 'reading_passages',
        entityId: 'reading-1',
        payloadJson:
            '{"id":"reading-1","pack_id":"pack-2","title":"Pack Reading","level":"B1","category":"History","is_pro":false}',
        updatedAt: DateTime.utc(2026, 3, 14, 10, 0),
      ),
    );

    final repository = FoundationReadingRepository(
      database: database,
      config: const AppConfig(
        appName: 'PASSAGETR',
        environment: AppEnvironment.dev,
        platformMode: PlatformMode.mobile,
        supabaseUrl: '',
        supabaseAnonKey: '',
        adminConsoleUrl: '',
        adminPreviewEnabled: true,
      ),
    );

    final readings = await repository.fetchReadings();

    expect(readings, hasLength(1));
    expect(readings.single.id, 'reading-1');
    expect(readings.single.packId, 'pack-2');
  });

  test('loads question count and cover fields from local sync store', () async {
    final database = FakeLocalSyncStore();
    await database.upsertContentEntity(
      ContentEntityRecord(
        scope: 'readings',
        entityType: 'reading_passages',
        entityId: 'reading-1',
        payloadJson:
            '{"id":"reading-1","pack_id":"pack-2","title":"Cover Reading","level":"B1","category":"History","is_pro":false,"cover_bucket_name":"reading-covers","cover_storage_path":"readings/reading-1/cover.png","cover_alt_text":"Cover Reading artwork"}',
        updatedAt: DateTime.utc(2026, 3, 14, 10, 0),
      ),
    );
    await database.upsertContentEntity(
      ContentEntityRecord(
        scope: 'readings',
        entityType: 'reading_passage_questions',
        entityId: 'question-1',
        payloadJson:
            '{"id":"question-1","passage_id":"reading-1","sort_order":1,"question":"First question?","options_json":["Yes","No"],"correct_option_index":0,"is_published":true}',
        updatedAt: DateTime.utc(2026, 3, 14, 10, 1),
      ),
    );
    await database.upsertContentEntity(
      ContentEntityRecord(
        scope: 'readings',
        entityType: 'reading_passage_questions',
        entityId: 'question-2',
        payloadJson:
            '{"id":"question-2","passage_id":"reading-1","sort_order":2,"question":"Second question?","options_json":["A","B"],"correct_option_index":1,"is_published":true}',
        updatedAt: DateTime.utc(2026, 3, 14, 10, 2),
      ),
    );

    SharedPreferences.setMockInitialValues(<String, Object>{});

    final repository = FoundationReadingRepository(
      database: database,
      config: const AppConfig(
        appName: 'PASSAGETR',
        environment: AppEnvironment.dev,
        platformMode: PlatformMode.mobile,
        supabaseUrl: 'https://example.supabase.co',
        supabaseAnonKey: 'anon',
        adminConsoleUrl: '',
        adminPreviewEnabled: true,
      ),
    );

    final readings = await repository.fetchReadings();

    expect(readings, hasLength(1));
    expect(readings.single.questionCount, 2);
    expect(readings.single.hasCover, isTrue);
    expect(
      readings.single.coverUrl,
      'https://example.supabase.co/storage/v1/object/public/reading-covers/readings/reading-1/cover.png',
    );
    expect(readings.single.coverAltText, 'Cover Reading artwork');
  });

  test('loads focus words by joining passage links with synced words', () async {
    final database = FakeLocalSyncStore();
    await database.upsertContentEntity(
      ContentEntityRecord(
        scope: 'readings',
        entityType: 'reading_passage_words',
        entityId: 'link-2',
        payloadJson: '{"passage_id":"reading-1","word_id":"word-2"}',
        updatedAt: DateTime.utc(2026, 3, 10, 18, 7),
      ),
    );
    await database.upsertContentEntity(
      ContentEntityRecord(
        scope: 'readings',
        entityType: 'reading_passage_words',
        entityId: 'link-1',
        payloadJson: '{"passage_id":"reading-1","word_id":"word-1"}',
        updatedAt: DateTime.utc(2026, 3, 10, 18, 6),
      ),
    );
    await database.upsertContentEntity(
      ContentEntityRecord(
        scope: 'words',
        entityType: 'words',
        entityId: 'word-1',
        payloadJson:
            '{"id":"word-1","en_word":"ocean","tr_meaning":"okyanus","pos":"noun"}',
        updatedAt: DateTime.utc(2026, 3, 10, 18, 0),
      ),
    );
    await database.upsertContentEntity(
      ContentEntityRecord(
        scope: 'words',
        entityType: 'words',
        entityId: 'word-2',
        payloadJson:
            '{"id":"word-2","en_word":"mystery","tr_meaning":"gizem","pos":"noun"}',
        updatedAt: DateTime.utc(2026, 3, 10, 18, 1),
      ),
    );

    final repository = FoundationReadingRepository(
      database: database,
      config: const AppConfig(
        appName: 'PASSAGETR',
        environment: AppEnvironment.dev,
        platformMode: PlatformMode.mobile,
        supabaseUrl: '',
        supabaseAnonKey: '',
        adminConsoleUrl: '',
        adminPreviewEnabled: true,
      ),
    );

    final focusWords = await repository.fetchFocusWords('reading-1');

    expect(
      focusWords.map((item) => item.enWord).toList(growable: false),
      <String>['ocean', 'mystery'],
    );
    expect(focusWords.first.trMeaning, 'okyanus');
  });

  test('loads published reading questions from local sync store', () async {
    final database = FakeLocalSyncStore();
    await database.upsertContentEntity(
      ContentEntityRecord(
        scope: 'readings',
        entityType: 'reading_passage_questions',
        entityId: 'question-2',
        payloadJson:
            '{"id":"question-2","passage_id":"reading-1","sort_order":2,"question":"Second question?","options_json":["A","B"],"correct_option_index":1,"is_published":true}',
        updatedAt: DateTime.utc(2026, 3, 13, 18, 2),
      ),
    );
    await database.upsertContentEntity(
      ContentEntityRecord(
        scope: 'readings',
        entityType: 'reading_passage_questions',
        entityId: 'question-1',
        payloadJson:
            '{"id":"question-1","passage_id":"reading-1","sort_order":1,"question":"First question?","options_json":["Yes","No"],"correct_option_index":0,"explanation":"Because the text says so.","is_published":true}',
        updatedAt: DateTime.utc(2026, 3, 13, 18, 1),
      ),
    );
    await database.upsertContentEntity(
      ContentEntityRecord(
        scope: 'readings',
        entityType: 'reading_passage_questions',
        entityId: 'question-hidden',
        payloadJson:
            '{"id":"question-hidden","passage_id":"reading-1","sort_order":3,"question":"Hidden question?","options_json":["A","B"],"correct_option_index":0,"is_published":false}',
        updatedAt: DateTime.utc(2026, 3, 13, 18, 3),
      ),
    );

    final repository = FoundationReadingRepository(
      database: database,
      config: const AppConfig(
        appName: 'PASSAGETR',
        environment: AppEnvironment.dev,
        platformMode: PlatformMode.mobile,
        supabaseUrl: '',
        supabaseAnonKey: '',
        adminConsoleUrl: '',
        adminPreviewEnabled: true,
      ),
    );

    final questions = await repository.fetchQuestions('reading-1');

    expect(
      questions.map((item) => item.question).toList(growable: false),
      <String>['First question?', 'Second question?'],
    );
    expect(questions.first.correctOptionIndex, 0);
    expect(questions.first.explanation, 'Because the text says so.');
  });
}
