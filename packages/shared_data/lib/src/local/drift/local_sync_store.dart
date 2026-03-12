import 'local_sync_models.dart';

abstract interface class LocalSyncStore {
  Future<SyncMetaRecord?> getSyncMeta(String scope);
  Future<void> upsertSyncMeta(SyncMetaRecord record);
  Future<void> upsertContentDelta(ContentDeltaRecord record);
  Future<List<ContentDeltaRecord>> listContentDeltas({
    String? scope,
    int? limit,
  });
  Future<void> upsertContentEntity(ContentEntityRecord record);
  Future<void> deleteContentEntity({
    required String scope,
    required String entityType,
    required String entityId,
  });
  Future<List<ContentEntityRecord>> listContentEntities({
    String? scope,
    String? entityType,
  });
  Future<void> upsertProgressSnapshot(ProgressSnapshotRecord record);
  Future<ProgressSnapshotRecord?> getProgressSnapshot({
    required String entityType,
    required String entityId,
  });
  Future<List<ProgressSnapshotRecord>> listProgressSnapshots({
    String? entityType,
  });
  Future<void> replaceProgressSnapshots({
    required String entityType,
    required List<ProgressSnapshotRecord> records,
  });
  Future<void> deleteProgressSnapshot({
    required String entityType,
    required String entityId,
  });
  Future<List<SyncOutboxRecord>> listOutbox({String status = 'pending'});
  Future<void> enqueueOutbox(SyncOutboxRecord record);
  Future<void> updateOutboxStatus({
    required String eventId,
    required String status,
    int? retryCount,
    DateTime? nextRetryAt,
  });
  Future<void> deleteOutboxEvent(String eventId);
}
