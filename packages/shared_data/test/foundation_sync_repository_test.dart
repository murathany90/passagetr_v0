import 'package:flutter_test/flutter_test.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_data/shared_data.dart';
import 'package:shared_domain/shared_domain.dart';

import 'support/fake_local_sync_store.dart';
import 'support/fake_sync_remote_client.dart';

void main() {
  group('FoundationSyncRepository', () {
    test(
      'syncIfStale content bootstraps local entity cache and applies deltas',
      () async {
        final database = FakeLocalSyncStore();
        final remoteClient = FakeSyncRemoteClient(
          bootstrapContentByScope: <String, List<ContentEntityRecord>>{
            'packs': <ContentEntityRecord>[
              ContentEntityRecord(
                scope: 'packs',
                entityType: 'packs',
                entityId: 'pack-1',
                payloadJson: '{"id":"pack-1","name":"Pack 1"}',
                updatedAt: DateTime.utc(2026, 3, 9, 12, 55),
              ),
            ],
          },
          contentChangesByScope: <String, List<ContentDeltaRecord>>{
            'packs': <ContentDeltaRecord>[
              ContentDeltaRecord(
                changeId: 11,
                scope: 'packs',
                entityType: 'packs',
                entityId: 'pack-1',
                operation: 'update',
                payloadJson: '{"id":"pack-1","name":"Pack 1 Updated"}',
                changedAt: DateTime.utc(2026, 3, 9, 13, 0),
              ),
            ],
            'readings': <ContentDeltaRecord>[
              ContentDeltaRecord(
                changeId: 21,
                scope: 'readings',
                entityType: 'reading_passages',
                entityId: '00000000-0000-0000-0000-000000000021',
                operation: 'insert',
                payloadJson: '{"id":"00000000-0000-0000-0000-000000000021"}',
                changedAt: DateTime.utc(2026, 3, 9, 13, 5),
              ),
            ],
          },
        );

        final repository = FoundationSyncRepository(
          database: database,
          remoteClient: remoteClient,
          now: () => DateTime.utc(2026, 3, 9, 14, 0),
        );

        final result = await repository.syncIfStale(SyncScope.content);

        expect(result, isA<AppSuccess<void>>());
        expect(
          remoteClient.requestedScopes,
          containsAll(<String>['packs', 'words', 'readings', 'grammar']),
        );
        expect(remoteClient.bootstrapScopes, contains('packs'));

        final deltas = await database.listContentDeltas();
        expect(deltas, hasLength(2));
        final entities = await database.listContentEntities(scope: 'packs');
        expect(entities, hasLength(1));
        expect(entities.first.payloadJson, contains('Updated'));

        final packsMeta = await database.getSyncMeta('content:packs');
        final readingsMeta = await database.getSyncMeta('content:readings');
        expect(packsMeta?.lastServerCursor, '11');
        expect(readingsMeta?.lastServerCursor, '21');
      },
    );

    test('syncNow content bypasses TTL and forces remote refresh', () async {
      final database = FakeLocalSyncStore();
      final remoteClient = FakeSyncRemoteClient(
        contentChangesByScope: <String, List<ContentDeltaRecord>>{
          'grammar': <ContentDeltaRecord>[
            ContentDeltaRecord(
              changeId: 31,
              scope: 'grammar',
              entityType: 'gramer_modulleri',
              entityId: '56',
              operation: 'update',
              payloadJson:
                  '{"id":56,"sira":1,"baslik":"Basics","toplam_sayfa":1,"icon":"menu_book","renk":"#2563EB","is_published":true}',
              changedAt: DateTime.utc(2026, 3, 11, 12, 5),
            ),
          ],
        },
      );
      await database.upsertSyncMeta(
        SyncMetaRecord(
          scope: 'content:grammar',
          lastPullAt: DateTime.utc(2026, 3, 11, 12, 0),
          lastServerCursor: '0',
          lastContentVersion: null,
        ),
      );
      final repository = FoundationSyncRepository(
        database: database,
        remoteClient: remoteClient,
        now: () => DateTime.utc(2026, 3, 11, 12, 10),
      );

      final result = await repository.syncNow(SyncScope.content);

      expect(result, isA<AppSuccess<void>>());
      expect(remoteClient.requestedScopes, contains('grammar'));
      final entities = await database.listContentEntities(scope: 'grammar');
      expect(entities, hasLength(1));
      expect(entities.single.entityType, 'gramer_modulleri');
    });

    test(
      'syncIfStale progress flushes pending outbox and marks records synced',
      () async {
        final database = FakeLocalSyncStore();
        final remoteClient = FakeSyncRemoteClient();
        final repository = FoundationSyncRepository(
          database: database,
          remoteClient: remoteClient,
          now: () => DateTime.utc(2026, 3, 9, 15, 0),
        );

        await database.enqueueOutbox(
          SyncOutboxRecord(
            eventId: 'evt-1',
            entityType: 'user_reading_bookmarks',
            entityId: '00000000-0000-0000-0000-000000000031',
            operation: 'event',
            payloadJson:
                '{"passage_id":"00000000-0000-0000-0000-000000000031","should_bookmark":true}',
            clientTs: DateTime.utc(2026, 3, 9, 14, 50),
            retryCount: 0,
            status: AppDatabaseContract.pendingStatus,
            nextRetryAt: null,
          ),
        );

        final result = await repository.syncIfStale(SyncScope.progress);

        expect(result, isA<AppSuccess<void>>());
        expect(remoteClient.appliedEventIds, <String>['evt-1']);

        final pending = await database.listOutbox(
          status: AppDatabaseContract.pendingStatus,
        );
        final synced = await database.listOutbox(
          status: AppDatabaseContract.syncedStatus,
        );
        expect(
          remoteClient.requestedProgressTypes,
          containsAll(<String>[
            'user_word_progress',
            'user_reading_progress',
            'user_grammar_progress',
          ]),
        );
        expect(pending, isEmpty);
        expect(synced, hasLength(1));
      },
    );

    test(
      'syncIfStale progress increments retry count on remote failure',
      () async {
        final database = FakeLocalSyncStore();
        final remoteClient = FakeSyncRemoteClient(
          failingEventIds: <String>{'evt-fail'},
        );
        final repository = FoundationSyncRepository(
          database: database,
          remoteClient: remoteClient,
          now: () => DateTime.utc(2026, 3, 9, 16, 0),
        );

        await database.enqueueOutbox(
          SyncOutboxRecord(
            eventId: 'evt-fail',
            entityType: 'user_reading_favorites',
            entityId: '00000000-0000-0000-0000-000000000041',
            operation: 'event',
            payloadJson:
                '{"passage_id":"00000000-0000-0000-0000-000000000041","should_favorite":true}',
            clientTs: DateTime.utc(2026, 3, 9, 15, 55),
            retryCount: 0,
            status: AppDatabaseContract.pendingStatus,
            nextRetryAt: null,
          ),
        );

        final result = await repository.syncIfStale(SyncScope.progress);

        expect(result, isA<AppSuccess<void>>());

        final failed = await database.listOutbox(
          status: AppDatabaseContract.failedStatus,
        );
        expect(failed, hasLength(1));
        expect(failed.first.retryCount, 1);
        expect(failed.first.nextRetryAt, isNotNull);
      },
    );

    test(
      'syncIfStale progress stores fetched progress snapshots locally',
      () async {
        final database = FakeLocalSyncStore();
        final remoteClient = FakeSyncRemoteClient(
          progressSnapshotsByType: <String, List<ProgressSnapshotRecord>>{
            'user_word_progress': <ProgressSnapshotRecord>[
              ProgressSnapshotRecord(
                entityType: 'user_word_progress',
                entityId: 'word-1',
                payloadJson: '{"word_id":"word-1","mastery":24}',
                updatedAt: DateTime.utc(2026, 3, 9, 18, 0),
              ),
            ],
          },
        );
        final repository = FoundationSyncRepository(
          database: database,
          remoteClient: remoteClient,
          now: () => DateTime.utc(2026, 3, 9, 18, 5),
        );

        final result = await repository.syncIfStale(SyncScope.progress);

        expect(result, isA<AppSuccess<void>>());
        final snapshots = await database.listProgressSnapshots(
          entityType: 'user_word_progress',
        );
        expect(snapshots, hasLength(1));
        expect(snapshots.first.payloadJson, contains('"mastery":24'));
      },
    );
  });
}
