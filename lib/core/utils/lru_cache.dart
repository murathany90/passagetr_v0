import 'dart:collection';

/// A simple Least Recently Used (LRU) cache backed by a [LinkedHashMap].
///
/// When the cache exceeds [maxSize], the least recently accessed entry
/// is evicted automatically.
class LruCache<K, V> {
  LruCache({this.maxSize = 500});

  final int maxSize;
  final LinkedHashMap<K, V> _map = LinkedHashMap<K, V>();

  /// Returns the cached value for [key], or `null` if absent.
  /// Accessing a key promotes it to the most-recently-used position.
  V? get(K key) {
    final V? value = _map.remove(key);
    if (value != null) {
      _map[key] = value;
    }
    return value;
  }

  /// Stores [key]/[value] in the cache. If the cache is full the least
  /// recently used entry is evicted first.
  void put(K key, V value) {
    _map.remove(key);
    _map[key] = value;
    if (_map.length > maxSize) {
      _map.remove(_map.keys.first);
    }
  }

  /// Whether the cache contains [key].
  bool containsKey(K key) => _map.containsKey(key);

  /// Number of entries currently in the cache.
  int get length => _map.length;

  /// Removes all entries from the cache.
  void clear() => _map.clear();
}
