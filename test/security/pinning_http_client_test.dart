import 'dart:io';

import 'package:dart_acdc/src/exceptions/acdc_security_exception.dart';
import 'package:dart_acdc/src/logging/acdc_log_delegate.dart';
import 'package:dart_acdc/src/logging/log_level.dart';
import 'package:dart_acdc/src/security/pinning_http_client.dart';
import 'package:dart_acdc/src/security/pinning_verifier.dart';
import 'package:dio/dio.dart';
import 'package:mockito/annotations.dart';
import 'package:test/test.dart';

import 'pinning_http_client_test.mocks.dart';

@GenerateMocks(
  [HttpClientRequest, HttpConnectionInfo, X509Certificate, RequestOptions],
)
void main() {
  group('PinningHttpClient', () {
    late FakeHttpClient fakeInner;
    late FakePinningVerifier fakeVerifier;
    late MockX509Certificate mockCert;

    setUp(() {
      fakeInner = FakeHttpClient();
      fakeVerifier = FakePinningVerifier();
      mockCert = MockX509Certificate();
    });

    group('Constructor and initialization', () {
      test('sets badCertificateCallback on inner client', () {
        PinningHttpClient(fakeInner, fakeVerifier);

        expect(fakeInner.badCertificateCallback, isNotNull);
      });

      test('constructor accepts optional logDelegate', () {
        final logDelegate = FakeLogDelegate();
        final client = PinningHttpClient(
          fakeInner,
          fakeVerifier,
          logDelegate: logDelegate,
        );

        expect(client.logDelegate, equals(logDelegate));
      });
    });

    group('badCertificateCallback behavior', () {
      test('sends cert to verifier and returns true on success', () {
        PinningHttpClient(fakeInner, fakeVerifier);
        fakeVerifier.shouldThrow = false;

        final callback = fakeInner.badCertificateCallback!;
        final result = callback(mockCert, 'example.com', 443);

        expect(result, isTrue);
        expect(fakeVerifier.verifyCalled, isTrue);
      });

      test('returns false when verifier throws AcdcSecurityException', () {
        PinningHttpClient(fakeInner, fakeVerifier);
        fakeVerifier.shouldThrow = true;

        final callback = fakeInner.badCertificateCallback!;
        final result = callback(mockCert, 'example.com', 443);

        expect(result, isFalse);
      });

      test('returns false when verifier throws non-AcdcSecurityException', () {
        PinningHttpClient(fakeInner, fakeVerifier);
        fakeVerifier.shouldThrowGeneric = true;

        final callback = fakeInner.badCertificateCallback!;
        final result = callback(mockCert, 'example.com', 443);

        expect(result, isFalse);
      });

      test('returns true (allow) if verifier does not throw (ReportOnly)', () {
        PinningHttpClient(fakeInner, fakeVerifier);
        fakeVerifier.shouldThrow = false;

        final callback = fakeInner.badCertificateCallback!;
        final result = callback(mockCert, 'example.com', 443);

        expect(result, isTrue);
      });
    });

    group('badCertificateCallback setter', () {
      test('logs warning when external callback is set', () {
        final logDelegate = FakeLogDelegate();
        final client = PinningHttpClient(
          fakeInner,
          fakeVerifier,
          logDelegate: logDelegate,
        );

        client.badCertificateCallback = (cert, host, port) => true;

        expect(logDelegate.logCalled, isTrue);
        expect(logDelegate.lastLevel, equals(LogLevel.warning));
        expect(
          logDelegate.lastMessage,
          contains('External badCertificateCallback ignored'),
        );
      });

      test('does not crash when no logDelegate provided', () {
        final client = PinningHttpClient(fakeInner, fakeVerifier);

        expect(
          () => client.badCertificateCallback = (cert, host, port) => true,
          returnsNormally,
        );
      });
    });

    group('Property getters and setters', () {
      late PinningHttpClient client;

      setUp(() {
        client = PinningHttpClient(fakeInner, fakeVerifier);
      });

      test('autoUncompress getter and setter proxy to inner', () {
        fakeInner.autoUncompress = true;
        expect(client.autoUncompress, isTrue);

        client.autoUncompress = false;
        expect(fakeInner.autoUncompress, isFalse);
      });

      test('connectionTimeout getter and setter proxy to inner', () {
        final timeout = Duration(seconds: 30);
        fakeInner.connectionTimeout = timeout;
        expect(client.connectionTimeout, equals(timeout));

        client.connectionTimeout = Duration(seconds: 60);
        expect(fakeInner.connectionTimeout, equals(Duration(seconds: 60)));
      });

      test('idleTimeout getter and setter proxy to inner', () {
        final timeout = Duration(seconds: 15);
        fakeInner.idleTimeout = timeout;
        expect(client.idleTimeout, equals(timeout));

        client.idleTimeout = Duration(seconds: 30);
        expect(fakeInner.idleTimeout, equals(Duration(seconds: 30)));
      });

      test('maxConnectionsPerHost getter and setter proxy to inner', () {
        fakeInner.maxConnectionsPerHost = 6;
        expect(client.maxConnectionsPerHost, equals(6));

        client.maxConnectionsPerHost = 10;
        expect(fakeInner.maxConnectionsPerHost, equals(10));
      });

      test('userAgent getter and setter proxy to inner', () {
        fakeInner.userAgent = 'TestAgent/1.0';
        expect(client.userAgent, equals('TestAgent/1.0'));

        client.userAgent = 'NewAgent/2.0';
        expect(fakeInner.userAgent, equals('NewAgent/2.0'));
      });
    });

    group('Method delegation', () {
      late PinningHttpClient client;

      setUp(() {
        client = PinningHttpClient(fakeInner, fakeVerifier);
      });

      test('close delegates to inner client', () {
        client.close(force: true);
        expect(fakeInner.closeCalled, isTrue);
        expect(fakeInner.closeForce, isTrue);
      });

      test('addCredentials delegates to inner client', () {
        final uri = Uri.parse('https://example.com');
        client.addCredentials(uri, 'realm', FakeCredentials());
        expect(fakeInner.addCredentialsCalled, isTrue);
      });

      test('addProxyCredentials delegates to inner client', () {
        client.addProxyCredentials(
            'proxy.com', 8080, 'realm', FakeCredentials());
        expect(fakeInner.addProxyCredentialsCalled, isTrue);
      });
    });

    group('Setter delegation', () {
      late PinningHttpClient client;

      setUp(() {
        client = PinningHttpClient(fakeInner, fakeVerifier);
      });

      test('authenticate setter delegates to inner', () {
        Future<bool> authFunc(Uri url, String scheme, String? realm) async =>
            true;
        client.authenticate = authFunc;
        expect(fakeInner.authenticate, equals(authFunc));
      });

      test('authenticateProxy setter delegates to inner', () {
        Future<bool> authFunc(
          String host,
          int port,
          String scheme,
          String? realm,
        ) async =>
            true;
        client.authenticateProxy = authFunc;
        expect(fakeInner.authenticateProxy, equals(authFunc));
      });

      test('connectionFactory setter delegates to inner', () {
        Future<ConnectionTask<Socket>> factory(
          Uri url,
          String? proxyHost,
          int? proxyPort,
        ) async =>
            throw UnimplementedError();
        client.connectionFactory = factory;
        expect(fakeInner.connectionFactory, equals(factory));
      });

      test('findProxy setter delegates to inner', () {
        String finder(Uri url) => 'DIRECT';
        client.findProxy = finder;
        expect(fakeInner.findProxy, equals(finder));
      });

      test('keyLog setter delegates to inner', () {
        void logger(String line) {}
        client.keyLog = logger;
        expect(fakeInner.keyLog, equals(logger));
      });
    });

    group('HTTP method delegation', () {
      late PinningHttpClient client;
      late MockHttpClientRequest mockRequest;

      setUp(() {
        client = PinningHttpClient(fakeInner, fakeVerifier);
        mockRequest = MockHttpClientRequest();
        fakeInner.requestToReturn = mockRequest;
      });

      test('open delegates to inner', () async {
        final result = await client.open('GET', 'example.com', 443, '/path');
        expect(result, equals(mockRequest));
        expect(fakeInner.openCalled, isTrue);
      });

      test('openUrl delegates to inner', () async {
        final result =
            await client.openUrl('GET', Uri.parse('https://example.com'));
        expect(result, equals(mockRequest));
        expect(fakeInner.openUrlCalled, isTrue);
      });

      test('get delegates to inner', () async {
        final result = await client.get('example.com', 443, '/path');
        expect(result, equals(mockRequest));
        expect(fakeInner.getCalled, isTrue);
      });

      test('getUrl delegates to inner', () async {
        final result = await client.getUrl(Uri.parse('https://example.com'));
        expect(result, equals(mockRequest));
        expect(fakeInner.getUrlCalled, isTrue);
      });

      test('post delegates to inner', () async {
        final result = await client.post('example.com', 443, '/path');
        expect(result, equals(mockRequest));
        expect(fakeInner.postCalled, isTrue);
      });

      test('postUrl delegates to inner', () async {
        final result = await client.postUrl(Uri.parse('https://example.com'));
        expect(result, equals(mockRequest));
        expect(fakeInner.postUrlCalled, isTrue);
      });

      test('put delegates to inner', () async {
        final result = await client.put('example.com', 443, '/path');
        expect(result, equals(mockRequest));
        expect(fakeInner.putCalled, isTrue);
      });

      test('putUrl delegates to inner', () async {
        final result = await client.putUrl(Uri.parse('https://example.com'));
        expect(result, equals(mockRequest));
        expect(fakeInner.putUrlCalled, isTrue);
      });

      test('delete delegates to inner', () async {
        final result = await client.delete('example.com', 443, '/path');
        expect(result, equals(mockRequest));
        expect(fakeInner.deleteCalled, isTrue);
      });

      test('deleteUrl delegates to inner', () async {
        final result = await client.deleteUrl(Uri.parse('https://example.com'));
        expect(result, equals(mockRequest));
        expect(fakeInner.deleteUrlCalled, isTrue);
      });

      test('head delegates to inner', () async {
        final result = await client.head('example.com', 443, '/path');
        expect(result, equals(mockRequest));
        expect(fakeInner.headCalled, isTrue);
      });

      test('headUrl delegates to inner', () async {
        final result = await client.headUrl(Uri.parse('https://example.com'));
        expect(result, equals(mockRequest));
        expect(fakeInner.headUrlCalled, isTrue);
      });

      test('patch delegates to inner', () async {
        final result = await client.patch('example.com', 443, '/path');
        expect(result, equals(mockRequest));
        expect(fakeInner.patchCalled, isTrue);
      });

      test('patchUrl delegates to inner', () async {
        final result = await client.patchUrl(Uri.parse('https://example.com'));
        expect(result, equals(mockRequest));
        expect(fakeInner.patchUrlCalled, isTrue);
      });
    });
  });
}

