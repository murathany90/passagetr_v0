import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_data/shared_data.dart';
import 'package:shared_domain/shared_domain.dart';

import 'support/fake_local_sync_store.dart';

void main() {
  group('FoundationReadingEngagementRepository local mode', () {
    test('fetchAll merges bookmark and favorite snapshots', () async {
      final database = FakeLocalSyncStore();
      await database.upsertProgressSnapshot(
        ProgressSnapshotRecord(
          entityType: 'user_reading_bookmarks',
          entityId: 'reading-1',
          payloadJson:
              '{"passage_id":"reading-1","created_at":"2026-03-09T10:00:00Z"}',
          updatedAt: DateTime.utc(2026, 3, 9, 10, 0),
        ),
      );
      await database.upsertProgressSnapshot(
        ProgressSnapshotRecord(
          entityType: 'user_reading_favorites',
          entityId: 'reading-1',
          payloadJson:
              '{"passage_id":"reading-1","created_at":"2026-03-09T10:05:00Z"}',
          updatedAt: DateTime.utc(2026, 3, 9, 10, 5),
        ),
      );
      await database.upsertProgressSnapshot(
        ProgressSnapshotRecord(
          entityType: 'user_reading_favorites',
          entityId: 'reading-2',
          payloadJson:
              '{"passage_id":"reading-2","created_at":"2026-03-09T11:00:00Z"}',
          updatedAt: DateTime.utc(2026, 3, 9, 11, 0),
        ),
      );

      final repository = FoundationReadingEngagementRepository(
        database: database,
        progressRepository: _FakeProgressRepository(),
        config: AppConfig.fromEnvironment(
          appName: 'PASSAGETR',
          platformMode: PlatformMode.mobile,
        ),
        accessContext: _identifiedAccessContext(),
      );

      final items = await repository.fetchAll();

      final byPassage = <String, ReadingEngagement>{
        for (final item in items) item.passageId: item,
      };
      expect(byPassage['reading-1']?.isBookmarked, isTrue);
      expect(byPassage['reading-1']?.isFavorite, isTrue);
      expect(byPassage['reading-2']?.isBookmarked, isFalse);
      expect(byPassage['reading-2']?.isFavorite, isTrue);
    });

    test(
      'setBookmark updates local mirror and enqueues bookmark event',
      () async {
        final database = FakeLocalSyncStore();
        final progressRepository = _FakeProgressRepository();
        final repository = FoundationReadingEngagementRepository(
          database: database,
          progressRepository: progressRepository,
          config: AppConfig.fromEnvironment(
            appName: 'PASSAGETR',
            platformMode: PlatformMode.mobile,
          ),
          accessContext: _identifiedAccessContext(),
          now: () => DateTime.utc(2026, 3, 9, 12, 0),
        );

        final result = await repository.setBookmark('reading-1', true);

        expect(result, isA<AppSuccess<void>>());
        final snapshots = await database.listProgressSnapshots(
          entityType: 'user_reading_bookmarks',
        );
        expect(snapshots.single.entityId, 'reading-1');
        expect(
          progressRepository.enqueuedEvents.single.entityType,
          'user_reading_bookmarks',
        );
        expect(
          progressRepository.enqueuedEvents.single.payloadJson,
          contains('"should_bookmark":true'),
        );
      },
    );

    test(
      'setFavorite removes local mirror and enqueues favorite event',
      () async {
        final database = FakeLocalSyncStore();
        await database.upsertProgressSnapshot(
          ProgressSnapshotRecord(
            entityType: 'user_reading_favorites',
            entityId: 'reading-2',
            payloadJson:
                '{"passage_id":"reading-2","created_at":"2026-03-09T12:01:00Z"}',
            updatedAt: DateTime.utc(2026, 3, 9, 12, 1),
          ),
        );
        final progressRepository = _FakeProgressRepository();
        final repository = FoundationReadingEngagementRepository(
          database: database,
          progressRepository: progressRepository,
          config: AppConfig.fromEnvironment(
            appName: 'PASSAGETR',
            platformMode: PlatformMode.mobile,
          ),
          accessContext: _identifiedAccessContext(),
          now: () => DateTime.utc(2026, 3, 9, 12, 5),
        );

        final result = await repository.setFavorite('reading-2', false);

        expect(result, isA<AppSuccess<void>>());
        final snapshots = await database.listProgressSnapshots(
          entityType: 'user_reading_favorites',
        );
        expect(snapshots, isEmpty);
        final payload =
            jsonDecode(progressRepository.enqueuedEvents.single.payloadJson)
                as Map<String, dynamic>;
        expect(payload['should_favorite'], isFalse);
      },
    );
  });

  group('FoundationReadingEngagementRepository remote mode', () {
    test(
      'identified web mode fetches remote state and writes through RPC',
      () async {
        final repository = _FakeRemoteReadingEngagementRepository(
          accessContext: _identifiedAccessContext(),
          bookmarkSnapshots: <ProgressSnapshotRecord>[
            ProgressSnapshotRecord(
              entityType: 'user_reading_bookmarks',
              entityId: 'reading-1',
              payloadJson:
                  '{"passage_id":"reading-1","created_at":"2026-03-09T14:00:00Z"}',
              updatedAt: DateTime.utc(2026, 3, 9, 14, 0),
            ),
          ],
          favoriteSnapshots: <ProgressSnapshotRecord>[
            ProgressSnapshotRecord(
              entityType: 'user_reading_favorites',
              entityId: 'reading-2',
              payloadJson:
                  '{"passage_id":"reading-2","created_at":"2026-03-09T14:05:00Z"}',
              updatedAt: DateTime.utc(2026, 3, 9, 14, 5),
            ),
          ],
        );

        final items = await repository.fetchAll();
        final result = await repository.setBookmark('reading-3', true);

        expect(items, hasLength(2));
        expect(result, isA<AppSuccess<void>>());
        expect(repository.remoteBookmarkFetchCount, 1);
        expect(repository.remoteFavoriteFetchCount, 1);
        expect(repository.bookmarkWrite, ('reading-3', true));
      },
    );

    test(
      'anonymous web mode returns empty state and does not write remote',
      () async {
        final repository = _FakeRemoteReadingEngagementRepository(
          accessContext: AccessContext.anonymous(),
        );

        final items = await repository.fetchAll();
        final result = await repository.setFavorite('reading-4', true);

        expect(items, isEmpty);
        expect(result, isA<AppSuccess<void>>());
        expect(repository.remoteBookmarkFetchCount, 0);
        expect(repository.remoteFavoriteFetchCount, 0);
        expect(repository.favoriteWrite, isNull);
      },
    );
  });
}

