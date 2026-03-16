import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_domain/shared_domain.dart';

import 'admin_console_models.dart';

class AdminSettingsController extends StateNotifier<AdminSettingsState> {
  AdminSettingsController({required AdminSettingsRepository repository})
    : _repository = repository,
      super(const AdminSettingsState()) {
    load();
  }

  final AdminSettingsRepository _repository;

  Future<void> load() async {
    state = state.copyWith(
      isLoading: true,
      isSaving: false,
      clearError: true,
      clearNotice: true,
    );
    final result = await _repository.fetchSettings();
    if (result case AppSuccess<AdminSettingsSnapshot>()) {
      state = state.copyWith(
        persisted: result.value,
        draft: result.value,
        isLoading: false,
        isSaving: false,
        clearError: true,
      );
      return;
    }

    state = state.copyWith(
      isLoading: false,
      isSaving: false,
      errorMessage: (result as AppFailure<AdminSettingsSnapshot>).message,
      clearNotice: true,
    );
  }

  void updateDraft(AdminSettingsSnapshot snapshot) {
    state = state.copyWith(
      draft: snapshot,
      clearError: true,
      clearNotice: true,
    );
  }

  void resetDraft() {
    state = state.copyWith(
      draft: state.persisted,
      noticeMessage: 'Degisiklikler geri alindi.',
      clearError: true,
    );
  }

  Future<AppResult<AdminSettingsSnapshot>> save() async {
    state = state.copyWith(isSaving: true, clearError: true, clearNotice: true);
    final result = await _repository.saveSettings(state.draft);
    if (result case AppSuccess<AdminSettingsSnapshot>()) {
      state = state.copyWith(
        persisted: result.value,
        draft: result.value,
        isLoading: false,
        isSaving: false,
        noticeMessage: 'Ayarlar kaydedildi.',
      );
      return result;
    }

    state = state.copyWith(
      isSaving: false,
      errorMessage: (result as AppFailure<AdminSettingsSnapshot>).message,
    );
    return result;
  }

  void clearTransientMessages() {
    state = state.copyWith(clearError: true, clearNotice: true);
  }
}
