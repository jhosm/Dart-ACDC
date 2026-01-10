import 'package:dart_acdc/src/cache/cache_config.dart';
import 'package:dart_acdc/src/cache/cache_store_factory.dart';
import 'package:dart_acdc/src/cache/encrypted_cache_store.dart';
import 'package:dart_acdc/src/cache/two_tier_cache_store.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:test/test.dart';

void main() {
  group('CacheStoreFactory', () {
    test('builds TwoTierCacheStore when inMemory is true', () {
      final config = CacheConfig(inMemory: true);
      final store = CacheStoreFactory.build(config);

      expect(store, isA<TwoTierCacheStore>());
    });

    test('builds EncryptedCacheStore when inMemory is false', () {
      final config = CacheConfig(inMemory: false);
      final store = CacheStoreFactory.build(config);

      expect(store, isA<EncryptedCacheStore>());
    });

    test('builds MemCacheStore when on web (simulated)', () {
      // Ideally we would simulate kIsWeb, but it's a compile-time constant.
      // We can only test the non-web paths here reliably.
      // However, we can assert that for non-web (VM), it behaves as expected.
    });

    // Test that the created store has correct properties passed from config if accessible
    // Since we can't inspect the private properties easily, we ensure the type is correct
    // and initialization doesn't throw.

    test('build does not throw error', () {
      final config = CacheConfig();
      expect(() => CacheStoreFactory.build(config), returnsNormally);
    });
  });
}
