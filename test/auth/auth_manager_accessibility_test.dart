import 'package:dart_acdc/dart_acdc.dart';

import 'package:test/test.dart';

void main() {
  test('AuthManager is accessible when auth is disabled', () async {
    final dio = await const AcdcClientBuilder().disableAuth().build();

    expect(() => dio.auth, returnsNormally);
    expect(dio.auth, isNotNull);

    // Verify methods don't crash
    // Cache operations moved to dio.cache
    await dio.cache.clearCache();
    // Logout still accessible on auth
    await dio.auth.logout();

    // refreshNow should throw StateError
    expect(
      () => dio.auth.refreshNow(),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          contains('Authentication is disabled'),
        ),
      ),
    );
  });
}
