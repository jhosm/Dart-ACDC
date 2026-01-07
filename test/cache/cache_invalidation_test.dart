import 'dart:io';

import 'package:dart_acdc/src/cache/encrypted_cache_store.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:path/path.dart' as p;

import 'cache_invalidation_test.mocks.dart';

@GenerateMocks([FlutterSecureStorage])
void main() {
  group('EncryptedCacheStore Invalidation & Errors', () {
    late MockFlutterSecureStorage mockStorage;
    late Directory tempDir;

    setUp(() {
      mockStorage = MockFlutterSecureStorage();
      final storageMap = <String, String>{};

      // Stateful mocks
      when(mockStorage.read(key: anyNamed('key')))
          .thenAnswer((invocation) async {
        final key = invocation.namedArguments[#key] as String;
        return storageMap[key];
      });

      when(mockStorage.write(key: anyNamed('key'), value: anyNamed('value')))
          .thenAnswer((invocation) async {
        final key = invocation.namedArguments[#key] as String;
        final value = invocation.namedArguments[#value] as String;
        storageMap[key] = value;
      });

      when(mockStorage.delete(key: anyNamed('key')))
          .thenAnswer((invocation) async {
        final key = invocation.namedArguments[#key] as String;
        storageMap.remove(key);
      });

      when(mockStorage.deleteAll()).thenAnswer((_) async {
        storageMap.clear();
      });

      tempDir = Directory.systemTemp.createTempSync('cache_invalidation_test');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('invalidates cache when version changes', () async {
      // 1. Initialize with version v1
      var store = EncryptedCacheStore(
        version: 'v1',
        storage: mockStorage,
        storePath: p.join(tempDir.path, 'test_cache'),
      );

      final response = _createCacheResponse(key: 'key1');
      await store.set(response);
      expect(await store.exists('key1'), isTrue);

      // 2. Re-initialize with same version v1 (should persist)
      store = EncryptedCacheStore(
        version: 'v1',
        storage: mockStorage,
        storePath: p.join(tempDir.path, 'test_cache'),
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
        storePath: p.join(tempDir.path, 'test_cache'),
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
      verify(mockStorage.read(key: 'acdc_cache_version'))
          .called(greaterThan(0));
      verify(mockStorage.write(key: 'acdc_cache_version', value: 'v2'))
          .called(1);
    });

    test('updates version key on first run if missing', () async {
      final store = EncryptedCacheStore(
        version: 'v1',
        storage: mockStorage,
        storePath: p.join(tempDir.path, 'version_update_cache'),
      );

      // Trigger load
      await store.exists('anything');

      verify(mockStorage.write(key: 'acdc_cache_version', value: 'v1'))
          .called(1);
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
        storePath: tempDir.path,
      );

      await expectLater(store.get('test_key'), throwsException);

      expect(capturedError, isNotNull);
      expect(capturedError.toString(), contains('Storage read error'));
    });

    test('calls onError when initialization fails', () async {
      final errorLog = <Object>[];

      // Make generic write fail to trigger initialization error (key generation)
      when(mockStorage.read(key: anyNamed('key')))
          .thenAnswer((_) async => null);
      when(mockStorage.write(key: anyNamed('key'), value: anyNamed('value')))
          .thenThrow(Exception('Storage write failed'));

      // Passing storePath so directory creation succeeds,
      // but key generation in _initialize will fail due to write error
      final store = EncryptedCacheStore(
        maxSize: 1024 * 1024,
        onError: (e, s) => errorLog.add(e),
        storage: mockStorage,
        storePath: tempDir.path,
      );

      // Attempting to use the store triggers initialization which fails
      await expectLater(
        () => store.set(_createCacheResponse(key: 'key1')),
        throwsException,
      );

      expect(errorLog, isNotEmpty);
      expect(errorLog.first.toString(), contains('Storage write failed'));
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
      statusCode: 200,
    );
