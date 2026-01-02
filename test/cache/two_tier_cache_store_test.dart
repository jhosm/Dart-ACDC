import 'package:dart_acdc/src/cache/two_tier_cache_store.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TwoTierCacheStore', () {
    late MemCacheStore memoryStore;
    late MemCacheStore persistentStore;
    late TwoTierCacheStore twoTierStore;

    setUp(() {
      memoryStore = MemCacheStore(maxSize: 10 * 1024 * 1024); // 10 MB
      persistentStore = MemCacheStore(maxSize: 20 * 1024 * 1024); // 20 MB
      twoTierStore = TwoTierCacheStore(
        memoryStore: memoryStore,
        persistentStore: persistentStore,
      );
    });

    test('stores and retrieves from memory cache', () async {
      final response = _createCacheResponse(key: 'test_key');

      await twoTierStore.set(response);

      final retrieved = await twoTierStore.get('test_key');
      expect(retrieved, isNotNull);
      expect(retrieved!.key, equals('test_key'));
    });

    test('promotes persistent cache entries to memory on access', () async {
      final response = _createCacheResponse(key: 'persistent_key');

      // Write directly to persistent store (bypassing memory)
      await persistentStore.set(response);

      // Memory should not have it yet
      expect(await memoryStore.exists('persistent_key'), isFalse);

      // Get from two-tier store should find it in persistent and promote
      final retrieved = await twoTierStore.get('persistent_key');
      expect(retrieved, isNotNull);
      expect(retrieved!.key, equals('persistent_key'));

      // Now it should be in memory cache
      expect(await memoryStore.exists('persistent_key'), isTrue);
    });

    test('checks existence in both tiers', () async {
      final memResponse = _createCacheResponse(key: 'in_memory');
      final persistResponse = _createCacheResponse(key: 'in_persistent');

      await memoryStore.set(memResponse);
      await persistentStore.set(persistResponse);

      expect(await twoTierStore.exists('in_memory'), isTrue);
      expect(await twoTierStore.exists('in_persistent'), isTrue);
      expect(await twoTierStore.exists('nowhere'), isFalse);
    });

    test('deletes from both tiers', () async {
      final response = _createCacheResponse(key: 'delete_both');

      await twoTierStore.set(response);

      // Should be in both tiers
      expect(await memoryStore.exists('delete_both'), isTrue);
      expect(await persistentStore.exists('delete_both'), isTrue);

      await twoTierStore.delete('delete_both');

      // Should be deleted from both
      expect(await memoryStore.exists('delete_both'), isFalse);
      expect(await persistentStore.exists('delete_both'), isFalse);
    });

    test('cleans both tiers', () async {
      await twoTierStore.set(_createCacheResponse(key: 'key1'));
      await twoTierStore.set(_createCacheResponse(key: 'key2'));

      await twoTierStore.clean();

      expect(await memoryStore.exists('key1'), isFalse);
      expect(await memoryStore.exists('key2'), isFalse);
      expect(await persistentStore.exists('key1'), isFalse);
      expect(await persistentStore.exists('key2'), isFalse);
    });

    test('getFromPath merges results from both tiers', () async {
      final memResponse = _createCacheResponse(
        key: 'mem_key',
        url: 'https://api.example.com/users/1',
      );
      final persistResponse = _createCacheResponse(
        key: 'persist_key',
        url: 'https://api.example.com/users/2',
      );

      await memoryStore.set(memResponse);
      await persistentStore.set(persistResponse);

      final results = await twoTierStore.getFromPath(
        RegExp(r'https://api\.example\.com/'),
      );

      expect(results.length, equals(2));
      expect(results.map((r) => r.key), containsAll(['mem_key', 'persist_key']));
    });

    test('getFromPath removes duplicates when merging', () async {
      final response = _createCacheResponse(
        key: 'duplicate_key',
        url: 'https://api.example.com/users/1',
      );

      // Store in both tiers
      await memoryStore.set(response);
      await persistentStore.set(response);

      final results = await twoTierStore.getFromPath(
        RegExp(r'https://api\.example\.com/'),
      );

      // Should only have one entry, not two
      expect(results.length, equals(1));
      expect(results.first.key, equals('duplicate_key'));
    });

    test('deleteFromPath removes from both tiers', () async {
      await twoTierStore.set(_createCacheResponse(
        key: 'key1',
        url: 'https://api.example.com/users/1',
      ),);
      await twoTierStore.set(_createCacheResponse(
        key: 'key2',
        url: 'https://api.other.com/users/1',
      ),);

      await twoTierStore.deleteFromPath(
        RegExp(r'https://api\.example\.com/'),
      );

      expect(await memoryStore.exists('key1'), isFalse);
      expect(await persistentStore.exists('key1'), isFalse);
      expect(await twoTierStore.exists('key2'), isTrue);
    });

    test('works without persistent store (memory-only mode)', () async {
      final memoryOnly = TwoTierCacheStore(
        memoryStore: memoryStore,
      );

      final response = _createCacheResponse(key: 'memory_only');

      await memoryOnly.set(response);

      final retrieved = await memoryOnly.get('memory_only');
      expect(retrieved, isNotNull);
      expect(retrieved!.key, equals('memory_only'));
    });

    test('gracefully handles persistent store failures', () async {
      // Create a store that will throw errors
      final failingStore = _FailingCacheStore();
      final resilientStore = TwoTierCacheStore(
        memoryStore: memoryStore,
        persistentStore: failingStore,
      );

      final response = _createCacheResponse(key: 'resilient');

      // Should not throw despite persistent store failures
      await expectLater(resilientStore.set(response), completes);
      await expectLater(resilientStore.get('resilient'), completes);
      await expectLater(resilientStore.delete('resilient'), completes);
      await expectLater(resilientStore.clean(), completes);
    });

    test('close closes both stores', () async {
      await expectLater(twoTierStore.close(), completes);
    });

    test('pathExists correctly matches URLs', () {
      expect(
        twoTierStore.pathExists(
          'https://api.example.com/users',
          RegExp(r'https://api\.example\.com/'),
        ),
        isTrue,
      );

      expect(
        twoTierStore.pathExists(
          'https://api.other.com/users',
          RegExp(r'https://api\.example\.com/'),
        ),
        isFalse,
      );
    });
  });
}

