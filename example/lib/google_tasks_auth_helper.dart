import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

// Helper class to handle Google OAuth 2.0 Implicit Flow
// (Preferred for Client-Side Web Apps without a backend proxy)
class GoogleTasksAuthHelper {
  final String clientId;
  final String redirectUrl;
  final List<String> scopes;

  GoogleTasksAuthHelper({
    required this.clientId,
    required this.redirectUrl,
    this.scopes = const ['https://www.googleapis.com/auth/tasks.readonly'],
  });

  /// Performs the OAuth login using Implicit Flow (Token Flow)
  Future<String> authenticate() async {
    // Determines the appropriate redirect URL
    String currentRedirectUrl = redirectUrl;
    if (kIsWeb) {
      final origin = html.window.location.origin;
      currentRedirectUrl = '$origin/callback.html';
    }

    // 2. Construct the authorization URL
    // https://accounts.google.com/o/oauth2/v2/auth
    // Note: response_type = token
    final authUri = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
      'client_id': clientId,
      'redirect_uri': currentRedirectUrl,
      'response_type': 'token', // IMPLICIT FLOW
      'scope': scopes.join(' '),
      // 'state': ..., // Optional but good practice
      // No PKCE params needed for Implicit Flow (though Code+PKCE is better if supported properly by provider without secret)
    });

    // 3. Open browser for user to sign in
    final result = await FlutterWebAuth2.authenticate(
      url: authUri.toString(),
      callbackUrlScheme: kIsWeb ? 'http' : Uri.parse(redirectUrl).scheme,
      options: const FlutterWebAuth2Options(
        windowName: 'dart_acdc_google_auth',
      ),
    );

    // 4. Extract access_token from Fragment (#)
    // FlutterWebAuth2 returns the full URL (or callback scheme URI)
    // Implicit flow returns: http://localhost:3000/callback.html#access_token=...&token_type=Bearer...

    // We need to parse the Fragment, not query params.
    // However, flutter_web_auth_2 on web might return it differently depending on how the callback handled it.
    // Our generic callback.html sends `window.location.href`.

    final uri = Uri.parse(result);
    // The fragment is usually where the token is. But Uri.parse might not parse fragment params automatically into a map.

    String? accessToken;

    // Check fragment first
    if (uri.fragment.isNotEmpty) {
      final params = Uri.splitQueryString(uri.fragment);
      accessToken = params['access_token'];
    }

    // Fallback: Check query (sometimes redirected as query if specific server config, but standard is fragment)
    accessToken ??= uri.queryParameters['access_token'];

    if (accessToken == null) {
      throw Exception('No access_token found in callback URL: $result');
    }

    return accessToken;
  }
}
