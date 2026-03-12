import 'package:shared_core/shared_core.dart';
import 'package:shared_domain/shared_domain.dart';

import '../local/drift/app_database_contract.dart';
import '../local/drift/local_sync_models.dart';
import '../local/drift/local_sync_store.dart';
import 'sync_remote_client.dart';

class FoundationSyncRepository implements SyncRepository {
  const FoundationSyncRepository.preview()
    : _database = null,
      _remoteClient = null,
      _now = _defaultNow;

  FoundationSyncRepository({
    required LocalSyncStore database,
    required SyncRemoteClient remoteClient,
    DateTime Function()? now,
  }) : _database = database,
       _remoteClient = remoteClient,
       _now = now ?? _defaultNow;

  final LocalSyncStore? _database;
  final SyncRemoteClient? _remoteClient;
  final DateTime Function() _now;

  @override
  Future<AppResult<void>> syncIfStale(SyncScope scope) async {
    return _runSync(scope, force: false);
  }

  @override
  Future<AppResult<void>> syncNow(SyncScope scope) async {
    return _runSync(scope, force: true);
  }

  Future<AppResult<void>> _runSync(
    SyncScope scope, {
    required bool force,
  }) async {
    if (_database == null) {
      return const AppSuccess<void>(null);
    }

    try {
      switch (scope) {
        case SyncScope.content:
          await _syncContentScope(force: force);
          break;
        case SyncScope.progress:
          final flushedAny = await _flushPendingOutbox();
          await _syncProgressSnapshots(force: force || flushedAny);
          await _touchScope(scope.name);
          break;
        case SyncScope.auth:
        case SyncScope.admin:
          if (force) {
            await _touchScope(scope.name);
          } else {
            await _touchIfExpired(scope.name, _ttlFor(scope));
          }
          break;
      }

      return const AppSuccess<void>(null);
    } catch (error) {
      return AppFailure<void>('Sync bootstrap failed.', cause: error);
    }
  }

  Future<void> _syncContentScope({bool force = false}) async {
    final database = _database;
    final remoteClient = _remoteClient;
    if (database == null ||
        remoteClient == null ||
        !await remoteClient.isAvailable()) {
      return;
    }

    final scopes = <String>['packs', 'words', 'readings', 'grammar'];
    final now = _now().toUtc();

    for (final remoteScope in scopes) {
      final localScope = 'content:$remoteScope';
      final meta = await database.getSyncMeta(localScope);
      final existingMirror = await database.listContentEntities(
        scope: remoteScope,
      );
      final needsBootstrap = existingMirror.isEmpty;

      if (needsBootstrap) {
        final bootstrap = await remoteClient.bootstrapContentScope(
          scope: remoteScope,
        );
        for (final entity in bootstrap) {
          await database.upsertContentEntity(entity);
        }
      }

      if (!force &&
          !_isExpired(meta?.lastPullAt, _ttlFor(SyncScope.content)) &&
          !needsBootstrap) {
        continue;
      }

      var afterId = int.tryParse(meta?.lastServerCursor ?? '0') ?? 0;
      while (true) {
        final changes = await remoteClient.pullContentChanges(
          scope: remoteScope,
          afterId: afterId,
          limit: 100,
        );

        if (changes.isEmpty) {
          break;
        }

        for (final change in changes) {
          await database.upsertContentDelta(change);
          await _applyContentDelta(change);
          afterId = change.changeId;
        }

        if (changes.length < 100) {
          break;
        }
      }

      await database.upsertSyncMeta(
        SyncMetaRecord(
          scope: localScope,
          lastPullAt: now,
          lastServerCursor: afterId.toString(),
          lastContentVersion: meta?.lastContentVersion,
        ),
      );
    }

    await database.upsertSyncMeta(
      SyncMetaRecord(
        scope: SyncScope.content.name,
        lastPullAt: now,
        lastServerCursor: null,
        lastContentVersion: null,
      ),
    );
  }

  Future<void> _applyContentDelta(ContentDeltaRecord change) async {
    final database = _database;
    if (database == null) {
      return;
    }

    if (change.operation == 'delete') {
      await database.deleteContentEntity(
        scope: change.scope,
        entityType: change.entityType,
        entityId: change.entityId,
      );
      return;
    }

    await database.upsertContentEntity(
      ContentEntityRecord(
        scope: change.scope,
        entityType: change.entityType,
        entityId: change.entityId,
        payloadJson: change.payloadJson,
        updatedAt: change.changedAt,
      ),
    );
  }

