import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_domain/shared_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../bootstrap/supabase_bootstrap.dart';
import '../local/drift/local_sync_models.dart';
import '../local/drift/local_sync_store.dart';

class FoundationReadingEngagementRepository
    implements ReadingEngagementRepository {
  FoundationReadingEngagementRepository.preview({
    AccessContext? accessContext,
    DateTime Function()? now,
  }) : _database = null,
       _progressRepository = null,
       _config = null,
       _accessContext = accessContext ?? AccessContext.anonymous(),
       _now = now ?? _defaultNow;

  FoundationReadingEngagementRepository({
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
  Future<List<ReadingEngagement>> fetchAll() async {
    if (!_canPersist) {
      return const <ReadingEngagement>[];
    }

    if (_database != null) {
      return _readFromLocal();
    }

    return _readFromRemote();
  }

  @override
  Future<AppResult<void>> setBookmark(
    String passageId,
    bool isBookmarked,
  ) async {
    if (!_canPersist) {
      return const AppSuccess<void>(null);
    }

    final timestamp = _now().toUtc();
    final database = _database;
    if (database != null) {
      try {
        if (isBookmarked) {
          await database.upsertProgressSnapshot(
            _engagementSnapshot(
              entityType: 'user_reading_bookmarks',
              passageId: passageId,
              createdAt: timestamp,
            ),
          );
        } else {
          await database.deleteProgressSnapshot(
            entityType: 'user_reading_bookmarks',
            entityId: passageId,
          );
        }

        final progressRepository = _progressRepository;
        if (progressRepository == null) {
          return const AppSuccess<void>(null);
        }

        return progressRepository.enqueue(
          OutboxEvent(
            eventId: 'bookmark-$passageId-${timestamp.microsecondsSinceEpoch}',
            scope: SyncScope.progress,
            entityType: 'user_reading_bookmarks',
            entityId: passageId,
            operation: OutboxOperation.event,
            payloadJson: jsonEncode(<String, dynamic>{
              'passage_id': passageId,
              'should_bookmark': isBookmarked,
            }),
          ),
        );
      } catch (error) {
        return AppFailure<void>(
          'Reading bookmark could not be updated.',
          cause: error,
        );
      }
    }

    try {
      await applyRemoteBookmarkWrite(
        eventId: 'bookmark-$passageId-${timestamp.microsecondsSinceEpoch}',
        passageId: passageId,
        isBookmarked: isBookmarked,
      );
      return const AppSuccess<void>(null);
    } catch (error) {
      return AppFailure<void>(
        'Reading bookmark could not be updated.',
        cause: error,
      );
    }
  }

  @override
  Future<AppResult<void>> setFavorite(String passageId, bool isFavorite) async {
    if (!_canPersist) {
      return const AppSuccess<void>(null);
    }

    final timestamp = _now().toUtc();
    final database = _database;
    if (database != null) {
      try {
        if (isFavorite) {
          await database.upsertProgressSnapshot(
            _engagementSnapshot(
              entityType: 'user_reading_favorites',
              passageId: passageId,
              createdAt: timestamp,
            ),
          );
        } else {
          await database.deleteProgressSnapshot(
            entityType: 'user_reading_favorites',
            entityId: passageId,
          );
        }

        final progressRepository = _progressRepository;
        if (progressRepository == null) {
          return const AppSuccess<void>(null);
        }

        return progressRepository.enqueue(
          OutboxEvent(
            eventId: 'favorite-$passageId-${timestamp.microsecondsSinceEpoch}',
            scope: SyncScope.progress,
            entityType: 'user_reading_favorites',
            entityId: passageId,
            operation: OutboxOperation.event,
            payloadJson: jsonEncode(<String, dynamic>{
              'passage_id': passageId,
              'should_favorite': isFavorite,
            }),
          ),
        );
      } catch (error) {
        return AppFailure<void>(
          'Reading favorite could not be updated.',
          cause: error,
        );
      }
    }

    try {
      await applyRemoteFavoriteWrite(
        eventId: 'favorite-$passageId-${timestamp.microsecondsSinceEpoch}',
        passageId: passageId,
        isFavorite: isFavorite,
      );
      return const AppSuccess<void>(null);
    } catch (error) {
      return AppFailure<void>(
        'Reading favorite could not be updated.',
        cause: error,
      );
    }
  }

  @visibleForTesting
  Future<List<ProgressSnapshotRecord>> fetchRemoteBookmarkSnapshots() async {
    final config = _config;
    if (config == null || !config.supabaseEnabled) {
      return const <ProgressSnapshotRecord>[];
    }

    await SupabaseBootstrap.initialize(config);
    final rows =
        (await Supabase.instance.client
                .from('user_reading_bookmarks')
                .select('passage_id,created_at'))
            as List<dynamic>;
    return _mapRemoteRowsToSnapshots(
      entityType: 'user_reading_bookmarks',
      rows: rows,
    );
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
                .from('user_reading_favorites')
                .select('passage_id,created_at'))
            as List<dynamic>;
    return _mapRemoteRowsToSnapshots(
      entityType: 'user_reading_favorites',
      rows: rows,
    );
  }

  @visibleForTesting
  Future<void> applyRemoteBookmarkWrite({
    required String eventId,
    required String passageId,
    required bool isBookmarked,
  }) async {
    final config = _config;
    if (config == null || !config.supabaseEnabled) {
      return;
    }

    await SupabaseBootstrap.initialize(config);
    await Supabase.instance.client.rpc<void>(
      'apply_user_bookmark_event',
      params: <String, dynamic>{
        'p_event_id': eventId,
        'p_passage_id': passageId,
        'p_should_bookmark': isBookmarked,
      },
    );
  }

  @visibleForTesting
  Future<void> applyRemoteFavoriteWrite({
    required String eventId,
    required String passageId,
    required bool isFavorite,
  }) async {
    final config = _config;
    if (config == null || !config.supabaseEnabled) {
      return;
    }

    await SupabaseBootstrap.initialize(config);
    await Supabase.instance.client.rpc<void>(
      'apply_user_favorite_event',
      params: <String, dynamic>{
        'p_event_id': eventId,
        'p_passage_id': passageId,
        'p_should_favorite': isFavorite,
      },
    );
  }

  Future<List<ReadingEngagement>> _readFromLocal() async {
    final database = _database;
    if (database == null) {
      return const <ReadingEngagement>[];
    }

    final bookmarkSnapshots = await database.listProgressSnapshots(
      entityType: 'user_reading_bookmarks',
    );
    final favoriteSnapshots = await database.listProgressSnapshots(
      entityType: 'user_reading_favorites',
    );
    return _mergeSnapshotState(bookmarkSnapshots, favoriteSnapshots);
  }

  Future<List<ReadingEngagement>> _readFromRemote() async {
    try {
      final bookmarkSnapshots = await fetchRemoteBookmarkSnapshots();
      final favoriteSnapshots = await fetchRemoteFavoriteSnapshots();
      return _mergeSnapshotState(bookmarkSnapshots, favoriteSnapshots);
    } catch (_) {
      return const <ReadingEngagement>[];
    }
  }

  List<ProgressSnapshotRecord> _mapRemoteRowsToSnapshots({
    required String entityType,
    required List<dynamic> rows,
  }) {
    return rows
        .whereType<Map<String, dynamic>>()
        .map(
          (row) => ProgressSnapshotRecord(
            entityType: entityType,
            entityId: row['passage_id']?.toString() ?? '',
            payloadJson: jsonEncode(row),
            updatedAt: _readTimestamp(row['created_at']) ?? _now(),
          ),
        )
        .where((record) => record.entityId.isNotEmpty)
        .toList(growable: false);
  }

  List<ReadingEngagement> _mergeSnapshotState(
    List<ProgressSnapshotRecord> bookmarkSnapshots,
    List<ProgressSnapshotRecord> favoriteSnapshots,
  ) {
    final byPassage = <String, ReadingEngagement>{};

    for (final snapshot in bookmarkSnapshots) {
      final payload = _decodePayload(snapshot.payloadJson);
      final passageId = payload['passage_id']?.toString() ?? snapshot.entityId;
      if (passageId.isEmpty) {
        continue;
      }

      final current =
          byPassage[passageId] ?? ReadingEngagement.empty(passageId: passageId);
      byPassage[passageId] = current.setBookmark(
        true,
        at: _readTimestamp(payload['created_at']) ?? snapshot.updatedAt,
      );
    }

    for (final snapshot in favoriteSnapshots) {
      final payload = _decodePayload(snapshot.payloadJson);
      final passageId = payload['passage_id']?.toString() ?? snapshot.entityId;
      if (passageId.isEmpty) {
        continue;
      }

      final current =
          byPassage[passageId] ?? ReadingEngagement.empty(passageId: passageId);
      byPassage[passageId] = current.setFavorite(
        true,
        at: _readTimestamp(payload['created_at']) ?? snapshot.updatedAt,
      );
    }

    return byPassage.values.toList(growable: false);
  }

  ProgressSnapshotRecord _engagementSnapshot({
    required String entityType,
    required String passageId,
    required DateTime createdAt,
  }) {
    return ProgressSnapshotRecord(
      entityType: entityType,
      entityId: passageId,
      payloadJson: jsonEncode(<String, dynamic>{
        'passage_id': passageId,
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
