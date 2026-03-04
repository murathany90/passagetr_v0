import 'package:drift/drift.dart';

import '../../core/utils/dictionary_text_normalizer.dart';
import '../../domain/entities/dictionary_bootstrap_state.dart';
import '../../domain/entities/dictionary_entry.dart';
import 'dictionary_local_database.dart';

class LocalFallbackCacheEntry {
  const LocalFallbackCacheEntry({
    required this.queryNormalized,
    required this.queryText,
    required this.sourceLang,
    required this.targetLang,
    required this.provider,
    required this.translatedText,
    required this.fromServerCache,
    required this.hitCount,
    required this.updatedAt,
  });

  final String queryNormalized;
  final String queryText;
  final String sourceLang;
  final String targetLang;
  final String provider;
  final String translatedText;
  final bool fromServerCache;
  final int hitCount;
  final DateTime updatedAt;
}

class DictionaryLocalDataSource {
  DictionaryLocalDataSource(this._db);

  final DictionaryLocalDatabase _db;

  Future<DictionaryBootstrapState> getBootstrapState() async {
    final LocalDictionaryBootstrapMetaData row = await _ensureBootstrapMeta();
    return _toBootstrapState(row);
  }

  Future<bool> hasLocalDictionaryData() async {
    final Expression<int> countExpression =
        _db.localDictionaryEntries.seqId.count();
    final query = _db.selectOnly(_db.localDictionaryEntries)
      ..addColumns(<Expression<Object>>[countExpression]);
    final TypedResult result = await query.getSingle();
    final int count = result.read(countExpression) ?? 0;
    return count > 0;
  }

  Future<void> resetDictionaryForVersion({
    required String datasetVersion,
    required String? batchId,
    required int rowCount,
  }) async {
    await _db.transaction(() async {
      await _db.delete(_db.localDictionaryEntries).go();
      await _db.into(_db.localDictionaryBootstrapMeta).insertOnConflictUpdate(
            LocalDictionaryBootstrapMetaCompanion(
              id: const Value(1),
              datasetVersion: Value(datasetVersion),
              batchId: Value(batchId),
              rowCount: Value(rowCount),
              downloadedCount: const Value(0),
              lastSeqId: const Value(0),
              status: const Value('in_progress'),
              errorMessage: const Value(null),
              updatedAt: Value(DateTime.now().toUtc()),
            ),
          );
    });
  }

