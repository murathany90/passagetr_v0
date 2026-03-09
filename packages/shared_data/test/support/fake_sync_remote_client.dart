import 'package:shared_data/shared_data.dart';

class FakeSyncRemoteClient implements SyncRemoteClient {
  FakeSyncRemoteClient({
    this.available = true,
    Map<String, List<ContentEntityRecord>>? bootstrapContentByScope,
    Map<String, List<ContentDeltaRecord>>? contentChangesByScope,
    Map<String, List<ProgressSnapshotRecord>>? progressSnapshotsByType,
    Set<String>? failingEventIds,
  }) : _contentChangesByScope =
           contentChangesByScope ?? <String, List<ContentDeltaRecord>>{},
       _bootstrapContentByScope =
           bootstrapContentByScope ?? <String, List<ContentEntityRecord>>{},
       _progressSnapshotsByType =
           progressSnapshotsByType ?? <String, List<ProgressSnapshotRecord>>{},
       _failingEventIds = failingEventIds ?? <String>{};

  final bool available;
  final Map<String, List<ContentEntityRecord>> _bootstrapContentByScope;
  final Map<String, List<ContentDeltaRecord>> _contentChangesByScope;
  final Map<String, List<ProgressSnapshotRecord>> _progressSnapshotsByType;
  final Set<String> _failingEventIds;
  final List<String> appliedEventIds = <String>[];
  final List<String> bootstrapScopes = <String>[];
  final List<String> requestedProgressTypes = <String>[];
  final List<String> requestedScopes = <String>[];

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<List<ContentEntityRecord>> bootstrapContentScope({
    required String scope,
  }) async {
    if (!available) {
      return const <ContentEntityRecord>[];
    }

    bootstrapScopes.add(scope);
    return _bootstrapContentByScope[scope] ?? const <ContentEntityRecord>[];
  }

  @override
  Future<bool> applyOutboxEvent(SyncOutboxRecord record) async {
    if (!available) {
      return false;
    }

    if (_failingEventIds.contains(record.eventId)) {
      throw StateError('Failed to apply ${record.eventId}');
    }

    appliedEventIds.add(record.eventId);
    return true;
  }

  @override
  Future<List<ProgressSnapshotRecord>> fetchProgressSnapshots({
    required String entityType,
  }) async {
    if (!available) {
      return const <ProgressSnapshotRecord>[];
    }

    requestedProgressTypes.add(entityType);
    return _progressSnapshotsByType[entityType] ??
        const <ProgressSnapshotRecord>[];
  }

  @override
  Future<List<ContentDeltaRecord>> pullContentChanges({
    required String scope,
    required int afterId,
    int limit = 100,
  }) async {
    if (!available) {
      return const <ContentDeltaRecord>[];
    }

    requestedScopes.add(scope);
    return _contentChangesByScope[scope]
            ?.where((record) => record.changeId > afterId)
            .take(limit)
            .toList(growable: false) ??
        const <ContentDeltaRecord>[];
  }
}
