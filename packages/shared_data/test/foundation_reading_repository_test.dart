import 'package:flutter_test/flutter_test.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_data/shared_data.dart';

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
}
