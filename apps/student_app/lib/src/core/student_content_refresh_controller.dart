import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_domain/shared_domain.dart';

enum StudentContentRefreshStatus { idle, loading, success, error }

class StudentContentRefreshState {
  const StudentContentRefreshState({
    this.status = StudentContentRefreshStatus.idle,
    this.message,
  });

  final StudentContentRefreshStatus status;
  final String? message;

  bool get isLoading => status == StudentContentRefreshStatus.loading;
}

class StudentContentRefreshController
    extends StateNotifier<StudentContentRefreshState> {
  StudentContentRefreshController({
    required SyncRepository syncRepository,
    required void Function() invalidateContentProviders,
  }) : _syncRepository = syncRepository,
       _invalidateContentProviders = invalidateContentProviders,
       super(const StudentContentRefreshState());

  final SyncRepository _syncRepository;
  final void Function() _invalidateContentProviders;

  Future<AppResult<void>> refreshContent() async {
    if (state.isLoading) {
      return const AppFailure<void>('Icerik yenileme zaten devam ediyor.');
    }

    state = const StudentContentRefreshState(
      status: StudentContentRefreshStatus.loading,
      message: 'Icerik yenileniyor...',
    );

    final result = await _syncRepository.syncNow(SyncScope.content);
    if (result case AppSuccess<void>()) {
      _invalidateContentProviders();
      state = const StudentContentRefreshState(
        status: StudentContentRefreshStatus.success,
        message: 'Icerik yenilendi.',
      );
      return result;
    }

    state = const StudentContentRefreshState(
      status: StudentContentRefreshStatus.error,
      message: 'Icerik simdi yenilenemedi.',
    );
    return result;
  }
}
