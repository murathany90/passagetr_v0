import 'package:flutter_test/flutter_test.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_domain/shared_domain.dart';
import 'package:student_app/src/core/student_word_favorite_controller.dart';

import '../support/fake_word_favorite_repository.dart';

void main() {
  group('StudentWordFavoriteController', () {
    test('load hydrates favorite state from repository', () async {
      final repository = FakeWordFavoriteRepository(
        items: const <WordFavorite>[
          WordFavorite(wordId: 'word-1', isFavorite: true, favoritedAt: null),
        ],
      );
      final controller = StudentWordFavoriteController(
        favoriteRepository: repository,
        syncRepository: const _FakeSyncRepository(),
        accessContext: _identifiedAccessContext(),
        isWeb: true,
      );

      await Future<void>.delayed(Duration.zero);

      expect(controller.state['word-1']?.isFavorite, isTrue);
    });

    test(
      'toggleFavorite updates local state and writes favorite intent',
      () async {
        final repository = FakeWordFavoriteRepository(
          items: const <WordFavorite>[
            WordFavorite(wordId: 'word-1', isFavorite: true),
          ],
        );
        final controller = StudentWordFavoriteController(
          favoriteRepository: repository,
          syncRepository: const _FakeSyncRepository(),
          accessContext: _identifiedAccessContext(),
          now: () => DateTime.utc(2026, 3, 13, 10, 0),
          isWeb: true,
        );

        await Future<void>.delayed(Duration.zero);
        await controller.toggleFavorite('word-1');

        expect(controller.state.containsKey('word-1'), isFalse);
        expect(repository.favoriteWrites.single, ('word-1', false));
      },
    );
  });
}

class _FakeSyncRepository implements SyncRepository {
  const _FakeSyncRepository();

  @override
  Future<AppResult<void>> syncIfStale(SyncScope scope) async =>
      const AppSuccess<void>(null);

  @override
  Future<AppResult<void>> syncNow(SyncScope scope) async =>
      const AppSuccess<void>(null);
}

AccessContext _identifiedAccessContext() {
  return AccessContext.fromSession(
    AuthSession(
      user: const AuthUser(
        id: 'test-user',
        email: 'test@passagetr.dev',
        isAnonymous: false,
      ),
      claims: const <String, String>{'app_role': 'user', 'plan': 'free'},
    ),
  );
}
