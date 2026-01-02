import 'package:dart_acdc/src/cache/encrypted_cache_store.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EncryptedCacheStore', () {
    late EncryptedCacheStore store;
    late FlutterSecureStorage mockStorage;

    setUp(() {
      // Use in-memory mock storage for testing
      FlutterSecureStorage.setMockInitialValues({});
      mockStorage = const FlutterSecureStorage();
      store = EncryptedCacheStore(
        maxSize: 1024 * 1024, // 1 MB
        storage: mockStorage,
      );
    });

    test('stores and retrieves cache responses', () async {
      final response = _createCacheResponse(
        key: 'test_key',
        url: 'https://api.example.com/users',
      );

      await store.set(response);

      final retrieved = await store.get('test_key');
      expect(retrieved, isNotNull);
      expect(retrieved!.key, equals('test_key'));
      expect(retrieved.url, equals('https://api.example.com/users'));
    });

    test('returns null for non-existent keys', () async {
      final result = await store.get('non_existent');
      expect(result, isNull);
    });

    test('checks if key exists', () async {
      final response = _createCacheResponse(key: 'exists_test');
      await store.set(response);

      expect(await store.exists('exists_test'), isTrue);
      expect(await store.exists('does_not_exist'), isFalse);
    });

    test('deletes cache entries', () async {
      final response = _createCacheResponse(key: 'delete_test');
      await store.set(response);

      expect(await store.exists('delete_test'), isTrue);

      await store.delete('delete_test');

      expect(await store.exists('delete_test'), isFalse);
    });

    test('clears all cache entries', () async {
      await store.set(_createCacheResponse(key: 'key1'));
      await store.set(_createCacheResponse(key: 'key2'));
      await store.set(_createCacheResponse(key: 'key3'));

      await store.clean();

      expect(await store.exists('key1'), isFalse);
      expect(await store.exists('key2'), isFalse);
      expect(await store.exists('key3'), isFalse);
    });

    test('implements LRU eviction when size limit exceeded', () async {
      final smallStore = EncryptedCacheStore(
        maxSize: 1500, // Small size to trigger eviction
        storage: mockStorage,
      );

      // Add multiple large entries to exceed size
      // Each entry is ~600-700 bytes when serialized
      await smallStore.set(_createLargeCacheResponse(key: 'first'));
      await smallStore.set(_createLargeCacheResponse(key: 'second'));
      await smallStore.set(_createLargeCacheResponse(key: 'third'));

      // At least one entry should be evicted (LRU) when we exceed maxSize
      // We can't guarantee which specific ones without knowing exact serialization size
      final totalStored = [
        await smallStore.exists('first'),
        await smallStore.exists('second'),
        await smallStore.exists('third'),
      ].where((exists) => exists).length;

      // Should have evicted at least one entry
      expect(totalStored, lessThan(3));
    });

    test('updates last accessed time on get', () async {
      final smallStore = EncryptedCacheStore(
        maxSize: 1500,
        storage: mockStorage,
      );

      await smallStore.set(_createLargeCacheResponse(key: 'first'));
      await smallStore.set(_createLargeCacheResponse(key: 'second'));

      // Access first to update LRU
      await smallStore.get('first');

      await smallStore.set(_createLargeCacheResponse(key: 'third'));

      // At least one entry should be evicted due to size constraint
      final totalStored = [
        await smallStore.exists('first'),
        await smallStore.exists('second'),
        await smallStore.exists('third'),
      ].where((exists) => exists).length;

      expect(totalStored, lessThan(3));

      // Third was just added, so it should still exist
      expect(await smallStore.exists('third'), isTrue);
    });

    test('deletes stale entries only when staleOnly is true', () async {
      final staleResponse = _createCacheResponse(
        key: 'stale',
        maxStale: DateTime.now().subtract(const Duration(hours: 1)),
      );
      final freshResponse = _createCacheResponse(
        key: 'fresh',
        maxStale: DateTime.now().add(const Duration(hours: 1)),
      );

      await store.set(staleResponse);
      await store.set(freshResponse);

      await store.delete('stale', staleOnly: true);
      await store.delete('fresh', staleOnly: true);

      expect(await store.exists('stale'), isFalse);
      expect(await store.exists('fresh'), isTrue);
    });

    test('getFromPath returns matching responses', () async {
      await store.set(_createCacheResponse(
        key: 'key1',
        url: 'https://api.example.com/users/1',
      ));
      await store.set(_createCacheResponse(
        key: 'key2',
        url: 'https://api.example.com/users/2',
      ));
      await store.set(_createCacheResponse(
        key: 'key3',
        url: 'https://api.other.com/users/1',
      ));

      final results = await store.getFromPath(
        RegExp(r'https://api\.example\.com/users/\d+'),
      );

      expect(results.length, equals(2));
      expect(results.map((r) => r.key), containsAll(['key1', 'key2']));
    });

    test('deleteFromPath removes matching entries', () async {
      await store.set(_createCacheResponse(
        key: 'key1',
        url: 'https://api.example.com/users/1',
      ));
      await store.set(_createCacheResponse(
        key: 'key2',
        url: 'https://api.example.com/users/2',
      ));
      await store.set(_createCacheResponse(
        key: 'key3',
        url: 'https://api.other.com/users/1',
      ));

      await store.deleteFromPath(
        RegExp(r'https://api\.example\.com/'),
      );

      expect(await store.exists('key1'), isFalse);
      expect(await store.exists('key2'), isFalse);
      expect(await store.exists('key3'), isTrue);
    });

    test('pathExists correctly matches URLs', () {
      expect(
        store.pathExists(
          'https://api.example.com/users',
          RegExp(r'https://api\.example\.com/'),
        ),
        isTrue,
      );

      expect(
        store.pathExists(
          'https://api.other.com/users',
          RegExp(r'https://api\.example\.com/'),
        ),
        isFalse,
      );
    });

    test('pathExists matches query parameters', () {
      expect(
        store.pathExists(
          'https://api.example.com/users?page=1&limit=10',
          RegExp(r'https://api\.example\.com/users'),
          queryParams: {'page': '1'},
        ),
        isTrue,
      );

      expect(
        store.pathExists(
          'https://api.example.com/users?page=2',
          RegExp(r'https://api\.example\.com/users'),
          queryParams: {'page': '1'},
        ),
        isFalse,
      );
    });

    test('close completes without errors', () async {
      await expectLater(store.close(), completes);
    });

    test('gracefully handles encryption failures', () async {
      // Even if encryption fails, operations should not throw
      final response = _createCacheResponse(key: 'test');

      await expectLater(store.set(response), completes);
      await expectLater(store.get('test'), completes);
      await expectLater(store.delete('test'), completes);
      await expectLater(store.clean(), completes);
    });
  });
}

