import 'dart:collection';

class CacheManager {
  final LinkedHashMap<String, _CacheEntry> _cache = LinkedHashMap<String, _CacheEntry>();
  final Duration defaultTtl;
  final int maxSize;

  CacheManager({
    this.defaultTtl = const Duration(minutes: 30),
    this.maxSize = 100,
  });

  /// Get cached value, returns null if not found or expired
  T? get<T>(String key) {
    final entry = _cache[key];
    if (entry == null) return null;
    
    if (DateTime.now().isAfter(entry.expiry)) {
      _cache.remove(key);
      return null;
    }
    
    return entry.value as T?;
  }

  /// Set value in cache with optional TTL
  void set<T>(String key, T value, {Duration? ttl}) {
    // Remove oldest entries if at max size
    while (_cache.length >= maxSize) {
      _cache.remove(_cache.keys.first);
    }
    
    _cache[key] = _CacheEntry(
      value: value,
      expiry: DateTime.now().add(ttl ?? defaultTtl),
    );
  }

  /// Check if key exists and is not expired
  bool containsKey(String key) {
    return get(key) != null;
  }

  /// Remove specific key
  void remove(String key) {
    _cache.remove(key);
  }

  /// Clear all cached items
  void clear() {
    _cache.clear();
  }

  /// Get current cache size
  int get size => _cache.length;

  /// Check if cache is empty
  bool get isEmpty => _cache.isEmpty;

  /// Check if cache has items
  bool get isNotEmpty => _cache.isNotEmpty;
}

class _CacheEntry {
  final dynamic value;
  final DateTime expiry;

  _CacheEntry({
    required this.value,
    required this.expiry,
  });
}
