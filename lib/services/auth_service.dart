import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  static const String baseUrl = 'https://mates-backend-dxma.onrender.com';

  static Future<String> registerUser(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/registerUser'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return "Success";
    } else {
      throw Exception('Failed to register: ${response.body}');
    }
  }

  static Future<String> loginUser(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/loginUser'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> body = jsonDecode(response.body);
      final token = body['access_token'];
      if (token == null) {
        throw Exception('Login Failed: access_token missing');
      }
      return token;
    } else {
      try {
        final Map<String, dynamic> body = jsonDecode(response.body);
        final detail = body['detail'] ?? 'Unknown error';
        throw Exception('Failed to login: $detail');
      } catch (e) {
        throw Exception('Failed to parse error response: $e');
      }
    }
  }
}
