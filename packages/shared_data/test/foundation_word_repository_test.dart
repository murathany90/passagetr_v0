import 'package:flutter_test/flutter_test.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_data/shared_data.dart';

import 'support/fake_local_sync_store.dart';

void main() {
  test(
    'fetchWords falls back to preview content when remote lookup throws',
    () async {
      final repository = FoundationWordRepository.preview(
        remoteReaderOverride: ({String? packId}) =>
            throw Exception('dns failure'),
      );

      final items = await repository.fetchWords();

      expect(items, isNotEmpty);
      expect(items.first.id, 'word-a');
      expect(items.first.enWord, 'a great deal of');
    },
  );

  test('fetchWordsByIds maps detailed metadata from local sync store', () async {
    final database = FakeLocalSyncStore();
    await database.upsertContentEntity(
      ContentEntityRecord(
        scope: 'words',
        entityType: 'words',
        entityId: 'word-1',
        payloadJson:
            '{"id":"word-1","pack_id":"pack-1","en_word":"orbit","tr_meaning":"yorunge","pos":"n.","example_en":"The satellite stays in orbit.","example_tr":"Uydu yorungede kalir.","synonyms_raw":"path, track","antonyms_raw":"standstill","notes":"science term"}',
        updatedAt: DateTime.utc(2026, 3, 12, 0, 30),
      ),
    );

    final repository = FoundationWordRepository(
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

    final items = await repository.fetchWordsByIds(<String>['word-1']);

    expect(items, hasLength(1));
    expect(items.single.enWord, 'orbit');
    expect(items.single.exampleEn, 'The satellite stays in orbit.');
    expect(items.single.exampleTr, 'Uydu yorungede kalir.');
    expect(items.single.synonymsRaw, 'path, track');
    expect(items.single.antonymsRaw, 'standstill');
    expect(items.single.notes, 'science term');
  });

  test(
    'fetchWordsByIds falls back to local metadata when remote lookup throws',
    () async {
      final database = FakeLocalSyncStore();
      await database.upsertContentEntity(
        ContentEntityRecord(
          scope: 'words',
          entityType: 'words',
          entityId: 'word-2',
          payloadJson:
              '{"id":"word-2","pack_id":"pack-1","en_word":"anchor","tr_meaning":"capa","pos":"n."}',
          updatedAt: DateTime.utc(2026, 3, 12, 0, 35),
        ),
      );

      final repository = FoundationWordRepository(
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
        remoteByIdsReaderOverride: (_) => throw Exception('dns failure'),
      );

      final items = await repository.fetchWordsByIds(<String>['word-2']);

      expect(items, hasLength(1));
      expect(items.single.id, 'word-2');
      expect(items.single.enWord, 'anchor');
      expect(items.single.trMeaning, 'capa');
      expect(items.single.exampleEn, isEmpty);
    },
  );
}