class _FakeProgressRepository implements ProgressRepository {
  final List<OutboxEvent> enqueuedEvents = <OutboxEvent>[];

  @override
  Future<AppResult<void>> enqueue(OutboxEvent event) async {
    enqueuedEvents.add(event);
    return const AppSuccess<void>(null);
  }

  @override
  Future<List<ReadingProgress>> fetchReadingProgress() async =>
      const <ReadingProgress>[];

  @override
  Future<List<GrammarProgress>> fetchGrammarProgress() async =>
      const <GrammarProgress>[];

  @override
  Future<List<WordProgress>> fetchWordProgress() async =>
      const <WordProgress>[];
}

class _FakeRemoteReadingEngagementRepository
    extends FoundationReadingEngagementRepository {
  _FakeRemoteReadingEngagementRepository({
    required AccessContext accessContext,
    List<ProgressSnapshotRecord>? bookmarkSnapshots,
    List<ProgressSnapshotRecord>? favoriteSnapshots,
  }) : bookmarkSnapshots =
           bookmarkSnapshots ?? const <ProgressSnapshotRecord>[],
       favoriteSnapshots =
           favoriteSnapshots ?? const <ProgressSnapshotRecord>[],
       super.preview(accessContext: accessContext);

  final List<ProgressSnapshotRecord> bookmarkSnapshots;
  final List<ProgressSnapshotRecord> favoriteSnapshots;
  int remoteBookmarkFetchCount = 0;
  int remoteFavoriteFetchCount = 0;
  (String, bool)? bookmarkWrite;
  (String, bool)? favoriteWrite;

  @override
  Future<List<ProgressSnapshotRecord>> fetchRemoteBookmarkSnapshots() async {
    remoteBookmarkFetchCount += 1;
    return bookmarkSnapshots;
  }

  @override
  Future<List<ProgressSnapshotRecord>> fetchRemoteFavoriteSnapshots() async {
    remoteFavoriteFetchCount += 1;
    return favoriteSnapshots;
  }

  @override
  Future<void> applyRemoteBookmarkWrite({
    required String eventId,
    required String passageId,
    required bool isBookmarked,
  }) async {
    bookmarkWrite = (passageId, isBookmarked);
  }

  @override
  Future<void> applyRemoteFavoriteWrite({
    required String eventId,
    required String passageId,
    required bool isFavorite,
  }) async {
    favoriteWrite = (passageId, isFavorite);
  }
}

AccessContext _identifiedAccessContext() {
  return AccessContext.fromSession(
    AuthSession(
      user: const AuthUser(
        id: 'identified-user',
        email: 'reader@passagetr.dev',
        isAnonymous: false,
      ),
      claims: const <String, String>{'app_role': 'user', 'plan': 'free'},
    ),
  );
}
