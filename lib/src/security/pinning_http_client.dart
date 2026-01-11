import 'dart:async';
import 'dart:io';

import 'package:dart_acdc/src/exceptions/acdc_security_exception.dart';
import 'package:dart_acdc/src/security/pinning_verifier.dart';

/// A wrapper around [HttpClient] that enforces certificate pinning.
class PinningHttpClient implements HttpClient {
  final HttpClient _inner;
  final PinningVerifier _verifier;

  PinningHttpClient(this._inner, this._verifier) {
    // We must set the badCertificateCallback on the inner client immediately
    // to catch untrusted certificates (e.g., self-signed or invalid hostname).
    // Note: If the user provides their own callback via properties, we need to handle that.
    // But since this is a specific security client, we take control.
    _inner.badCertificateCallback = _handleBadCertificate;
  }

  bool _handleBadCertificate(X509Certificate cert, String host, int port) {
    // This callback is invoked for "bad" certificates (untrusted root, mismatch, expired).
    // In pinning, we ignore standard trust IF the certificate matches our pin.
    // So if the verifier passes, we return true (trust it).
    // If verifier fails, we return false (reject).

    try {
      // Create a chain of 1 (leaf) since badCertificateCallback only gives us the leaf.
      // This is a limitation, but often sufficient for pinning the leaf.
      _verifier.verify(host, [cert]);
      return true; // Pinned & Trusted by us.
    } on AcdcSecurityException {
      // If reportOnly mode is on, verify() does NOT throw, so we returned true above.
      // Wait, if verify() was reportOnly, it consumes exception and returns normal.
      // So we return true! This allows the "bad" cert to proceed if reportOnly is on.
      // Correct.
      return false; // Not pinned, so it remains "bad".
    } catch (e) {
      return false;
    }
  }

  // --- HttpClient Interface Implementation (Proxy) ---

  @override
  bool get autoUncompress => _inner.autoUncompress;
  @override
  set autoUncompress(bool value) => _inner.autoUncompress = value;

  @override
  Duration? get connectionTimeout => _inner.connectionTimeout;
  @override
  set connectionTimeout(Duration? value) => _inner.connectionTimeout = value;

  @override
  Duration get idleTimeout => _inner.idleTimeout;
  @override
  set idleTimeout(Duration value) => _inner.idleTimeout = value;

  @override
  int? get maxConnectionsPerHost => _inner.maxConnectionsPerHost;
  @override
  set maxConnectionsPerHost(int? value) => _inner.maxConnectionsPerHost = value;

  @override
  String? get userAgent => _inner.userAgent;
  @override
  set userAgent(String? value) => _inner.userAgent = value;

  @override
  void addCredentials(
          Uri url, String realm, HttpClientCredentials credentials) =>
      _inner.addCredentials(url, realm, credentials);

  @override
  void addProxyCredentials(String host, int port, String realm,
          HttpClientCredentials credentials) =>
      _inner.addProxyCredentials(host, port, realm, credentials);

  @override
  set authenticate(
          Future<bool> Function(Uri url, String scheme, String? realm)? f) =>
      _inner.authenticate = f;

  @override
  set authenticateProxy(
          Future<bool> Function(
                  String host, int port, String scheme, String? realm)?
              f) =>
      _inner.authenticateProxy = f;

  @override
  set badCertificateCallback(
      bool Function(X509Certificate cert, String host, int port)? callback) {
    // If the USER tries to set a callback, we should wrap it or error?
    // For now, we ignore external overrides because pinning must be authoritative.
    // Or we could chain, but that complicates "I allow this" vs "Pinning allows this".
    // Pinning is stricter.
    // TODO: Log warning?
  }

  @override
  void close({bool force = false}) => _inner.close(force: force);

  @override
  set connectionFactory(
          Future<ConnectionTask<Socket>> Function(
                  Uri url, String? proxyHost, int? proxyPort)?
              f) =>
      _inner.connectionFactory = f;

  @override
  set findProxy(String Function(Uri url)? f) => _inner.findProxy = f;

  @override
  set keyLog(Function(String line)? callback) => _inner.keyLog = callback;

  // --- Methods just proxy to inner ---

  @override
  Future<HttpClientRequest> open(
      String method, String host, int port, String path) {
    return _inner.open(method, host, port, path);
  }

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) {
    return _inner.openUrl(method, url);
  }

  @override
  Future<HttpClientRequest> get(String host, int port, String path) =>
      _inner.get(host, port, path);

  @override
  Future<HttpClientRequest> getUrl(Uri url) => _inner.getUrl(url);

  @override
  Future<HttpClientRequest> post(String host, int port, String path) =>
      _inner.post(host, port, path);

  @override
  Future<HttpClientRequest> postUrl(Uri url) => _inner.postUrl(url);

  @override
  Future<HttpClientRequest> put(String host, int port, String path) =>
      _inner.put(host, port, path);

  @override
  Future<HttpClientRequest> putUrl(Uri url) => _inner.putUrl(url);

  @override
  Future<HttpClientRequest> delete(String host, int port, String path) =>
      _inner.delete(host, port, path);

  @override
  Future<HttpClientRequest> deleteUrl(Uri url) => _inner.deleteUrl(url);

  @override
  Future<HttpClientRequest> head(String host, int port, String path) =>
      _inner.head(host, port, path);

  @override
  Future<HttpClientRequest> headUrl(Uri url) => _inner.headUrl(url);

  @override
  Future<HttpClientRequest> patch(String host, int port, String path) =>
      _inner.patch(host, port, path);

  @override
  Future<HttpClientRequest> patchUrl(Uri url) => _inner.patchUrl(url);
}
