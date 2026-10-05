import 'package:flutter_test/flutter_test.dart';
import 'package:gamatube/api/cache_manager.dart';

void main() {
  group('CacheManager Tests', () {
    test('Stores and retrieves cache data within TTL', () {
      final cache = CacheManager(maxCacheSizeMb: 10);
      const key = 'test_key';
      final data = {'title': 'Sample Video', 'views': 500};

      cache.put(key: key, data: data, ttl: const Duration(seconds: 10));
      final retrieved = cache.get(key);

      expect(retrieved, isNotNull);
      expect(retrieved['title'], 'Sample Video');
      expect(retrieved['views'], 500);
    });

    test('Returns null for expired items', () async {
      final cache = CacheManager(maxCacheSizeMb: 10);
      const key = 'expiring_key';
      final data = {'status': 'temporary'};

      cache.put(key: key, data: data, ttl: const Duration(milliseconds: 50));
      await Future.delayed(const Duration(milliseconds: 60));

      final retrieved = cache.get(key);
      expect(retrieved, isNull);
    });

    test('Clear removes all entries and resets size', () {
      final cache = CacheManager(maxCacheSizeMb: 10);
      cache.put(key: 'k1', data: {'val': 1});
      cache.put(key: 'k2', data: {'val': 2});

      expect(cache.itemCount, 2);
      expect(cache.currentSizeBytes, greaterThan(0));

      cache.clear();

      expect(cache.itemCount, 0);
      expect(cache.currentSizeBytes, 0);
      expect(cache.get('k1'), isNull);
    });

    test('Generates deterministic keys for identical query params', () {
      final key1 = CacheManager.generateKey('search', {'q': 'flutter', 'type': 'video'});
      final key2 = CacheManager.generateKey('search', {'type': 'video', 'q': 'flutter'});

      expect(key1, key2);
    });
  });
}
