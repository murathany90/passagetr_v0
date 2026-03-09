import 'package:shared_data/shared_data.dart';

class FakeLocalSyncStore implements LocalSyncStore {
  final Map<String, SyncMetaRecord> _metaByScope = <String, SyncMetaRecord>{};
  final Map<int, ContentDeltaRecord> _contentDeltas =
      <int, ContentDeltaRecord>{};
  final Map<String, ContentEntityRecord> _contentEntities =
      <String, ContentEntityRecord>{};
  final Map<String, ProgressSnapshotRecord> _progressSnapshots =
      <String, ProgressSnapshotRecord>{};
  final Map<String, SyncOutboxRecord> _outboxById =
      <String, SyncOutboxRecord>{};

  @override
  Future<void> deleteOutboxEvent(String eventId) async {
    _outboxById.remove(eventId);
  }

  @override
  Future<void> enqueueOutbox(SyncOutboxRecord record) async {
    _outboxById[record.eventId] = record;
  }

  @override
  Future<void> deleteContentEntity({
    required String scope,
    required String entityType,
    required String entityId,
  }) async {
    _contentEntities.remove(_contentEntityKey(scope, entityType, entityId));
  }

  @override
  Future<List<ContentDeltaRecord>> listContentDeltas({
    String? scope,
    int? limit,
  }) async {
    final items =
        _contentDeltas.values
            .where((record) => scope == null || record.scope == scope)
            .toList(growable: false)
          ..sort((left, right) => right.changeId.compareTo(left.changeId));

    if (limit == null || limit <= 0 || items.length <= limit) {
      return items;
    }

    return items.take(limit).toList(growable: false);
  }

  @override
  Future<List<ContentEntityRecord>> listContentEntities({
    String? scope,
    String? entityType,
  }) async {
    final items =
        _contentEntities.values
            .where(
              (record) =>
                  (scope == null || record.scope == scope) &&
                  (entityType == null || record.entityType == entityType),
            )
            .toList(growable: false)
          ..sort((left, right) => left.entityId.compareTo(right.entityId));

    return items;
  }

  @override
  Future<SyncMetaRecord?> getSyncMeta(String scope) async {
    return _metaByScope[scope];
  }

  @override
  Future<ProgressSnapshotRecord?> getProgressSnapshot({
    required String entityType,
    required String entityId,
  }) async {
    return _progressSnapshots[_progressKey(entityType, entityId)];
  }

  @override
  Future<List<SyncOutboxRecord>> listOutbox({
    String status = AppDatabaseContract.pendingStatus,
  }) async {
    return _outboxById.values
        .where((record) => record.status == status)
        .toList(growable: false)
      ..sort((left, right) => left.clientTs.compareTo(right.clientTs));
  }

  @override
  Future<List<ProgressSnapshotRecord>> listProgressSnapshots({
    String? entityType,
  }) async {
    final items =
        _progressSnapshots.values
            .where(
              (record) => entityType == null || record.entityType == entityType,
            )
            .toList(growable: false)
          ..sort((left, right) => left.entityId.compareTo(right.entityId));

    return items;
  }

  @override
  Future<void> updateOutboxStatus({
    required String eventId,
    required String status,
    int? retryCount,
    DateTime? nextRetryAt,
  }) async {
    final existing = _outboxById[eventId];
    if (existing == null) {
      return;
    }

    _outboxById[eventId] = SyncOutboxRecord(
      eventId: existing.eventId,
      entityType: existing.entityType,
      entityId: existing.entityId,
      operation: existing.operation,
      payloadJson: existing.payloadJson,
      clientTs: existing.clientTs,
      retryCount: retryCount ?? existing.retryCount,
      status: status,
      nextRetryAt: nextRetryAt ?? existing.nextRetryAt,
    );
  }

  @override
  Future<void> upsertSyncMeta(SyncMetaRecord record) async {
    _metaByScope[record.scope] = record;
  }

  @override
  Future<void> upsertContentEntity(ContentEntityRecord record) async {
    _contentEntities[_contentEntityKey(
          record.scope,
          record.entityType,
          record.entityId,
        )] =
        record;
  }

  @override
  Future<void> upsertContentDelta(ContentDeltaRecord record) async {
    _contentDeltas[record.changeId] = record;
  }

  @override
  Future<void> upsertProgressSnapshot(ProgressSnapshotRecord record) async {
    _progressSnapshots[_progressKey(record.entityType, record.entityId)] =
        record;
  }

  String _contentEntityKey(String scope, String entityType, String entityId) {
    return '$scope::$entityType::$entityId';
  }

  String _progressKey(String entityType, String entityId) {
    return '$entityType::$entityId';
  }
}
