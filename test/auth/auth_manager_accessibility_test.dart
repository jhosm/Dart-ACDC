import 'package:dart_acdc/dart_acdc.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

void main() {
  test('AuthManager is accessible when no auth is explicitly configured',
      () async {
    final dio = await AcdcClientBuilder().build();

    expect(() => dio.auth, returnsNormally);
    expect(dio.auth, isNotNull);
  });
}
