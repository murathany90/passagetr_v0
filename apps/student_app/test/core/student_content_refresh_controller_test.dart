import 'package:flutter_test/flutter_test.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_domain/shared_domain.dart';
import 'package:student_app/src/core/student_content_refresh_controller.dart';

void main() {
  group('StudentContentRefreshController', () {
    test('syncs content and invalidates caches on success', () async {
      final syncRepository = _FakeSyncRepository(
        result: const AppSuccess<void>(null),
      );
      var invalidationCount = 0;
      final controller = StudentContentRefreshController(
        syncRepository: syncRepository,
        invalidateContentProviders: () {
          invalidationCount += 1;
        },
      );

      final result = await controller.refreshContent();

      expect(result.isSuccess, isTrue);
      expect(syncRepository.syncNowCalls, <SyncScope>[SyncScope.content]);
      expect(invalidationCount, 1);
      expect(controller.state.status, StudentContentRefreshStatus.success);
      expect(controller.state.message, 'Icerik yenilendi.');
    });

    test('surfaces a short error and skips invalidation on failure', () async {
      final syncRepository = _FakeSyncRepository(
        result: const AppFailure<void>('Sync bootstrap failed.'),
      );
      var invalidationCount = 0;
      final controller = StudentContentRefreshController(
        syncRepository: syncRepository,
        invalidateContentProviders: () {
          invalidationCount += 1;
        },
      );

      final result = await controller.refreshContent();

      expect(result.isFailure, isTrue);
      expect(syncRepository.syncNowCalls, <SyncScope>[SyncScope.content]);
      expect(invalidationCount, 0);
      expect(controller.state.status, StudentContentRefreshStatus.error);
      expect(controller.state.message, 'Icerik simdi yenilenemedi.');
    });
  });
}

class _FakeSyncRepository implements SyncRepository {
  _FakeSyncRepository({required this.result});

  final AppResult<void> result;
  final List<SyncScope> syncNowCalls = <SyncScope>[];

  @override
  Future<AppResult<void>> syncIfStale(SyncScope scope) async {
    return const AppSuccess<void>(null);
  }

  @override
  Future<AppResult<void>> syncNow(SyncScope scope) async {
    syncNowCalls.add(scope);
    return result;
  }
}
