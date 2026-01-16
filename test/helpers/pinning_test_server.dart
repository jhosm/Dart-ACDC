import 'dart:convert';
import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as shelf_io;

/// A helper server for testing certificate pinning.
///
/// Starts a secure HTTPS server using the self-signed certificates
/// generated in `test/security/certs`.
class PinningTestServer {
  PinningTestServer({
    this.certPath = 'test/security/certs/server.crt',
    this.keyPath = 'test/security/certs/server.key',
  });
  HttpServer? _server;
  int? _port;
  final String certPath;
  final String keyPath;

  /// Starts the server on a random port.
  Future<void> start() async {
    final securityContext = SecurityContext()
      ..useCertificateChain(certPath)
      ..usePrivateKey(keyPath);

    final handler = const Pipeline()
        .addMiddleware(logRequests())
        .addHandler(_handleRequest);

    _server = await shelf_io.serve(
      handler,
      'localhost',
      0,
      securityContext: securityContext,
    );
    _port = _server!.port;
  }

  /// Stops the server.
  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _port = null;
  }

  String get baseUrl => 'https://localhost:$_port';

  Future<Response> _handleRequest(Request request) async => Response.ok(
        jsonEncode({'data': 'secure_data'}),
        headers: {'content-type': 'application/json'},
      );
}
