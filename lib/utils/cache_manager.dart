class CacheManager {
  final Map<String, _CacheEntry> _cache = {};
  final int maxSize;
  int _currentSize = 0;

  CacheManager({this.maxSize = AppConstants.cacheMaxSize});

  T? get<T>(String key) {
    final entry = _cache[key];
    if (entry == null) return null;
    
    if (_isExpired(entry)) {
      _remove(key);
      return null;
    }
    
    entry.lastAccess = DateTime.now();
    return entry.data as T?;
  }

  void set<T>(String key, T data, {Duration ttl = const Duration(minutes: 30)}) {
    if (_cache.containsKey(key)) {
      _cache[key]!.data = data;
      _cache[key]!.expiresAt = DateTime.now().add(ttl);
      _cache[key]!.lastAccess = DateTime.now();
      return;
    }

    if (_currentSize >= maxSize) {
      _evictLRU();
    }

    _cache[key] = _CacheEntry<T>(
      data: data,
      expiresAt: DateTime.now().add(ttl),
      createdAt: DateTime.now(),
    );
    _currentSize++;
  }

  bool containsKey(String key) {
    final entry = _cache[key];
    if (entry == null) return false;
    if (_isExpired(entry)) {
      _remove(key);
      return false;
    }
    return true;
  }

  void remove(String key) {
    _remove(key);
  }

  void clear() {
    _cache.clear();
    _currentSize = 0;
  }

  int get size => _currentSize;

  bool get isEmpty => _currentSize == 0;

  void _remove(String key) {
    _cache.remove(key);
    _currentSize--;
  }

  bool _isExpired(_CacheEntry entry) {
    return DateTime.now().isAfter(entry.expiresAt);
  }

  void _evictLRU() {
    if (_cache.isEmpty) return;
    
    String? lruKey;
    DateTime? lruTime;
    
    _cache.forEach((key, entry) {
      if (lruTime == null || entry.lastAccess.isBefore(lruTime)) {
        lruTime = entry.lastAccess;
        lruKey = key;
      }
    });
    
    if (lruKey != null) {
      _remove(lruKey);
    }
  }
}

class _CacheEntry<T> {
  T data;
  final DateTime expiresAt;
  final DateTime createdAt;
  late DateTime lastAccess;

  _CacheEntry({
    required this.data,
    required this.expiresAt,
    required this.createdAt,
  }) : lastAccess = createdAt;
}

// LRU Cache implementation for more control
class LRUCache<K, V> {
  final int capacity;
  final Map<K, V> _cache = {};
  final List<K> _accessOrder = [];

  LRUCache(this.capacity);

  V? get(K key) {
    if (!_cache.containsKey(key)) return null;
    
    _accessOrder.remove(key);
    _accessOrder.add(key);
    
    return _cache[key];
  }

  void put(K key, V value) {
    if (_cache.containsKey(key)) {
      _cache[key] = value;
      _accessOrder.remove(key);
      _accessOrder.add(key);
      return;
    }

    if (_cache.length >= capacity) {
      final oldest = _accessOrder.removeAt(0);
      _cache.remove(oldest);
    }

    _cache[key] = value;
    _accessOrder.add(key);
  }

  bool containsKey(K key) => _cache.containsKey(key);

  void remove(K key) {
    _cache.remove(key);
    _accessOrder.remove(key);
  }

  void clear() {
    _cache.clear();
    _accessOrder.clear();
  }

  int get length => _cache.length;
}