  Future<void> markBootstrapInProgress({
    required String datasetVersion,
    required String? batchId,
    required int rowCount,
    required int downloadedCount,
    required int lastSeqId,
  }) async {
    await _db.into(_db.localDictionaryBootstrapMeta).insertOnConflictUpdate(
          LocalDictionaryBootstrapMetaCompanion(
            id: const Value(1),
            datasetVersion: Value(datasetVersion),
            batchId: Value(batchId),
            rowCount: Value(rowCount),
            downloadedCount: Value(downloadedCount),
            lastSeqId: Value(lastSeqId),
            status: const Value('in_progress'),
            errorMessage: const Value(null),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
  }

  Future<void> updateBootstrapProgress({
    required int downloadedCount,
    required int lastSeqId,
  }) async {
    await (_db.update(_db.localDictionaryBootstrapMeta)
          ..where((tbl) => tbl.id.equals(1)))
        .write(
      LocalDictionaryBootstrapMetaCompanion(
        downloadedCount: Value(downloadedCount),
        lastSeqId: Value(lastSeqId),
        status: const Value('in_progress'),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Future<void> markBootstrapReady({
    required int downloadedCount,
    required int lastSeqId,
  }) async {
    await (_db.update(_db.localDictionaryBootstrapMeta)
          ..where((tbl) => tbl.id.equals(1)))
        .write(
      LocalDictionaryBootstrapMetaCompanion(
        downloadedCount: Value(downloadedCount),
        lastSeqId: Value(lastSeqId),
        status: const Value('ready'),
        errorMessage: const Value(null),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Future<void> markBootstrapFailed(String errorMessage) async {
    await (_db.update(_db.localDictionaryBootstrapMeta)
          ..where((tbl) => tbl.id.equals(1)))
        .write(
      LocalDictionaryBootstrapMetaCompanion(
        status: const Value('failed'),
        errorMessage: Value(errorMessage),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );
  }

  Future<void> upsertEntries(List<DictionaryEntry> entries) async {
    if (entries.isEmpty) {
      return;
    }

    await _db.batch((Batch batch) {
      batch.insertAllOnConflictUpdate(
        _db.localDictionaryEntries,
        entries
            .map(
              (DictionaryEntry entry) => LocalDictionaryEntriesCompanion.insert(
                seqId: Value(entry.seqId),
                entryId: entry.id,
                enWord: entry.enWord,
                enWordNormalized: entry.enWordNormalized,
                searchKey: entry.searchKey,
                pos: Value(entry.pos),
                trMeaning: entry.trMeaning,
                source: entry.source,
                updatedAt: Value(entry.updatedAt),
              ),
            )
            .toList(growable: false),
      );
    });
  }

  Future<List<DictionaryEntry>> searchEntries({
    required String query,
    int limit = 30,
  }) async {
    final String normalized = normalizeDictionaryQuery(query);
    if (normalized.isEmpty) {
      return const <DictionaryEntry>[];
    }

    final String prefix = '$normalized%';
    final String contains = '%$normalized%';
    final int boundedLimit = limit <= 0 ? 30 : limit;

    final List<QueryRow> rows = await _db.customSelect(
      '''
select
  entry_id,
  seq_id,
  en_word,
  en_word_normalized,
  search_key,
  pos,
  tr_meaning,
  source,
  updated_at,
  case
    when en_word_normalized = ?1 then 0
    when en_word_normalized like ?2 then 1
    when search_key like ?2 then 2
    when en_word_normalized like ?3 then 3
    when search_key like ?3 then 4
    else 5
  end as rank_score
from local_dictionary_entries
where
  en_word_normalized = ?1
  or en_word_normalized like ?2
  or search_key like ?2
  or en_word_normalized like ?3
  or search_key like ?3
order by rank_score asc, length(en_word_normalized) asc, en_word asc
limit ?4
      ''',
      variables: <Variable<Object>>[
        Variable<String>(normalized),
        Variable<String>(prefix),
        Variable<String>(contains),
        Variable<int>(boundedLimit),
      ],
      readsFrom: <ResultSetImplementation<dynamic, dynamic>>{
        _db.localDictionaryEntries,
      },
    ).get();

    return rows.map(_rowToEntry).toList(growable: false);
  }

  Future<LocalFallbackCacheEntry?> getFallbackCache({
    required String queryNormalized,
    required String sourceLang,
    required String targetLang,
  }) async {
    final String normalized = normalizeDictionaryQuery(queryNormalized);
    if (normalized.isEmpty) {
      return null;
    }

    final LocalDictionaryFallbackCacheData? row =
        await (_db.select(_db.localDictionaryFallbackCache)
              ..where(
                (tbl) =>
                    tbl.queryNormalized.equals(normalized) &
                    tbl.sourceLang.equals(sourceLang) &
                    tbl.targetLang.equals(targetLang),
              )
              ..limit(1))
            .getSingleOrNull();

    if (row == null) {
      return null;
    }

    await (_db.update(_db.localDictionaryFallbackCache)
          ..where(
            (tbl) =>
                tbl.queryNormalized.equals(normalized) &
                tbl.sourceLang.equals(sourceLang) &
                tbl.targetLang.equals(targetLang),
          ))
        .write(
      LocalDictionaryFallbackCacheCompanion(
        hitCount: Value(row.hitCount + 1),
        updatedAt: Value(DateTime.now().toUtc()),
      ),
    );

    return LocalFallbackCacheEntry(
      queryNormalized: row.queryNormalized,
      queryText: row.queryText,
      sourceLang: row.sourceLang,
      targetLang: row.targetLang,
      provider: row.provider,
      translatedText: row.translatedText,
      fromServerCache: row.fromServerCache,
      hitCount: row.hitCount + 1,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  Future<void> upsertFallbackCache({
    required String queryText,
    required String queryNormalized,
    required String sourceLang,
    required String targetLang,
    required String provider,
    required String translatedText,
    required bool fromServerCache,
  }) async {
    final String normalized = normalizeDictionaryQuery(queryNormalized);
    if (normalized.isEmpty || translatedText.trim().isEmpty) {
      return;
    }

    await _db.into(_db.localDictionaryFallbackCache).insertOnConflictUpdate(
          LocalDictionaryFallbackCacheCompanion.insert(
            queryNormalized: normalized,
            queryText: queryText,
            sourceLang: sourceLang,
            targetLang: targetLang,
            provider: provider,
            translatedText: translatedText,
            fromServerCache: Value(fromServerCache),
            hitCount: const Value(1),
            updatedAt: Value(DateTime.now().toUtc()),
          ),
        );
  }

  DictionaryEntry _rowToEntry(QueryRow row) {
    final String id = row.read<String>('entry_id');
    final int seqId = row.read<int>('seq_id');
    final String enWord = row.read<String>('en_word');
    final String enWordNormalized = row.read<String>('en_word_normalized');
    final String searchKey = row.read<String>('search_key');
    final String? pos = row.read<String?>('pos');
    final String trMeaning = row.read<String>('tr_meaning');
    final String source = row.read<String>('source');
    final DateTime? updatedAt = row.read<DateTime?>('updated_at');

    return DictionaryEntry(
      id: id,
      seqId: seqId,
      enWord: enWord,
      enWordNormalized: enWordNormalized,
      searchKey: searchKey,
      pos: pos,
      trMeaning: trMeaning,
      source: source,
      updatedAt: updatedAt,
    );
  }

  Future<LocalDictionaryBootstrapMetaData> _ensureBootstrapMeta() async {
    LocalDictionaryBootstrapMetaData? row =
        await (_db.select(_db.localDictionaryBootstrapMeta)
              ..where((tbl) => tbl.id.equals(1))
              ..limit(1))
            .getSingleOrNull();

    if (row != null) {
      return row;
    }

    await _db.into(_db.localDictionaryBootstrapMeta).insert(
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

    row = await (_db.select(_db.localDictionaryBootstrapMeta)
          ..where((tbl) => tbl.id.equals(1))
          ..limit(1))
        .getSingle();
    return row;
  }

  DictionaryBootstrapState _toBootstrapState(
      LocalDictionaryBootstrapMetaData row) {
    return DictionaryBootstrapState(
      status: _statusFromRaw(row.status),
      datasetVersion: row.datasetVersion,
      batchId: row.batchId,
      rowCount: row.rowCount,
      downloadedCount: row.downloadedCount,
      lastSeqId: row.lastSeqId,
      updatedAt: row.updatedAt,
      errorMessage: row.errorMessage,
    );
  }

  DictionaryBootstrapStatus _statusFromRaw(String raw) {
    switch (raw.trim().toLowerCase()) {
      case 'in_progress':
        return DictionaryBootstrapStatus.inProgress;
      case 'ready':
        return DictionaryBootstrapStatus.ready;
      case 'failed':
        return DictionaryBootstrapStatus.failed;
      default:
        return DictionaryBootstrapStatus.idle;
    }
  }
}
