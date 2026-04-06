import 'api_service.dart';

class AuthService {
  /// Private helper method to store tokens and handle missing tokens
  static Future<void> _storeTokens(Map<String, dynamic> body) async {
    final accessToken = body['access_token'];
    final refreshToken = body['refresh_token'];
    if (accessToken == null || refreshToken == null) {
      throw Exception('Auth failed: tokens missing');
    }
    await ApiService.setToken(accessToken);
    await ApiService.setToken(refreshToken, key: 'refresh_token');
  }

  static Future<void> registerUser(String email, String password) async {
    final body = await ApiService.post(
      '/registerUser',
      body: {'email': email, 'password': password},
      requiresAuth: false,
    );
    await _storeTokens(body);
  }

  static Future<void> loginUser(String email, String password) async {
    final body = await ApiService.post(
      '/loginUser',
      body: {'email': email, 'password': password},
      requiresAuth: false,
    );
    await _storeTokens(body);
  }
}
