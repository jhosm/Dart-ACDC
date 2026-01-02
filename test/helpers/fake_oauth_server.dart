import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;

/// Simple fake OAuth server for integration tests.
///
/// Supports:
/// - Token refresh (POST /token with grant_type=refresh_token)
/// - Token revocation (POST /revoke)
/// - Configurable responses and errors
class FakeOAuthServer {
  HttpServer? _server;
  int? _port;

  // Configuration
  String _accessToken = 'new-access-token';
  String? _refreshToken = 'new-refresh-token';
  int _expiresIn = 3600;
  String? _oauthError;
  String? _oauthErrorDescription;
  int _responseStatusCode = 200;
  Duration _responseDelay = Duration.zero;

  // Request tracking
  final List<shelf.Request> receivedRequests = [];
  int refreshCallCount = 0;
  int revokeCallCount = 0;
  Map<String, String>? lastRefreshRequestParams;

  /// Starts the fake OAuth server on a random port.
  Future<void> start() async {
    final handler = const shelf.Pipeline()
        .addMiddleware(shelf.logRequests())
        .addHandler(_handleRequest);

    _server = await shelf_io.serve(handler, 'localhost', 0);
    _port = _server!.port;
  }

  /// Stops the fake OAuth server.
  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _port = null;
  }

  /// Gets the base URL for the server.
  String get baseUrl => 'http://localhost:$_port';

  /// Gets the token refresh endpoint URL.
  String get tokenUrl => '$baseUrl/token';

  /// Gets the token revocation endpoint URL.
  String get revokeUrl => '$baseUrl/revoke';

  /// Configures successful token refresh response.
  void respondWithSuccess({
    String accessToken = 'new-access-token',
    String? refreshToken = 'new-refresh-token',
    int expiresIn = 3600,
  }) {
    _accessToken = accessToken;
    _refreshToken = refreshToken;
    _expiresIn = expiresIn;
    _responseStatusCode = 200;
    _oauthError = null;
    _oauthErrorDescription = null;
  }

  /// Configures OAuth error response.
  void respondWithOAuthError({
    required String error,
    String? errorDescription,
    int statusCode = 400,
  }) {
    _oauthError = error;
    _oauthErrorDescription = errorDescription;
    _responseStatusCode = statusCode;
  }

  /// Configures server error response.
  void respondWithServerError({int statusCode = 500}) {
    _responseStatusCode = statusCode;
    _oauthError = null;
  }

  /// Adds a delay to all responses.
  void setResponseDelay(Duration delay) {
    _responseDelay = delay;
  }

  /// Resets all configuration to defaults.
  void reset() {
    receivedRequests.clear();
    refreshCallCount = 0;
    revokeCallCount = 0;
    lastRefreshRequestParams = null;
    respondWithSuccess();
    _responseDelay = Duration.zero;
  }

  Future<shelf.Response> _handleRequest(shelf.Request request) async {
    // Track request
    receivedRequests.add(request);

    // Add delay if configured
    if (_responseDelay > Duration.zero) {
      await Future<void>.delayed(_responseDelay);
    }

    // Route to appropriate handler
    if (request.url.path == 'token' && request.method == 'POST') {
      return _handleTokenRefresh(request);
    } else if (request.url.path == 'revoke' && request.method == 'POST') {
      return _handleTokenRevocation(request);
    }

    return shelf.Response.notFound('Not found');
  }

  Future<shelf.Response> _handleTokenRefresh(shelf.Request request) async {
    refreshCallCount++;

    // Parse request body
    final body = await request.readAsString();
    final params = Uri.splitQueryString(body);

    // Store params for test inspection
    lastRefreshRequestParams = params;

    // Validate request
    if (params['grant_type'] != 'refresh_token') {
      return _buildOAuthErrorResponse(
        'unsupported_grant_type',
        'Only refresh_token grant type is supported',
      );
    }

    if (params['refresh_token'] == null || params['refresh_token']!.isEmpty) {
      return _buildOAuthErrorResponse(
        'invalid_request',
        'Missing refresh_token parameter',
      );
    }

    // Return configured response
    if (_oauthError != null) {
      return _buildOAuthErrorResponse(_oauthError!, _oauthErrorDescription);
    }

    if (_responseStatusCode != 200) {
      return shelf.Response(
        _responseStatusCode,
        body: jsonEncode({'error': 'server_error'}),
        headers: {'content-type': 'application/json'},
      );
    }

    // Success response
    final responseData = <String, dynamic>{
      'access_token': _accessToken,
      'token_type': 'Bearer',
      'expires_in': _expiresIn,
    };

    if (_refreshToken != null) {
      responseData['refresh_token'] = _refreshToken;
    }

    return shelf.Response.ok(
      jsonEncode(responseData),
      headers: {
        'content-type': 'application/json',
        'date': HttpDate.format(DateTime.now().toUtc()),
      },
    );
  }

  Future<shelf.Response> _handleTokenRevocation(shelf.Request request) async {
    revokeCallCount++;

    // Parse request body
    final body = await request.readAsString();
    final params = Uri.splitQueryString(body);

    // Validate request
    if (params['token'] == null || params['token']!.isEmpty) {
      return shelf.Response(
        400,
        body: jsonEncode({
          'error': 'invalid_request',
          'error_description': 'Missing token parameter',
        }),
        headers: {'content-type': 'application/json'},
      );
    }

    // Return configured response
    if (_responseStatusCode != 200) {
      return shelf.Response(_responseStatusCode);
    }

    // Success - RFC 7009 says revocation endpoint returns 200 OK
    return shelf.Response.ok('');
  }

  shelf.Response _buildOAuthErrorResponse(
    String error,
    String? errorDescription,
  ) {
    final responseData = <String, dynamic>{'error': error};
    if (errorDescription != null) {
      responseData['error_description'] = errorDescription;
    }

    return shelf.Response(
      _responseStatusCode,
      body: jsonEncode(responseData),
      headers: {'content-type': 'application/json'},
    );
  }
}
