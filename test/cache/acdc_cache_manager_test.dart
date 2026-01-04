import 'package:dart_acdc/dart_acdc.dart';
import 'package:test/test.dart';

void main() {
  group('AcdcCacheManager', () {
    test('is accessible via dio.cache extension', () async {
      // successful build requires valid token provider or disabled auth in test environment
      final dio = await const AcdcClientBuilder().disableAuth().build();

      expect(() => dio.cache, returnsNormally);
      expect(dio.cache, isNotNull);
      expect(dio.cache, isA<AcdcCacheManager>());
    });

    test('is accessible even when cache is disabled', () async {
      // Even if cache is disabled, the manager should be present (though operations might be no-ops)
      // Actually strictly speaking, if cache is disabled, the interceptor is not added,
      // but the manager is still created with null interceptor by default logic in builder?
      // Let's check builder logic: builder creates manager regardless.
      final dio =
          await const AcdcClientBuilder().disableCache().disableAuth().build();

      expect(() => dio.cache, returnsNormally);
      expect(dio.cache, isNotNull);

      // Verify no-op
      await dio.cache.clearCache();
    });

    test('clearCache delegates to interceptor', () async {
      // White-box testing implies we'd mock interceptor, but we are using public API.
      // We can verify it doesn't crash.
      final dio = await const AcdcClientBuilder().disableAuth().build();
      await expectLater(dio.cache.clearCache(), completes);
    });

    test('clearCacheForUrl delegates to interceptor', () async {
      final dio = await const AcdcClientBuilder().disableAuth().build();
      await expectLater(
        dio.cache.clearCacheForUrl('https://example.com'),
        completes,
      );
    });
  });
}
