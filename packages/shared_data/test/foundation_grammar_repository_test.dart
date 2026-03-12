import 'package:flutter_test/flutter_test.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_data/shared_data.dart';

import 'support/fake_local_sync_store.dart';

void main() {
  group('FoundationGrammarRepository', () {
    test('fetchModules orders grammar modules by sort order', () async {
      final database = FakeLocalSyncStore();
      await database.upsertContentEntity(
        ContentEntityRecord(
          scope: 'grammar',
          entityType: 'gramer_modulleri',
          entityId: '67',
          payloadJson:
              '{"id":67,"sira":12,"baslik":"Review","toplam_sayfa":40,"icon":"quiz","renk":"#F59E0B","is_published":true}',
          updatedAt: DateTime.utc(2026, 3, 11, 10, 0),
        ),
      );
      await database.upsertContentEntity(
        ContentEntityRecord(
          scope: 'grammar',
          entityType: 'gramer_modulleri',
          entityId: '57',
          payloadJson:
              '{"id":57,"sira":2,"baslik":"Tense System","toplam_sayfa":25,"icon":"schedule","renk":"#2563EB","is_published":true}',
          updatedAt: DateTime.utc(2026, 3, 11, 10, 1),
        ),
      );

      final repository = FoundationGrammarRepository(
        database: database,
        config: _testConfig,
      );

      final modules = await repository.fetchModules();

      expect(modules, hasLength(2));
      expect(modules.first.id, 57);
      expect(modules.first.sortOrder, 2);
      expect(modules.first.icon, 'schedule');
      expect(modules.last.id, 67);
    });

    test('fetchModuleDetail assembles pages, examples, and questions', () async {
      final database = FakeLocalSyncStore();
      await database.upsertContentEntity(
        ContentEntityRecord(
          scope: 'grammar',
          entityType: 'gramer_modulleri',
          entityId: '57',
          payloadJson:
              '{"id":57,"sira":2,"baslik":"Tense System","toplam_sayfa":2,"icon":"schedule","renk":"#2563EB","is_published":true}',
          updatedAt: DateTime.utc(2026, 3, 11, 10, 0),
        ),
      );
      await database.upsertContentEntity(
        ContentEntityRecord(
          scope: 'grammar',
          entityType: 'gramer_sayfalari',
          entityId: '502',
          payloadJson:
              '{"id":502,"modul_id":57,"sayfa_no":2,"baslik":"Present Perfect","icerik_html":"<p>Effects that continue now.</p>","kelime_sayisi":14,"is_published":true}',
          updatedAt: DateTime.utc(2026, 3, 11, 10, 2),
        ),
      );
      await database.upsertContentEntity(
        ContentEntityRecord(
          scope: 'grammar',
          entityType: 'gramer_sayfalari',
          entityId: '501',
          payloadJson:
              '{"id":501,"modul_id":57,"sayfa_no":1,"baslik":"Present Simple","icerik_html":"<p>Habits and routines.</p>","kelime_sayisi":12,"is_published":true}',
          updatedAt: DateTime.utc(2026, 3, 11, 10, 1),
        ),
      );
      await database.upsertContentEntity(
        ContentEntityRecord(
          scope: 'grammar',
          entityType: 'gramer_ornekler',
          entityId: '9001',
          payloadJson:
              '{"id":9001,"sayfa_id":501,"sira":1,"ingilizce":"She works every day.","turkce":"O her gun calisir.","aciklama":"Habit","is_published":true}',
          updatedAt: DateTime.utc(2026, 3, 11, 10, 3),
        ),
      );
      await database.upsertContentEntity(
        ContentEntityRecord(
          scope: 'grammar',
          entityType: 'gramer_testler',
          entityId: '9101',
          payloadJson:
              '{"id":9101,"sayfa_id":502,"sira":1,"soru":"Which sentence is present perfect?","secenekler_json":["I work daily.","I have finished my homework."],"dogru_cevap":"I have finished my homework.","aciklama":"Choose the correct tense.","is_published":true}',
          updatedAt: DateTime.utc(2026, 3, 11, 10, 4),
        ),
      );

      final repository = FoundationGrammarRepository(
        database: database,
        config: _testConfig,
      );

      final detail = await repository.fetchModuleDetail(57);

      expect(detail, isNotNull);
      expect(detail!.module.title, 'Tense System');
      expect(detail.pages, hasLength(2));
      expect(detail.pages.first.title, 'Present Simple');
      expect(
        detail.pages.first.examples.single.english,
        'She works every day.',
      );
      expect(
        detail.pages.last.questions.single.correctAnswer,
        'I have finished my homework.',
      );
    });

    test(
      'fetchModuleDetail preserves labeled options from keyed question maps',
      () async {
        final database = FakeLocalSyncStore();
        await database.upsertContentEntity(
          ContentEntityRecord(
            scope: 'grammar',
            entityType: 'gramer_modulleri',
            entityId: '56',
            payloadJson:
                '{"id":56,"sira":1,"baslik":"Basics","toplam_sayfa":1,"icon":"menu_book","renk":"#2563EB","is_published":true}',
            updatedAt: DateTime.utc(2026, 3, 11, 10, 0),
          ),
        );
        await database.upsertContentEntity(
          ContentEntityRecord(
            scope: 'grammar',
            entityType: 'gramer_sayfalari',
            entityId: '1169',
            payloadJson:
                '{"id":1169,"modul_id":56,"sayfa_no":1,"baslik":"Sentence basics","icerik_html":"<p>Content</p>","kelime_sayisi":12,"is_published":true}',
            updatedAt: DateTime.utc(2026, 3, 11, 10, 1),
          ),
        );
        await database.upsertContentEntity(
          ContentEntityRecord(
            scope: 'grammar',
            entityType: 'gramer_testler',
            entityId: '1183',
            payloadJson:
                '{"id":1183,"sayfa_id":1169,"sira":0,"soru":"How many noun phrases?","secenekler_json":{"A":"2","B":"3","C":"4","D":"5"},"dogru_cevap":"B) 3","aciklama":"Three noun phrases.","is_published":true}',
            updatedAt: DateTime.utc(2026, 3, 11, 10, 2),
          ),
        );

        final repository = FoundationGrammarRepository(
          database: database,
          config: _testConfig,
        );

        final detail = await repository.fetchModuleDetail(56);

        expect(detail, isNotNull);
        expect(detail!.pages.single.questions.single.options, <String>[
          'A) 2',
          'B) 3',
          'C) 4',
          'D) 5',
        ]);
      },
    );
  });
}

const AppConfig _testConfig = AppConfig(
  appName: 'PASSAGETR',
  environment: AppEnvironment.dev,
  platformMode: PlatformMode.mobile,
  supabaseUrl: '',
  supabaseAnonKey: '',
  adminConsoleUrl: '',
  adminPreviewEnabled: true,
);
