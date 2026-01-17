import 'package:dart_acdc/src/builder/acdc_client_builder.dart';
import 'package:dart_acdc/src/cache/cache_config.dart';
import 'package:dart_acdc/src/interceptors/cache_interceptor.dart';
import 'package:dio_cache_interceptor/dio_cache_interceptor.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fake_token_provider.dart';
import '../helpers/mock_network_info.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    const channel = MethodChannel('dev.fluttercommunity.plus/connectivity');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (methodCall) async {
      if (methodCall.method == 'check') {
        return 'wifi';
      }
      if (methodCall.method == 'checkConnectivity') {
        return <dynamic>['wifi'];
      }
      return null;
    });
  });

  group('AcdcClientBuilder.withCacheStore', () {
    test('returns new builder instance', () {
      const builder1 = AcdcClientBuilder();
      final store = MemCacheStore();
      final builder2 = builder1.withCacheStore(store);

      expect(builder1, isNot(same(builder2)));
    });

    test('injected store is used instead of factory-created store', () async {
      final injectedStore = MemCacheStore(maxSize: 5 * 1024 * 1024);

      final dio = await const AcdcClientBuilder()
          .withTokenProvider(FakeTokenProvider())
          .withNetworkInfo(MockNetworkInfo())
          .withCacheStore(injectedStore)
          .build();

      final cacheInterceptor =
          dio.interceptors.whereType<AcdcCacheInterceptor>().firstOrNull;

      expect(cacheInterceptor, isNotNull);
      expect(cacheInterceptor!.store, same(injectedStore));
    });

    test('works together with withCache for config', () async {
      final injectedStore = MemCacheStore(maxSize: 5 * 1024 * 1024);
      const customConfig = CacheConfig(
        ttl: Duration(minutes: 30),
        staleWhileRevalidate: true,
      );

      final dio = await const AcdcClientBuilder()
          .withTokenProvider(FakeTokenProvider())
          .withNetworkInfo(MockNetworkInfo())
          .withCache(customConfig)
          .withCacheStore(injectedStore)
          .build();

      final cacheInterceptor =
          dio.interceptors.whereType<AcdcCacheInterceptor>().firstOrNull;

      expect(cacheInterceptor, isNotNull);
      // Store is the injected one
      expect(cacheInterceptor!.store, same(injectedStore));
    });

    test('cache persists across client rebuilds with shared store', () async {
      // Create a shared store
      final sharedStore = MemCacheStore(maxSize: 5 * 1024 * 1024);

      // Create builder with shared store
      final builder = const AcdcClientBuilder()
          .withTokenProvider(FakeTokenProvider())
          .withNetworkInfo(MockNetworkInfo())
          .withCache(const CacheConfig(ttl: Duration(minutes: 5)))
          .withCacheStore(sharedStore);

      // Build first client
      final dio1 = await builder.build();
      final cacheInterceptor1 =
          dio1.interceptors.whereType<AcdcCacheInterceptor>().first;

      // Build second client
      final dio2 = await builder.build();
      final cacheInterceptor2 =
          dio2.interceptors.whereType<AcdcCacheInterceptor>().first;

      // Both should use the same store instance
      expect(cacheInterceptor1.store, same(sharedStore));
      expect(cacheInterceptor2.store, same(sharedStore));
      expect(cacheInterceptor1.store, same(cacheInterceptor2.store));
    });

    test('disableCache prevents cache interceptor even with injected store',
        () async {
      final injectedStore = MemCacheStore();

      final dio = await const AcdcClientBuilder()
          .withTokenProvider(FakeTokenProvider())
          .withNetworkInfo(MockNetworkInfo())
          .withCacheStore(injectedStore)
          .disableCache()
          .build();

      final cacheInterceptor =
          dio.interceptors.whereType<AcdcCacheInterceptor>().firstOrNull;

      expect(cacheInterceptor, isNull);
    });

    test('withCache after disableCache re-enables caching with store',
        () async {
      final injectedStore = MemCacheStore();

      final dio = await const AcdcClientBuilder()
          .withTokenProvider(FakeTokenProvider())
          .withNetworkInfo(MockNetworkInfo())
          .withCacheStore(injectedStore)
          .disableCache()
          .withCache(const CacheConfig())
          .build();

      final cacheInterceptor =
          dio.interceptors.whereType<AcdcCacheInterceptor>().firstOrNull;

      expect(cacheInterceptor, isNotNull);
      expect(cacheInterceptor!.store, same(injectedStore));
    });

    test('order of withCache and withCacheStore does not matter', () async {
      final injectedStore = MemCacheStore(maxSize: 3 * 1024 * 1024);
      const customConfig = CacheConfig(ttl: Duration(hours: 2));

      // withCacheStore before withCache
      final dio1 = await const AcdcClientBuilder()
          .withTokenProvider(FakeTokenProvider())
          .withNetworkInfo(MockNetworkInfo())
          .withCacheStore(injectedStore)
          .withCache(customConfig)
          .build();

      // withCache before withCacheStore
      final dio2 = await const AcdcClientBuilder()
          .withTokenProvider(FakeTokenProvider())
          .withNetworkInfo(MockNetworkInfo())
          .withCache(customConfig)
          .withCacheStore(injectedStore)
          .build();

      final interceptor1 =
          dio1.interceptors.whereType<AcdcCacheInterceptor>().first;
      final interceptor2 =
          dio2.interceptors.whereType<AcdcCacheInterceptor>().first;

      // Both should use the same injected store
      expect(interceptor1.store, same(injectedStore));
      expect(interceptor2.store, same(injectedStore));
    });

    test('default cache config is used when only withCacheStore is called',
        () async {
      final injectedStore = MemCacheStore();

      final dio = await const AcdcClientBuilder()
          .withTokenProvider(FakeTokenProvider())
          .withNetworkInfo(MockNetworkInfo())
          .withCacheStore(injectedStore)
          .build();

      final cacheInterceptor =
          dio.interceptors.whereType<AcdcCacheInterceptor>().firstOrNull;

      // Cache interceptor should be added with the injected store
      expect(cacheInterceptor, isNotNull);
      expect(cacheInterceptor!.store, same(injectedStore));
    });
  });
}
