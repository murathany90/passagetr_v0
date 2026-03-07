import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_providers.dart';
import 'content_providers.dart';
import 'grammar_providers.dart';
import 'pack_providers.dart';
import 'reading_providers.dart';

final Provider<WebStartupWarmupController> webStartupWarmupProvider =
    Provider<WebStartupWarmupController>((Ref ref) {
  return WebStartupWarmupController(ref);
});

class WebStartupWarmupController {
  WebStartupWarmupController(this._ref);

  final Ref _ref;
  Future<void>? _pending;

  Future<void> warmup() {
    if (!_ref.read(isWebPlatformProvider) ||
        _ref.read(effectiveUseLocalStaticContentProvider)) {
      return Future<void>.value();
    }

    return _pending ??= _run();
  }

  Future<void> _run() async {
    try {
      await _ref.read(authBootstrapProvider.future);

      final List<Future<void>> tasks = <Future<void>>[
        Future<void>(() async {
          try {
            await _ref.read(packListProvider.future);
          } catch (_) {}
        }),
        Future<void>(() async {
          try {
            await _ref.read(grammarModulesProvider.future);
          } catch (_) {}
        }),
        Future<void>(() async {
          try {
            await _ref.read(
              readingFeedProvider(
                const ReadingFeedRequest(),
              ).future,
            );
          } catch (_) {}
        }),
      ];

      await Future.wait<void>(tasks, eagerError: false);
    } finally {
      _pending = null;
    }
  }
}
