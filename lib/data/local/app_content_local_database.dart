import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_content_local_database.g.dart';

class AppContentMeta extends Table {
  @override
  String get tableName => 'meta';

  TextColumn get key => text()();

  TextColumn get value => text()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{key};
}

class AppContentPacks extends Table {
  @override
  String get tableName => 'packs';

  TextColumn get id => text()();

  TextColumn get name => text()();

  TextColumn get fromLang => text().named('from_lang')();

  TextColumn get toLang => text().named('to_lang')();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

class AppContentWords extends Table {
  @override
  String get tableName => 'words';

  TextColumn get id => text()();

  TextColumn get packId => text().named('pack_id')();

  TextColumn get enWord => text().named('en_word')();

  TextColumn get trMeaning => text().named('tr_meaning')();

  TextColumn get pos => text()();

  TextColumn get posRaw => text().named('pos_raw').nullable()();

  TextColumn get exampleEn => text().named('example_en')();

  TextColumn get exampleTr => text().named('example_tr').nullable()();

  TextColumn get synonymsRaw => text().named('synonyms_raw').nullable()();

  TextColumn get antonymsRaw => text().named('antonyms_raw').nullable()();

  TextColumn get level => text().nullable()();

  TextColumn get tagsRaw => text().named('tags_raw').nullable()();

  TextColumn get notes => text().nullable()();

  TextColumn get enWordNormalized => text().named('en_word_normalized')();

  TextColumn get searchKey => text().named('search_key')();

  IntColumn get createdAt => integer().named('created_at')();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

class AppContentReadingPassages extends Table {
  @override
  String get tableName => 'reading_passages';

  TextColumn get id => text()();

  TextColumn get packId => text().named('pack_id').nullable()();

  TextColumn get packName => text().named('pack_name').nullable()();

  TextColumn get title => text()();

  TextColumn get level => text().nullable()();

  TextColumn get tagsRaw => text().named('tags_raw').nullable()();

  TextColumn get category => text().nullable()();

  IntColumn get createdAt => integer().named('created_at')();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

class AppContentReadingSentences extends Table {
  @override
  String get tableName => 'reading_sentences';

  TextColumn get id => text()();

  TextColumn get passageId => text().named('passage_id')();

  TextColumn get passageTitle => text().named('passage_title')();

  IntColumn get idx => integer()();

  TextColumn get sentenceEn => text().named('sentence_en')();

  TextColumn get sentenceTr => text().named('sentence_tr').nullable()();

  IntColumn get createdAt => integer().named('created_at')();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

class AppContentGrammarModules extends Table {
  @override
  String get tableName => 'grammar_modules';

  IntColumn get id => integer()();

  IntColumn get sourceModuleId =>
      integer().named('source_module_id').nullable()();

  IntColumn get sira => integer()();

  TextColumn get baslik => text()();

  TextColumn get dosyaAdi => text().named('dosya_adi')();

  IntColumn get toplamSayfa => integer().named('toplam_sayfa')();

  TextColumn get icon => text()();

  TextColumn get renk => text()();

  IntColumn get updatedAt => integer().named('updated_at')();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

class AppContentGrammarPages extends Table {
  @override
  String get tableName => 'grammar_pages';

  IntColumn get id => integer()();

  IntColumn get moduleId => integer().named('module_id')();

  IntColumn get sourcePageId => integer().named('source_page_id').nullable()();

  IntColumn get sayfaNo => integer().named('sayfa_no')();

  TextColumn get baslik => text()();

  TextColumn get icerikHtml => text().named('icerik_html')();

  IntColumn get kelimeSayisi => integer().named('kelime_sayisi')();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

class AppContentGrammarExamples extends Table {
  @override
  String get tableName => 'grammar_examples';

  IntColumn get id => integer()();

  IntColumn get pageId => integer().named('page_id')();

  IntColumn get sira => integer()();

  TextColumn get ingilizce => text()();

  TextColumn get turkce => text()();

  TextColumn get aciklama => text()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

class AppContentGrammarTests extends Table {
  @override
  String get tableName => 'grammar_tests';

  IntColumn get id => integer()();

  IntColumn get pageId => integer().named('page_id')();

  IntColumn get sira => integer()();

  TextColumn get soru => text()();

  TextColumn get seceneklerJson => text().named('secenekler_json')();

  TextColumn get dogruCevap => text().named('dogru_cevap')();

  TextColumn get aciklama => text()();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@DriftDatabase(
  tables: <Type>[
    AppContentMeta,
    AppContentPacks,
    AppContentWords,
    AppContentReadingPassages,
    AppContentReadingSentences,
    AppContentGrammarModules,
    AppContentGrammarPages,
    AppContentGrammarExamples,
    AppContentGrammarTests,
  ],
)
class AppContentLocalDatabase extends _$AppContentLocalDatabase {
  AppContentLocalDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onUpgrade: (Migrator m, int from, int to) async {
          if (from < 2) {
            await m.createTable(appContentGrammarModules);
            await m.createTable(appContentGrammarPages);
            await m.createTable(appContentGrammarExamples);
            await m.createTable(appContentGrammarTests);
            await customStatement(
              'create unique index if not exists ix_grammar_pages_module_no on grammar_pages(module_id, sayfa_no)',
            );
            await customStatement(
              'create unique index if not exists ix_grammar_examples_page_sira on grammar_examples(page_id, sira)',
            );
            await customStatement(
              'create unique index if not exists ix_grammar_tests_page_sira on grammar_tests(page_id, sira)',
            );
          }
        },
      );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final Directory directory = await getApplicationDocumentsDirectory();
    final File file = File(p.join(directory.path, 'app_content.db'));
    await _copyAppContentIfNeeded(file);
    return NativeDatabase.createInBackground(file);
  });
}

Future<void> _copyAppContentIfNeeded(File targetFile) async {
  final Directory directory = targetFile.parent;
  final File metaFile = File(p.join(directory.path, 'app_content_meta.json'));

  final Map<String, dynamic> assetMeta = await _loadAssetMeta();
  final String assetVersion =
      (assetMeta['dataset_version'] ?? '').toString().trim();

  bool shouldCopy = !await targetFile.exists();
  if (!shouldCopy && assetVersion.isNotEmpty) {
    if (!await metaFile.exists()) {
      shouldCopy = true;
    } else {
      try {
        final Map<String, dynamic> localMeta = jsonDecode(
          await metaFile.readAsString(),
        ) as Map<String, dynamic>;
        final String localVersion =
            (localMeta['dataset_version'] ?? '').toString().trim();
        shouldCopy = localVersion != assetVersion;
      } catch (_) {
        shouldCopy = true;
      }
    }
  }

  if (!shouldCopy) {
    return;
  }

  final ByteData data = await rootBundle.load('assets/db/app_content.db');
  final Uint8List bytes = data.buffer.asUint8List(
    data.offsetInBytes,
    data.lengthInBytes,
  );
  await directory.create(recursive: true);
  await targetFile.writeAsBytes(bytes, flush: true);

  final Map<String, dynamic> finalMeta = assetMeta.isEmpty
      ? <String, dynamic>{
          'dataset_version': '',
          'generated_at': DateTime.now().toUtc().toIso8601String(),
        }
      : assetMeta;
  await metaFile.writeAsString(
    jsonEncode(finalMeta),
    flush: true,
  );
}

Future<Map<String, dynamic>> _loadAssetMeta() async {
  try {
    final String raw =
        await rootBundle.loadString('assets/db/app_content.meta.json');
    final Object? decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    return const <String, dynamic>{};
  } catch (_) {
    return const <String, dynamic>{};
  }
}
