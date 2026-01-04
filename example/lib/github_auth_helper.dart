import 'package:dio/dio.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

// Helper class to handle GitHub OAuth flow with PKCE
class GitHubAuthHelper {
  final String clientId;
  final String redirectUrl;
  final List<String> scopes;

  GitHubAuthHelper({
    required this.clientId,
    required this.redirectUrl,
    this.scopes = const ['user', 'repo'],
  });

  /// Performs the OAuth login using PKCE and returns the access token.
  Future<String> authenticate() async {
    // 1. Generate PKCE Verifier and Challenge
    final codeVerifier = _generateCodeVerifier();
    final codeChallenge = _generateCodeChallenge(codeVerifier);

    // Determines the appropriate redirect URL
    String currentRedirectUrl = redirectUrl;
    if (kIsWeb) {
      // On Web, use the current origin + /callback.html
      // This requires window location access
      final origin = html.window.location.origin;
      currentRedirectUrl = '$origin/callback.html';
    }

    // 2. Construct the authorization URL
    final authUri = Uri.https('github.com', '/login/oauth/authorize', {
      'client_id': clientId,
      'redirect_uri': currentRedirectUrl,
      'scope': scopes.join(' '),
      'state': _generateRandomString(16),
      'code_challenge': codeChallenge,
      'code_challenge_method': 'S256',
    });

    // 3. Open browser for user to sign in
    // Note: For Web, ensure callback.html exists in web/ and redirects correctly.
    final result = await FlutterWebAuth2.authenticate(
      url: authUri.toString(),
      callbackUrlScheme: kIsWeb ? 'http' : Uri.parse(redirectUrl).scheme,
      options: const FlutterWebAuth2Options(windowName: 'dart_acdc_auth'),
    );

    // 4. Extract code from callback
    final code = Uri.parse(result).queryParameters['code'];
    if (code == null) {
      throw Exception('No code found in callback URL');
    }

    // 5. Exchange code for access token using Verifier
    return await _exchangeCodeForToken(code, codeVerifier, currentRedirectUrl);
  }

  Future<String> _exchangeCodeForToken(
    String code,
    String codeVerifier,
    String usedRedirectUrl,
  ) async {
    final dio = Dio();

    // GitHub returns XML by default unless Accept header is set
    // NOTE: This call will fail on Web Client due to CORS if not proxied.
    final response = await dio.post(
      'https://github.com/login/oauth/access_token',
      data: {
        'client_id': clientId,
        'code': code,
        'redirect_uri': usedRedirectUrl,
        'code_verifier': codeVerifier,
      },
      options: Options(headers: {'Accept': 'application/json'}),
    );

    final data = response.data;
    if (data['error'] != null) {
      final errorMsg = data['error_description'] ?? data['error'];
      throw Exception('OAuth Error: $errorMsg');
    }

    return data['access_token'];
  }

  // --- PKCE Helpers ---

  String _generateCodeVerifier() {
    return _generateRandomString(128);
  }

  String _generateCodeChallenge(String verifier) {
    final bytes = utf8.encode(verifier);
    final digest = sha256.convert(bytes);
    return _base64UrlEncode(digest.bytes);
  }

  String _generateRandomString(int length) {
    final random = Random.secure();
    final values = List<int>.generate(length, (i) => random.nextInt(256));
    return _base64UrlEncode(values);
  }

  String _base64UrlEncode(List<int> bytes) {
    return base64Url.encode(bytes).replaceAll('=', '');
  }
}
