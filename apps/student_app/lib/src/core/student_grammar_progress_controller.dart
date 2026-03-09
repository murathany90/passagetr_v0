import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_domain/shared_domain.dart';

class StudentGrammarProgressController
    extends StateNotifier<AsyncValue<Map<int, GrammarProgress>>> {
  StudentGrammarProgressController({
    required ProgressRepository progressRepository,
    DateTime Function()? now,
  }) : _progressRepository = progressRepository,
       _now = now ?? _defaultNow,
       super(const AsyncValue.loading()) {
    unawaited(load());
  }

  final ProgressRepository _progressRepository;
  final DateTime Function() _now;

  Future<void> load() async {
    if ((state.valueOrNull ?? const <int, GrammarProgress>{}).isEmpty) {
      state = const AsyncValue.loading();
    }

    state = await AsyncValue.guard(() async {
      final progress = await _progressRepository.fetchGrammarProgress();
      final latestState = state.valueOrNull ?? const <int, GrammarProgress>{};
      return <int, GrammarProgress>{..._toMap(progress), ...latestState};
    });
  }

  Future<AppResult<void>> recordProgress({
    required int moduleId,
    int? pageId,
    required int lastPageNo,
    required int completedPages,
    required bool completed,
  }) async {
    final current = state.valueOrNull ?? const <int, GrammarProgress>{};
    final existing =
        current[moduleId] ??
        GrammarProgress(
          moduleId: moduleId,
          pageId: pageId,
          lastPageNo: 0,
          completedPages: 0,
          completed: false,
        );

    state = AsyncValue.data(<int, GrammarProgress>{
      ...current,
      moduleId: GrammarProgress(
        moduleId: moduleId,
        pageId: pageId ?? existing.pageId,
        lastPageNo: lastPageNo > existing.lastPageNo
            ? lastPageNo
            : existing.lastPageNo,
        completedPages: completedPages > existing.completedPages
            ? completedPages
            : existing.completedPages,
        completed: existing.completed || completed,
      ),
    });

    return _progressRepository.enqueue(
      OutboxEvent(
        eventId: 'grammar-$moduleId-${_now().microsecondsSinceEpoch}',
        scope: SyncScope.progress,
        entityType: 'user_grammar_progress',
        entityId: '$moduleId',
        operation: OutboxOperation.event,
        payloadJson: jsonEncode(<String, dynamic>{
          'module_id': moduleId,
          'page_id': pageId,
          'last_page_no': lastPageNo,
          'completed_pages': completedPages,
          'completed': completed,
        }),
      ),
    );
  }

  Map<int, GrammarProgress> _toMap(List<GrammarProgress> progress) {
    return <int, GrammarProgress>{
      for (final item in progress) item.moduleId: item,
    };
  }

  static DateTime _defaultNow() => DateTime.now().toUtc();
}
