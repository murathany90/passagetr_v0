import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

extension ProviderCacheX<State> on Ref<State> {
  void cacheFor(Duration duration) {
    final dynamic dynamicRef = this;
    KeepAliveLink? link;
    try {
      link = dynamicRef.keepAlive() as KeepAliveLink;
    } catch (_) {
      return;
    }

    final Timer timer = Timer(duration, link.close);
    onDispose(timer.cancel);
  }
}
