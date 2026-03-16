import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_core/shared_core.dart';
import 'package:shared_domain/shared_domain.dart';

class StudentWordFavoriteController
    extends StateNotifier<Map<String, WordFavorite>> {
  StudentWordFavoriteController({
    required WordFavoriteRepository favoriteRepository,
    required SyncRepository syncRepository,
    required AccessContext accessContext,
    DateTime Function()? now,
    bool? isWeb,
  }) : _favoriteRepository = favoriteRepository,
       _syncRepository = syncRepository,
       _accessContext = accessContext,
       _now = now ?? _defaultNow,
       _isWeb = isWeb ?? kIsWeb,
       super(const <String, WordFavorite>{}) {
    load();
  }

  final WordFavoriteRepository _favoriteRepository;
  final SyncRepository _syncRepository;
  final AccessContext _accessContext;
  final DateTime Function() _now;
  final bool _isWeb;

  WordFavorite favoriteFor(String wordId) {
    return state[wordId] ?? WordFavorite.empty(wordId: wordId);
  }

  Future<void> load() async {
    if (!_accessContext.hasIdentifiedProfile) {
      state = const <String, WordFavorite>{};
      return;
    }

    if (!_isWeb) {
      await _syncRepository.syncIfStale(SyncScope.progress);
    }

    final favorites = await _favoriteRepository.fetchAll();
    state = <String, WordFavorite>{
      for (final favorite in favorites)
        if (favorite.isFavorite) favorite.wordId: favorite,
    };
  }

  Future<AppResult<void>> toggleFavorite(String wordId) async {
    if (!_accessContext.hasIdentifiedProfile) {
      return const AppSuccess<void>(null);
    }

    final current = favoriteFor(wordId);
    final next = current.setFavorite(!current.isFavorite, at: _now());
    final previousState = state;
    state = <String, WordFavorite>{...state};
    if (next.isFavorite) {
      state = <String, WordFavorite>{...state, wordId: next};
    } else {
      final updated = <String, WordFavorite>{...state}..remove(wordId);
      state = updated;
    }

    final result = await _favoriteRepository.setFavorite(
      wordId,
      next.isFavorite,
    );
    if (result is AppFailure<void>) {
      state = previousState;
    }
    return result;
  }

  static DateTime _defaultNow() => DateTime.now().toUtc();
}
