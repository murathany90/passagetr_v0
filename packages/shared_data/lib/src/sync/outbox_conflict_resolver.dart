import 'dart:convert';

import 'package:shared_domain/shared_domain.dart';

import '../local/drift/app_database_contract.dart';
import '../local/drift/local_sync_models.dart';

class ConflictResolutionResult {
  const ConflictResolutionResult({
    required this.record,
    required this.eventIdsToDelete,
  });

  final SyncOutboxRecord record;
  final List<String> eventIdsToDelete;
}

class OutboxConflictResolver {
  const OutboxConflictResolver._();

  static ConflictResolutionResult resolve({
    required OutboxEvent incomingEvent,
    required List<SyncOutboxRecord> existingRecords,
    required DateTime clientTs,
  }) {
    final candidateIds = existingRecords
        .where(
          (record) =>
              _isMergeable(record.entityType) &&
              record.entityType == incomingEvent.entityType &&
              record.entityId == incomingEvent.entityId,
        )
        .map((record) => record.eventId)
        .toList(growable: false);

    final payloadJson = _mergePayload(
      entityType: incomingEvent.entityType,
      incomingPayloadJson: incomingEvent.payloadJson,
      existingRecords: existingRecords,
    );

    return ConflictResolutionResult(
      record: SyncOutboxRecord(
        eventId: incomingEvent.eventId,
        entityType: incomingEvent.entityType,
        entityId: incomingEvent.entityId,
        operation: incomingEvent.operation.name,
        payloadJson: payloadJson,
        clientTs: clientTs,
        retryCount: 0,
        status: AppDatabaseContract.pendingStatus,
        nextRetryAt: null,
      ),
      eventIdsToDelete: candidateIds,
    );
  }

  static bool _isMergeable(String entityType) {
    return switch (entityType) {
      'user_reading_progress' ||
      'user_word_progress' ||
      'user_grammar_progress' ||
      'user_reading_bookmarks' ||
      'user_reading_favorites' => true,
      _ => false,
    };
  }

  static String _mergePayload({
    required String entityType,
    required String incomingPayloadJson,
    required List<SyncOutboxRecord> existingRecords,
  }) {
    if (!_isMergeable(entityType)) {
      return incomingPayloadJson;
    }

    final incomingPayload = _decodePayload(incomingPayloadJson);

    return switch (entityType) {
      'user_reading_progress' => jsonEncode(
        _mergeReadingProgressPayload(incomingPayload, existingRecords),
      ),
      'user_word_progress' => jsonEncode(
        _mergeWordProgressPayload(incomingPayload, existingRecords),
      ),
      'user_grammar_progress' => jsonEncode(
        _mergeGrammarProgressPayload(incomingPayload, existingRecords),
      ),
      'user_reading_bookmarks' ||
      'user_reading_favorites' => jsonEncode(incomingPayload),
      _ => incomingPayloadJson,
    };
  }

  static Map<String, dynamic> _mergeReadingProgressPayload(
    Map<String, dynamic> incomingPayload,
    List<SyncOutboxRecord> existingRecords,
  ) {
    var lastIdx = _readInt(incomingPayload['last_idx']);
    var completed = _readBool(incomingPayload['completed']);

    for (final record in existingRecords) {
      if (record.entityType != 'user_reading_progress') {
        continue;
      }

      final payload = _decodePayload(record.payloadJson);
      lastIdx = lastIdx > _readInt(payload['last_idx'])
          ? lastIdx
          : _readInt(payload['last_idx']);
      completed = completed || _readBool(payload['completed']);
    }

    return <String, dynamic>{
      ...incomingPayload,
      'last_idx': lastIdx,
      'completed': completed,
    };
  }

  static Map<String, dynamic> _mergeWordProgressPayload(
    Map<String, dynamic> incomingPayload,
    List<SyncOutboxRecord> existingRecords,
  ) {
    var seenCountDelta = _readInt(incomingPayload['seen_count_delta']);
    var correctCountDelta = _readInt(incomingPayload['correct_count_delta']);
    var wrongCountDelta = _readInt(incomingPayload['wrong_count_delta']);
    var masteryDelta = _readInt(incomingPayload['mastery_delta']);

    for (final record in existingRecords) {
      if (record.entityType != 'user_word_progress') {
        continue;
      }

      final payload = _decodePayload(record.payloadJson);
      seenCountDelta += _readInt(payload['seen_count_delta']);
      correctCountDelta += _readInt(payload['correct_count_delta']);
      wrongCountDelta += _readInt(payload['wrong_count_delta']);
      masteryDelta += _readInt(payload['mastery_delta']);
    }

    return <String, dynamic>{
      ...incomingPayload,
      'seen_count_delta': seenCountDelta,
      'correct_count_delta': correctCountDelta,
      'wrong_count_delta': wrongCountDelta,
      'mastery_delta': masteryDelta,
    };
  }

  static Map<String, dynamic> _mergeGrammarProgressPayload(
    Map<String, dynamic> incomingPayload,
    List<SyncOutboxRecord> existingRecords,
  ) {
    var completedPages = _readInt(incomingPayload['completed_pages']);
    var lastPageNo = _readInt(incomingPayload['last_page_no']);
    var completed = _readBool(incomingPayload['completed']);
    Object? pageId = incomingPayload['page_id'];

    for (final record in existingRecords) {
      if (record.entityType != 'user_grammar_progress') {
        continue;
      }

      final payload = _decodePayload(record.payloadJson);
      completedPages = completedPages > _readInt(payload['completed_pages'])
          ? completedPages
          : _readInt(payload['completed_pages']);
      lastPageNo = lastPageNo > _readInt(payload['last_page_no'])
          ? lastPageNo
          : _readInt(payload['last_page_no']);
      completed = completed || _readBool(payload['completed']);
      pageId ??= payload['page_id'];
    }

    return <String, dynamic>{
      ...incomingPayload,
      'page_id': pageId,
      'completed_pages': completedPages,
      'last_page_no': lastPageNo,
      'completed': completed,
    };
  }

  static Map<String, dynamic> _decodePayload(String payloadJson) {
    final decoded = jsonDecode(payloadJson);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    }

    throw const FormatException('Outbox payload must decode to a JSON object.');
  }

  static int _readInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }

    return 0;
  }

  static bool _readBool(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is String) {
      return value.toLowerCase() == 'true';
    }

    return false;
  }
}
