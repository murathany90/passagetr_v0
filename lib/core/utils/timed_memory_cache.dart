class TimedMemoryCache<K, V> {
  TimedMemoryCache({required this.ttl});

  final Duration ttl;
  final Map<K, _TimedMemoryEntry<V>> _entries = <K, _TimedMemoryEntry<V>>{};

  V? get(K key) {
    final _TimedMemoryEntry<V>? entry = _entries[key];
    if (entry == null) {
      return null;
    }
    if (DateTime.now().difference(entry.storedAt) > ttl) {
      _entries.remove(key);
      return null;
    }
    return entry.value;
  }

  V? peek(K key) => _entries[key]?.value;

  void put(K key, V value) {
    _entries[key] = _TimedMemoryEntry<V>(
      value: value,
      storedAt: DateTime.now(),
    );
  }

  void remove(K key) => _entries.remove(key);

  void clear() => _entries.clear();
}

class _TimedMemoryEntry<V> {
  const _TimedMemoryEntry({
    required this.value,
    required this.storedAt,
  });

  final V value;
  final DateTime storedAt;
}
