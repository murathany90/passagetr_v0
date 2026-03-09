import 'dart:convert';

import 'package:shared_core/shared_core.dart';
import 'package:shared_domain/shared_domain.dart';

import '../local/drift/app_database_contract.dart';
import '../local/drift/local_sync_models.dart';
import '../local/drift/local_sync_store.dart';
import '../sync/outbox_conflict_resolver.dart';

class FoundationProgressRepository implements ProgressRepository {
  const FoundationProgressRepository.preview()
    : _database = null,
      _now = _defaultNow;

  FoundationProgressRepository({
    required LocalSyncStore database,
    DateTime Function()? now,
  }) : _database = database,
       _now = now ?? _defaultNow;

  final LocalSyncStore? _database;
  final DateTime Function() _now;

  @override
  Future<List<WordProgress>> fetchWordProgress() async {
    final database = _database;
    if (database == null) {
      return const <WordProgress>[
        WordProgress(wordId: 'word-a', mastery: 48, seenCount: 6),
        WordProgress(wordId: 'word-b', mastery: 72, seenCount: 11),
      ];
    }

    final snapshots = await database.listProgressSnapshots(
      entityType: 'user_word_progress',
    );

    return snapshots
        .map((snapshot) {
          final payload = _decodePayload(snapshot.payloadJson);
          return WordProgress(
            wordId: payload['word_id']?.toString() ?? snapshot.entityId,
            mastery: _readInt(payload['mastery']),
            seenCount: _readInt(payload['seen_count']),
          );
        })
        .where((item) => item.wordId.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<List<ReadingProgress>> fetchReadingProgress() async {
    final database = _database;
    if (database == null) {
      return const <ReadingProgress>[
        ReadingProgress(
          passageId: 'reading-silent-ocean',
          completed: true,
          lastIndex: 18,
        ),
        ReadingProgress(
          passageId: 'reading-brief-history',
          completed: false,
          lastIndex: 9,
        ),
      ];
    }

    final snapshots = await database.listProgressSnapshots(
      entityType: 'user_reading_progress',
    );

    return snapshots
        .map((snapshot) {
          final payload = _decodePayload(snapshot.payloadJson);
          return ReadingProgress(
            passageId: payload['passage_id']?.toString() ?? snapshot.entityId,
            completed: _readBool(payload['completed']),
            lastIndex: _readInt(payload['last_idx']),
          );
        })
        .where((item) => item.passageId.isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<List<GrammarProgress>> fetchGrammarProgress() async {
    final database = _database;
    if (database == null) {
      return const <GrammarProgress>[
        GrammarProgress(
          moduleId: 1,
          pageId: 12,
          lastPageNo: 12,
          completedPages: 12,
          completed: true,
        ),
        GrammarProgress(
          moduleId: 2,
          pageId: 8,
          lastPageNo: 8,
          completedPages: 8,
          completed: false,
        ),
      ];
    }

    final snapshots = await database.listProgressSnapshots(
      entityType: 'user_grammar_progress',
    );

    return snapshots
        .map((snapshot) {
          final payload = _decodePayload(snapshot.payloadJson);
          return GrammarProgress(
            moduleId:
                int.tryParse(
                  payload['module_id']?.toString() ?? snapshot.entityId,
                ) ??
                0,
            pageId: int.tryParse(payload['page_id']?.toString() ?? ''),
            lastPageNo: _readInt(payload['last_page_no']),
            completedPages: _readInt(payload['completed_pages']),
            completed: _readBool(payload['completed']),
          );
        })
        .where((item) => item.moduleId > 0)
        .toList(growable: false);
  }

  @override
  Future<AppResult<void>> enqueue(OutboxEvent event) async {
    if (_database == null) {
      return const AppSuccess<void>(null);
    }

    try {
      final clientTs = _now().toUtc();
      final existingRecords =
          <SyncOutboxRecord>[
                ...await _database.listOutbox(
                  status: AppDatabaseContract.pendingStatus,
                ),
                ...await _database.listOutbox(
                  status: AppDatabaseContract.failedStatus,
                ),
              ]
              .where(
                (record) =>
                    record.entityType == event.entityType &&
                    record.entityId == event.entityId,
              )
              .toList(growable: false);

      final resolution = OutboxConflictResolver.resolve(
        incomingEvent: event,
        existingRecords: existingRecords,
        clientTs: clientTs,
      );

      for (final eventId in resolution.eventIdsToDelete) {
        await _database.deleteOutboxEvent(eventId);
      }

      await _database.enqueueOutbox(resolution.record);
      return const AppSuccess<void>(null);
    } catch (error) {
      return AppFailure<void>(
        'Progress event could not be enqueued.',
        cause: error,
      );
    }
  }

  static DateTime _defaultNow() => DateTime.now().toUtc();

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

  int _readInt(Object? value) {
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

  bool _readBool(Object? value) {
    if (value is bool) {
      return value;
    }
    if (value is String) {
      return value.toLowerCase() == 'true';
    }

    return false;
  }
}