  Future<void> _syncProgressSnapshots({bool force = false}) async {
    final database = _database;
    final remoteClient = _remoteClient;
    if (database == null ||
        remoteClient == null ||
        !await remoteClient.isAvailable()) {
      return;
    }

    final entityTypes = <String>[
      'user_word_progress',
      'user_word_favorites',
      'user_reading_progress',
      'user_grammar_progress',
      'user_reading_bookmarks',
      'user_reading_favorites',
    ];
    final now = _now().toUtc();

    for (final entityType in entityTypes) {
      final scope = 'progress:$entityType';
      final meta = await database.getSyncMeta(scope);
      if (!force &&
          !_isExpired(meta?.lastPullAt, _ttlFor(SyncScope.progress))) {
        continue;
      }

      final snapshots = await remoteClient.fetchProgressSnapshots(
        entityType: entityType,
      );
      if (_shouldReplaceProgressSnapshots(entityType)) {
        await database.replaceProgressSnapshots(
          entityType: entityType,
          records: snapshots,
        );
      } else {
        for (final snapshot in snapshots) {
          await database.upsertProgressSnapshot(snapshot);
        }
      }

      await database.upsertSyncMeta(
        SyncMetaRecord(
          scope: scope,
          lastPullAt: now,
          lastServerCursor: null,
          lastContentVersion: null,
        ),
      );
    }
  }

  Future<bool> _flushPendingOutbox() async {
    final database = _database;
    final remoteClient = _remoteClient;
    if (database == null ||
        remoteClient == null ||
        !await remoteClient.isAvailable()) {
      return false;
    }

    final now = _now().toUtc();
    final pending = <SyncOutboxRecord>[
      ...await database.listOutbox(status: AppDatabaseContract.pendingStatus),
      ...await _eligibleFailedRecords(now),
    ];

    var flushedAny = false;
    for (final record in pending) {
      try {
        final applied = await remoteClient.applyOutboxEvent(record);
        if (!applied) {
          continue;
        }
        flushedAny = true;
        await database.updateOutboxStatus(
          eventId: record.eventId,
          status: AppDatabaseContract.syncedStatus,
          retryCount: record.retryCount,
          nextRetryAt: null,
        );
      } catch (_) {
        final nextRetryCount = record.retryCount + 1;
        final exceededRetryBudget = nextRetryCount >= 5;
        await database.updateOutboxStatus(
          eventId: record.eventId,
          status: exceededRetryBudget
              ? AppDatabaseContract.deadLetterStatus
              : AppDatabaseContract.failedStatus,
          retryCount: nextRetryCount,
          nextRetryAt: exceededRetryBudget
              ? null
              : now.add(
                  Duration(minutes: 1 << (nextRetryCount - 1).clamp(0, 4)),
                ),
        );
      }
    }

    return flushedAny;
  }

  Future<List<SyncOutboxRecord>> _eligibleFailedRecords(DateTime now) async {
    final database = _database;
    if (database == null) {
      return const <SyncOutboxRecord>[];
    }

    final failed = await database.listOutbox(
      status: AppDatabaseContract.failedStatus,
    );
    return failed
        .where(
          (record) =>
              record.nextRetryAt == null || !record.nextRetryAt!.isAfter(now),
        )
        .toList(growable: false);
  }

  Future<void> _touchIfExpired(String scope, Duration ttl) async {
    final meta = await _database!.getSyncMeta(scope);
    if (!_isExpired(meta?.lastPullAt, ttl)) {
      return;
    }

    await _touchScope(
      scope,
      lastServerCursor: meta?.lastServerCursor,
      lastContentVersion: meta?.lastContentVersion,
    );
  }

  Future<void> _touchScope(
    String scope, {
    String? lastServerCursor,
    String? lastContentVersion,
  }) async {
    await _database!.upsertSyncMeta(
      SyncMetaRecord(
        scope: scope,
        lastPullAt: _now().toUtc(),
        lastServerCursor: lastServerCursor,
        lastContentVersion: lastContentVersion,
      ),
    );
  }

  bool _isExpired(DateTime? lastPullAt, Duration ttl) {
    if (lastPullAt == null) {
      return true;
    }

    return _now().toUtc().difference(lastPullAt) >= ttl;
  }

  Duration _ttlFor(SyncScope scope) {
    return switch (scope) {
      SyncScope.auth => const Duration(minutes: 5),
      SyncScope.content => const Duration(hours: 6),
      SyncScope.progress => const Duration(seconds: 30),
      SyncScope.admin => const Duration(minutes: 1),
    };
  }

  bool _shouldReplaceProgressSnapshots(String entityType) {
    return entityType == 'user_reading_bookmarks' ||
        entityType == 'user_reading_favorites' ||
        entityType == 'user_word_favorites';
  }

  static DateTime _defaultNow() => DateTime.now().toUtc();
}
