import 'package:drift/drift.dart';

import 'app_database_contract.dart';
import 'database_executor_factory.dart';
import 'local_sync_models.dart';
import 'local_sync_store.dart';

class AppDatabase extends GeneratedDatabase implements LocalSyncStore {
  AppDatabase()
    : super(
        DatabaseConnection.delayed(
          createAppDatabaseExecutor().then(DatabaseConnection.new),
        ),
      );

  AppDatabase.inMemory() : super(createInMemoryExecutor());

  @override
  int get schemaVersion => AppDatabaseContract.schemaVersion;

  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      const <TableInfo<Table, Object?>>[];

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await _createSyncMetaTable();
      await _createContentDeltaTable();
      await _createContentEntityTable();
      await _createProgressSnapshotTable();
      await _createSyncOutboxTable();
    },
    onUpgrade: (migrator, from, to) async {
      await _createSyncMetaTable();
      await _createContentDeltaTable();
      await _createContentEntityTable();
      await _createProgressSnapshotTable();
      await _createSyncOutboxTable();
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON;');
    },
  );

  @override
  Future<SyncMetaRecord?> getSyncMeta(String scope) async {
    final row = await customSelect(
      '''
      SELECT scope, last_pull_at, last_server_cursor, last_content_version
      FROM ${AppDatabaseContract.syncMetaTable}
      WHERE scope = ?
      LIMIT 1
      ''',
      variables: <Variable<Object>>[Variable.withString(scope)],
    ).getSingleOrNull();

    if (row == null) {
      return null;
    }

    return SyncMetaRecord(
      scope: row.read<String>('scope'),
      lastPullAt: _readDateTime(row, 'last_pull_at'),
      lastServerCursor: row.readNullable<String>('last_server_cursor'),
      lastContentVersion: row.readNullable<String>('last_content_version'),
    );
  }

  @override
  Future<void> upsertSyncMeta(SyncMetaRecord record) async {
    await customStatement(
      '''
      INSERT INTO ${AppDatabaseContract.syncMetaTable} (
        scope,
        last_pull_at,
        last_server_cursor,
        last_content_version
      )
      VALUES (?, ?, ?, ?)
      ON CONFLICT(scope) DO UPDATE SET
        last_pull_at = excluded.last_pull_at,
        last_server_cursor = excluded.last_server_cursor,
        last_content_version = excluded.last_content_version
      ''',
      <Object?>[
        record.scope,
        record.lastPullAt?.toUtc().toIso8601String(),
        record.lastServerCursor,
        record.lastContentVersion,
      ],
    );
  }

  @override
  Future<void> upsertContentDelta(ContentDeltaRecord record) async {
    await customStatement(
      '''
      INSERT INTO ${AppDatabaseContract.contentDeltaTable} (
        change_id,
        scope,
        entity_type,
        entity_id,
        operation,
        payload_json,
        changed_at
      )
      VALUES (?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(change_id) DO UPDATE SET
        scope = excluded.scope,
        entity_type = excluded.entity_type,
        entity_id = excluded.entity_id,
        operation = excluded.operation,
        payload_json = excluded.payload_json,
        changed_at = excluded.changed_at
      ''',
      <Object?>[
        record.changeId,
        record.scope,
        record.entityType,
        record.entityId,
        record.operation,
        record.payloadJson,
        record.changedAt.toUtc().toIso8601String(),
      ],
    );
  }

  @override
  Future<List<ContentDeltaRecord>> listContentDeltas({
    String? scope,
    int? limit,
  }) async {
    final hasScope = scope != null && scope.isNotEmpty;
    final hasLimit = limit != null && limit > 0;
    final rows = await customSelect(
      '''
      SELECT change_id, scope, entity_type, entity_id, operation, payload_json, changed_at
      FROM ${AppDatabaseContract.contentDeltaTable}
      ${hasScope ? 'WHERE scope = ?' : ''}
      ORDER BY change_id DESC
      ${hasLimit ? 'LIMIT ?' : ''}
      ''',
      variables: <Variable<Object>>[
        if (hasScope) Variable.withString(scope),
        if (hasLimit) Variable.withInt(limit),
      ],
    ).get();

    return rows
        .map(
          (row) => ContentDeltaRecord(
            changeId: row.read<int>('change_id'),
            scope: row.read<String>('scope'),
            entityType: row.read<String>('entity_type'),
            entityId: row.read<String>('entity_id'),
            operation: row.read<String>('operation'),
            payloadJson: row.read<String>('payload_json'),
            changedAt:
                _readDateTime(row, 'changed_at') ?? DateTime.now().toUtc(),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> upsertContentEntity(ContentEntityRecord record) async {
    await customStatement(
      '''
      INSERT INTO ${AppDatabaseContract.contentEntityTable} (
        scope,
        entity_type,
        entity_id,
        payload_json,
        updated_at
      )
      VALUES (?, ?, ?, ?, ?)
      ON CONFLICT(scope, entity_type, entity_id) DO UPDATE SET
        payload_json = excluded.payload_json,
        updated_at = excluded.updated_at
      ''',
      <Object?>[
        record.scope,
        record.entityType,
        record.entityId,
        record.payloadJson,
        record.updatedAt.toUtc().toIso8601String(),
      ],
    );
  }

  @override
  Future<void> deleteContentEntity({
    required String scope,
    required String entityType,
    required String entityId,
  }) async {
    await customStatement(
      '''
      DELETE FROM ${AppDatabaseContract.contentEntityTable}
      WHERE scope = ? AND entity_type = ? AND entity_id = ?
      ''',
      <Object?>[scope, entityType, entityId],
    );
  }

  @override
  Future<List<ContentEntityRecord>> listContentEntities({
    String? scope,
    String? entityType,
  }) async {
    final hasScope = scope != null && scope.isNotEmpty;
    final hasEntityType = entityType != null && entityType.isNotEmpty;
    final rows = await customSelect(
      '''
      SELECT scope, entity_type, entity_id, payload_json, updated_at
      FROM ${AppDatabaseContract.contentEntityTable}
      ${_whereClause(hasScope, hasEntityType)}
      ORDER BY entity_id ASC
      ''',
      variables: <Variable<Object>>[
        if (hasScope) Variable.withString(scope),
        if (hasEntityType) Variable.withString(entityType),
      ],
    ).get();

    return rows
        .map(
          (row) => ContentEntityRecord(
            scope: row.read<String>('scope'),
            entityType: row.read<String>('entity_type'),
            entityId: row.read<String>('entity_id'),
            payloadJson: row.read<String>('payload_json'),
            updatedAt:
                _readDateTime(row, 'updated_at') ?? DateTime.now().toUtc(),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> upsertProgressSnapshot(ProgressSnapshotRecord record) async {
    await customStatement(
      '''
      INSERT INTO ${AppDatabaseContract.progressSnapshotTable} (
        entity_type,
        entity_id,
        payload_json,
        updated_at
      )
      VALUES (?, ?, ?, ?)
      ON CONFLICT(entity_type, entity_id) DO UPDATE SET
        payload_json = excluded.payload_json,
        updated_at = excluded.updated_at
      ''',
      <Object?>[
        record.entityType,
        record.entityId,
        record.payloadJson,
        record.updatedAt.toUtc().toIso8601String(),
      ],
    );
  }

  @override
  Future<ProgressSnapshotRecord?> getProgressSnapshot({
    required String entityType,
    required String entityId,
  }) async {
    final row = await customSelect(
      '''
      SELECT entity_type, entity_id, payload_json, updated_at
      FROM ${AppDatabaseContract.progressSnapshotTable}
      WHERE entity_type = ? AND entity_id = ?
      LIMIT 1
      ''',
      variables: <Variable<Object>>[
        Variable.withString(entityType),
        Variable.withString(entityId),
      ],
    ).getSingleOrNull();

    if (row == null) {
      return null;
    }

    return ProgressSnapshotRecord(
      entityType: row.read<String>('entity_type'),
      entityId: row.read<String>('entity_id'),
      payloadJson: row.read<String>('payload_json'),
      updatedAt: _readDateTime(row, 'updated_at') ?? DateTime.now().toUtc(),
    );
  }

  @override
  Future<List<ProgressSnapshotRecord>> listProgressSnapshots({
    String? entityType,
  }) async {
    final hasEntityType = entityType != null && entityType.isNotEmpty;
    final rows = await customSelect(
      '''
      SELECT entity_type, entity_id, payload_json, updated_at
      FROM ${AppDatabaseContract.progressSnapshotTable}
      ${hasEntityType ? 'WHERE entity_type = ?' : ''}
      ORDER BY entity_id ASC
      ''',
      variables: <Variable<Object>>[
        if (hasEntityType) Variable.withString(entityType),
      ],
    ).get();

    return rows
        .map(
          (row) => ProgressSnapshotRecord(
            entityType: row.read<String>('entity_type'),
            entityId: row.read<String>('entity_id'),
            payloadJson: row.read<String>('payload_json'),
            updatedAt:
                _readDateTime(row, 'updated_at') ?? DateTime.now().toUtc(),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> replaceProgressSnapshots({
    required String entityType,
    required List<ProgressSnapshotRecord> records,
  }) async {
    await transaction(() async {
      await customStatement(
        '''
        DELETE FROM ${AppDatabaseContract.progressSnapshotTable}
        WHERE entity_type = ?
        ''',
        <Object?>[entityType],
      );

      for (final record in records) {
        await upsertProgressSnapshot(record);
      }
    });
  }

  @override
  Future<void> deleteProgressSnapshot({
    required String entityType,
    required String entityId,
  }) async {
    await customStatement(
      '''
      DELETE FROM ${AppDatabaseContract.progressSnapshotTable}
      WHERE entity_type = ? AND entity_id = ?
      ''',
      <Object?>[entityType, entityId],
    );
  }

  @override
  Future<List<SyncOutboxRecord>> listOutbox({
    String status = AppDatabaseContract.pendingStatus,
  }) async {
    final rows = await customSelect(
      '''
      SELECT event_id, entity_type, entity_id, op, payload_json, client_ts, retry_count, status
      , next_retry_at
      FROM ${AppDatabaseContract.syncOutboxTable}
      WHERE status = ?
      ORDER BY client_ts ASC
      ''',
      variables: <Variable<Object>>[Variable.withString(status)],
    ).get();

    return rows
        .map(
          (row) => SyncOutboxRecord(
            eventId: row.read<String>('event_id'),
            entityType: row.read<String>('entity_type'),
            entityId: row.read<String>('entity_id'),
            operation: row.read<String>('op'),
            payloadJson: row.read<String>('payload_json'),
            clientTs: _readDateTime(row, 'client_ts') ?? DateTime.now().toUtc(),
            retryCount: row.read<int>('retry_count'),
            status: row.read<String>('status'),
            nextRetryAt: _readDateTime(row, 'next_retry_at'),
          ),
        )
        .toList(growable: false);
  }

  @override
  Future<void> enqueueOutbox(SyncOutboxRecord record) async {
    await customStatement(
      '''
      INSERT INTO ${AppDatabaseContract.syncOutboxTable} (
        event_id,
        entity_type,
        entity_id,
        op,
        payload_json,
        client_ts,
        retry_count,
        status,
        next_retry_at
      )
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(event_id) DO UPDATE SET
        entity_type = excluded.entity_type,
        entity_id = excluded.entity_id,
        op = excluded.op,
        payload_json = excluded.payload_json,
        client_ts = excluded.client_ts,
        retry_count = excluded.retry_count,
        status = excluded.status,
        next_retry_at = excluded.next_retry_at
      ''',
      <Object?>[
        record.eventId,
        record.entityType,
        record.entityId,
        record.operation,
        record.payloadJson,
        record.clientTs.toUtc().toIso8601String(),
        record.retryCount,
        record.status,
        record.nextRetryAt?.toUtc().toIso8601String(),
      ],
    );
  }

  @override
  Future<void> updateOutboxStatus({
    required String eventId,
    required String status,
    int? retryCount,
    DateTime? nextRetryAt,
  }) async {
    await customStatement(
      '''
      UPDATE ${AppDatabaseContract.syncOutboxTable}
      SET status = ?,
          retry_count = COALESCE(?, retry_count),
          next_retry_at = ?
      WHERE event_id = ?
      ''',
      <Object?>[
        status,
        retryCount,
        nextRetryAt?.toUtc().toIso8601String(),
        eventId,
      ],
    );
  }

  @override
  Future<void> deleteOutboxEvent(String eventId) async {
    await customStatement(
      'DELETE FROM ${AppDatabaseContract.syncOutboxTable} WHERE event_id = ?',
      <Object?>[eventId],
    );
  }

  Future<void> _createSyncMetaTable() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS ${AppDatabaseContract.syncMetaTable} (
        scope TEXT NOT NULL PRIMARY KEY,
        last_pull_at TEXT NULL,
        last_server_cursor TEXT NULL,
        last_content_version TEXT NULL
      )
      ''');
  }

  Future<void> _createContentDeltaTable() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS ${AppDatabaseContract.contentDeltaTable} (
        change_id INTEGER NOT NULL PRIMARY KEY,
        scope TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        operation TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        changed_at TEXT NOT NULL
      )
      ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_content_delta_scope_change_id
      ON ${AppDatabaseContract.contentDeltaTable} (scope, change_id DESC)
      ''');
  }

  Future<void> _createContentEntityTable() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS ${AppDatabaseContract.contentEntityTable} (
        scope TEXT NOT NULL,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (scope, entity_type, entity_id)
      )
      ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_content_entity_scope_type
      ON ${AppDatabaseContract.contentEntityTable} (scope, entity_type)
      ''');
  }

  Future<void> _createProgressSnapshotTable() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS ${AppDatabaseContract.progressSnapshotTable} (
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        PRIMARY KEY (entity_type, entity_id)
      )
      ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_progress_snapshot_type
      ON ${AppDatabaseContract.progressSnapshotTable} (entity_type)
      ''');
  }

  Future<void> _createSyncOutboxTable() async {
    await customStatement('''
      CREATE TABLE IF NOT EXISTS ${AppDatabaseContract.syncOutboxTable} (
        event_id TEXT NOT NULL PRIMARY KEY,
        entity_type TEXT NOT NULL,
        entity_id TEXT NOT NULL,
        op TEXT NOT NULL,
        payload_json TEXT NOT NULL,
        client_ts TEXT NOT NULL,
        retry_count INTEGER NOT NULL DEFAULT 0,
        status TEXT NOT NULL DEFAULT '${AppDatabaseContract.pendingStatus}',
        next_retry_at TEXT NULL
      )
      ''');
    await customStatement('''
      CREATE INDEX IF NOT EXISTS idx_sync_outbox_status_client_ts
      ON ${AppDatabaseContract.syncOutboxTable} (status, client_ts)
      ''');
  }

  String _whereClause(bool hasScope, bool hasEntityType) {
    if (!hasScope && !hasEntityType) {
      return '';
    }

    if (hasScope && hasEntityType) {
      return 'WHERE scope = ? AND entity_type = ?';
    }

    if (hasScope) {
      return 'WHERE scope = ?';
    }

    return 'WHERE entity_type = ?';
  }

  DateTime? _readDateTime(QueryRow row, String column) {
    final rawValue = row.readNullable<String>(column);
    if (rawValue == null || rawValue.isEmpty) {
      return null;
    }

    return DateTime.tryParse(rawValue)?.toUtc();
  }
}