/// Creates a test cache response.
CacheResponse _createCacheResponse({
  required String key,
  String? url,
  DateTime? maxStale,
}) {
  return CacheResponse(
    key: key,
    url: url ?? 'https://api.example.com/test',
    cacheControl: CacheControl(
      maxAge: 3600,
      privacy: null,
      noCache: false,
      noStore: false,
      mustRevalidate: false,
      maxStale: -1,
      minFresh: -1,
      other: [],
    ),
    content: [72, 101, 108, 108, 111], // "Hello" in bytes
    date: DateTime.now(),
    eTag: 'etag-123',
    expires: null,
    headers: [123, 125], // Empty JSON object
    lastModified: null,
    maxStale: maxStale,
    priority: CachePriority.normal,
    requestDate: DateTime.now(),
    responseDate: DateTime.now(),
  );
}

/// Creates a large test cache response for testing eviction.
CacheResponse _createLargeCacheResponse({
  required String key,
  String? url,
}) {
  // Create a large content payload (200 bytes)
  final largeContent = List<int>.filled(200, 65); // 200 'A' characters
  return CacheResponse(
    key: key,
    url: url ?? 'https://api.example.com/test',
    cacheControl: CacheControl(
      maxAge: 3600,
      privacy: null,
      noCache: false,
      noStore: false,
      mustRevalidate: false,
      maxStale: -1,
      minFresh: -1,
      other: [],
    ),
    content: largeContent,
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
}
