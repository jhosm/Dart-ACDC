import 'package:dart_acdc/src/cache/encrypted_cache_store.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'cache_invalidation_test.mocks.dart';

@GenerateMocks([FlutterSecureStorage])
void main() {
  group('EncryptedCacheStore Invalidation & Errors', () {
    late FlutterSecureStorage mockStorage;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      mockStorage = const FlutterSecureStorage();
    });

    test('invalidates cache when version changes', () async {
      // 1. Initialize with version v1
      var store = EncryptedCacheStore(
        version: 'v1',
        storage: mockStorage,
      );

      final response = _createCacheResponse(key: 'key1');
      await store.set(response);
      expect(await store.exists('key1'), isTrue);

      // 2. Re-initialize with same version v1 (should persist)
      store = EncryptedCacheStore(
        version: 'v1',
        storage: mockStorage,
      );
      expect(
        await store.exists('key1'),
        isTrue,
        reason: 'Should persist with same version',
      );

      // 3. Re-initialize with version v2 (should clear)
      store = EncryptedCacheStore(
        version: 'v2',
        storage: mockStorage,
      );

      // Force metadata reload by calling exists/get
      expect(
        await store.exists('key1'),
        isFalse,
        reason: 'Should clear on version change',
      );

      // 4. Verify everything is gone
      final response2 = _createCacheResponse(key: 'key2');
      await store.set(response2);
      expect(await store.exists('key2'), isTrue);

      // Check that version key is updated
      final version = await mockStorage.read(key: 'acdc_cache_version');
      expect(version, equals('v2'));
    });

    test('updates version key on first run if missing', () async {
      final store = EncryptedCacheStore(
        version: 'v1',
        storage: mockStorage,
      );

      // Trigger load
      await store.exists('anything');

      final version = await mockStorage.read(key: 'acdc_cache_version');
      expect(version, equals('v1'));
    });

    test('calls onError when storage read fails', () async {
      final failingStorage = MockFlutterSecureStorage();

      when(failingStorage.read(key: anyNamed('key')))
          .thenThrow(Exception('Storage read error'));

      Object? capturedError;
      final store = EncryptedCacheStore(
        storage: failingStorage,
        onError: (error, stack) {
          capturedError = error;
        },
      );

      await store.get('test_key');

      expect(capturedError, isNotNull);
      expect(capturedError.toString(), contains('Storage read error'));
    });

    test('calls onError when storage write fails', () async {
      final failingStorage = MockFlutterSecureStorage();

      // Mock read to allow metadata loading (or fail there too, fine either way)
      when(failingStorage.read(key: anyNamed('key')))
          .thenAnswer((_) async => null);

      when(failingStorage.write(key: anyNamed('key'), value: anyNamed('value')))
          .thenThrow(Exception('Storage write error'));

      Object? capturedError;
      final store = EncryptedCacheStore(
        storage: failingStorage,
        onError: (error, stack) {
          capturedError = error;
        },
      );

      final response = _createCacheResponse(key: 'test_key');
      await store.set(response);

      expect(capturedError, isNotNull);
      expect(capturedError.toString(), contains('Storage write error'));
    });
  });
}

CacheResponse _createCacheResponse({
  required String key,
}) =>
    CacheResponse(
      key: key,
      url: 'https://api.example.com/test',
      content: [1, 2, 3],
      date: DateTime.now(),
      eTag: 'etag',
      priority: CachePriority.normal,
      requestDate: DateTime.now(),
      responseDate: DateTime.now(),
      cacheControl: CacheControl(),
      expires: null,
      headers: [],
      lastModified: null,
      maxStale: null,
    );
