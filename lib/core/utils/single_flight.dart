class SingleFlight<K, V> {
  final Map<K, Future<V>> _inFlight = <K, Future<V>>{};

  Future<V> run(K key, Future<V> Function() operation) {
    final Future<V>? existing = _inFlight[key];
    if (existing != null) {
      return existing;
    }

    final Future<V> future = operation();
    _inFlight[key] = future;
    return future.whenComplete(() {
      if (identical(_inFlight[key], future)) {
        _inFlight.remove(key);
      }
    });
  }
}
