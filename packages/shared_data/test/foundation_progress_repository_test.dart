import 'package:flutter_test/flutter_test.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_data/shared_data.dart';
import 'package:shared_domain/shared_domain.dart';

import 'support/fake_local_sync_store.dart';

void main() {
  group('FoundationProgressRepository', () {
    test(
      'fetchWordProgress returns preview defaults when database is absent',
      () async {
        const repository = FoundationProgressRepository.preview();

        final progress = await repository.fetchWordProgress();

        expect(progress, hasLength(2));
        expect(progress.first.wordId, 'word-a');
        expect(progress.first.mastery, 48);
      },
    );

    test('fetchWordProgress reads cached snapshots from local store', () async {
      final database = FakeLocalSyncStore();
      final repository = FoundationProgressRepository(
        database: database,
        now: () => DateTime.utc(2026, 3, 9, 9, 55),
      );

      await database.upsertProgressSnapshot(
        ProgressSnapshotRecord(
          entityType: 'user_word_progress',
          entityId: 'word-99',
          payloadJson: '{"word_id":"word-99","mastery":63,"seen_count":9}',
          updatedAt: DateTime.utc(2026, 3, 9, 9, 50),
        ),
      );

      final progress = await repository.fetchWordProgress();

      expect(progress, hasLength(1));
      expect(progress.single.wordId, 'word-99');
      expect(progress.single.mastery, 63);
      expect(progress.single.seenCount, 9);
    });

    test(
      'fetchGrammarProgress reads cached grammar snapshots from local store',
      () async {
        final database = FakeLocalSyncStore();
        final repository = FoundationProgressRepository(
          database: database,
          now: () => DateTime.utc(2026, 3, 9, 9, 56),
        );

        await database.upsertProgressSnapshot(
          ProgressSnapshotRecord(
            entityType: 'user_grammar_progress',
            entityId: '2',
            payloadJson:
                '{"module_id":2,"page_id":8,"last_page_no":8,"completed_pages":8,"completed":false}',
            updatedAt: DateTime.utc(2026, 3, 9, 9, 51),
          ),
        );

        final progress = await repository.fetchGrammarProgress();

        expect(progress, hasLength(1));
        expect(progress.single.moduleId, 2);
        expect(progress.single.lastPageNo, 8);
        expect(progress.single.completed, isFalse);
      },
    );

    test('enqueue writes event into pending outbox', () async {
      final database = FakeLocalSyncStore();

      final repository = FoundationProgressRepository(
        database: database,
        now: () => DateTime.utc(2026, 3, 9, 10, 0),
      );

      final result = await repository.enqueue(
        const OutboxEvent(
          eventId: 'evt-progress-1',
          scope: SyncScope.progress,
          entityType: 'word_progress',
          entityId: 'word-42',
          operation: OutboxOperation.upsert,
          payloadJson: '{"mastery":3}',
        ),
      );

      expect(result, isA<AppSuccess<void>>());

      final outbox = await database.listOutbox();
      expect(outbox, hasLength(1));
      expect(outbox.first.eventId, 'evt-progress-1');
      expect(outbox.first.entityType, 'word_progress');
      expect(outbox.first.operation, OutboxOperation.upsert.name);
      expect(outbox.first.status, AppDatabaseContract.pendingStatus);
    });

    test(
      'enqueue merges reading progress events into the newest payload',
      () async {
        final database = FakeLocalSyncStore();
        final repository = FoundationProgressRepository(
          database: database,
          now: () => DateTime.utc(2026, 3, 9, 10, 5),
        );

        await database.enqueueOutbox(
          SyncOutboxRecord(
            eventId: 'evt-progress-old',
            entityType: 'user_reading_progress',
            entityId: 'passage-11',
            operation: OutboxOperation.event.name,
            payloadJson:
                '{"passage_id":"passage-11","last_idx":9,"completed":false}',
            clientTs: DateTime.utc(2026, 3, 9, 10, 0),
            retryCount: 1,
            status: AppDatabaseContract.failedStatus,
            nextRetryAt: DateTime.utc(2026, 3, 9, 10, 1),
          ),
        );

        final result = await repository.enqueue(
          const OutboxEvent(
            eventId: 'evt-progress-new',
            scope: SyncScope.progress,
            entityType: 'user_reading_progress',
            entityId: 'passage-11',
            operation: OutboxOperation.event,
            payloadJson:
                '{"passage_id":"passage-11","last_idx":14,"completed":true}',
          ),
        );

        expect(result, isA<AppSuccess<void>>());

        final pending = await database.listOutbox(
          status: AppDatabaseContract.pendingStatus,
        );
        final failed = await database.listOutbox(
          status: AppDatabaseContract.failedStatus,
        );

        expect(failed, isEmpty);
        expect(pending, hasLength(1));
        expect(pending.first.eventId, 'evt-progress-new');
        expect(pending.first.payloadJson, contains('"last_idx":14'));
        expect(pending.first.payloadJson, contains('"completed":true'));
        expect(pending.first.retryCount, 0);
      },
    );

    test(
      'enqueue keeps newest bookmark intent and removes older duplicates',
      () async {
        final database = FakeLocalSyncStore();
        final repository = FoundationProgressRepository(
          database: database,
          now: () => DateTime.utc(2026, 3, 9, 10, 10),
        );

        await database.enqueueOutbox(
          SyncOutboxRecord(
            eventId: 'evt-bookmark-old',
            entityType: 'user_reading_bookmarks',
            entityId: 'passage-12',
            operation: OutboxOperation.event.name,
            payloadJson: '{"passage_id":"passage-12","should_bookmark":true}',
            clientTs: DateTime.utc(2026, 3, 9, 10, 2),
            retryCount: 0,
            status: AppDatabaseContract.pendingStatus,
            nextRetryAt: null,
          ),
        );

        final result = await repository.enqueue(
          const OutboxEvent(
            eventId: 'evt-bookmark-new',
            scope: SyncScope.progress,
            entityType: 'user_reading_bookmarks',
            entityId: 'passage-12',
            operation: OutboxOperation.event,
            payloadJson: '{"passage_id":"passage-12","should_bookmark":false}',
          ),
        );

        expect(result, isA<AppSuccess<void>>());

        final pending = await database.listOutbox(
          status: AppDatabaseContract.pendingStatus,
        );
        expect(pending, hasLength(1));
        expect(pending.first.eventId, 'evt-bookmark-new');
        expect(pending.first.payloadJson, contains('"should_bookmark":false'));
      },
    );

    test(
      'enqueue keeps newest word favorite intent and removes older duplicates',
      () async {
        final database = FakeLocalSyncStore();
        final repository = FoundationProgressRepository(
          database: database,
          now: () => DateTime.utc(2026, 3, 13, 10, 10),
        );

        await database.enqueueOutbox(
          SyncOutboxRecord(
            eventId: 'evt-word-favorite-old',
            entityType: 'user_word_favorites',
            entityId: 'word-12',
            operation: OutboxOperation.event.name,
            payloadJson: '{"word_id":"word-12","should_favorite":true}',
            clientTs: DateTime.utc(2026, 3, 13, 10, 2),
            retryCount: 0,
            status: AppDatabaseContract.pendingStatus,
            nextRetryAt: null,
          ),
        );

        final result = await repository.enqueue(
          const OutboxEvent(
            eventId: 'evt-word-favorite-new',
            scope: SyncScope.progress,
            entityType: 'user_word_favorites',
            entityId: 'word-12',
            operation: OutboxOperation.event,
            payloadJson: '{"word_id":"word-12","should_favorite":false}',
          ),
        );

        expect(result, isA<AppSuccess<void>>());

        final pending = await database.listOutbox(
          status: AppDatabaseContract.pendingStatus,
        );
        expect(pending, hasLength(1));
        expect(pending.first.eventId, 'evt-word-favorite-new');
        expect(pending.first.payloadJson, contains('"should_favorite":false'));
      },
    );

    test('enqueue merges word progress deltas into newest payload', () async {
      final database = FakeLocalSyncStore();
      final repository = FoundationProgressRepository(
        database: database,
        now: () => DateTime.utc(2026, 3, 9, 10, 15),
      );

      await database.enqueueOutbox(
        SyncOutboxRecord(
          eventId: 'evt-word-old',
          entityType: 'user_word_progress',
          entityId: 'word-42',
          operation: OutboxOperation.event.name,
          payloadJson:
              '{"word_id":"word-42","answer":"unsure","seen_count_delta":1,"correct_count_delta":0,"wrong_count_delta":1,"mastery_delta":-4}',
          clientTs: DateTime.utc(2026, 3, 9, 10, 5),
          retryCount: 0,
          status: AppDatabaseContract.pendingStatus,
          nextRetryAt: null,
        ),
      );

      final result = await repository.enqueue(
        const OutboxEvent(
          eventId: 'evt-word-new',
          scope: SyncScope.progress,
          entityType: 'user_word_progress',
          entityId: 'word-42',
          operation: OutboxOperation.event,
          payloadJson:
              '{"word_id":"word-42","answer":"known","seen_count_delta":1,"correct_count_delta":1,"wrong_count_delta":0,"mastery_delta":12}',
        ),
      );

      expect(result, isA<AppSuccess<void>>());

      final pending = await database.listOutbox(
        status: AppDatabaseContract.pendingStatus,
      );
      expect(pending, hasLength(1));
      expect(pending.single.eventId, 'evt-word-new');
      expect(pending.single.payloadJson, contains('"answer":"known"'));
      expect(pending.single.payloadJson, contains('"seen_count_delta":2'));
      expect(pending.single.payloadJson, contains('"correct_count_delta":1'));
      expect(pending.single.payloadJson, contains('"wrong_count_delta":1'));
      expect(pending.single.payloadJson, contains('"mastery_delta":8'));
    });
  });
}
