class SyncMetaRecord {
  const SyncMetaRecord({
    required this.scope,
    required this.lastPullAt,
    required this.lastServerCursor,
    required this.lastContentVersion,
  });

  final String scope;
  final DateTime? lastPullAt;
  final String? lastServerCursor;
  final String? lastContentVersion;
}

class ContentDeltaRecord {
  const ContentDeltaRecord({
    required this.changeId,
    required this.scope,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payloadJson,
    required this.changedAt,
  });

  final int changeId;
  final String scope;
  final String entityType;
  final String entityId;
  final String operation;
  final String payloadJson;
  final DateTime changedAt;
}

class ContentEntityRecord {
  const ContentEntityRecord({
    required this.scope,
    required this.entityType,
    required this.entityId,
    required this.payloadJson,
    required this.updatedAt,
  });

  final String scope;
  final String entityType;
  final String entityId;
  final String payloadJson;
  final DateTime updatedAt;
}

class ProgressSnapshotRecord {
  const ProgressSnapshotRecord({
    required this.entityType,
    required this.entityId,
    required this.payloadJson,
    required this.updatedAt,
  });

  final String entityType;
  final String entityId;
  final String payloadJson;
  final DateTime updatedAt;
}

class SyncOutboxRecord {
  const SyncOutboxRecord({
    required this.eventId,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payloadJson,
    required this.clientTs,
    required this.retryCount,
    required this.status,
    required this.nextRetryAt,
  });

  final String eventId;
  final String entityType;
  final String entityId;
  final String operation;
  final String payloadJson;
  final DateTime clientTs;
  final int retryCount;
  final String status;
  final DateTime? nextRetryAt;
}
