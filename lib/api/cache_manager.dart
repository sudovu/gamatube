import 'dart:convert';
import 'package:crypto/crypto.dart';
import '../core/logging/app_logger.dart';

class CacheEntry {
  final String key;
  final String data;
  final DateTime expiresAt;
  DateTime lastAccessed;
  final int byteSize;

  CacheEntry({
    required this.key,
    required this.data,
    required this.expiresAt,
    required this.lastAccessed,
    required this.byteSize,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class CacheManager {
  final Map<String, CacheEntry> _cache = {};
  int _currentSizeBytes = 0;
  int _maxSizeBytes;

  CacheManager({int maxCacheSizeMb = 250})
      : _maxSizeBytes = maxCacheSizeMb * 1024 * 1024;

  void updateMaxSizeBytes(int sizeMb) {
    _maxSizeBytes = sizeMb * 1024 * 1024;
    _evictIfNeeded();
  }

  static String generateKey(String endpoint, Map<String, dynamic> params) {
    final sortedParams = params.keys.toList()..sort();
    final paramString = sortedParams.map((k) => '$k=${params[k]}').join('&');
    final combined = '$endpoint?$paramString';
    return md5.convert(utf8.encode(combined)).toString();
  }

  void put({
    required String key,
    required dynamic data,
    Duration ttl = const Duration(hours: 2),
  }) {
    try {
      final jsonString = jsonEncode(data);
      final byteSize = utf8.encode(jsonString).length;

      // Don't cache single items larger than 10MB
      if (byteSize > 10 * 1024 * 1024) return;

      if (_cache.containsKey(key)) {
        _currentSizeBytes -= _cache[key]!.byteSize;
      }

      final entry = CacheEntry(
        key: key,
        data: jsonString,
        expiresAt: DateTime.now().add(ttl),
        lastAccessed: DateTime.now(),
        byteSize: byteSize,
      );

      _cache[key] = entry;
      _currentSizeBytes += byteSize;

      _evictIfNeeded();
      AppLogger.debug('Cached key $key (${byteSize ~/ 1024} KB). Total: ${_currentSizeBytes ~/ 1024} KB');
    } catch (e) {
      AppLogger.warning('Failed to cache data for key $key', e);
    }
  }

  dynamic get(String key) {
    final entry = _cache[key];
    if (entry == null) return null;

    if (entry.isExpired) {
      _cache.remove(key);
      _currentSizeBytes -= entry.byteSize;
      return null;
    }

    entry.lastAccessed = DateTime.now();
    try {
      return jsonDecode(entry.data);
    } catch (e) {
      _cache.remove(key);
      _currentSizeBytes -= entry.byteSize;
      return null;
    }
  }

  void _evictIfNeeded() {
    // 1. Evict expired entries first
    final now = DateTime.now();
    final expiredKeys = _cache.entries
        .where((e) => now.isAfter(e.value.expiresAt))
        .map((e) => e.key)
        .toList();

    for (final k in expiredKeys) {
      final entry = _cache.remove(k);
      if (entry != null) _currentSizeBytes -= entry.byteSize;
    }

    // 2. LRU eviction if still over quota
    if (_currentSizeBytes > _maxSizeBytes) {
      final sortedEntries = _cache.values.toList()
        ..sort((a, b) => a.lastAccessed.compareTo(b.lastAccessed));

      for (final entry in sortedEntries) {
        if (_currentSizeBytes <= _maxSizeBytes) break;
        _cache.remove(entry.key);
        _currentSizeBytes -= entry.byteSize;
      }
    }
  }

  void clear() {
    _cache.clear();
    _currentSizeBytes = 0;
    AppLogger.info('Cache cleared completely');
  }

  int get currentSizeBytes => _currentSizeBytes;
  int get itemCount => _cache.length;
}
