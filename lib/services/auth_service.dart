import 'api_service.dart';

class AuthService {
  /// Persists access + refresh tokens to secure storage. Throws if either token is missing in the response body.
  static Future<void> _storeTokens(Map<String, dynamic> body) async {
    final accessToken = body['access_token'];
    final refreshToken = body['refresh_token'];
    if (accessToken == null || refreshToken == null) {
      throw Exception('Auth failed: tokens missing');
    }
    await ApiService.setToken(accessToken);
    await ApiService.setToken(refreshToken, key: 'refresh_token');
  }

  /// Registers a new account and persists tokens. Returns `true` if the account is already email-verified (dev bypass), `false` if
  /// a verification code was sent.
  static Future<bool> registerUser(String email, String password) async {
    final body = await ApiService.post(
      '/registerUser',
      body: {'email': email, 'password': password},
      requiresAuth: false,
    );
    await _storeTokens(body);
    return body['email_verified'] ?? false;
  }

  /// Authenticates and persists tokens. Returns `email_verified` - callers should route unverified users to the verification page
  /// before HomeShell.
  static Future<bool> loginUser(String email, String password) async {
    final body = await ApiService.post(
      '/loginUser',
      body: {'email': email, 'password': password},
      requiresAuth: false,
    );
    await _storeTokens(body);
    return body['email_verified'] ?? false;
  }

  /// Invalidates the current session server-side via /logout and clears local tokens. Swallows network errors, local state is
  /// cleared regardless so the user always ends up logged out.
  static Future<void> logout() async {
    try {
      final refreshToken = await ApiService.getToken(key: 'refresh_token');

      if (refreshToken != null) {
        await ApiService.post(
          '/logout',
          body: {'refresh_token': refreshToken},
          requiresAuth: true,
        ).timeout(const Duration(seconds: 5));
      }
    } catch (_) {}
    await ApiService.clearToken();
    await ApiService.clearToken(key: 'refresh_token');
  }

  /// Submits a 6-digit verification code for the current user. Throws on invalid/expired code (surfaced as backend 400).
  static Future<void> verifyEmail(String code) async {
    await ApiService.post(
      '/verifyEmail',
      body: {'code': code},
      requiresAuth: true,
    );
  }

  /// Requests a fresh verification code for the current user. Backend enforces a 60s cooldown; throws 429 if called too soon.
  static Future<void> resendVerification() async {
    await ApiService.post('/resendVerification', requiresAuth: true);
  }

  /// Requests a password reset code by email. Always succeeds regardless of whether the email is registered (anti-enumeration).
  static Future<void> forgotPassword(String email) async {
    await ApiService.post(
      '/forgotPassword',
      body: {'email': email},
      requiresAuth: false,
    );
  }

  /// Submits a reset code + new password. Backend validates code, updates password, and invalidates all existing sessions (user
  /// must log in again).
  static Future<void> resetPassword(
    String email,
    String code,
    String newPassword,
  ) async {
    await ApiService.post(
      '/resetPassword',
      body: {'email': email, 'code': code, 'new_password': newPassword},
      requiresAuth: false,
    );
  }
}
