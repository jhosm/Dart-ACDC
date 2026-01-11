import 'dart:async';
import 'dart:io';

import 'package:dart_acdc/src/exceptions/acdc_security_exception.dart';
import 'package:dart_acdc/src/security/pinning_http_client.dart';
import 'package:dart_acdc/src/security/pinning_verifier.dart';
import 'package:dio/dio.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'pinning_http_client_test.mocks.dart';

@GenerateMocks(
    [HttpClientRequest, HttpConnectionInfo, X509Certificate, RequestOptions])
void main() {
  group('PinningHttpClient', () {
    late FakeHttpClient fakeInner;
    late FakePinningVerifier fakeVerifier;
    late PinningHttpClient client;
    late MockX509Certificate mockCert;

    setUp(() {
      fakeInner = FakeHttpClient();
      fakeVerifier = FakePinningVerifier();
      client = PinningHttpClient(fakeInner, fakeVerifier);

      mockCert = MockX509Certificate();
    });

    test(
        'badCertificateCallback sends cert to verifier and returns true on success',
        () {
      fakeVerifier.shouldThrow = false;

      final callback = fakeInner.badCertificateCallback!;
      final result = callback(mockCert, 'example.com', 443);

      expect(result, isTrue);
      expect(fakeVerifier.verifyCalled, isTrue);
    });

    test(
        'badCertificateCallback returns false when verifier throws AcdcSecurityException',
        () {
      fakeVerifier.shouldThrow = true;

      final callback = fakeInner.badCertificateCallback!;
      final result = callback(mockCert, 'example.com', 443);

      expect(result, isFalse);
    });

    test(
        'badCertificateCallback returns true (allow) if verifier absorbs checks (ReportOnly)',
        () {
      // Typically verifier handles ReportOnly internal logic and decides whether to throw.
      // Here, the test simulates "Verifier does NOT throw".
      // Which means reportOnly was true (or pin matched).
      fakeVerifier.shouldThrow = false;

      final callback = fakeInner.badCertificateCallback!;
      final result = callback(mockCert, 'example.com', 443);

      expect(result, isTrue);
    });
  });
}

class FakeHttpClient implements HttpClient {
  @override
  bool Function(X509Certificate cert, String host, int port)?
      badCertificateCallback;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakePinningVerifier implements PinningVerifier {
  bool shouldThrow = false;
  bool verifyCalled = false;

  @override
  void verify(String hostname, List<X509Certificate> chain) {
    verifyCalled = true;
    if (shouldThrow) {
      throw AcdcSecurityException(
          requestOptions: MockRequestOptions(), hostname: hostname);
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

// Ensure mocks are generated for needed classes
// We removed manual MockRequestOptions as we added it to annotation
