import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_domain/shared_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../bootstrap/supabase_bootstrap.dart';
import '../local/drift/local_sync_models.dart';
import '../local/drift/local_sync_store.dart';

class FoundationWordFavoriteRepository implements WordFavoriteRepository {
  FoundationWordFavoriteRepository.preview({
    AccessContext? accessContext,
    DateTime Function()? now,
  }) : _database = null,
       _progressRepository = null,
       _config = null,
       _accessContext = accessContext ?? AccessContext.anonymous(),
       _now = now ?? _defaultNow;

  FoundationWordFavoriteRepository({
    LocalSyncStore? database,
    ProgressRepository? progressRepository,
    required AppConfig config,
    required AccessContext accessContext,
    DateTime Function()? now,
  }) : _database = database,
       _progressRepository = progressRepository,
       _config = config,
       _accessContext = accessContext,
       _now = now ?? _defaultNow;

  final LocalSyncStore? _database;
  final ProgressRepository? _progressRepository;
  final AppConfig? _config;
  final AccessContext _accessContext;
  final DateTime Function() _now;

  bool get _canPersist => _accessContext.hasIdentifiedProfile;

  @override
  Future<List<WordFavorite>> fetchAll() async {
    if (!_canPersist) {
      return const <WordFavorite>[];
    }

    if (_database != null) {
      return _readFromLocal();
    }

    return _readFromRemote();
  }

  @override
  Future<AppResult<void>> setFavorite(String wordId, bool isFavorite) async {
    if (!_canPersist) {
      return const AppSuccess<void>(null);
    }

    final timestamp = _now().toUtc();
    final database = _database;
    if (database != null) {
      try {
        if (isFavorite) {
          await database.upsertProgressSnapshot(
            _favoriteSnapshot(wordId: wordId, createdAt: timestamp),
          );
        } else {
          await database.deleteProgressSnapshot(
            entityType: 'user_word_favorites',
            entityId: wordId,
          );
        }

        final progressRepository = _progressRepository;
        if (progressRepository == null) {
          return const AppSuccess<void>(null);
        }

        return progressRepository.enqueue(
          OutboxEvent(
            eventId:
                'word-favorite-$wordId-${timestamp.microsecondsSinceEpoch}',
            scope: SyncScope.progress,
            entityType: 'user_word_favorites',
            entityId: wordId,
            operation: OutboxOperation.event,
            payloadJson: jsonEncode(<String, dynamic>{
              'word_id': wordId,
              'should_favorite': isFavorite,
            }),
          ),
        );
      } catch (error) {
        return AppFailure<void>(
          'Word favorite could not be updated.',
          cause: error,
        );
      }
    }

    try {
      await applyRemoteFavoriteWrite(
        eventId: 'word-favorite-$wordId-${timestamp.microsecondsSinceEpoch}',
        wordId: wordId,
        isFavorite: isFavorite,
      );
      return const AppSuccess<void>(null);
    } catch (error) {
      return AppFailure<void>(
        'Word favorite could not be updated.',
        cause: error,
      );
    }
  }

  @visibleForTesting
  Future<List<ProgressSnapshotRecord>> fetchRemoteFavoriteSnapshots() async {
    final config = _config;
    if (config == null || !config.supabaseEnabled) {
      return const <ProgressSnapshotRecord>[];
    }

    await SupabaseBootstrap.initialize(config);
    final rows =
        (await Supabase.instance.client
                .from('user_word_favorites')
                .select('word_id,created_at'))
            as List<dynamic>;
    return _mapRemoteRowsToSnapshots(rows);
  }

  @visibleForTesting
  Future<void> applyRemoteFavoriteWrite({
    required String eventId,
    required String wordId,
    required bool isFavorite,
  }) async {
    final config = _config;
    if (config == null || !config.supabaseEnabled) {
      return;
    }

    await SupabaseBootstrap.initialize(config);
    await Supabase.instance.client.rpc<void>(
      'apply_user_word_favorite_event',
      params: <String, dynamic>{
        'p_event_id': eventId,
        'p_word_id': wordId,
        'p_should_favorite': isFavorite,
      },
    );
  }

  Future<List<WordFavorite>> _readFromLocal() async {
    final database = _database;
    if (database == null) {
      return const <WordFavorite>[];
    }

    final favoriteSnapshots = await database.listProgressSnapshots(
      entityType: 'user_word_favorites',
    );
    return _mergeSnapshotState(favoriteSnapshots);
  }

  Future<List<WordFavorite>> _readFromRemote() async {
    try {
      final favoriteSnapshots = await fetchRemoteFavoriteSnapshots();
      return _mergeSnapshotState(favoriteSnapshots);
    } catch (_) {
      return const <WordFavorite>[];
    }
  }

  List<ProgressSnapshotRecord> _mapRemoteRowsToSnapshots(List<dynamic> rows) {
    return rows
        .whereType<Map<String, dynamic>>()
        .map(
          (row) => ProgressSnapshotRecord(
            entityType: 'user_word_favorites',
            entityId: row['word_id']?.toString() ?? '',
            payloadJson: jsonEncode(row),
            updatedAt: _readTimestamp(row['created_at']) ?? _now(),
          ),
        )
        .where((record) => record.entityId.isNotEmpty)
        .toList(growable: false);
  }

  List<WordFavorite> _mergeSnapshotState(
    List<ProgressSnapshotRecord> favoriteSnapshots,
  ) {
    final byWord = <String, WordFavorite>{};

    for (final snapshot in favoriteSnapshots) {
      final payload = _decodePayload(snapshot.payloadJson);
      final wordId = payload['word_id']?.toString() ?? snapshot.entityId;
      if (wordId.isEmpty) {
        continue;
      }

      final current = byWord[wordId] ?? WordFavorite.empty(wordId: wordId);
      byWord[wordId] = current.setFavorite(
        true,
        at: _readTimestamp(payload['created_at']) ?? snapshot.updatedAt,
      );
    }

    return byWord.values.toList(growable: false);
  }

  ProgressSnapshotRecord _favoriteSnapshot({
    required String wordId,
    required DateTime createdAt,
  }) {
    return ProgressSnapshotRecord(
      entityType: 'user_word_favorites',
      entityId: wordId,
      payloadJson: jsonEncode(<String, dynamic>{
        'word_id': wordId,
        'created_at': createdAt.toIso8601String(),
      }),
      updatedAt: createdAt,
    );
  }

  Map<String, dynamic> _decodePayload(String payloadJson) {
    final decoded = jsonDecode(payloadJson);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    }

    return const <String, dynamic>{};
  }

  DateTime? _readTimestamp(Object? value) {
    if (value is String) {
      return DateTime.tryParse(value)?.toUtc();
    }

    return null;
  }

  static DateTime _defaultNow() => DateTime.now().toUtc();
}
