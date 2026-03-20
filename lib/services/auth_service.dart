import 'api_service.dart';

class AuthService {
  static Future<void> registerUser(String email, String password) async {
    await ApiService.post(
      '/registerUser',
      body: {'email': email, 'password': password},
      requiresAuth: false,
    );
  }

  static Future<String> loginUser(String email, String password) async {
    final body = await ApiService.post(
      '/loginUser',
      body: {'email': email, 'password': password},
      requiresAuth: false,
    );
    final token = body['access_token'];
    if (token == null) {
      throw Exception('Login failed: access_token missing');
    }
    return token as String;
  }
}
