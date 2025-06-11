import 'dart:convert';
import 'package:http/http.dart' as http;

class AuthService {
  static const String baseUrl =
      'https://6848cad2942c78ae66042532--lovely-mochi-170b16.netlify.app/';

  static Future<String> registerUser(String email, String password) async {
    final response = await http.post(
      Uri.parse('$baseUrl/registerUser'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
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
      return jsonDecode(response.body)['token'];
    } else {
      throw Exception('Failed to login: ${response.body}');
    }
  }
}
