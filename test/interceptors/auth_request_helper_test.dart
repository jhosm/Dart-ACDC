import 'package:dart_acdc/src/interceptors/auth_request_helper.dart';
import 'package:dio/dio.dart';
import 'package:test/test.dart';

void main() {
  group('AuthRequestHelper', () {
    group('createEmptyRequestOptions', () {
      test('creates a new RequestOptions instance', () {
        final options = AuthRequestHelper.createEmptyRequestOptions();

        expect(options, isA<RequestOptions>());
        expect(options.path, isEmpty);
      });

      test('creates unique instances each time', () {
        final options1 = AuthRequestHelper.createEmptyRequestOptions();
        final options2 = AuthRequestHelper.createEmptyRequestOptions();

        expect(identical(options1, options2), isFalse);
      });
    });

    group('injectBearerToken', () {
      test('adds Authorization header with Bearer token', () {
        final options = RequestOptions(path: '/test');

        AuthRequestHelper.injectBearerToken(options, 'my-token');

        expect(options.headers['Authorization'], equals('Bearer my-token'));
      });

      test('overwrites existing Authorization header', () {
        final options = RequestOptions(
          path: '/test',
          headers: {'Authorization': 'Basic old-auth'},
        );

        AuthRequestHelper.injectBearerToken(options, 'new-token');

        expect(options.headers['Authorization'], equals('Bearer new-token'));
      });

      test('handles empty token string', () {
        final options = RequestOptions(path: '/test');

        AuthRequestHelper.injectBearerToken(options, '');

        expect(options.headers['Authorization'], equals('Bearer '));
      });
    });

    group('hasManualAuthHeader', () {
      test('returns true when Authorization header exists', () {
        final options = RequestOptions(
          path: '/test',
          headers: {'Authorization': 'Bearer manual-token'},
        );

        expect(AuthRequestHelper.hasManualAuthHeader(options), isTrue);
      });

      test('returns false when Authorization header does not exist', () {
        final options = RequestOptions(path: '/test');

        expect(AuthRequestHelper.hasManualAuthHeader(options), isFalse);
      });

      test('returns false when headers are empty', () {
        final options = RequestOptions(path: '/test', headers: {});

        expect(AuthRequestHelper.hasManualAuthHeader(options), isFalse);
      });

      test('is case-insensitive for header key (Dio behavior)', () {
        final options = RequestOptions(
          path: '/test',
          headers: {'authorization': 'Bearer token'}, // lowercase
        );

        // Dio headers are case-insensitive, so this should still return true
        expect(AuthRequestHelper.hasManualAuthHeader(options), isTrue);
      });
    });

    group('markAsRetry', () {
      test('sets retry flag in request extra', () {
        final options = RequestOptions(path: '/test');

        AuthRequestHelper.markAsRetry(options);

        expect(options.extra['_acdc_retry_after_refresh'], isTrue);
      });

      test('overwrites existing retry flag', () {
        final options = RequestOptions(
          path: '/test',
          extra: {'_acdc_retry_after_refresh': false},
        );

        AuthRequestHelper.markAsRetry(options);

        expect(options.extra['_acdc_retry_after_refresh'], isTrue);
      });
    });

    group('isRetryRequest', () {
      test('returns true when retry flag is true', () {
        final options = RequestOptions(
          path: '/test',
          extra: {'_acdc_retry_after_refresh': true},
        );

        expect(AuthRequestHelper.isRetryRequest(options), isTrue);
      });

      test('returns false when retry flag is false', () {
        final options = RequestOptions(
          path: '/test',
          extra: {'_acdc_retry_after_refresh': false},
        );

        expect(AuthRequestHelper.isRetryRequest(options), isFalse);
      });

      test('returns false when retry flag does not exist', () {
        final options = RequestOptions(path: '/test');

        expect(AuthRequestHelper.isRetryRequest(options), isFalse);
      });

      test('returns false when extra is empty', () {
        final options = RequestOptions(path: '/test', extra: {});

        expect(AuthRequestHelper.isRetryRequest(options), isFalse);
      });

      test('returns false when retry flag is non-boolean', () {
        final options = RequestOptions(
          path: '/test',
          extra: {'_acdc_retry_after_refresh': 'true'}, // string, not boolean
        );

        expect(AuthRequestHelper.isRetryRequest(options), isFalse);
      });
    });

    group('integration scenarios', () {
      test('typical auth flow without manual header', () {
        final options = RequestOptions(path: '/api/data');

        // Check no manual auth
        expect(AuthRequestHelper.hasManualAuthHeader(options), isFalse);

        // Inject token
        AuthRequestHelper.injectBearerToken(options, 'access-token-123');
        expect(
          options.headers['Authorization'],
          equals('Bearer access-token-123'),
        );

        // Not a retry initially
        expect(AuthRequestHelper.isRetryRequest(options), isFalse);
      });

      test('retry flow after 401', () {
        final options = RequestOptions(path: '/api/data');

        // First request - inject token
        AuthRequestHelper.injectBearerToken(options, 'old-token');

        // Mark as retry after refresh
        AuthRequestHelper.markAsRetry(options);
        expect(AuthRequestHelper.isRetryRequest(options), isTrue);

        // Inject new token for retry
        AuthRequestHelper.injectBearerToken(options, 'new-token');
        expect(options.headers['Authorization'], equals('Bearer new-token'));

        // Still marked as retry
        expect(AuthRequestHelper.isRetryRequest(options), isTrue);
      });

      test('manual auth header bypasses token injection', () {
        final options = RequestOptions(
          path: '/api/data',
          headers: {'Authorization': 'Bearer manual-override'},
        );

        expect(AuthRequestHelper.hasManualAuthHeader(options), isTrue);

        // Even if we inject, it would overwrite (showing we shouldn't call inject)
        // In actual use, we check hasManualAuthHeader first
      });
    });
  });
}
