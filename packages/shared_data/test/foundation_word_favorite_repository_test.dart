import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_data/shared_data.dart';
import 'package:shared_domain/shared_domain.dart';

import 'support/fake_local_sync_store.dart';

void main() {
  group('FoundationWordFavoriteRepository local mode', () {
    test('fetchAll merges favorite snapshots', () async {
      final database = FakeLocalSyncStore();
      await database.upsertProgressSnapshot(
        ProgressSnapshotRecord(
          entityType: 'user_word_favorites',
          entityId: 'word-1',
          payloadJson:
              '{"word_id":"word-1","created_at":"2026-03-09T10:00:00Z"}',
          updatedAt: DateTime.utc(2026, 3, 9, 10, 0),
        ),
      );
      await database.upsertProgressSnapshot(
        ProgressSnapshotRecord(
          entityType: 'user_word_favorites',
          entityId: 'word-2',
          payloadJson:
              '{"word_id":"word-2","created_at":"2026-03-09T11:00:00Z"}',
          updatedAt: DateTime.utc(2026, 3, 9, 11, 0),
        ),
      );

      final repository = FoundationWordFavoriteRepository(
        database: database,
        progressRepository: _FakeProgressRepository(),
        config: AppConfig.fromEnvironment(
          appName: 'PASSAGETR',
          platformMode: PlatformMode.mobile,
        ),
        accessContext: _identifiedAccessContext(),
      );

      final items = await repository.fetchAll();

      final byWord = <String, WordFavorite>{
        for (final item in items) item.wordId: item,
      };
      expect(byWord['word-1']?.isFavorite, isTrue);
      expect(byWord['word-2']?.isFavorite, isTrue);
    });

    test(
      'setFavorite updates local mirror and enqueues favorite event',
      () async {
        final database = FakeLocalSyncStore();
        final progressRepository = _FakeProgressRepository();
        final repository = FoundationWordFavoriteRepository(
          database: database,
          progressRepository: progressRepository,
          config: AppConfig.fromEnvironment(
            appName: 'PASSAGETR',
            platformMode: PlatformMode.mobile,
          ),
          accessContext: _identifiedAccessContext(),
          now: () => DateTime.utc(2026, 3, 9, 12, 0),
        );

        final result = await repository.setFavorite('word-1', true);

        expect(result, isA<AppSuccess<void>>());
        final snapshots = await database.listProgressSnapshots(
          entityType: 'user_word_favorites',
        );
        expect(snapshots.single.entityId, 'word-1');
        final payload =
            jsonDecode(progressRepository.enqueuedEvents.single.payloadJson)
                as Map<String, dynamic>;
        expect(payload['word_id'], 'word-1');
        expect(payload['should_favorite'], isTrue);
      },
    );

    test('setFavorite removes local mirror when toggled off', () async {
      final database = FakeLocalSyncStore();
      await database.upsertProgressSnapshot(
        ProgressSnapshotRecord(
          entityType: 'user_word_favorites',
          entityId: 'word-2',
          payloadJson:
              '{"word_id":"word-2","created_at":"2026-03-09T12:01:00Z"}',
          updatedAt: DateTime.utc(2026, 3, 9, 12, 1),
        ),
      );
      final repository = FoundationWordFavoriteRepository(
        database: database,
        progressRepository: _FakeProgressRepository(),
        config: AppConfig.fromEnvironment(
          appName: 'PASSAGETR',
          platformMode: PlatformMode.mobile,
        ),
        accessContext: _identifiedAccessContext(),
        now: () => DateTime.utc(2026, 3, 9, 12, 5),
      );

      final result = await repository.setFavorite('word-2', false);

      expect(result, isA<AppSuccess<void>>());
      final snapshots = await database.listProgressSnapshots(
        entityType: 'user_word_favorites',
      );
      expect(snapshots, isEmpty);
    });
  });

  group('FoundationWordFavoriteRepository remote mode', () {
    test(
      'identified web mode fetches remote state and writes through RPC',
      () async {
        final repository = _FakeRemoteWordFavoriteRepository(
          accessContext: _identifiedAccessContext(),
          favoriteSnapshots: <ProgressSnapshotRecord>[
            ProgressSnapshotRecord(
              entityType: 'user_word_favorites',
              entityId: 'word-2',
              payloadJson:
                  '{"word_id":"word-2","created_at":"2026-03-09T14:05:00Z"}',
              updatedAt: DateTime.utc(2026, 3, 9, 14, 5),
            ),
          ],
        );

        final items = await repository.fetchAll();
        final result = await repository.setFavorite('word-3', true);

        expect(items, hasLength(1));
        expect(items.single.wordId, 'word-2');
        expect(result, isA<AppSuccess<void>>());
        expect(repository.remoteFavoriteFetchCount, 1);
        expect(repository.favoriteWrite, ('word-3', true));
      },
    );

    test(
      'anonymous web mode returns empty state and does not write remote',
      () async {
        final repository = _FakeRemoteWordFavoriteRepository(
          accessContext: AccessContext.anonymous(),
        );

        final items = await repository.fetchAll();
        final result = await repository.setFavorite('word-4', true);

        expect(items, isEmpty);
        expect(result, isA<AppSuccess<void>>());
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

class _FakeRemoteWordFavoriteRepository
    extends FoundationWordFavoriteRepository {
  _FakeRemoteWordFavoriteRepository({
    required AccessContext accessContext,
    List<ProgressSnapshotRecord>? favoriteSnapshots,
  }) : favoriteSnapshots =
           favoriteSnapshots ?? const <ProgressSnapshotRecord>[],
       super.preview(accessContext: accessContext);

  final List<ProgressSnapshotRecord> favoriteSnapshots;
  int remoteFavoriteFetchCount = 0;
  (String, bool)? favoriteWrite;

  @override
  Future<List<ProgressSnapshotRecord>> fetchRemoteFavoriteSnapshots() async {
    remoteFavoriteFetchCount += 1;
    return favoriteSnapshots;
  }

  @override
  Future<void> applyRemoteFavoriteWrite({
    required String eventId,
    required String wordId,
    required bool isFavorite,
  }) async {
    favoriteWrite = (wordId, isFavorite);
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
