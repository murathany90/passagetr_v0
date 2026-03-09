import '../local/drift/local_sync_models.dart';

abstract interface class SyncRemoteClient {
  Future<bool> isAvailable();

  Future<List<ContentEntityRecord>> bootstrapContentScope({
    required String scope,
  });

  Future<List<ProgressSnapshotRecord>> fetchProgressSnapshots({
    required String entityType,
  });

  Future<List<ContentDeltaRecord>> pullContentChanges({
    required String scope,
    required int afterId,
    int limit = 100,
  });

  Future<bool> applyOutboxEvent(SyncOutboxRecord record);
}
