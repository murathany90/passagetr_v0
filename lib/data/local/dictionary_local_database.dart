import 'package:drift/drift.dart';

import 'dictionary_local_database_connection_native.dart'
    if (dart.library.html) 'dictionary_local_database_connection_web.dart';
import 'local_database_runtime_info.dart';

part 'dictionary_local_database.g.dart';

class LocalDictionaryEntries extends Table {
  IntColumn get seqId => integer()();

  TextColumn get entryId => text().named('entry_id')();

  TextColumn get enWord => text().named('en_word')();

  TextColumn get enWordNormalized => text().named('en_word_normalized')();

  TextColumn get searchKey => text().named('search_key')();

  TextColumn get pos => text().nullable()();

  TextColumn get trMeaning => text().named('tr_meaning')();

  TextColumn get source => text()();

  DateTimeColumn get updatedAt => dateTime().nullable().named('updated_at')();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{seqId};
}

class LocalDictionaryFallbackCache extends Table {
  TextColumn get queryNormalized => text().named('query_normalized')();

  TextColumn get queryText => text().named('query_text')();

  TextColumn get sourceLang => text().named('source_lang')();

  TextColumn get targetLang => text().named('target_lang')();

  TextColumn get provider => text()();

  TextColumn get translatedText => text().named('translated_text')();

  BoolColumn get fromServerCache =>
      boolean().named('from_server_cache').withDefault(const Constant(false))();

  IntColumn get hitCount =>
      integer().named('hit_count').withDefault(const Constant(1))();

  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{
        queryNormalized,
        sourceLang,
        targetLang,
      };
}

class LocalDictionaryBootstrapMeta extends Table {
  IntColumn get id => integer().withDefault(const Constant(1))();

  TextColumn get datasetVersion =>
      text().named('dataset_version').withDefault(const Constant(''))();

  TextColumn get batchId => text().nullable().named('batch_id')();

  IntColumn get rowCount =>
      integer().named('row_count').withDefault(const Constant(0))();

  IntColumn get downloadedCount =>
      integer().named('downloaded_count').withDefault(const Constant(0))();

  IntColumn get lastSeqId =>
      integer().named('last_seq_id').withDefault(const Constant(0))();

  TextColumn get status => text().withDefault(const Constant('idle'))();

  TextColumn get errorMessage => text().nullable().named('error_message')();

  DateTimeColumn get updatedAt =>
      dateTime().named('updated_at').withDefault(currentDateAndTime)();

  @override
  Set<Column<Object>> get primaryKey => <Column<Object>>{id};
}

@DriftDatabase(
  tables: <Type>[
    LocalDictionaryEntries,
    LocalDictionaryFallbackCache,
    LocalDictionaryBootstrapMeta,
  ],
)
class DictionaryLocalDatabase extends _$DictionaryLocalDatabase {
  DictionaryLocalDatabase() : super(openDictionaryLocalDatabaseConnection());

  DictionaryLocalDatabase.connect(super.connection);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (Migrator m) async {
          await m.createAll();
          await customStatement(
            'create unique index if not exists ix_local_dictionary_entry_id '
            'on local_dictionary_entries (entry_id);',
          );
          await customStatement(
            'create index if not exists ix_local_dictionary_norm '
            'on local_dictionary_entries (en_word_normalized);',
          );
          await customStatement(
            'create index if not exists ix_local_dictionary_search_key '
            'on local_dictionary_entries (search_key);',
          );
          await customStatement(
            'create index if not exists ix_local_fallback_updated_at '
            'on local_dictionary_fallback_cache (updated_at desc);',
          );

          await into(localDictionaryBootstrapMeta).insert(
            LocalDictionaryBootstrapMetaCompanion.insert(
              id: const Value(1),
              datasetVersion: const Value(''),
              batchId: const Value(null),
              rowCount: const Value(0),
              downloadedCount: const Value(0),
              lastSeqId: const Value(0),
              status: const Value('idle'),
              errorMessage: const Value(null),
            ),
            mode: InsertMode.insertOrIgnore,
          );
        },
      );
}

Future<LocalDatabaseRuntimeInfo> getDictionaryLocalDatabaseRuntimeInfo() {
  return dictionaryLocalDatabaseRuntimeInfo();
}