/// Creates a test cache response.
CacheResponse _createCacheResponse({
  required String key,
  String? url,
}) =>
    CacheResponse(
      key: key,
      url: url ?? 'https://api.example.com/test',
      cacheControl: CacheControl(
        maxAge: 3600,
        other: [],
      ),
      content: [72, 101, 108, 108, 111],
      date: DateTime.now(),
      eTag: 'etag-123',
      expires: null,
      headers: [123, 125],
      lastModified: null,
      maxStale: null,
      priority: CachePriority.normal,
      requestDate: DateTime.now(),
      responseDate: DateTime.now(),
    );

/// A cache store that always fails (for testing error handling).
class _FailingCacheStore implements CacheStore {
  @override
  Future<void> clean({
    CachePriority priorityOrBelow = CachePriority.high,
    bool staleOnly = false,
  }) async {
    throw Exception('Persistent store failed');
  }

  @override
  Future<void> close() async {
    throw Exception('Persistent store failed');
  }

  @override
  Future<void> delete(String key, {bool staleOnly = false}) async {
    throw Exception('Persistent store failed');
  }

  @override
  Future<void> deleteFromPath(
    RegExp pathPattern, {
    Map<String, String?>? queryParams,
  }) async {
    throw Exception('Persistent store failed');
  }

  @override
  Future<bool> exists(String key) async {
    throw Exception('Persistent store failed');
  }

  @override
  Future<CacheResponse?> get(String key) async {
    throw Exception('Persistent store failed');
  }

  @override
  Future<List<CacheResponse>> getFromPath(
    RegExp pathPattern, {
    Map<String, String?>? queryParams,
  }) async {
    throw Exception('Persistent store failed');
  }

  @override
  bool pathExists(
    String url,
    RegExp pathPattern, {
    Map<String, String?>? queryParams,
  }) {
    throw Exception('Persistent store failed');
  }

  @override
  Future<void> set(CacheResponse response) async {
    throw Exception('Persistent store failed');
  }
}
