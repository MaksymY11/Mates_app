import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../login_page.dart';

class ApiService {
  static final String baseUrl = kIsWeb
      ? 'https://mates-backend-dxma.onrender.com'
      : Platform.isAndroid
          ? 'http://10.0.2.2:8000'
          : 'http://localhost:8000';

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  // Gets the stored token from SharedPreferences
  static Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // Clears the token and redirects to login
  static Future<void> handleUnauthorized() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    navigatorKey.currentState?.pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (route) => false,
    );
  }

  // Authenticated GET request
  static Future<Map<String, dynamic>> get(String path) async {
    final token = await _getToken();
    final res = await http.get(
      Uri.parse('$baseUrl$path'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 401) {
      await handleUnauthorized();
      throw Exception('Session expired. Please log in again.');
    }

    if (res.statusCode != 200) {
      throw Exception('GET $path failed: ${res.body}');
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // Authenticated POST request
  static Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? body,
    bool requiresAuth = true,
  }) async {
    final headers = {'Content-Type': 'application/json'};

    if (requiresAuth) {
      final token = await _getToken();
      headers['Authorization'] = 'Bearer $token';
    }

    final res = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: headers,
      body: body != null ? jsonEncode(body) : null,
    );

    if (res.statusCode == 401) {
      await handleUnauthorized();
      throw Exception('Session expired. Please log in again.');
    }

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('POST $path failed: ${res.body}');
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // Authenticated DELETE request
  static Future<Map<String, dynamic>> delete(String path) async {
    final token = await _getToken();
    final res = await http.delete(
      Uri.parse('$baseUrl$path'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 401) {
      await handleUnauthorized();
      throw Exception('Session expired. Please log in again.');
    }

    if (res.statusCode != 200) {
      throw Exception('DELETE $path failed: ${res.body}');
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // Authenticated multipart file upload
  static Future<Map<String, dynamic>> uploadFile(
    String path, {
    required Uint8List bytes,
    required String filename,
    MediaType? contentType,
  }) async {
    final token = await _getToken();
    final uri = Uri.parse('$baseUrl$path');
    final req = http.MultipartRequest('POST', uri);
    req.headers['Authorization'] = 'Bearer $token';
    req.files.add(
      http.MultipartFile.fromBytes(
        'file',
        bytes,
        filename: filename,
        contentType: contentType ?? MediaType('image', 'jpeg'),
      ),
    );
    final streamed = await req.send();
    final res = await http.Response.fromStream(streamed);

    if (res.statusCode == 401) {
      await handleUnauthorized();
      throw Exception('Session expired. Please log in again.');
    }

    if (res.statusCode != 200) {
      throw Exception('Upload $path failed: ${res.body}');
    }

    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