class FakeHttpClient implements HttpClient {
  @override
  bool Function(X509Certificate cert, String host, int port)?
      badCertificateCallback;

  @override
  bool autoUncompress = false;

  @override
  Duration? connectionTimeout;

  @override
  Duration idleTimeout = Duration(seconds: 15);

  @override
  int? maxConnectionsPerHost;

  @override
  String? userAgent;

  @override
  Future<bool> Function(Uri url, String scheme, String? realm)? authenticate;

  @override
  Future<bool> Function(String host, int port, String scheme, String? realm)?
      authenticateProxy;

  @override
  Future<ConnectionTask<Socket>> Function(
    Uri url,
    String? proxyHost,
    int? proxyPort,
  )? connectionFactory;

  @override
  String Function(Uri url)? findProxy;

  @override
  void Function(String line)? keyLog;

  bool closeCalled = false;
  bool closeForce = false;
  bool addCredentialsCalled = false;
  bool addProxyCredentialsCalled = false;
  bool openCalled = false;
  bool openUrlCalled = false;
  bool getCalled = false;
  bool getUrlCalled = false;
  bool postCalled = false;
  bool postUrlCalled = false;
  bool putCalled = false;
  bool putUrlCalled = false;
  bool deleteCalled = false;
  bool deleteUrlCalled = false;
  bool headCalled = false;
  bool headUrlCalled = false;
  bool patchCalled = false;
  bool patchUrlCalled = false;

