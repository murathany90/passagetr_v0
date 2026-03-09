import 'sync_scope.dart';

enum OutboxOperation { event, upsert, delete }

class OutboxEvent {
  const OutboxEvent({
    required this.eventId,
    required this.scope,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.payloadJson,
  });

  final String eventId;
  final SyncScope scope;
  final String entityType;
  final String entityId;
  final OutboxOperation operation;
  final String payloadJson;
}
