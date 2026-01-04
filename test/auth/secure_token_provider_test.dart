import 'package:dart_acdc/src/auth/secure_token_provider.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';

import 'secure_token_provider_test.mocks.dart';

@GenerateMocks([FlutterSecureStorage])
void main() {
  group('SecureTokenProvider', () {
    late MockFlutterSecureStorage mockStorage;
    late SecureTokenProvider provider;

    setUp(() {
      mockStorage = MockFlutterSecureStorage();
      provider = SecureTokenProvider(storage: mockStorage);
    });

    test('getAccessToken reads from secure storage', () async {
      when(mockStorage.read(key: 'acdc_access_token'))
          .thenAnswer((_) async => 'access_token');

      final token = await provider.getAccessToken();

      expect(token, 'access_token');
      verify(mockStorage.read(key: 'acdc_access_token')).called(1);
    });

    test('getRefreshToken reads from secure storage', () async {
      when(mockStorage.read(key: 'acdc_refresh_token'))
          .thenAnswer((_) async => 'refresh_token');

      final token = await provider.getRefreshToken();

      expect(token, 'refresh_token');
      verify(mockStorage.read(key: 'acdc_refresh_token')).called(1);
    });

    test('getAccessTokenExpiry returns parsed DateTime', () async {
      final now = DateTime.utc(2024, 1);
      when(mockStorage.read(key: 'acdc_access_expiry'))
          .thenAnswer((_) async => now.toIso8601String());

      final expiry = await provider.getAccessTokenExpiry();

      expect(expiry, now);
      verify(mockStorage.read(key: 'acdc_access_expiry')).called(1);
    });

    test('getAccessTokenExpiry returns null if not found', () async {
      when(mockStorage.read(key: 'acdc_access_expiry'))
          .thenAnswer((_) async => null);

      final expiry = await provider.getAccessTokenExpiry();

      expect(expiry, isNull);
    });

    test('getRefreshTokenExpiry returns parsed DateTime', () async {
      final now = DateTime.utc(2024, 1);
      when(mockStorage.read(key: 'acdc_refresh_expiry'))
          .thenAnswer((_) async => now.toIso8601String());

      final expiry = await provider.getRefreshTokenExpiry();

      expect(expiry, now);
      verify(mockStorage.read(key: 'acdc_refresh_expiry')).called(1);
    });

    test('setTokens writes all values to secure storage', () async {
      final accessExpiry = DateTime.utc(2024, 1);
      final refreshExpiry = DateTime.utc(2024, 1, 2);

      when(mockStorage.write(key: anyNamed('key'), value: anyNamed('value')))
          .thenAnswer((_) async {});

      await provider.setTokens(
        accessToken: 'access_123',
        refreshToken: 'refresh_123',
        accessExpiry: accessExpiry,
        refreshExpiry: refreshExpiry,
      );

      verify(mockStorage.write(key: 'acdc_access_token', value: 'access_123'))
          .called(1);
      verify(mockStorage.write(key: 'acdc_refresh_token', value: 'refresh_123'))
          .called(1);
      verify(
        mockStorage.write(
          key: 'acdc_access_expiry',
          value: accessExpiry.toIso8601String(),
        ),
      ).called(1);
      verify(
        mockStorage.write(
          key: 'acdc_refresh_expiry',
          value: refreshExpiry.toIso8601String(),
        ),
      ).called(1);
    });

    test('clearTokens deletes all keys', () async {
      when(mockStorage.delete(key: anyNamed('key'))).thenAnswer((_) async {});

      await provider.clearTokens();

      verify(mockStorage.delete(key: 'acdc_access_token')).called(1);
      verify(mockStorage.delete(key: 'acdc_refresh_token')).called(1);
      verify(mockStorage.delete(key: 'acdc_access_expiry')).called(1);
      verify(mockStorage.delete(key: 'acdc_refresh_expiry')).called(1);
    });
  });
}