  HttpClientRequest? requestToReturn;

  @override
  void close({bool force = false}) {
    closeCalled = true;
    closeForce = force;
  }

  @override
  void addCredentials(
    Uri url,
    String realm,
    HttpClientCredentials credentials,
  ) {
    addCredentialsCalled = true;
  }

  @override
  void addProxyCredentials(
    String host,
    int port,
    String realm,
    HttpClientCredentials credentials,
  ) {
    addProxyCredentialsCalled = true;
  }

  @override
  Future<HttpClientRequest> open(
    String method,
    String host,
    int port,
    String path,
  ) async {
    openCalled = true;
    return requestToReturn!;
  }

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    openUrlCalled = true;
    return requestToReturn!;
  }

  @override
  Future<HttpClientRequest> get(String host, int port, String path) async {
    getCalled = true;
    return requestToReturn!;
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    getUrlCalled = true;
    return requestToReturn!;
  }

  @override
  Future<HttpClientRequest> post(String host, int port, String path) async {
    postCalled = true;
    return requestToReturn!;
  }

  @override
  Future<HttpClientRequest> postUrl(Uri url) async {
    postUrlCalled = true;
    return requestToReturn!;
  }

  @override
  Future<HttpClientRequest> put(String host, int port, String path) async {
    putCalled = true;
    return requestToReturn!;
  }

  @override
  Future<HttpClientRequest> putUrl(Uri url) async {
    putUrlCalled = true;
    return requestToReturn!;
  }

  @override
  Future<HttpClientRequest> delete(String host, int port, String path) async {
    deleteCalled = true;
    return requestToReturn!;
  }

  @override
  Future<HttpClientRequest> deleteUrl(Uri url) async {
    deleteUrlCalled = true;
    return requestToReturn!;
  }

  @override
  Future<HttpClientRequest> head(String host, int port, String path) async {
    headCalled = true;
    return requestToReturn!;
  }

  @override
  Future<HttpClientRequest> headUrl(Uri url) async {
    headUrlCalled = true;
    return requestToReturn!;
  }

  @override
  Future<HttpClientRequest> patch(String host, int port, String path) async {
    patchCalled = true;
    return requestToReturn!;
  }

  @override
  Future<HttpClientRequest> patchUrl(Uri url) async {
    patchUrlCalled = true;
    return requestToReturn!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakePinningVerifier implements PinningVerifier {
  bool shouldThrow = false;
  bool shouldThrowGeneric = false;
  bool verifyCalled = false;

  @override
  void verify(String hostname, List<X509Certificate> chain) {
    verifyCalled = true;
    if (shouldThrowGeneric) {
      throw Exception('Generic error');
    }
    if (shouldThrow) {
      throw AcdcSecurityException(
        requestOptions: MockRequestOptions(),
        hostname: hostname,
      );
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeLogDelegate implements AcdcLogDelegate {
  bool logCalled = false;
  String? lastMessage;
  LogLevel? lastLevel;
  Map<String, dynamic>? lastMetadata;

  @override
  void log(String message, LogLevel level, [Map<String, dynamic>? metadata]) {
    logCalled = true;
    lastMessage = message;
    lastLevel = level;
    lastMetadata = metadata;
  }
}

class FakeCredentials implements HttpClientCredentials {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
